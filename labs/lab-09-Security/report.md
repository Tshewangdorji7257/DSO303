# Lab 09: Security Review of the USMS Cloud Environment


## 1. Aim / Objective

To review the security of the USMS environment built in Labs 1 to 6, and to harden it using the AWS CLI. The objectives were:

- To list every IAM role, policy, and access key, and audit them for risky settings.
- To reduce permissions with a read-only policy, a scoped trust policy, a scoped `iam:PassRole`, and a permissions boundary.
- To rotate an access key with no outage.
- To require IMDSv2 on an EC2 instance.
- To write security group egress rules, narrow the SSH rule, and prove that the database is not reachable from the internet.
- To prove that the controls survive a restart and that no earlier lab was broken.

---

## 2. Introduction

This lab used AWS IAM (Identity and Access Management) and Amazon EC2 security groups, run on Floci, a local AWS emulator. IAM decides who can do what in an account, using users, roles, policies, trust policies, and permissions boundaries. Security groups work as virtual firewalls that decide which network traffic can reach a resource and what the resource can send out. These services are the base of cloud security, because almost every cloud incident starts with a wrong permission or an open network rule. They are used in every real AWS account to follow the "least privilege" rule, to protect databases and servers, and to pass security audits. Floci accepts any credentials and does not enforce policies, so all controls in this lab were proven by reading the policy documents and rules.

---

## 3. Use Case

- Giving a deployment pipeline only the permissions it needs, using a role with a permissions boundary.
- Giving a reporting application read-only access to a storage bucket using a separate role.
- Protecting a database so that only the application tier can connect to it.
- Controlling what a load balancer or container can send out, to reduce data leaks.
- Rotating access keys regularly so a stolen key does not stay useful.
- Stopping attackers from stealing instance credentials through the metadata service (SSRF attacks).

---

## 4. System Architecture / Design

The diagram below shows the USMS system that was reviewed and the controls that were added in this lab.

![alt text](<aws-architecture-diagram (4).png>)

```
                         INTERNET
                            |
                  tcp/80 (accepted risk)
                            |
                    +---------------+
                    | usms-alb-sg   |   egress: tcp/80 -> usms-enrolment-sg ONLY
                    | Load Balancer |
                    +-------+-------+
                            | tcp/80 (group reference)
                    +-------v--------+
                    | usms-enrolment |   egress: tcp/443 only (S3 prefix list + HTTPS)
                    | -sg  (Fargate) |   task role: usms-ecs-task-role (scoped trust)
                    +-------+--------+
                            | tcp/443 via S3 gateway endpoint
                       +----v----+
                       |   S3    |  <- usms-transcripts-reader-role (read only)
                       +---------+

   Admin user --assume--> usms-deploy-role  (permissions boundary + scoped PassRole)

   usms-bastion-sg --tcp/22--> usms-app-sg (usms-web-01, IMDSv2 required)
                                    |
                              tcp/5432 (group reference)
                                    |
                           +--------v--------+
                           |   usms-db-sg    |  private subnet, no internet route,
                           |  (usms-db-01)   |  egress: tcp/443 only
                           +-----------------+
```

- **Services used:** IAM, STS, EC2 (security groups, instances, metadata options), ECS, S3, and a load balancer.
- **User interactions:** the admin user assumes the deploy role, and the developer user uses a rotated access key.
- **Resource relationships:** security groups refer to other security groups instead of IP addresses.
- **Data flow:** internet to load balancer, then to the enrolment tasks, then to S3. The web tier talks to the database on port 5432 only.

---

## 5. Implementation Procedure

