# Lab 11 Report: CI/CD Pipeline with S3, CodeBuild and CodePipeline

## 1. Aim / Objective

To build a small CI/CD pipeline using the AWS CLI on the Floci AWS emulator. The objectives were:

- To create a versioned S3 bucket to store source code and build artifacts.
- To write a `buildspec.yml` and create a CodeBuild project to build a small web service.
- To create IAM roles and least-privilege policies for CodeBuild and CodePipeline.
- To create a two-stage CodePipeline (Source and Build) and run it.
- To verify the setup with a verification script.

## 2. Introduction

CI/CD (Continuous Integration and Continuous Delivery) is a way of building and releasing software automatically every time the code changes. On AWS, **Amazon S3** stores the source code and build files, **AWS CodeBuild** compiles, tests and packages the code using the commands in a `buildspec.yml` file, and **AWS CodePipeline** joins these steps into stages that run in order. **IAM** roles decide what each service is allowed to do. These services are important in cloud computing because they make releases faster, repeatable and less likely to contain human mistakes. They are typically used to build, test and deploy web applications and containers. In this lab I used the Floci emulator, which copies the AWS API on my own computer, so no real AWS account was used.

## 3. Use Case

- Building and testing application code automatically each time a developer uploads a new version.
- Keeping versioned source and build artifacts in Amazon S3 so an older release can be recovered.
- Controlling what a build server and a pipeline can do by using separate IAM roles with limited permissions.
- Delivering a new container image to Amazon ECS after a successful build (the next lab, Lab 12).

## 4. System Architecture / Design

The workflow below shows how the services worked together.

```mermaid
flowchart LR
    Dev[Developer<br/>AWS CLI] -->|1. zip source and upload| S3[(S3 bucket<br/>usms-pipeline-artifacts<br/>versioning ON)]
    subgraph Pipeline[CodePipeline: usms-enrolment-pipeline]
        direction LR
        Src[Stage 1: Source<br/>S3 action] -->|SourceOutput| Bld[Stage 2: Build<br/>CodeBuild action]
    end
    S3 -->|2. read source version| Src
    Bld -->|3. start build| CB[CodeBuild project<br/>usms-enrolment-build]
    CB -->|4. BuildOutput zip| S3
    IAM1[usms-codepipeline-role] -.used by.-> Pipeline
    IAM2[usms-codebuild-role] -.used by.-> CB
    IAM1 -.iam:PassRole.-> IAM2
    Local[Local runner<br/>usms-buildspec-run.sh] -.same buildspec.-> CB
```

Text version of the same diagram:

```
Developer (AWS CLI)
   |  1. zip + upload source
   v
S3: usms-pipeline-artifacts (versioning ON)
   |  2. Source stage reads the newest version
   v
CodePipeline: usms-enrolment-pipeline
   [Source] --SourceOutput--> [Build]
                                |  3. starts
                                v
                      CodeBuild: usms-enrolment-build
                                |  4. writes BuildOutput zip
                                v
                      S3: usms-pipeline-artifacts

IAM: usms-codepipeline-role --PassRole--> usms-codebuild-role
```
![alt text](<aws-architecture-diagram (6).png>)

- **AWS services used:** S3, IAM, CodeBuild, CodePipeline (CloudWatch Logs for build logs).
- **User interaction:** all commands were run by me from the AWS CLI in Git Bash.
- **Resource relationships:** the pipeline role starts the build project and can pass only the build role to CodeBuild.
- **Data flow:** source zip → Source stage → Build stage → build artifact zip in S3.

## 5. Implementation Procedure

1. **Started Floci.** I started the emulator and checked that storage mode was `hybrid`. I fixed the CLI endpoint to `http://localhost:4566` so the account showed `000000000000`.
2. **Loaded earlier lab settings.** I sourced `course.env` and the earlier lab env files. The container name was `enrolment-api`.
3. **Probed CI/CD support.** I ran a probe script. It reported **Path A** (CodeBuild and CodePipeline both answered).
4. **Created directories** for the app, policies, templates and notes.
5. **Created the artifact bucket** `usms-pipeline-artifacts` with tags, versioning and blocked public access.
6. **Proved versioning.** I uploaded two files to one key and saw two versions. I then deleted them (I added `tr -d '\r'` to fix a Windows line-ending problem).
7. **Wrote the app source:** `VERSION`, `index.html`, `healthz.html`, `service.json` and `smoke.sh`.
8. **Wrote `buildspec.yml`** with four phases: install, pre_build, build and post_build.
9. **Created the CodeBuild role and policy** (`usms-codebuild-role`, `USMSCodeBuildBase`), including a deny on student data.
10. **Created the CodeBuild project** `usms-enrolment-build` with an S3 source.
11. **Packed and uploaded the source** with a packer script that kept `buildspec.yml` at the zip root.
12. **Ran the build on its own.** It ended in `FAULT` because Floci could not pull the image `aws/codebuild/standard:7.0`.
13. **Skipped log reading.** The build never ran, so there were no logs or artifacts.
14. **Built a local buildspec runner** (`usms-buildspec-run.sh` and `usms-buildspec-gen.py`) and ran the same buildspec on my computer. It passed.
15. **Created the CodePipeline role and policy** (`usms-codepipeline-role`, `USMSCodePipelineBase`) with a scoped `iam:PassRole`.
16. **Wrote the pipeline definition** `lab-11-pipeline.json`.
17. **Created the pipeline** with two stages.
18. **Changed the build project source to `CODEPIPELINE`.**
19. **Ran the pipeline with release r4 and r5.** The Source stage succeeded and the Build stage failed with the same image error.
20. **Broke the build on purpose** (wrong container name), saw it fail in `pre_build`, then fixed it.
21. **Saved outputs** to `configs/lab-11.env` (26 exports), committed to Git, and ran `verify-lab-11.sh`.

