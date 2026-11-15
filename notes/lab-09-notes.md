Lab 09 path: B (management only)

## Step 4 - trust policies
(sentence 1: which role has a Service principal, which has an AWS principal)
(sentence 2: what each means for WHO can get the credentials and HOW)

## Step 6 - transcripts policy
Bucket usms-student-data did not exist yet at the time of this review (Lab 10 creates it).

## Step 7 - confused deputy fix
usms-ecs-task-role: same principal (ecs-tasks), now with aws:SourceAccount and aws:SourceArn conditions. New usms-transcripts-reader-role carries USMSStudentDataReadOnly (Get + List, explicit Deny on writes). usms-ec2-app-role stays unconditioned because EC2 does not send aws:SourceArn for instance profiles.

## Step 8 - PassRole and boundary
USMSDeployBase scopes iam:PassRole to three named roles, only to ecs-tasks.amazonaws.com, with an explicit Deny on passing roles to ec2.amazonaws.com. USMSPermissionsBoundary is attached to nothing and used only as usms-deploy-role's permissions boundary; it is not an orphan, and deleting it would remove the only ceiling on the pipeline. The boundary was stored by this Floci build.

## Step 9 - session policy
Assumed usms-developer-role with a session policy allowing only Describe actions. Effective permissions are the intersection of identity policy, boundary and session policy; a session policy only subtracts. Computed by hand (Python fallback, simulate-principal-policy unavailable). Floci does not enforce it.

## Step 9 - correction
First assume-role failed: USMS_ROLE_DEVELOPER already holds a full ARN, so my ARN was doubled. Fixed by using the variable as-is. sts:GetCallerIdentity was allowed by the identity policy, so I added iam:CreateUser to the session policy to show a denied action. Intersection computed by Python, simulate-principal-policy being unavailable.

## Step 9 - result
assume-role with --policy succeeded after the ARN fix. In the by-hand intersection, iam:CreateUser was reported as denied (see check of USMSDeveloperBase for an explicit Deny). Describe actions and sts:GetCallerIdentity were allowed because the identity policy already grants them.

## Step 10 - key rotation
Order: create second key, repoint usms-dev profile, deactivate old key (reversible), verify profile still works, delete old key (irreversible). This lab compresses the observation pause that a real rotation would hold for days. On real AWS I would replace the long-lived key with IAM Identity Center or federation for humans, and roles for workloads.

## Step 12 - SG audit
HIGH=5 MED=10 LOW=6 groups=9. This Floci build does not return group-referenced sources (UserIdGroupPairs empty, ReferencedGroupInfo None) in either describe-security-groups or describe-security-group-rules. Group-sourced rules (db 5432, enrolment 80, app 22) show as <none>. Several groups carry duplicate rules (db-sg 7x tcp/5432, enrolment-sg 6x tcp/80, alb-sg duplicate tcp/80). Controls on group references are proven by the policy documents, not by API read-back.

## Step 13 - enrolment egress
Authorized tcp/443 (S3 prefix list + 0.0.0.0/0) BEFORE revoking the default allow-all on usms-enrolment-sg. Undo kept in policies/usms-egress-allow-all.json. This still permits HTTPS to anywhere; narrowing needs interface endpoints on real AWS.

## Step 13 - read-back discrepancy
describe-security-groups shows 0 allow-all egress rules on usms-enrolment-sg, but describe-security-group-rules still listed a -1 / 0.0.0.0/0 rule record. Treated as a Floci limitation in rule-record bookkeeping; the group-level view is the one Section 8 asserts.

## Step 14 - ALB egress
usms-alb-sg egress now tcp/80 to usms-enrolment-sg (group reference reads back as GroupId). Revoking the default by --ip-permissions left a stale -1 record visible only in describe-security-group-rules; removing it by --security-group-rule-ids cleared it (same pattern as Step 13).

## Steps 13-14 - correction
The by-ID revoke (--security-group-rule-ids) returned True but did NOT remove the stale -1/0.0.0.0/0 records from describe-security-group-rules, on either usms-enrolment-sg or usms-alb-sg. describe-security-groups shows 0 allow-all egress rules for both, which is what the verification script asserts. Treated as a Floci rule-record bookkeeping limitation. My earlier note saying the by-ID revoke cleared it was wrong.

## Step 15 - data tier egress
usms-db-sg egress is now tcp/443 to 0.0.0.0/0 (authorised before the default was revoked). DNS is deliberately absent (Exercise 1). The lab's verify queries omit SecurityGroups[0]. and error on this CLI; the prefixed form works.

## Step 16 - SSH cutover
Added tcp/22 from usms-bastion-sg to usms-app-sg first, then removed the 10.0.0.0/16 SSH rule by rule ID. Port 22 now has no CIDR source and the bastion group reads back as a source. Several older port-22 records with no source remain (Floci bookkeeping); they admit nothing.

## Step 17 - reachability and negative proof
Control 1 read 127.0.0.1 (Floci container artefact; real AWS must show None). Controls 2, 3 (NAT only, no igw) and 5 held. Control 4 unproven by API: db-sg group source not stored on this build. Matrix shows usms-web-02 as a second internet-facing instance on usms-app-sg, and default egress remains on app, bastion, eks, exam and default groups.
If control 3 failed: (your sentence)
If control 4 failed: (your sentence)

## Known benign verification failures
- Boundary "attached to nothing": AttachmentCount is 0 and list-entities-for-policy is empty; the check's nested quoting is at fault.
- "No unexpanded variable": the only match is ${aws:username} in usms-self-manage-credentials.json, an IAM policy variable from Lab 1.
- usms-db-01 PublicIpAddress: Floci returns 127.0.0.1 (loopback, not internet-routable); the private subnet has no IGW route and does not auto-assign public IPs.