1. **Step 1 – Resumed the environment.** Started Floci, loaded the seven env files, and printed 17 values to confirm none were empty.
2. **Step 2 – Recorded a baseline.** Ran the verification scripts of Labs 2 to 6 and saved their summary lines.
3. **Step 3 – Probed Floci.** Tested which IAM and EC2 calls the build supported, to choose the lab path.
4. **Step 4 – Made an identity inventory.** Listed roles, users, and policies, and saved a JSON inventory of every role.
5. **Step 5 – Built the IAM audit script.** Checked for wildcard actions, wildcard resources, unscoped `iam:PassRole`, and trust policies with no condition.
6. **Step 6 – Read the transcripts policy.** Found that `s3:PutObject` was given to a role that only needed to read. Checked that the bucket did not exist yet.
7. **Step 7 – Created the read-only policy and role.** Made `USMSStudentDataReadOnly` and `usms-transcripts-reader-role`, and added conditions to the trust policy of `usms-ecs-task-role` after saving the old one.
8. **Step 8 – Scoped `iam:PassRole` and added a boundary.** Created `USMSPermissionsBoundary`, `USMSDeployBase`, and `usms-deploy-role`.
9. **Step 9 – Used a session policy.** Assumed a role with a session policy, computed the effective permissions by hand, then restored my normal identity.
10. **Step 10 – Rotated the access key.** Created a new key, moved the profile, deactivated the old key, tested, and then deleted it.
11. **Step 11 – Required IMDSv2.** Set `HttpTokens` to `required` and hop limit to 1 on `usms-web-01`, and compared before and after.
12. **Step 12 – Built the security group audit script.** Reported open internet rules, default egress, and unused groups.
13. **Steps 13 to 15 – Wrote egress rules.** Added new egress rules first, then removed the default allow-all rule, for the enrolment, load balancer, and database groups. I saved an undo file before the change.
14. **Step 16 – Narrowed SSH.** Added an SSH rule from `usms-bastion-sg`, then removed the old rule that allowed the whole VPC.
15. **Step 17 – Built the reachability matrix.** Showed who can reach what, and proved by five controls that `usms-db-01` is not reachable from the internet.
16. **Step 18 – Tested persistence.** Recorded nine facts, restarted Floci, re-read every value from the API, and compared. Re-ran the earlier verification scripts and compared them with the baseline.
17. **Step 19 – Wrote `configs/lab-09.env`.** Saved names and ARNs only, with no secrets.
18. **Step 20 – Committed.** Checked that no secret was staged, and committed by naming each path.
19. **Section 8 – Verification.** Built and ran `verify-lab-09.sh`, then fixed the problems found (see section 7).

---

## 6. Results and Evidence

### 6.1 CLI / SDK Output

**Step 1 – Environment started and 17 values printed**

![Floci started and env files loaded](../../screenshots/lab9/image.png)
![17 values printed](../../screenshots/lab9/image-2.png)

**Step 2 – Security baseline recorded**

![Baseline](../../screenshots/lab9/image-1.png)

**Step 3 – Floci support probe**

![Probe](../../screenshots/lab9/image-3.png)

**Step 4 – Identity inventory (readable pass, JSON file, and validation)**

![Readable inventory](../../screenshots/lab9/image-4.png)
![JSON inventory](../../screenshots/lab9/image-5.png)
![JSON validated](../../screenshots/lab9/image-6.png)

**Step 5 – IAM audit script (created, run, and exit code)**

![Script created](../../screenshots/lab9/image-7.png)
![Script syntax and run](../../screenshots/lab9/image-9.png)
![Script output](../../screenshots/lab9/image-8.png)
![Exit code](../../screenshots/lab9/image-10.png)

**Step 6 – Transcripts policy and bucket check**

![Policy and who uses it](../../screenshots/lab9/image-11.png)
![Policy continued](../../screenshots/lab9/image-13.png)
![Bucket check](../../screenshots/lab9/image-12.png)

**Step 7 – Read-only policy, scoped trust, and new role**

![Policy document](../../screenshots/lab9/image-14.png)
![Policy created](../../screenshots/lab9/image-15.png)
![Scoped trust policy](../../screenshots/lab9/image-16.png)
![New role and policy attached](../../screenshots/lab9/image-17.png)
![Task role trust policy changed](../../screenshots/lab9/image-18.png)
![Task role change continued](../../screenshots/lab9/image-19.png)
![Verification](../../screenshots/lab9/image-20.png)

**Step 8 – Permissions boundary, scoped PassRole, and deploy role**

![Boundary document](../../screenshots/lab9/image-21.png)
![Boundary created](../../screenshots/lab9/image-22.png)
![Deploy policy](../../screenshots/lab9/image-23.png)
![Deploy role](../../screenshots/lab9/image-24.png)
![Verification](../../screenshots/lab9/image-25.png)

**Step 9 – Session policy and intersection**

![Session policy](../../screenshots/lab9/image-26.png)
![Assume role with policy](../../screenshots/lab9/image-27.png)
![Temporary credentials used](../../screenshots/lab9/image-28.png)
![Intersection computed](../../screenshots/lab9/image-29.png)
![Identity restored](../../screenshots/lab9/image-30.png)

**Step 10 – Access key rotation**

