## Revision 5 decision
Deregistered usms-enrolment:5. It named image r8, which was never pushed,
so it could never run. Deregistering marks it INACTIVE; the revision still
exists in the family as a record.
How someone would notice it later: `aws ecs list-task-definitions
--family-prefix usms-enrolment --status INACTIVE` lists it, and
describe-task-definition on :5 shows an image tag that ECR's
describe-images does not have. An audit script should compare every
revision's image against ECR.

## SourceOutput question
If the Deploy action's inputArtifacts named SourceOutput, it would look for
imagedefinitions.json at the root of the source archive, not find it, and
fail in Deploy, not in Build where the mistake actually is.
