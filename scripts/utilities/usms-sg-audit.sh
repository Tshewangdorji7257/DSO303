#!/usr/bin/env bash
# USMS security group audit. Reports findings; changes nothing.
# Exit 0 if there are no HIGH findings, 1 otherwise.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env" 2>/dev/null || true
source "$REPO_ROOT/configs/lab-02.env" 2>/dev/null || true

VPC="${1:-${USMS_VPC_ID:-}}"
if [ -z "$VPC" ] || [ "$VPC" = "none" ]; then
  echo "usage: $0 [vpc-id]" >&2
  exit 2
fi

SG_JSON="/tmp/usms-sg-audit-$$.json"
ENI_TXT="/tmp/usms-sg-enis-$$.txt"

aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" --output json \
  > "$SG_JSON" || { echo "cannot read security groups" >&2; exit 2; }

for g in $(python3 -c "
import json,sys
print(' '.join(s['GroupId'] for s in json.load(open(sys.argv[1]))['SecurityGroups']))
" "$SG_JSON"); do
  n=$(aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$g" \
        --query 'length(NetworkInterfaces)' --output text 2>/dev/null || echo 0)
  echo "$g $n"
done > "$ENI_TXT"

python3 scripts/utilities/usms-sg-audit.py "$SG_JSON" "$ENI_TXT"
rc=$?
rm -f "$SG_JSON" "$ENI_TXT"
exit $rc
