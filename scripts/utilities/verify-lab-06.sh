#!/usr/bin/env bash
# Verify Lab 06 artefacts. Read-only. Exit 0 if every check passes.
# Scheduled-action checks are omitted: unsupported on this Floci build.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
for n in 01 02 03 04 05 06; do source "$REPO_ROOT/configs/lab-$n.env" 2>/dev/null || true; done

: "${USMS_PRIVATE_SUBNET_A:=none}"
: "${USMS_PRIVATE_SUBNET_B:=none}"
: "${USMS_ECS_CLUSTER:=usms-ecs-cluster}"
: "${USMS_ENROLMENT_SERVICE:=usms-enrolment-svc}"
: "${USMS_ECS_DESIRED_BASELINE:=2}"
: "${USMS_TG_NAME:=usms-enrolment-tg}"
: "${USMS_POLICY_CPU_TT:=usms-enrolment-cpu-target-tracking}"
: "${USMS_POLICY_STEP_OUT:=usms-enrolment-queue-step-out}"
: "${USMS_ALARM_QUEUE_HIGH:=usms-enrolment-queue-high}"
: "${USMS_METRIC_NAMESPACE:=USMS/Enrolment}"
: "${USMS_METRIC_NAME:=EnrolmentQueueDepth}"

EXPECTED_RID="service/${USMS_ECS_CLUSTER}/${USMS_ENROLMENT_SERVICE}"
SVC_ARN=$(aws ecs describe-services --cluster "$USMS_ECS_CLUSTER" --services "$USMS_ENROLMENT_SERVICE" --query 'services[0].serviceArn' --output text 2>/dev/null | tr -d '\r')
RID="${SVC_ARN##*:}"
[ -n "$RID" ] || RID="$EXPECTED_RID"

PASS=0; FAIL=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf "  ok   %s\n" "$1"; PASS=$((PASS+1))
  else printf "  FAIL %s\n" "$1"; FAIL=$((FAIL+1)); fi
}
tgt()  { aws application-autoscaling describe-scalable-targets --service-namespace ecs --resource-ids "$RID" --query "ScalableTargets[0].$1" --output text | tr -d '\r'; }
pol()  { aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id "$RID" --policy-names "$1" --query "ScalingPolicies[0].$2" --output text | tr -d '\r'; }
svcq() { aws ecs describe-services --cluster "$USMS_ECS_CLUSTER" --services "$USMS_ENROLMENT_SERVICE" --query "services[0].$1" --output text | tr -d '\r'; }
alm()  { aws cloudwatch describe-alarms --alarm-names "$USMS_ALARM_QUEUE_HIGH" --query "MetricAlarms[0].$1" --output text | tr -d '\r'; }

echo "== Environment =="
check "AWS CLI reaches Floci" "aws sts get-caller-identity"
check "Account is 000000000000" 'test "$(aws sts get-caller-identity --query Account --output text | tr -d "\r")" = 000000000000'

echo "== Lab 02 to 05 dependencies =="
check "cluster is ACTIVE" 'test "$(aws ecs describe-clusters --clusters $USMS_ECS_CLUSTER --query clusters[0].status --output text | tr -d "\r")" = ACTIVE'
check "service is ACTIVE" 'test "$(svcq status)" = ACTIVE'
check "service has exactly ONE loadBalancers entry" 'test "$(svcq "length(loadBalancers)")" = 1'
check "target group has target type ip" 'test "$(aws elbv2 describe-target-groups --names $USMS_TG_NAME --query TargetGroups[0].TargetType --output text | tr -d "\r")" = ip'

echo "== Lab 06 scalable target =="
check "exactly ONE scalable target" 'test "$(aws application-autoscaling describe-scalable-targets --service-namespace ecs --query "length(ScalableTargets)" --output text | tr -d "\r")" = 1'
check "resource ID is $EXPECTED_RID" 'test "$(tgt ResourceId)" = "$EXPECTED_RID"'
check "dimension is ecs:service:DesiredCount" 'test "$(tgt ScalableDimension)" = ecs:service:DesiredCount'
check "MinCapacity is the baseline" 'test "$(tgt MinCapacity)" = "$USMS_ECS_DESIRED_BASELINE"'
check "MaxCapacity is 10" 'test "$(tgt MaxCapacity)" = 10'
check "NO suspension switch left true" 'test "$(tgt "SuspendedState.*" | grep -ci true)" = 0'

