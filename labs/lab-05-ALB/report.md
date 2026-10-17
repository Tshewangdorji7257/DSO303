# Practical Report: AWS Application Load Balancer Integration with ECS on Floci

## Table of Contents

1. [Aim](#1-aim)
2. [Objectives](#2-objectives)
3. [Environment and Resources](#3-environment-and-resources)
4. [Architecture](#4-architecture)
5. [Procedure and Evidence](#5-procedure-and-evidence)
6. [Results Summary](#6-results-summary)
7. [Issues Requiring Follow-up](#7-issues-requiring-follow-up)
8. [Reflection](#8-reflection)
9. [Conclusion](#9-conclusion)

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

## 4. Architecture

### 4.1 Overview

Before this lab, the Enrolment API tasks were reached directly through a security-group rule. In this lab, an internet-facing Application Load Balancer became the single entry point. The ALB sits in two public subnets across two Availability Zones, while the ECS tasks stay in private subnets without public IP addresses. The ALB forwards requests to the tasks through an IP-type target group, which matches the `awsvpc` network mode used by the ECS service.

### 4.2 Architecture diagram

![alt text](<aws-architecture-diagram (1).png>)

```mermaid
flowchart TB
    client([Client / Internet])

    subgraph vpc["VPC (Labs 02-04 network)"]
        subgraph pub["Public subnets (two Availability Zones)"]
            alb["Application Load Balancer<br/>usms-enrolment-alb<br/>SG: usms-alb-sg"]
        end

        subgraph listener["Listener: HTTP :80"]
            rule["Rule, priority 10<br/>/alb-health, /alb-health/*<br/>Fixed response 200"]
            default["Default action<br/>Forward"]
        end

        tg["Target group<br/>usms-enrolment-tg<br/>type: ip"]

        subgraph priv["Private subnets"]
            subgraph ecs["ECS cluster: usms-ecs-cluster"]
                svc["Service: usms-enrolment-svc<br/>2 tasks, awsvpc<br/>SG: usms-enrolment-sg"]
                t1["Task 172.21.0.3<br/>enrolment-api :80"]
                t2["Task 172.21.0.5<br/>enrolment-api :80"]
            end
        end
    end

    client -->|"HTTP 80 / HTTPS 443 allowed"| alb
    alb --> rule
    alb --> default
    default --> tg
    tg --> t1
    tg --> t2
    svc -.manages.-> t1
    svc -.manages.-> t2
```


### 4.3 Components and their roles

| Component | Role in the design |
|---|---|
| Application Load Balancer (`usms-enrolment-alb`) | Internet-facing entry point, deployed across two public subnets for availability. |
| ALB security group (`usms-alb-sg`) | Allows inbound TCP 80 from `0.0.0.0/0` (and the HTTPS practice rule on 443). |
| HTTP listener (port 80) | Receives requests and applies routing rules; the default action forwards to the target group. |
| Listener rule (priority 10) | Returns a fixed `200 text/plain` response (`usms-enrolment-alb ok`) for `/alb-health` and `/alb-health/*`, without involving the tasks. |
| Target group (`usms-enrolment-tg`) | Holds the registered task IP addresses, tracks target health, and applies a 30-second deregistration delay. |
| ECS service (`usms-enrolment-svc`) | Keeps two `enrolment-api` tasks running and registers each task's IP with the target group. |
| Task security group (`usms-enrolment-sg`) | Intended to allow TCP 80 only from `usms-alb-sg`, not from every source. |

### 4.4 Request flow

1. A client sends an HTTP request to the ALB DNS name.
2. `usms-alb-sg` permits the traffic on port 80.
3. The listener evaluates the rules in priority order. Requests to `/alb-health` match the priority 10 rule and receive the fixed response.
4. All other requests use the default action and are forwarded to `usms-enrolment-tg`.
5. The target group selects a healthy target (`172.21.0.3` or `172.21.0.5`) and sends the request to the `enrolment-api` container on port 80.
6. `usms-enrolment-sg` accepts the connection only because its source is the ALB security group.

### 4.5 Design decisions

- **IP target type:** ECS tasks using `awsvpc` mode receive their own network interface and IP address, so targets are registered by IP rather than by instance.
- **Security-group referencing:** The task security group references `usms-alb-sg` as its source instead of a CIDR range, so the tasks can be reached through the load balancer but not directly.
- **Removal of the direct path:** The earlier direct-access rule was removed so the ALB is the only intended route to the service.
- **Two Availability Zones:** Placing the ALB in two public subnets is the minimum for a highly available load balancer.
- **Deregistration delay of 30 seconds:** A shorter delay than the default lets draining targets be released more quickly during deployments.

### 4.6 Environment limitation

Floci emulates the AWS control plane (ELBv2, ECS, EC2 APIs), but the data plane did not return an HTTP response for requests to the ALB DNS name. The architecture above is therefore evidenced through API output, not through a live end-to-end request.

---

## 5. Procedure and Evidence

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

**Evidence**

![Build and run Lab 05 verification script](../../screenshots/lab5/image-68.png)

---

## 6. Results Summary

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

## 7. Issues Requiring Follow-up

The practical produced the required core ALB, target group, listener, and ECS service resources, but the final verification script did not pass completely. Before reporting the lab as fully complete, address the following:

1. Recheck the ALB security-group ingress using a compact AWS CLI query and confirm that the ALB is attached to `sg-169971968fbc4b762`.
2. Inspect `usms-enrolment-sg` ingress and confirm that TCP port 80 references the ALB security group.
3. Inspect the ECS service's `healthCheckGracePeriodSeconds` value and set an appropriate non-zero value if required by the lab instructions.
4. Inspect ECS service deployments and wait until only one deployment remains, if the service is still rolling out.
5. Create or restore `configs/lab-05.env` with the values required by the course guide, using values derived from the actual environment rather than guessed ARNs.
6. Rerun `./scripts/utilities/verify-lab-05.sh` and save the final output.
7. If the ALB endpoint still returns `000`, record this as a Floci data-plane limitation and retain the control-plane API evidence. Do not claim a successful live HTTP response unless one is observed.

---

## 8. Reflection

### 8.1 What I learned

This lab showed how several separate pieces have to line up before a load balancer can serve an ECS service: the ALB and its security group, the listener, the target group, the task security group, and the ECS service's load-balancer configuration. Each piece was created and checked on its own, but the design only works when all of them agree. For example, the target type had to be `ip` because the service uses `awsvpc` networking, and the task security group had to trust the ALB security group rather than a CIDR range.

I also learned that a security group can be used as a source in a rule. Referencing `usms-alb-sg` is more precise than opening port 80 to the whole internet, because it ties access to the load balancer itself and still works if the ALB's addresses change.

### 8.2 What went well

- The control-plane resources (ALB, target group, listener, fixed-response rule, and service attachment) were all created and could be inspected through the API.
- Deriving ARNs from API output after the restart, rather than copying them by hand, made the persistence check more reliable.
- The restart check showed that the configuration survived a Floci stop and start in hybrid storage mode.
- Writing a verification script made the lab measurable. It confirmed 43 checks and highlighted exactly where the setup was incomplete.

### 8.3 Challenges and limitations

- **No live HTTP response:** Requests to the ALB DNS name returned status `000`. Floci did not provide a working data plane for the load balancer, so I could not show a real request travelling from client to task. I treated this as an environment limitation and relied on control-plane evidence instead of claiming success.
- **Draining not observed:** Forcing a deployment left the service stable at two tasks, and no draining state appeared in my captured checks. The 30-second deregistration delay was configured, but I cannot say I saw it working.
- **Six failed verification checks:** The verifier flagged the security-group rules, the ALB's security-group attachment, the health-check grace period, the number of deployments, and the missing `configs/lab-05.env`. These show that some steps were either not fully applied or not captured the way the script expects.
- **Effect on earlier labs:** Removing the direct access rule changed what the Lab 04 verification expects, which showed that later labs can invalidate the checks of earlier ones.

### 8.4 Differences from real AWS

On real AWS, the ALB would receive traffic and run health checks against the task IPs, so the target health states (`initial`, `healthy`, `draining`) would be visible and the fixed-response rule could be tested with a simple request. In Floci, these behaviours are only partly represented, so the lab validates configuration more than runtime behaviour. Any conclusion about real-world traffic handling should therefore be tested on actual AWS before being trusted.

### 8.5 What I would do differently

- Save the `configs/lab-05.env` file early and update it after each step, so the verifier and later labs have the values they need.
- Run the verification script after each major step rather than only at the end, so problems are found while the context is fresh.
- Set the `healthCheckGracePeriodSeconds` value when attaching the service to the target group, since tasks behind a load balancer need time to start before health checks count against them.
- Confirm the task security-group rule with a compact CLI query immediately after applying it, instead of relying only on screenshots.
- Capture target health at short intervals during a forced deployment to have a better chance of recording the draining state.
- Consider adding an HTTPS listener with a certificate if this design were extended beyond practice, since port 443 is currently open without a listener behind it.

### 8.6 Security reflection

Opening ports 80 and 443 to `0.0.0.0/0` on the ALB security group is acceptable for an internet-facing load balancer, but the task security group must stay restricted. Keeping the tasks in private subnets without public IPs and removing the previous direct access rule reduces the attack surface to a single entry point. However, the verifier's failed checks on these exact rules mean the security configuration should be rechecked before the lab is considered complete.

---

## 9. Conclusion

This practical configured the USMS Enrolment API behind an internet-facing Application Load Balancer in Floci. The ALB, IP-type target group, HTTP listener, fixed-response listener rule, and ECS service load-balancer attachment were created and verified through the AWS-compatible control-plane APIs. The earlier direct access path was removed, and the resource records checked after a Floci restart matched the normalized pre-restart records.

Some outcomes remain incomplete or inconclusive: the live ALB request did not return an HTTP response, target draining was not conclusively observed, and the final verification script reported six failures. The security-group checks, ECS health-check grace period, deployment count, and missing Lab 05 configuration file should be resolved and the verifier rerun before treating the practical as fully passed.