## 6. Results and Evidence

### 6.1 CLI / SDK Output

**Steps 1 to 4: Floci, environment, probe and directories**

![alt text](../../screenshots/lab11/image.png)
![alt text](../../screenshots/lab11/image-1.png)
![alt text](../../screenshots/lab11/image-2.png)
![alt text](../../screenshots/lab11/image-3.png)
![alt text](../../screenshots/lab11/image-4.png)
![alt text](../../screenshots/lab11/image-5.png)

**Steps 5 and 6: Bucket and versioning proof**

![alt text](../../screenshots/lab11/image-6.png)
![alt text](../../screenshots/lab11/image-7.png)
![alt text](../../screenshots/lab11/image-8.png)
![alt text](../../screenshots/lab11/image-9.png)
![alt text](../../screenshots/lab11/image-10.png)

**Steps 7 and 8: Source tree and buildspec**

![alt text](../../screenshots/lab11/image-11.png)
![alt text](../../screenshots/lab11/image-12.png)
![alt text](../../screenshots/lab11/image-13.png)
![alt text](../../screenshots/lab11/image-14.png)
![alt text](../../screenshots/lab11/image-15.png)
![alt text](../../screenshots/lab11/image-16.png)

**Steps 9 and 10: CodeBuild role, policy and project**

![alt text](../../screenshots/lab11/image-17.png)
![alt text](../../screenshots/lab11/image-18.png)
![alt text](../../screenshots/lab11/image-19.png)
![alt text](../../screenshots/lab11/image-20.png)
![alt text](../../screenshots/lab11/image-21.png)
![alt text](../../screenshots/lab11/image-22.png)
![alt text](../../screenshots/lab11/image-23.png)

**Steps 11 and 12: Package, upload and first build (FAULT)**

![alt text](../../screenshots/lab11/image-24.png)
![alt text](../../screenshots/lab11/image-25.png)
![alt text](../../screenshots/lab11/image-26.png)
![alt text](../../screenshots/lab11/image-27.png)
![alt text](../../screenshots/lab11/image-28.png)

**Step 14: Local buildspec runner (passed, 7 smoke tests OK)**

![alt text](../../screenshots/lab11/image-29.png)
![alt text](../../screenshots/lab11/image-30.png)
![alt text](../../screenshots/lab11/image-31.png)
![alt text](../../screenshots/lab11/image-32.png)
![alt text](../../screenshots/lab11/image-33.png)
![alt text](../../screenshots/lab11/image-34.png)
![alt text](../../screenshots/lab11/image-35.png)

**Steps 15 to 18: Pipeline role, definition, creation and project hand-over**

![alt text](../../screenshots/lab11/image-36.png)
![alt text](../../screenshots/lab11/image-37.png)
![alt text](../../screenshots/lab11/image-38.png)
![alt text](../../screenshots/lab11/image-39.png)
![alt text](../../screenshots/lab11/image-40.png)
![alt text](../../screenshots/lab11/image-41.png)
![alt text](../../screenshots/lab11/image-42.png)
![alt text](../../screenshots/lab11/image-43.png)
![alt text](../../screenshots/lab11/image-44.png)

**Step 19: Pipeline run (Source Succeeded, Build FAULT) and local r4 build**

![alt text](../../screenshots/lab11/image-45.png)
![alt text](../../screenshots/lab11/image-46.png)
![alt text](../../screenshots/lab11/image-47.png)
![alt text](../../screenshots/lab11/image-48.png)
![alt text](../../screenshots/lab11/image-49.png)

**Step 20: Deliberate failure and fix**

![alt text](../../screenshots/lab11/image-50.png)
![alt text](../../screenshots/lab11/image-51.png)
![alt text](../../screenshots/lab11/image-52.png)

