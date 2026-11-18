# Lab 13: Centralized Logging and Monitoring with CloudWatch and X-Ray

## 1. Aim / Objective

To build a centralized logging and monitoring layer for the University Student Management System (USMS) using Amazon CloudWatch (Logs, Metrics, Alarms, Dashboards) and AWS X-Ray, and to verify it with the AWS CLI. The specific objectives were to:

- create a central log group and apply retention policies,
- turn log lines into metrics with metric filters,
- publish custom metrics with dimensions,
- grant least-privilege IAM permissions for telemetry,
- instrument an AWS Lambda function and enable active tracing,
- create alarms (including one that detects silence) and a dashboard,
- prove that the configuration persisted across a restart.

## 2. Introduction

Amazon CloudWatch is the AWS observability service. It collects logs (text events grouped into log groups and streams), metrics (numeric time series identified by namespace, name and dimensions), alarms (rules that watch a metric and hold a state) and dashboards (JSON-defined widgets). AWS X-Ray complements it by recording traces, which follow a single request through several services as segments and subsegments. Together they let engineers see what a system did, how well it performed and where a request slowed down or failed. This matters in cloud computing because distributed systems cannot be debugged by logging in to one server. Typical applications include error and latency alerting, capacity monitoring, incident detection and root-cause analysis.

## 3. Use Case

- Collecting application logs from Lambda, ECS and EC2 into one searchable place with controlled retention (for cost and compliance).
- Converting log events into metrics, for example counting transcript notifications or errors.
- Alerting operations staff when latency is high or when a pipeline goes silent.
- Building a dashboard so a non-expert can see whether the transcript system is healthy in seconds.
- Tracing a request across services to find which step is slow.

## 4. System Architecture / Design

```mermaid
flowchart LR
    U[Student / Upload to S3] --> S3[(S3: usms-student-data)]
    S3 -->|event via alias live| L[Lambda: usms-transcript-notifier v4]
    L -->|USMS_NOTIFY and USMS_SUMMARY logs| LG1[CloudWatch Logs: /aws/lambda/usms-transcript-notifier]
    E[Emitter script] -->|USMS_EVENT logs| LG2[CloudWatch Logs: /usms/central/application]
    LG1 -->|metric filter| M[CloudWatch Metrics: USMS/Application]
    LG2 -->|metric filter| M
    L -->|put-metric-data| M
    E -->|put-metric-data| M
    M --> A[Alarms: lag-high and notify-silence]
    M --> D[Dashboard: usms-overview]
    L -.->|trace segments| X[X-Ray - documents only on this build]
    IAM[IAM policy: USMSObservabilityWrite] -.->|permits| L
```
![alt text](<aws-architecture-diagram (8).png>)

**Data flow:** an S3 upload triggers the notifier through the `live` alias. The function writes logs and publishes metrics. Metric filters convert matching log lines into metrics in `USMS/Application`. Alarms and the dashboard read those metrics. X-Ray segment documents were built by hand because the X-Ray API was not available on the emulator.

## 5. Implementation Procedure

| Step | Action performed |
|---|---|
| 1 | Started Floci and ran the storage check (hybrid mode, all checks passed). |
| 2 | Sourced the earlier lab environment files and confirmed the identity. Fixed the endpoint (`localhost.floci.io` did not resolve) by setting `http://localhost:4566`. |
| 3 | Created the lab directories. |
| 4 | Probed which features this Floci build supported (Insights and X-Ray were unsupported). |
| 5 | Took an inventory of existing log groups, alarms, metrics and dashboards. |
| 6 | Created `/usms/central/application` and set retention (30 days for application and ECS groups, 14 days for Lambda groups). Set `MSYS_NO_PATHCONV=1` after Git Bash corrupted a log group name. |
| 7 | Wrote five log events from a JSON file, including one non-matching line. |
| 8 | Tested the filter patterns `USMS_NOTIFY` and `ERROR`, and examined a false positive. |
| 9 | Deployed the metric filters `usms-notify-count` and `usms-central-errors`. |
| 10 | Uploaded an object, invoked the notifier and read `NotifyCount` back (Sum 2.0). Compared with an earlier window (empty). |
| 11 | Published custom metrics with and without dimensions. |
| 12 | Created and attached the `USMSObservabilityWrite` IAM policy to the Lambda and EC2 roles. |
| 13 | Deployed the instrumented notifier (version 3), repointed alias `live`, and tested rollback and roll-forward. |
| 14 | Enabled active tracing and published version 4. |
| 15 to 16 | Built X-Ray parent, subsegment and downstream documents and validated them structurally. |
| 17 | Wrote an emitter script that sent one log, two metrics and one trace document per run. |
| 18 | Wrote an X-Ray sampling rule document. |
| 19 | Created two alarms: `usms-transcript-lag-high` and `usms-notify-silence`. |
| 20 | Forced an alarm state change and restored it. |
| 21 | Attempted a composite alarm and saved the rule as a document. |
| 22 | Created the `usms-overview` dashboard (5 widgets). |
| 23 | Counted events by faculty using `filter-log-events` and Python. |
| 24 | Restarted Floci and compared the configuration before and after. |
| 25 | Wrote `configs/lab-13.env` (28 exports). |
| 26 | Committed the work to Git and ran `verify-lab-13.sh`. |

