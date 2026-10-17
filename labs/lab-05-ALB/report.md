# Practical Report: AWS Application Load Balancer Integration with ECS on Floci

## Table of Contents

1. [Aim](#1-aim)
2. [Objectives](#2-objectives)
3. [Environment and Resources](#3-environment-and-resources)
4. [Procedure and Evidence](#4-procedure-and-evidence)
5. [Results Summary](#5-results-summary)
6. [Issues Requiring Follow-up](#6-issues-requiring-follow-up)
7. [Conclusion](#7-conclusion)

---

## 1. Aim

The aim of this practical was to place the USMS Enrolment API ECS service behind an internet-facing Application Load Balancer (ALB), configure target health checks and listener routing, remove the previous direct access path, observe deployment behaviour, and verify that the configuration persists after restarting Floci.

---

## 2. Objectives

- Start Floci and load the configuration from the previous labs.
- Verify that the network, security groups, ECS cluster, and service from Labs 02–04 are available.
- Create and configure an ALB security group.
- Create an internet-facing Application Load Balancer across two public subnets.
- Create an IP-type target group and configure its health-check and deregistration settings.
- Create an HTTP listener and an additional fixed-response listener rule.
- Allow traffic from the ALB security group to reach the ECS task security group.
- Attach the ECS service to the target group and observe target registration.
- Test the ALB endpoint and document any Floci data-plane limitations.
- Remove the previous direct access rule, force a deployment, and record the resulting state.
- Restart Floci and check whether the resources persist.
- Run the Lab 05 verification script and document its result.

---

## 3. Environment and Resources

### 3.1 Resource summary

| Resource | Observed value |
|---|---|
| AWS-compatible region | `us-east-1` |
| Account ID returned by STS | `000000000000` |
| ECS cluster | `usms-ecs-cluster` |
| ECS service | `usms-enrolment-svc` |
| ECS container | `enrolment-api` |
| Application Load Balancer | `usms-enrolment-alb` |
| ALB security group | `usms-alb-sg` (`sg-169971968fbc4b762`) |
| Target group | `usms-enrolment-tg` |
| Target type | `ip` |
| Listener | HTTP on port 80 |
| ALB DNS name | `usms-enrolment-alb-9799cbb555ad438f.elb.floci` |

### 3.2 ARNs

**Application Load Balancer**

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:loadbalancer/app/usms-enrolment-alb/9799cbb555ad438f
```

**Target group**

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/usms-enrolment-tg/109124adae3d4860
```

**HTTP listener**

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:listener/app/usms-enrolment-alb/9799cbb555ad438f/3c2bea0451e64c1a
```

---

## 4. Procedure and Evidence

> **Evidence note:** All screenshots are referenced from `../../screenshots/lab5/`. Make sure the image files are stored in that folder (relative to this report), or update the links to match your evidence folder.

### Step 1 — Start Floci and load the previous labs

Floci was started and the configuration files from the earlier labs were loaded. The AWS CLI environment was checked before continuing.

**Evidence**

![Start Floci](../../screenshots/lab5/image.png)

![Load previous lab configurations](../../screenshots/lab5/image-1.png)

![Check AWS environment](../../screenshots/lab5/image-2.png)

![AWS environment details](../../screenshots/lab5/image-3.png)

---

### Step 2 — Verify Labs 02, 03, and 04

The earlier lab resources were checked to confirm that the VPC, subnets, security groups, ECS cluster, and service were available before adding the load balancer.

**Evidence**

![Verify previous lab resources](../../screenshots/lab5/image-4.png)

![Additional previous-lab verification](../../screenshots/lab5/image-5.png)

---

### Step 3 — Check Floci load-balancer support

The available load-balancer functionality was inspected before creating the ALB resources.

**Evidence**

![Inspect Floci load-balancer support](../../screenshots/lab5/image-6.png)

![Additional load-balancer capability check](../../screenshots/lab5/image-7.png)

---

### Step 4 — Create the ALB security group

The VPC ID was checked, the `usms-alb-sg` security group was created, and a JSON file was prepared and validated for the inbound HTTP rule. The rule allows TCP port 80 from `0.0.0.0/0`, which is appropriate for the internet-facing ALB used in this exercise.

**Evidence**

![Check VPC ID](../../screenshots/lab5/image-8.png)

![Create ALB security group](../../screenshots/lab5/image-9.png)

![Prepare HTTP ingress rule](../../screenshots/lab5/image-10.png)

![Validate ingress JSON](../../screenshots/lab5/image-11.png)

![Apply HTTP ingress rule](../../screenshots/lab5/image-12.png)

![Inspect ALB security group](../../screenshots/lab5/image-13.png)

---

### Step 5 — Configure ALB outbound traffic and the HTTPS practice rule

The existing outbound rules were inspected. An HTTPS inbound rule was also added as the practice task specified, and its JSON file was validated before applying it.

**Evidence**

![Inspect outbound rules](../../screenshots/lab5/image-14.png)

![Prepare HTTPS inbound practice rule](../../screenshots/lab5/image-15.png)

![Validate HTTPS rule file](../../screenshots/lab5/image-16.png)

![Apply HTTPS rule](../../screenshots/lab5/image-17.png)

---

### Step 6 — Create the Application Load Balancer

Both public subnets were checked. The HTTP and HTTPS security-group rules were reviewed, then the internet-facing Application Load Balancer was created across two Availability Zones. Its DNS name and state were inspected.

**Evidence**

![Verify public subnets](../../screenshots/lab5/image-18.png)

![Verify HTTP and HTTPS rules](../../screenshots/lab5/image-19.png)

![Create Application Load Balancer](../../screenshots/lab5/image-20.png)

![Get DNS name and verify ALB](../../screenshots/lab5/image-21.png)

---

### Step 7 — Create the target group

The ALB ARN variable was restored from the AWS API output, then the target group was created and inspected. The target type was `ip`, which matches the ECS service's `awsvpc` network mode.

**Evidence**

![Restore ALB ARN](../../screenshots/lab5/image-22.png)

![Create target group](../../screenshots/lab5/image-23.png)

![Verify target group](../../screenshots/lab5/image-24.png)

---

### Step 8 — Configure target group attributes

The target group attributes were inspected and configured, including the deregistration delay. The recorded configuration used a deregistration delay of **30 seconds**.

**Evidence**

![Inspect target group attributes](../../screenshots/lab5/image-25.png)

![Verify target group attributes](../../screenshots/lab5/image-26.png)

---

### Step 9 — Create the listener configuration

The listener configuration was prepared and validated. An HTTP listener on port 80 was created with a default action that forwards requests to `usms-enrolment-tg`.

**Evidence**

![Prepare listener configuration](../../screenshots/lab5/image-27.png)

![Validate listener configuration](../../screenshots/lab5/image-28.png)

![Create HTTP listener](../../screenshots/lab5/image-29.png)

![Verify HTTP listener](../../screenshots/lab5/image-30.png)

---

### Step 10 — Allow the ALB to reach ECS tasks

An ingress rule file was prepared for the enrolment task security group. The intended rule allows TCP port 80 from `usms-alb-sg`, rather than opening the task port to every source. The file was validated, applied, and inspected.

**Evidence**

![Check security group variables](../../screenshots/lab5/image-31.png)

![Prepare enrolment security-group rule](../../screenshots/lab5/image-32.png)

![Apply and verify the ingress rule](../../screenshots/lab5/image-33.png)

![Verify the exact source security group](../../screenshots/lab5/image-34.png)

---

### Step 11 — Prepare the ECS load-balancer configuration

The ECS service load-balancer configuration was prepared and applied so that the `enrolment-api` container's port 80 was associated with the target group. The service attachment was then inspected.

**Evidence**

![Prepare ECS load-balancer configuration](../../screenshots/lab5/image-35.png)

![Attach ECS service to target group](../../screenshots/lab5/image-36.png)

![Verify service update](../../screenshots/lab5/image-37.png)

![Inspect load-balancer attachment](../../screenshots/lab5/image-38.png)

---

### Step 12 — Watch target registration

Target registration and health were observed alongside ECS task health. The service was also scaled to three tasks to check whether a third target appeared, then scaled back to two tasks.

**Evidence**

![Watch target registration](../../screenshots/lab5/image-39.png)

![Check ECS service account or identity](../../screenshots/lab5/image-40.png)

![Additional ECS service inspection](../../screenshots/lab5/image-41.png)

![Compare ECS task health and target health](../../screenshots/lab5/image-42.png)

![Additional task and target health evidence](../../screenshots/lab5/image-43.png)

![Scale service to three tasks](../../screenshots/lab5/image-44.png)

![Check for the third target](../../screenshots/lab5/image-45.png)

![Scale service back to two tasks](../../screenshots/lab5/image-46.png)

---

### Step 13 — Test the ALB path

The ALB DNS name was tested, and the end-to-end path was examined. In this Floci environment, the HTTP request attempts returned status `000` with an empty response body. Therefore, a successful live HTTP response could not be demonstrated from the data-plane test.

> **Limitation:** This is recorded as a limitation of the observed environment, not as proof that the ALB control-plane resources were absent.

**Evidence**

![Test ALB DNS endpoint](../../screenshots/lab5/image-47.png)

![Additional ALB endpoint test](../../screenshots/lab5/image-48.png)

![Verify the complete request path](../../screenshots/lab5/image-49.png)

![Additional end-to-end path evidence](../../screenshots/lab5/image-50.png)

---

### Step 14 — Remove the previous direct access path

The existing security-group rule that permitted the previous direct path was identified and confirmed before removal. After the rule was removed, the security group was inspected again. The Lab 04 verification script was also checked to observe the effect of this change on the earlier lab's expectations.

**Evidence**

![Find and confirm the direct-access rule](../../screenshots/lab5/image-51.png)

![Remove the direct-access rule](../../screenshots/lab5/image-52.png)

![Verify the rule removal](../../screenshots/lab5/image-53.png)

![Check the effect on Lab 04 verification](../../screenshots/lab5/image-54.png)

---

### Step 15 — Force a deployment and observe target draining

The service state was recorded before deployment. A deployment was forced without changing the task definition, and the ECS tasks and target health were observed.

**Post-deployment state**

| Item | Value |
|---|---|
| Task definition | `usms-enrolment:2` |
| Desired count | 2 |
| Running count | 2 |
| Target IPs | `172.21.0.3`, `172.21.0.5` |

**Running tasks**

| Task ARN | Start time |
|---|---|
| `arn:aws:ecs:us-east-1:000000000000:task/usms-ecs-cluster/bde17a768f4f462ea661f7eef1560eb9` | `2026-10-17T16:38:31.515000+06:00` |
| `arn:aws:ecs:us-east-1:000000000000:task/usms-ecs-cluster/2302955b3bd74e22b485f403785a600c` | `2026-10-17T16:23:57.713000+06:00` |

No draining state was observed in the captured checks, and the service remained at two running tasks. The control-plane evidence therefore showed a stable service, but it did not conclusively demonstrate a target entering and leaving the draining state.

**Evidence**

![Record state before deployment](../../screenshots/lab5/image-55.png)

![Observe tasks and target health during deployment](../../screenshots/lab5/image-56.png)

![Force a deployment](../../screenshots/lab5/image-57.png)

![Save post-deployment evidence](../../screenshots/lab5/image-58.png)

---

### Step 16 — Add a listener rule

A non-default listener rule was created at priority 10.

| Property | Value |
|---|---|
| Priority | 10 |
| Path patterns | `/alb-health`, `/alb-health/*` |
| Action | Fixed response |
| Status code | 200 |
| Content type | `text/plain` |
| Body | `usms-enrolment-alb ok` |

The rule was verified through the ELBv2 API. The live endpoint test did not return a successful HTTP response in this Floci environment, so the successful rule verification is based on the control-plane API output rather than a live request.

**Evidence**

![Prepare listener rule](../../screenshots/lab5/image-59.png)

![Create listener rule](../../screenshots/lab5/image-60.png)

![Verify listener rule](../../screenshots/lab5/image-61.png)

![Inspect listener rule details](../../screenshots/lab5/image-62.png)

---

### Step 17 — Verify persistence after restarting Floci

Before restarting Floci, the ALB, target group, listener rules, ECS service, and relevant security-group information were recorded. Floci was stopped and restarted using the provided scripts. The environment configuration was loaded again, and the resources were queried by deriving their ARNs from the APIs.

Floci reported that it stopped while preserving state in `C:/Users/Dell/floci-data`, and then started again at `http://localhost:4566` in hybrid storage mode. The post-restart records matched the filtered pre-restart records for the checked resources, which supports the conclusion that the recorded configuration persisted through the restart.

**Evidence**

![Record resources before restart](../../screenshots/lab5/image-64.png)

![Additional pre-restart evidence](../../screenshots/lab5/image-63.png)

![Stop and restart Floci](../../screenshots/lab5/image-65.png)

![Verify full records after restart](../../screenshots/lab5/image-66.png)

![Derive ARNs from the API after restart](../../screenshots/lab5/image-67.png)

---

### Step 18 — Build and run the Lab 05 verification script

The utility script `scripts/utilities/verify-lab-05.sh` was created and run. The syntax check returned `syntax OK`. The verification output reported **43 checks passed and 6 failed**.

**Failed checks**

1. `usms-alb-sg admits tcp/80 from 0.0.0.0/0`
2. `usms-enrolment-sg admits tcp/80 from usms-alb-sg`
3. `carries usms-alb-sg`
4. `healthCheckGracePeriodSeconds is set (not None, not 0)`
5. `exactly ONE deployment (nothing stuck mid-roll)`
6. `configs/lab-05.env exists`

**Passed checks:** running Floci container, non-memory storage, AWS CLI reachability, account ID, prior-lab dependencies, ALB existence and state, target group properties, listener existence and routing, service wiring, private-subnet placement, no public IP assignment, JSON validity, and Git secret hygiene.

> **Note:** A separate security-group inspection visibly showed that `usms-alb-sg` has a TCP port 80 ingress rule from `0.0.0.0/0`. The verifier's failure for that specific check should therefore be investigated rather than assumed to mean the rule is absent. The captured output was truncated while displaying the following rule, so the complete set of ALB security-group rules should be rechecked with a compact query. The other security-group and service failures also require follow-up before the lab can be considered fully verified.

**Evidence**

![Build and run Lab 05 verification script](../../screenshots/lab5/image-68.png)

---

## 5. Results Summary

| Area | Result |
|---|---|
| Floci environment | Passed in the verification output |
| Labs 02–04 dependencies | Passed in the verification output |
| ALB creation and state | Passed in the verification output |
| Target group | Passed in the verification output |
| Listener and non-default fixed-response rule | Passed in the verification output |
| ECS service load-balancer wiring | Passed in the verification output |
| HTTP data-plane test | Not successful; `curl` returned status `000` |
| Deployment / target draining observation | Service remained stable, but draining was not conclusively observed |
| Persistence after restart | Checked records matched after normalization |
| Final verification script | 43 passed, 6 failed |

---

## 6. Issues Requiring Follow-up

The practical produced the required core ALB, target group, listener, and ECS service resources, but the final verification script did not pass completely. Before reporting the lab as fully complete, address the following:

1. Recheck the ALB security-group ingress using a compact AWS CLI query and confirm that the ALB is attached to `sg-169971968fbc4b762`.
2. Inspect `usms-enrolment-sg` ingress and confirm that TCP port 80 references the ALB security group.
3. Inspect the ECS service's `healthCheckGracePeriodSeconds` value and set an appropriate non-zero value if required by the lab instructions.
4. Inspect ECS service deployments and wait until only one deployment remains, if the service is still rolling out.
5. Create or restore `configs/lab-05.env` with the values required by the course guide, using values derived from the actual environment rather than guessed ARNs.
6. Rerun `./scripts/utilities/verify-lab-05.sh` and save the final output.
7. If the ALB endpoint still returns `000`, record this as a Floci data-plane limitation and retain the control-plane API evidence. Do not claim a successful live HTTP response unless one is observed.

---

## 7. Conclusion

This practical configured the USMS Enrolment API behind an internet-facing Application Load Balancer in Floci. The ALB, IP-type target group, HTTP listener, fixed-response listener rule, and ECS service load-balancer attachment were created and verified through the AWS-compatible control-plane APIs. The earlier direct access path was removed, and the resource records checked after a Floci restart matched the normalized pre-restart records.

Some outcomes remain incomplete or inconclusive: the live ALB request did not return an HTTP response, target draining was not conclusively observed, and the final verification script reported six failures. The security-group checks, ECS health-check grace period, deployment count, and missing Lab 05 configuration file should be resolved and the verifier rerun before treating the practical as fully passed.