**Step 21: Environment file and commit**

![alt text](../../screenshots/lab11/image-53.png)
![alt text](../../screenshots/lab11/image-54.png)
![alt text](../../screenshots/lab11/image-55.png)
![alt text](../../screenshots/lab11/image-56.png)

**Verification script: PASS=46 FAIL=0**

![alt text](../../screenshots/lab11/image-57.png)

### 6.2 AWS Management Console Verification

This lab ran on the **Floci emulator**, not on real AWS, so there was no AWS Management Console to check. I used CLI read-back commands instead, and they are shown in section 6.1:

| Resource | CLI check used | One-line explanation |
|---|---|---|
| S3 bucket | `get-bucket-versioning`, `get-bucket-tagging` | Confirmed versioning was `Enabled` and the three tags existed. |
| IAM roles | `list-attached-role-policies`, `get-role` | Confirmed each role had its one policy and the right trusted service. |
| CodeBuild project | `batch-get-projects` | Confirmed the project name, S3 source, image and 15-minute timeout. |
| CodePipeline | `get-pipeline-state` | Confirmed the Source stage succeeded and the Build stage failed. |

## 7. Analysis and Discussion

**What was achieved?** I created the versioned bucket, two IAM roles with scoped policies, a CodeBuild project, a `buildspec.yml`, a local build runner and a two-stage pipeline. The verification script passed all 46 checks. The pipeline's Source stage succeeded, which proved that the bucket was versioned, the source object existed and the pipeline role could read it.

**Did the results match the expected outcome?** Partly. The setup and wiring matched. The build did not: every CodeBuild run (`usms-enrolment-build:1`, `:2` and `:4`) ended in `FAULT`, so no `BuildOutput` artifact was created. The probe said Path A, but the probe only checks that the API answers, not that builds can run.

**Errors encountered and how I fixed them:**

| Error | Fix |
|---|---|
| CLI pointed to `localhost.floci.io` and could not connect | Set `AWS_ENDPOINT_URL=http://localhost:4566` |
| Delete loop left 2 versions (hidden `\r` characters) | Added `\| tr -d '\r'` |
| Large pasted blocks were scrambled in Git Bash | Split files into smaller pieces and checked line counts |
| Build `FAULT`: `pull access denied for aws/codebuild/standard` | Used the local runner and reported it honestly |
| One pasted line started an extra pipeline execution (`[200~`) | Used the second, clean execution in my results |

**Observations:**

- Both the standalone build and the pipeline build failed for the same single reason, so the pipeline wiring was correct and only the build image was missing.
- My first idea that Floci did not run pipelines was wrong. It ran them once I started an execution.
- Floci accepted `start-build` on a `CODEPIPELINE` project, which real AWS would reject.
- The source key got a new version on every upload (4 versions at the r5 check), while `BuildOutput` stayed at 0 because only a successful build uploads an artifact.
- The deliberate failure showed that a build stops in the phase where the mistake is, and the message names the command.
- Local results had `buildId: local`, so I reported them as "built locally, not by CodeBuild".

## 8. Reflection

**1. What did I learn about these services?**
A pipeline is a chain of stages that pass zip files through one S3 bucket. The buildspec keeps build commands in the source code, so a build change is a normal, reviewable change. Versioning lets you go back to older source. I also learned that a green pipeline is not proof. The contents of the output artifact are the proof.

**2. What challenges did I meet?**
The CodeBuild image could not be pulled, so no real build finished. I also had Windows line-ending (`\r`) problems and scrambled pasted commands in Git Bash.

**3. How would I use this in a real cloud environment?**
I would store the code in a repository, have the pipeline start on every change (using EventBridge instead of polling), and run tests in CodeBuild. Then I would deploy the new container to ECS. I would keep separate, narrow IAM roles, as I did here, and use `iam:PassRole` with a condition so a pipeline can only hand over the roles it needs.

**4. What would I like to explore next?**
Blue/green deployments with CodeDeploy (Lab 12), pipeline triggers with EventBridge, build caching, approval stages, and failure notifications with CloudWatch and SNS.

## 9. Conclusion

I achieved most of the objectives. I built and verified the bucket, roles, policies, buildspec, CodeBuild project and two-stage pipeline, and the verification script passed all 46 checks. The one objective I could not meet was a successful CodeBuild run, because the emulator could not pull the build image. I ran the same buildspec with a local runner instead, and I stated clearly which results came from CodeBuild's setup and which came from the local build.

I learned how source, build and pipeline stages connect, why versioning and least-privilege roles matter, and how to find the cause of a failure by working from the pipeline stage to the build phase to the command. I improved my skills in the AWS CLI, writing IAM policies, YAML build files and shell scripts, and troubleshooting on Windows. These services matter because they make software releases automatic, repeatable and safer.