echo "== Lab 06 scaling policies =="
check "CPU policy is TargetTrackingScaling" 'test "$(pol $USMS_POLICY_CPU_TT PolicyType)" = TargetTrackingScaling'
check "CPU policy metric is ECSServiceAverageCPUUtilization" 'test "$(pol $USMS_POLICY_CPU_TT TargetTrackingScalingPolicyConfiguration.PredefinedMetricSpecification.PredefinedMetricType)" = ECSServiceAverageCPUUtilization'
check "CPU target value is 50" 'test "$(pol $USMS_POLICY_CPU_TT TargetTrackingScalingPolicyConfiguration.TargetValue | cut -d. -f1)" = 50'
check "cooldowns 60 and 300" 'test "$(pol $USMS_POLICY_CPU_TT TargetTrackingScalingPolicyConfiguration.ScaleOutCooldown)" = 60 && test "$(pol $USMS_POLICY_CPU_TT TargetTrackingScalingPolicyConfiguration.ScaleInCooldown)" = 300'
check "step policy is StepScaling" 'test "$(pol $USMS_POLICY_STEP_OUT PolicyType)" = StepScaling'
check "step policy has 2+ steps and an open-ended top" 'test "$(pol $USMS_POLICY_STEP_OUT "length(StepScalingPolicyConfiguration.StepAdjustments)")" -ge 2 && test "$(pol $USMS_POLICY_STEP_OUT "StepScalingPolicyConfiguration.StepAdjustments[-1].MetricIntervalUpperBound")" = None'

echo "== Lab 06 alarms =="
check "custom alarm exists" 'test "$(alm AlarmName)" = "$USMS_ALARM_QUEUE_HIGH"'
check "alarm watches the custom metric" 'test "$(alm Namespace)" = "$USMS_METRIC_NAMESPACE" && test "$(alm MetricName)" = "$USMS_METRIC_NAME"'
check "alarm INVOKES the step policy" 'alm "AlarmActions[]" | grep -q "policyName/$USMS_POLICY_STEP_OUT"'
check "target tracking made 2+ managed alarms" 'test "$(aws cloudwatch describe-alarms --alarm-name-prefix "TargetTracking-$RID" --query "length(MetricAlarms)" --output text | tr -d "\r")" -ge 2'

echo "== Lab 06 service state =="
check "desiredCount inside the bounds" 'test "$(svcq desiredCount)" -ge "$(tgt MinCapacity)" && test "$(svcq desiredCount)" -le "$(tgt MaxCapacity)"'
check "desiredCount is back at the baseline" 'test "$(svcq desiredCount)" = "$USMS_ECS_DESIRED_BASELINE"'
check "exactly ONE deployment" 'test "$(svcq "length(deployments)")" = 1'

echo "== Lab 06 custom metric =="
check "custom namespace has a metric" 'test "$(aws cloudwatch list-metrics --namespace "$USMS_METRIC_NAMESPACE" --query "length(Metrics)" --output text | tr -d "\r")" -ge 1'

echo "== Files and Git hygiene =="
check "configs/lab-06.env exists" "test -f configs/lab-06.env"
check "env file has no empty values or None" '! grep -qE "export [A-Z_]+=\$|=None\$" configs/lab-06.env'
check "scheduled-action names recorded in env file" 'grep -q USMS_SCHEDULED_OUT configs/lab-06.env && grep -q USMS_SCHEDULED_IN configs/lab-06.env'
check "cpu document is valid JSON" "python3 -m json.tool templates/lab-06-target-tracking-cpu.json"
check "requests document is valid JSON" "python3 -m json.tool templates/lab-06-target-tracking-requests.json"
check "step document is valid JSON" "python3 -m json.tool templates/lab-06-step-scaling-out.json"
check "suspended document does not suspend scale-out" "python3 -c \"import json,sys;d=json.load(open('templates/lab-06-suspended-state.json'));sys.exit(0 if d.get('DynamicScalingOutSuspended') is False else 1)\""
check "no Lab 06 document has an unexpanded variable" '! grep -l "[$]" templates/lab-06-*.json'
check "no outputs/ file tracked by git" '! git ls-files | grep -q "^outputs/"'

echo; echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