![Keys before](../../screenshots/lab9/image-31.png)
![New key created](../../screenshots/lab9/image-32.png)
![Key IDs captured](../../screenshots/lab9/image-33.png)
![Profile moved](../../screenshots/lab9/image-34.png)
![Old key deactivated](../../screenshots/lab9/image-35.png)
![Old key deleted](../../screenshots/lab9/image-36.png)

**Step 11 – IMDSv2 required**

![Before](../../screenshots/lab9/image-37.png)
![Tokens required](../../screenshots/lab9/image-38.png)
![After](../../screenshots/lab9/image-39.png)
![Comparison](../../screenshots/lab9/image-40.png)

**Step 12 – Security group audit**

![Analyser](../../screenshots/lab9/image-41.png)
![Analyser checked](../../screenshots/lab9/image-42.png)
![Wrapper](../../screenshots/lab9/image-43.png)
![Audit run](../../screenshots/lab9/image-44.png)

**Steps 13 to 15 – Egress rules**

![S3 prefix list](../../screenshots/lab9/image-45.png)
![Enrolment egress document](../../screenshots/lab9/image-46.png)
![Undo document](../../screenshots/lab9/image-47.png)
![Authorize then revoke](../../screenshots/lab9/image-48.png)
![Enrolment egress verified](../../screenshots/lab9/image-49.png)
![Enrolment ingress unchanged](../../screenshots/lab9/image-50.png)
![Load balancer egress document](../../screenshots/lab9/image-51.png)
![Load balancer authorize then revoke](../../screenshots/lab9/image-52.png)
![Load balancer verified](../../screenshots/lab9/image-53.png)
![No allow-all row left](../../screenshots/lab9/image-54.png)
![Database egress document](../../screenshots/lab9/image-55.png)
![Database authorize then revoke](../../screenshots/lab9/image-56.png)
![Three groups checked](../../screenshots/lab9/image-58.png)
![Three groups checked, continued](../../screenshots/lab9/image-59.png)

**Step 16 – SSH narrowed to the bastion group**

![Current SSH rules](../../screenshots/lab9/image-60.png)
![Current SSH rules continued](../../screenshots/lab9/image-61.png)
![Bastion group found](../../screenshots/lab9/image-63.png)
![New rule added](../../screenshots/lab9/image-64.png)
![Old rule removed](../../screenshots/lab9/image-65.png)
![Old rule removal continued](../../screenshots/lab9/image-66.png)
![Verification](../../screenshots/lab9/image-67.png)

**Step 17 – Reachability matrix and negative proof**

![Matrix analyser](../../screenshots/lab9/image-68.png)
![Matrix wrapper](../../screenshots/lab9/image-69.png)
![Matrix output](../../screenshots/lab9/image-70.png)
![Five-control proof](../../screenshots/lab9/image-71.png)

**Step 18 – Persistence and regression test**

![Pre-checks](../../screenshots/lab9/image-72.png)
![Facts recorded](../../screenshots/lab9/image-73.png)
![Floci restarted](../../screenshots/lab9/image-74.png)
![Values re-read](../../screenshots/lab9/image-75.png)
![Earlier labs re-verified](../../screenshots/lab9/image-76.png)

**Step 19 – Env file**

![Env file written](../../screenshots/lab9/image-77.png)
![Env file verified](../../screenshots/lab9/image-79.png)

**Step 20 – Git commit**

![Checked before adding](../../screenshots/lab9/image-80.png)
![Commit](../../screenshots/lab9/image-81.png)
![Commit continued](../../screenshots/lab9/image-82.png)

**Section 8 – Final verification script**

![Verification script](../../screenshots/lab9/image-83.png)

### 6.2 AWS Management Console Verification

This lab used Floci, a local emulator, so there was no AWS Management Console to take screenshots from. The resources were verified instead with the AWS CLI (`get-role`, `list-policies`, `describe-security-groups`, `describe-instances`) and with the verification script. The CLI screenshots in section 6.1 serve as this evidence. The actions confirmed were:

| Resource | One-line explanation | Evidence |
|---|---|---|
| `USMSStudentDataReadOnly` policy | Allowed only list and read on the transcripts bucket | image-15, image-20 |
| `usms-transcripts-reader-role` | New role with the read-only policy and a scoped trust policy | image-17, image-20 |
| `usms-ecs-task-role` | Same principal, but a new confused-deputy condition was added | image-18, image-19, image-20 |
| `USMSPermissionsBoundary` and `usms-deploy-role` | Created a ceiling and a role that uses it | image-22, image-24, image-25 |
| `usms-dev-01` access key | Rotated so only one new active key remained | image-36 |
| `usms-web-01` metadata options | IMDSv2 required, hop limit 1 | image-39, image-40 |
| Three egress rules | Replaced allow-all egress with written rules | image-49, image-53, image-58, image-59 |
| `usms-app-sg` SSH rule | SSH allowed only from `usms-bastion-sg` | image-67 |
| `usms-db-01` | Proved not reachable from the internet by five controls | image-71 |

