#!/usr/bin/env bash
# Verify every Lab 10 artefact exists AND is configured for the edge.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
source "$REPO_ROOT/configs/lab-01.env" 2>/dev/null || true
source "$REPO_ROOT/configs/lab-10.env" 2>/dev/null || true
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL_OVERRIDE:-http://localhost:4566}"

BUCKET="${USMS_BUCKET_NAME:-usms-student-data}"
ROLE_NAME="${USMS_ROLE_LAMBDA:-usms-lambda-exec-role}"
ROLE_NAME="${ROLE_NAME##*/}"
VIEWER=usms-edge-viewer-request
ORIGIN=usms-edge-origin-response
NOTIFIER=usms-transcript-notifier
DIST_CFG=templates/lab-10-distribution-config.json

PASS=0; FAIL=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf "  ok   %s\n" "$1"; PASS=$((PASS+1))
  else printf "  FAIL %s\n" "$1"; FAIL=$((FAIL+1)); fi
}

fn_field() { aws lambda get-function-configuration --function-name "$1" --query "$2" --output text; }
fn_env_count() {
  aws lambda get-function-configuration --function-name "$1" --output json 2>/dev/null \
    | python3 -c 'import json,sys; c=json.load(sys.stdin); print(len((c.get("Environment") or {}).get("Variables") or {}))'
}
fn_version_count() { aws lambda list-versions-by-function --function-name "$1" --query 'length(Versions)' --output text; }
role_principals() {
  aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.AssumeRolePolicyDocument.Statement[].Principal.Service' --output json
}
notifier_policy() { aws lambda get-policy --function-name "$NOTIFIER" --qualifier live --query 'Policy' --output text; }
notif() { aws s3api get-bucket-notification-configuration --bucket "$BUCKET" --output text; }

echo "== Environment =="
check "AWS CLI reaches Floci" 'aws sts get-caller-identity'
echo "== Origin bucket =="
check "bucket exists" 'aws s3api head-bucket --bucket "$BUCKET"'
check "bucket tagged Project=USMS" 'aws s3api get-bucket-tagging --bucket "$BUCKET" --output text | grep -q USMS'
check "object under transcripts/" 'test "$(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix transcripts/ --query "length(Contents)" --output text)" != "None"'
echo "== Execution role =="
check "role exists" 'aws iam get-role --role-name "$ROLE_NAME"'
check "trusts lambda.amazonaws.com" 'role_principals | grep -q "lambda.amazonaws.com"'
check "trusts edgelambda.amazonaws.com" 'role_principals | grep -q "edgelambda.amazonaws.com"'
check "USMSLambdaBasic attached" 'aws iam list-attached-role-policies --role-name "$ROLE_NAME" --output text | grep -q USMSLambdaBasic'
echo "== Edge function 1: viewer-request =="
check "exists" 'aws lambda get-function-configuration --function-name "$VIEWER"'
check "runtime node or python" 'fn_field "$VIEWER" Runtime | grep -qE "^(nodejs|python)"'
check "handler index.handler" 'test "$(fn_field "$VIEWER" Handler)" = index.handler'
check "memory <= 128" 'test "$(fn_field "$VIEWER" MemorySize)" -le 128'
check "timeout <= 5" 'test "$(fn_field "$VIEWER" Timeout)" -le 5'
check "no environment variables" 'test "$(fn_env_count "$VIEWER")" -eq 0'
check "published version exists" 'test "$(fn_version_count "$VIEWER")" -ge 2'
echo "== Edge function 2: origin-response =="
check "exists" 'aws lambda get-function-configuration --function-name "$ORIGIN"'
check "runtime node or python" 'fn_field "$ORIGIN" Runtime | grep -qE "^(nodejs|python)"'
check "memory <= 128" 'test "$(fn_field "$ORIGIN" MemorySize)" -le 128'
check "no environment variables" 'test "$(fn_env_count "$ORIGIN")" -eq 0'
check "published version exists" 'test "$(fn_version_count "$ORIGIN")" -ge 2'
echo "== Regional function: notifier =="
check "exists" 'aws lambda get-function-configuration --function-name "$NOTIFIER"'
check "handler notifier.handler" 'test "$(fn_field "$NOTIFIER" Handler)" = notifier.handler'
check "HAS environment variables" 'test "$(fn_env_count "$NOTIFIER")" -ge 1'
check "alias live exists" 'aws lambda get-alias --function-name "$NOTIFIER" --name live'
check "alias live is a numbered version" 'aws lambda get-alias --function-name "$NOTIFIER" --name live --query FunctionVersion --output text | grep -qE "^[0-9]+$"'
check "policy allows s3.amazonaws.com" 'notifier_policy | grep -q "s3.amazonaws.com"'
check "policy scoped to this bucket" 'notifier_policy | grep -q "$BUCKET"'
echo "== S3 notification =="
check "notification exists" 'notif | grep -q usms-transcript-upload'
check "targets live alias" 'notif | grep -q "function:$NOTIFIER:live"'
check "filtered to transcripts/" 'notif | grep -q "transcripts/"'
echo "== CloudFront config =="
check "config file valid JSON" 'python3 -m json.tool "$DIST_CFG"'
check "viewer-request ARN is version-qualified" 'grep -E "usms-edge-viewer-request:[0-9]+\"" "$DIST_CFG"'
check "origin-response ARN is version-qualified" 'grep -E "usms-edge-origin-response:[0-9]+\"" "$DIST_CFG"'
check "distribution exists in Floci" 'aws cloudfront list-distributions --query "DistributionList.Items[].Comment" --output text | grep -q usms-transcript-cdn'
echo "== Source, scripts and Git hygiene =="
check "viewer source exists" 'test -f labs/lab-10-lambda-edge/edge-viewer-request/index.mjs'
check "origin source exists" 'test -f labs/lab-10-lambda-edge/edge-origin-response/index.mjs'
check "notifier source exists" 'test -f labs/lab-10-lambda-edge/transcript-notifier/notifier.py'
check "viewer kept its template literal" 'grep -q "studentId.toLowerCase()}" labs/lab-10-lambda-edge/edge-viewer-request/index.mjs'
check "simulate script valid" 'bash -n scripts/utilities/usms-edge-simulate.sh'
check "edge trace has 3 stages" 'python3 -c "import json;print(len(json.load(open(\"outputs/lab-10-edge-trace.json\"))[\"chain\"]))" | grep -q 3'
check "lab-10.env has 25 exports" 'test "$(grep -c "^export" configs/lab-10.env)" -eq 25'
check "no empty values in lab-10.env" '! grep -qE "^export [A-Z_]+=$" configs/lab-10.env'
check "no outputs/ file tracked (except .gitkeep)" '! git ls-files | grep "^outputs/" | grep -qv ".gitkeep"'
check "no zip tracked" '! git ls-files | grep -q "\.zip$"'

echo; echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
