
## Step 4 - service-linked role
- Role already existed in the account (create returned InvalidInput, "name has been taken").
- Real name on this build: AWSServiceRoleForEcsApplicationAutoscaling, not the lab's AWSServiceRoleForApplicationAutoScaling_ECSService.
- Path /aws-service-role/ecs.application-autoscaling.amazonaws.com/ and trust principal verified.
- No attached policies listed (Floci limitation; role is a record, nothing assumes it).
- TODO: Step 16 hardcodes the lab's name for USMS_ASA_SLR; change it to the real name.

## Step 5 - scalable target
- RID derived from service ARN: service/usms-ecs-cluster/usms-enrolment-svc (3 segments, OK). Lab 04 Exercise 5 had not recorded one.
- Registered min 2 / max 10; service stayed at desired 2 (no-op inside bounds).
- Role field shows AWSServiceRoleForApplicationAutoScaling_ECSService, which get-role says does not exist. Floci fills in the lab's name without validating it.

## Step 6 - bounds and re-registration
- Re-registered with only --max-capacity 12: min stayed 2 (omitted parameter keeps its old value). Put back to 2/10, exactly one scalable target.
- Your turn: set min 5 with service at 2 tasks. Polled 6 x 5s: desired stayed 2/2/0, describe-scaling-activities length 0.
- Result: this build does NOT enforce MinCapacity against desiredCount (real AWS would raise desired to 5 within seconds). Support path looks like B (control plane only).
- (a) On real AWS the scalable target made the change: it enforces its bounds by calling ECS UpdateService through the service-linked role. No policy, no alarm.
- (b) A forgotten MinCapacity of 5 means you pay for 5 tasks around the clock and scale-in can never go below it. describe-scalable-targets would reveal it, since a monitor can compare MinCapacity with the expected 2.

## Step 7 - CPU target tracking policy
- Policy usms-enrolment-cpu-target-tracking created: target 50.0, cooldowns 60/300, DisableScaleIn false.
- Policy ARN uses the autoscaling namespace and embeds the resource ID.
- Floci DID create the two managed alarms (AlarmHigh and AlarmLow) as a side effect.

## Step 8 - managed alarms
- 2 alarms found (count 2); both AlarmActions equal the CPU policy ARN.
- Evals: High 3, Low 15, Period 60 (as in the lab).
- Floci differences: MetricName shows ECSServiceAverageCPUUtilization (real AWS: CPUUtilization); Low threshold is 50.0 (real AWS: below target, giving a dead band).
- Time to third task at 100% CPU = 60x3 (180) + ~0 invocation + task start-up (from Lab 04 Ex 5) + 60 grace = 240 s + start-up.
- First term I would change: [choose one, and state its cost].

## Step 9 - request-count policy
- ResourceLabel derived from API (no Lab 05 label recorded): app/usms-enrolment-alb/9799cbb555ad438f/targetgroup/usms-enrolment-tg/109124adae3d4860 (6 segments, OK).
- Policy usms-enrolment-requests-target-tracking created, target 1000 requests per target per minute (provisional until a load test).
- Two policies, 2 managed alarms each, 4 in total.
- Rule: scale out takes the LARGEST request from any policy; scale in only when EVERY policy agrees.

## Step 10 - step scaling policy and alarm
- Published EnrolmentQueueDepth (3, 5, 4); list-metrics shows it with Service=enrolment.
- Policy usms-enrolment-queue-step-out: StepScaling, ChangeInCapacity, Average, cooldown 60; steps 0-100 -> +1, 100+ -> +3 (open-ended top).
- Alarm usms-enrolment-queue-high: >= 100, period 60, 1 eval, notBreaching; AlarmActions holds the step policy ARN. State OK.
- Floci difference: the policy's Alarms list is EMPTY (no back-link from a hand-made alarm), unlike the managed alarms. Forward link alarm -> policy is present.

## Step 11 - scheduled actions
- put-scheduled-action returns UnsupportedOperation on this Floci build, with and without --timezone, so the UTC fallback failed too. Not a timezone or syntax problem.
- describe-scheduled-actions answers (empty list), so Step 3's probe showed SUPPORTED for the read while the write is unsupported.
- Consequence: no scheduled actions exist. The "Your turn" at() action cannot be created either. Instructor told: [yes/no].
- Intended design (for the write-up): morning cron(45 7 ? * MON-FRI *) Asia/Thimphu min 4 max 10 (UTC equivalent 01:45); evening cron(0 20 ? * MON-FRI *) min 2 max 10 (UTC 14:00).

## Step 12 - firing the alarm
- Path A: this build evaluates alarms. Alarm went to ALARM by itself ("Threshold Crossed: 1 datapoint(s)"), then I also forced it with set-alarm-state (not needed).
- desiredCount 2 -> 5 -> 8 -> 10 in three activities 10s apart; Cause names alarm usms-enrolment-queue-high and policy usms-enrolment-queue-step-out. Detail is null.
- Floci difference: the 60s step cooldown is not honoured, so a persistent ALARM re-fires every ~10s until the ceiling (10). Real AWS would add +3 once per cooldown.
- Step 6 finding stands: raising MinCapacity did not move desiredCount, even though alarm-driven scaling does.
- Earlier note "path B" is superseded: path A for alarms; scheduled actions unsupported (Step 11).

## Step 13 - suspend and resume
- Suspended scale-in only via register-scalable-target --suspended-state (file://templates/lab-06-suspended-state.json). Bounds stayed 2/10.
- Resumed with shorthand; grep -ci true returned 0.

## Steps 11 and 14 - scheduled actions
- describe-scheduled-actions also returns UnsupportedOperation (not just put-scheduled-action). Step 3's probe said SUPPORTED for the read, which was wrong for this build.
- Step 14: pre-restart file rebuilt from the terminal capture after a paste error; scheduled actions omitted from the comparison.
- Expect verify-lab-06.sh to fail the 3 scheduled-action checks (and possibly more, since it calls the same unsupported API).

## Step 14 - persistence diff
- First diff failed on every line but the text was identical: the hand-rebuilt pre file had LF endings, the CLI output has CRLF (Windows Git Bash).
- Re-compared with tr -d '\r': PROVEN. Pre file was rebuilt from the terminal capture, not generated by the CLI before restart.

## Step 15 - trace
- Blocks 1-3 are this lab (alarm, policies, target); blocks 4-6 are Labs 04/05, unchanged; block 7 is :2, 1 LB, 1 deployment.
- healthCheckGracePeriodSeconds is None (lab expects 60). Cause: Lab 05 Step 10 never applied it (USMS_SVC_GRACE_PERIOD is None in the env file too, so not a restart loss). Time-to-third-task earlier assumed 60 s grace, so the total is 180 + start-up + 0.
- Floci: request-count alarm shows namespace AWS/ECS and metric ALBRequestCountPerTarget; target AZ is None.

## Step 17 - commit
- scripts/cleanup/lab-04-cleanup.sh and lab-05-cleanup.sh do not exist in my repo, so the hint-string repair was skipped.
- verify-lab-06.sh and lab-06-cleanup.sh are not created yet; they come with Section 8 and the cleanup section.