---

## 7. Analysis and Discussion

**What was achieved.** I reviewed the whole USMS account and fixed the weak points I found. The ECS task role got a confused-deputy condition. A read-only role was created. `iam:PassRole` was limited to three named roles. A permissions boundary was created and used on the deploy role. The access key was rotated. IMDSv2 was required. Egress was written for three security groups. SSH was narrowed to a bastion group. I also proved that the controls survived a restart and that Labs 2 to 6 still reported the same results.

**Did the results match the expected outcome?** Mostly yes. The first run of `verify-lab-09.sh` gave **PASS=39, FAIL=11**. After I investigated and fixed the causes, the final run passed with **FAIL=0**.

**Errors encountered and how they were solved.**

| Problem | Cause | Solution |
|---|---|---|
| Egress and SSH checks failed | The lab's queries were missing `SecurityGroups[0].`, so they returned nothing. My real rules were correct. | Fixed the queries in the verification script. The same fix was needed in the Step 18 commands. |
| Old SSH rule for `10.0.0.0/16` still existed | The old rule had not been removed in Step 16. This was a real gap. | Removed the rule by its rule ID and checked again. |
| "Boundary attached to nothing" check failed | `AttachmentCount` was 0 and no roles or users were listed, so the setup was correct. The check's nested quoting was broken. | Rewrote the check in a simpler form. |
| "Unexpanded variable" check failed | The only match was `${aws:username}` in Lab 1's policy, which is a real IAM variable. | Changed the check to ignore `${aws:`. |
| `usms-db-01` public address check failed | Floci returned `127.0.0.1`, a loopback address that the internet cannot reach. | Changed the check to accept it. The route table and subnet checks still passed. |

**Observations.**

- Floci does not enforce policies, so a command succeeding proved nothing. Reading the documents was the real proof.
- Adding the new rule before removing the old one avoided any window with no rules.
- A revoke command can print `True` and still remove nothing, so every change must be read back.
- An audit tool gives findings, not verdicts. For example, the load balancer's open port 80 was an accepted risk, but the web instance's open ports 80 and 443 stayed an open finding.
- The EC2 role's trust policy could not be given the same condition, because EC2 does not send `aws:SourceArn`.

---

## 8. Reflection

**1. What did I learn about this AWS service?**
A trust policy decides who can become a role, and an identity policy decides what the role can do. A permissions boundary and a session policy can only reduce permissions, never add them. Unscoped `iam:PassRole` is a path to privilege escalation. For networks, I learned that egress is as important as ingress, and that rules based on security groups are better than rules based on IP addresses.

**2. What challenges did I encounter?**
The biggest challenges were long copy-and-paste commands breaking in the terminal, quoting problems inside heredocs, and wrong queries in the verification script. Finding that an old SSH rule was still there, even though the revoke printed `True`, taught me to always read back each change.

**3. How would I apply this service in a real-world cloud environment?**
I would give every workload its own role with the smallest set of permissions, scope `iam:PassRole` to named roles, and put a permissions boundary on any role that can create other roles. I would use IAM Identity Center or federation instead of long-lived keys, require IMDSv2 on all instances, and write egress rules for every security group. I would also run audit scripts like these on a regular schedule.

**4. What additional concepts would I like to explore?**
Service Control Policies in AWS Organizations, IAM Access Analyzer, `simulate-principal-policy`, interface VPC endpoints to tighten egress, AWS Network Firewall for hostname filtering, and MFA on the deploy role.

---

## 9. Conclusion

In this practical I completed a full security review of the USMS environment. I made an inventory of all identities, built three audit tools, and fixed the weak points they found. The objectives were achieved: the final verification script passed with no failures, the controls survived a restart, and the earlier labs were not broken.

I learned how trust policies, permissions boundaries, session policies, and `iam:PassRole` work together, how to rotate a key safely, why IMDSv2 matters, and how to use egress rules and security group references. I developed skills in writing audit scripts, reading policy documents, debugging failing checks, and using Git safely. IAM and security groups are important because they are the first and last line of defence in any cloud system, and a small mistake in either can expose the whole account.