## 6. Results and Evidence

### 6.1 CLI / SDK Output

**Environment and discovery (Steps 1 to 5)**

![Step 1](../../screenshots/lab13/image.png)
![Step 2](../../screenshots/lab13/image-1.png)
![Step 2 identity](../../screenshots/lab13/image-3.png)
![Step 2 variable checks](../../screenshots/lab13/image-4.png)
![Step 3](../../screenshots/lab13/image-2.png)
![Step 4 support probe](../../screenshots/lab13/image-5.png)
![Step 5 inventory](../../screenshots/lab13/image-6.png)
![Step 5 inventory continued](../../screenshots/lab13/image-7.png)

**Logs and filters (Steps 6 to 10)**

![Step 6 central log group](../../screenshots/lab13/image-8.png)
![Step 6 retention](../../screenshots/lab13/image-9.png)
![Step 6 verification](../../screenshots/lab13/image-10.png)
![Step 7 log events](../../screenshots/lab13/image-11.png)
![Step 7 verification](../../screenshots/lab13/image-12.png)
![Step 8 USMS_NOTIFY filter test](../../screenshots/lab13/image-13.png)
![Step 8 retention fix](../../screenshots/lab13/image-14.png)
![Step 8 ERROR pattern](../../screenshots/lab13/image-15.png)
![Step 8 false positive](../../screenshots/lab13/image-16.png)
![Step 9 metric filters](../../screenshots/lab13/image-17.png)
![Step 9 verification](../../screenshots/lab13/image-18.png)
![Step 10 perturb](../../screenshots/lab13/image-19.png)
![Step 10 metric read-back](../../screenshots/lab13/image-20.png)
![Step 10 supporting output](../../screenshots/lab13/image-21.png)
![Step 10 earlier window](../../screenshots/lab13/image-22.png)

**Metrics and IAM (Steps 11 to 12)**

![Step 11 shorthand](../../screenshots/lab13/image-23.png)
![Step 11 JSON](../../screenshots/lab13/image-24.png)
![Step 11 verification](../../screenshots/lab13/image-25.png)
![Step 11 window recomputed](../../screenshots/lab13/image-26.png)
![Step 11 file check](../../screenshots/lab13/image-27.png)
![Step 12 policy](../../screenshots/lab13/image-28.png)
![Step 12 attach](../../screenshots/lab13/image-29.png)
![Step 12 verification](../../screenshots/lab13/image-30.png)

**Lambda instrumentation and tracing (Steps 13 to 18)**

![Step 13 handler part 1](../../screenshots/lab13/image-31.png)
![Step 13 handler part 2](../../screenshots/lab13/image-32.png)
![Step 13 deploy](../../screenshots/lab13/image-33.png)
![Handler check](../../screenshots/lab13/image-34.png)
![Upload code](../../screenshots/lab13/image-35.png)
![Environment and publish](../../screenshots/lab13/image-36.png)
![Alias update](../../screenshots/lab13/image-37.png)
![Invoke through alias](../../screenshots/lab13/image-38.png)
![Log decode attempt](../../screenshots/lab13/image-39.png)
![USMS_SUMMARY in log group](../../screenshots/lab13/image-40.png)
![Version list](../../screenshots/lab13/image-41.png)
![Rollback and roll forward](../../screenshots/lab13/image-42.png)
![Step 14 active tracing](../../screenshots/lab13/image-43.png)
![Step 14 verification](../../screenshots/lab13/image-44.png)
![Step 15 script](../../screenshots/lab13/image-45.png)
![Step 15 run](../../screenshots/lab13/image-46.png)
![Step 15 send attempt](../../screenshots/lab13/image-47.png)
![Step 16 subsegments script](../../screenshots/lab13/image-48.png)
![Step 16 downstream script](../../screenshots/lab13/image-49.png)
![Step 16 generated documents](../../screenshots/lab13/image-50.png)
![Step 16 validator script](../../screenshots/lab13/image-51.png)
![Step 16 validator output](../../screenshots/lab13/image-52.png)
![Step 17 skip note](../../screenshots/lab13/image-53.png)
![Step 17 emitter script](../../screenshots/lab13/image-54.png)
![Step 17 emitter runs](../../screenshots/lab13/image-56.png)
![Step 17 emitter runs continued](../../screenshots/lab13/image-55.png)
![Step 17 verification](../../screenshots/lab13/image-57.png)
![Step 18 sampling rule](../../screenshots/lab13/image-58.png)
![Step 18 validation](../../screenshots/lab13/image-59.png)

