Path: A
Step 12: build usms-enrolment-build:1 ended FAULT. Floci log: pull access denied for aws/codebuild/standard:7.0 (image not available on Docker Hub). Probe said Path A, but builds cannot execute here. Effective path for execution: C (local runner).
Step 17: pipeline created (2 stages) but get-pipeline-state shows no latestExecution. Floci stores the pipeline without executing it. Recorded, not observed.
Correction to Step 17: Floci does execute pipelines. No execution starts at creation, but start-pipeline-execution runs one. Source stage Succeeded; Build stage Failed (expected: CodeBuild cannot pull aws/codebuild/standard:7.0 here).
Step 18: start-build on a CODEPIPELINE-source project was NOT rejected by Floci (created build usms-enrolment-build:2). Recorded, not observed on real AWS.
Your turn (r5): source/usms-enrolment-src.zip had 4 versions at that point (Step 11 r3, Step 19 r4, Step 19 r5 roll-forward, plus the Step 11 upload counted once each upload). BuildOutput objects: 0, because every CodeBuild run FAULTED on the image pull; only a successful build uploads an artifact. Source versions grow with every upload; BuildOutput grows only with successful executions.
Step 20: failure reproduced with the local runner (pre_build, exit 1), not via the pipeline. Fixed and re-uploaded.