**Alarms, dashboard and queries (Steps 19 to 23)**

![Step 19 alarms](../../screenshots/lab13/image-60.png)
![Step 19 verification](../../screenshots/lab13/image-61.png)
![Step 20 force ALARM](../../screenshots/lab13/image-62.png)
![Step 20 restore](../../screenshots/lab13/image-63.png)
![Step 20 findings](../../screenshots/lab13/image-64.png)
![Step 21 composite](../../screenshots/lab13/image-65.png)
![Step 21 composite continued](../../screenshots/lab13/image-69.png)
![Step 21 child alarm](../../screenshots/lab13/image-66.png)
![Step 22 dashboard file](../../screenshots/lab13/image-67.png)
![Step 22 dashboard deploy](../../screenshots/lab13/image-68.png)
![Step 23 script](../../screenshots/lab13/image-70.png)
![Step 23 first run](../../screenshots/lab13/image-71.png)
![Step 23 fix](../../screenshots/lab13/image-72.png)
![Step 23 result](../../screenshots/lab13/image-73.png)

**Persistence, configuration and verification (Steps 24 to 26)**

![Step 24 record](../../screenshots/lab13/image-74.png)
![Step 24 restart](../../screenshots/lab13/image-75.png)
![Step 24 read back](../../screenshots/lab13/image-76.png)
![Step 25 env file](../../screenshots/lab13/image-77.png)
![Step 25 verification](../../screenshots/lab13/image-78.png)
![Step 26 git status](../../screenshots/lab13/image-80.png)
![Step 26 checks](../../screenshots/lab13/image-79.png)
![Step 26 commit](../../screenshots/lab13/image-81.png)
![Step 26 commit continued](../../screenshots/lab13/image-82.png)
![Verification script result](../../screenshots/lab13/image-83.png)

**Key results**

| Check | Result |
|---|---|
| Log retention | 30 days (central, ECS), 14 days (Lambda groups) |
| Metric filter evidence | `NotifyCount` Sum 2.0, SampleCount 4.0 |
| Lag statistics | SampleCount 2, Sum 2.33, Average 1.165, Maximum 1.91 |
| Lambda versions | 1, 2, 3, 4 (alias `live` on 4, tracing Active) |
| Faculty counts from logs | science 5, engineering 3 |
| Restart persistence | Configuration identical, metric data preserved |
| `verify-lab-13.sh` | PASS=46, FAIL=1 |

### 6.2 AWS Management Console Verification

Floci is a local emulator and has no AWS Management Console, so console screenshots could not be taken. The equivalent verification was done with CLI describe and list commands, which are shown in section 6.1:

| Resource | Verification and explanation |
|---|---|
| CloudWatch log groups | `describe-log-groups` table confirmed that `/usms/central/application` existed with a retention policy. |
| Metric filters | `describe-metric-filters` confirmed each filter was attached to the correct log group. |
| CloudWatch metrics | `list-metrics` confirmed the five metrics in `USMS/Application`. |
| IAM policy | `list-attached-role-policies` confirmed that `USMSObservabilityWrite` was attached to the Lambda role. |
| Lambda alias | `get-function-configuration` confirmed `live` pointed to version 4 with tracing Active. |
| Alarms | `describe-alarms` confirmed the statistic and missing-data settings of both alarms. |
| Dashboard | `list-dashboards` confirmed that `usms-overview` was stored with no validation messages. |

*If a real AWS account is available, console screenshots of CloudWatch Log groups, Alarms and Dashboards can be inserted here.*

## 7. Analysis and Discussion

**What was achieved.** A complete monitoring layer was built: central logging with retention, two metric filters, five custom metrics, a least-privilege IAM policy, an instrumented and traced Lambda with a working rollback, two alarms, a five-widget dashboard, structurally validated X-Ray documents and a verification script.

**Did the results match the expected outcome?** Mostly. Several outcomes differed from the lab text because of this Floci build:

- Metric filters and alarms were evaluated, although the lab expected them not to be. The `usms-notify-silence` alarm entered `ALARM` by itself when `NotifyCount` went quiet, which demonstrated the missing-data setting working correctly.
- X-Ray, Logs Insights, `PutCompositeAlarm` and `DescribeAlarmHistory` were unsupported. The X-Ray and composite alarm documents were built and validated structurally instead.
- The verification script finished at PASS=46, FAIL=1. The failing check was the dimensionless `TranscriptsProcessed` total, which was published in Step 11 but was missing after the restart and could not be republished.

**Errors encountered and how they were resolved.**

| Error | Resolution |
|---|---|
| CLI could not connect (`localhost.floci.io`) | Changed the endpoint to `http://localhost:4566` in `~/.bashrc`. |
| Log group named `C:/Program Files/Git/...` | Disabled Git Bash path conversion with `MSYS_NO_PATHCONV=1` and recreated the group. |
| `--log-events` JSON parse error | Passed the events as a JSON file with `file://`. |
| Corrupted scripts from terminal pasting | Used Notepad or short heredocs and verified with syntax checks. |
| Zip and emitter path errors | Used relative paths because Windows Python could not read `/c/...` paths. |
| Metrics sent to `USMS/Enrolment` | Hard-coded `USMS/Application` after finding an older export in `lab-06.env`. |
| Role checks received an ARN | Extracted the role name with `${VAR##*/}`. |

**Observations.**

- A metric filter pattern is not a regular expression. The pattern `ERROR` matched `"no ERROR here"`, which is a false positive, so structured JSON filters would be safer in production.
- A filter is not retroactive. A window before the filter existed returned an empty list rather than zeroes.
- A dimension is part of a metric's identity, so a total must be published separately.
- A Lambda alias made deployment and rollback a single `update-alias` call.
- Missing-data treatment decides whether an alarm can detect silence.

## 8. Reflection

**1. What did I learn about this AWS service?**
I learned that logs are text and metrics are numbers, and that a metric filter is what converts one into the other. I learned how retention controls cost, how dimensions define a metric's identity, how alarm statistics and missing-data settings change behavior, and how traces are built from segments and subsegments.

**2. What challenges did I encounter?**
The main challenges were environment-specific: Git Bash rewriting paths, unreliable terminal pasting, Windows Python rejecting Unix-style paths, and unsupported features on the emulator. Diagnosing each one taught me to read errors carefully and to verify files instead of trusting output that looked successful.

**3. How would I apply this service in a real-world cloud environment?**
I would send all application logs to a small number of log groups with sensible retention, derive metrics for error counts and latency, and create alarms that page one composite alarm per service. I would add a silence alarm on every critical pipeline, use X-Ray with a sampling rule to control cost, and keep dashboards and policies as JSON in version control.

**4. What additional concepts or features would I like to explore?**
I would like to explore CloudWatch Logs Insights queries, composite alarms with SNS notifications, the CloudWatch agent on EC2, embedded metric format, and X-Ray tracing on a real AWS account.

## 9. Conclusion

The objectives of the practical were achieved. A central logging and monitoring layer for USMS was created and verified, covering log retention, metric filters, custom metrics, a least-privilege IAM policy, an instrumented and traced Lambda, alarms, a dashboard and a restart-persistence test. Where the Floci build lacked X-Ray, Logs Insights and composite alarms, the equivalent documents were produced and validated structurally, and the differences were recorded honestly. One verification check (the dimensionless metric total) remained failing because of an emulator limitation.

The key concepts learned were the separation of logs and metrics, metric identity through dimensions, alarm missing-data treatment, alias-based deployment and rollback, and the trace data model. The skills developed included CLI automation, JSON document authoring, scripted verification, Git hygiene and systematic troubleshooting. CloudWatch and X-Ray are important because they give teams the visibility needed to detect, diagnose and prevent failures in cloud systems.