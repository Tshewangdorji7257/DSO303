# Lab 10: Edge Functions with AWS Lambda (Lambda@Edge, S3 and CloudFront)

---

## 1. Aim / Objective

To create and test AWS Lambda functions using the AWS CLI on Floci (a local AWS emulator). The objectives were:

- To create an S3 bucket and update an IAM role so that Lambda@Edge could use it.
- To create two edge functions: a viewer-request function and an origin-response function.
- To publish function versions and create a CloudFront distribution that uses them.
- To create a regional Lambda function that runs when a file is uploaded to S3.
- To verify that all resources work and survive a restart.

---

## 2. Introduction

AWS Lambda is a serverless compute service that runs code without the need to manage servers. Lambda@Edge is a feature of Lambda that lets CloudFront run code at locations close to the user, so requests can be checked or changed before they reach the origin. Its key features are automatic scaling, pay-per-use pricing, versions and aliases for safe releases, and links to other services such as S3 and CloudFront. In cloud computing, it is important because it lowers cost and delay while keeping the system secure and flexible. Typical applications include user authentication at the edge, adding security headers, URL rewriting, and reacting to file uploads.

---

## 3. Use Case

- Checking whether a student is logged in before a transcript is delivered (viewer-request function).
- Adding security headers and cache rules to every file served from S3 (origin-response function).
- Sending a notification to the registrar when a new transcript is uploaded to S3 (regional Lambda function).
- Delivering static files quickly to users around the world using CloudFront.

---

## 4. System Architecture / Design

```
                          +-------------------------------+
   Viewer (browser)       |          CloudFront           |
         |                |   (usms-transcript-cdn)       |
         |  1. request    |                               |
         +--------------->|  viewer-request function      |
         |                |  - lowercase the URI          |
         |  403 if no     |  - check student header       |
         |<---------------|  - stamp the request          |
         |   header       |           |                   |
         |                |           v                   |
         |                |      Edge cache               |
         |                |           | (cache miss)      |
         |                |           v                   |
         |                |  origin-response function     |
         |                |  - add 4 security headers     |
         |  5. response   |  - add cache-control          |
         |<---------------|           ^                   |
                          +-----------|-------------------+
                                      | 3. fetch object
                                      |
                          +-----------+-------------------+
                          |   S3 bucket: usms-student-data |
                          |   (origin, transcripts/ folder)|
                          +-----------+-------------------+
                                      | 4. ObjectCreated event
                                      |    (prefix transcripts/, suffix .json)
                                      v
                          +-------------------------------+
                          | Lambda: usms-transcript-       |
                          | notifier (alias: live)         |
                          | - prints a USMS_NOTIFY line    |
                          +-------------------------------+

   IAM role: usms-lambda-exec-role
   (trusts lambda.amazonaws.com and edgelambda.amazonaws.com)
```
![alt text](<aws-architecture-diagram (5).png>)

**Data flow:** The viewer sends a request to CloudFront. The viewer-request function checks it. If it is allowed, CloudFront gets the file from S3, and the origin-response function adds headers before the response is cached and returned. Separately, when a new `.json` file lands in `transcripts/`, S3 calls the notifier function.

---

## 5. Implementation Procedure

1. **Started Floci** and checked the storage status.
2. **Loaded earlier lab settings** and confirmed the account was `000000000000`. I set `AWS_ENDPOINT_URL=http://localhost:4566` because `localhost.floci.io` did not resolve.
3. **Created the lab folders**, one for each function.
4. **Probed Floci support.** Lambda, S3, logs and CloudFront were supported, so I used the real CloudFront path.
5. **Created the S3 bucket** `usms-student-data` and added three tags.
6. **Updated the IAM role trust policy** so it trusted both `lambda.amazonaws.com` and `edgelambda.amazonaws.com`.
7. **Wrote the viewer-request function** (`index.mjs`) to lowercase the URI, return 403 without a student header, and stamp allowed requests.
8. **Packaged and created the function** with Node.js 20, 128 MB memory and a 5 second timeout.
9. **Invoked it** with an allow event and a deny event.
10. **Tried to read the logs.** The build did not return usable logs, so I used the returned results as evidence.
11. **Published version 1** of the viewer function.
12. **Wrote, created and invoked the origin-response function** to add four security headers, a cache-control header and a chain marker.
13. **Published version 1** of the origin-response function.
14. **Checked both functions against the edge restrictions:** no environment variables, memory and timeout limits, no VPC, and a published version. All checks passed.
15. **Created the CloudFront distribution** with both functions attached by version ARN.
16. **Simulated the full edge chain** with a script, for both allow and deny cases.
17. **Wrote the regional notifier** (`notifier.py`) in Python.
18. **Created the notifier**, published versions, created the alias `live`, and moved the alias to version 2 and back to version 1.
19. **Added a resource policy** so that only my S3 bucket in my account could call the function.
20. **Added an S3 bucket notification** for `.json` files in `transcripts/` and uploaded a test file.
21. **Proved the notifier ran** using a made-up S3 event, and tested that the filter ignored two wrong files.
22. **Restarted Floci** and compared the state before and after.
23. **Wrote `configs/lab-10.env`** with 25 exports.
24. **Checked Git** and ran the verification script.

---

## 6. Results and Evidence

### 6.1 CLI / SDK Output

**Setup (Steps 1 to 4)**

Floci was started and the identity check showed account `000000000000`.

![Step 1: start Floci](../../screenshots/lab10/image.png)
![Step 2: load settings](../../screenshots/lab10/image-1.png)
![Step 2: identity check](../../screenshots/lab10/image-2.png)
Three lab folders were created.

![Step 3: lab folders](../../screenshots/lab10/image-3.png)

The support probe showed that CloudFront was available.

![Step 4: support probe](../../screenshots/lab10/image-4.png)

**S3 bucket and IAM role (Steps 5 and 6)**

The bucket was created and tagged.

![Step 5: create bucket](../../screenshots/lab10/image-5.png)
![Step 5: verify bucket](../../screenshots/lab10/image-6.png)

The role trust policy was read, rewritten and applied. The check showed two principals.

![Step 6: read role](../../screenshots/lab9/image-7.png)
![Step 6: trust policy](../../screenshots/lab10/image-8.png)
![Step 6: apply policy](../../screenshots/lab10/image-9.png)
![Step 6: verify](../../screenshots/lab10/image-10.png)

**Viewer-request function (Steps 7 to 11)**

The handler was written and the function was created with the correct settings.

![Step 7: handler](../../screenshots/lab10/image-11.png)
![Step 8: create function](../../screenshots/lab10/image-12.png)

The allow case returned a lowercase URI and the stamp header. The deny case returned status 403.

![Step 9: event](../../screenshots/lab10/image-13.png)
![Step 9: invoke](../../screenshots/lab10/image-14.png)
![Step 9: result](../../screenshots/lab10/image-15.png)
![Step 9: assertion](../../screenshots/lab10/image-16.png)
The logs were garbled on this build, which is a known Floci limit.

![Step 10: logs](../../screenshots/lab10/image-17.png)
![Step 10: log group](../../screenshots/lab10/image-18.png)

Version 1 was published and its ARN ended in `:1`.

![Step 11: publish version](../../screenshots/lab10/image-19.png)

**Origin-response function (Steps 12 and 13)**

The function was created, invoked and published. The result had four security headers, cache-control and the chain marker.

![Step 12-13: handler](../../screenshots/lab10/image-20.png)
![Step 12-13: create](../../screenshots/lab10/image-21.png)
![Step 12-13: event and invoke](../../screenshots/lab10/image-22.png)
![Step 12-13: verify and publish](../../screenshots/lab10/image-23.png)

**Edge restrictions (Step 14)**

An environment variable was added on purpose and then removed. The eligibility check showed 0 failures.

![Step 14: mistake](../../screenshots/lab10/image-24.png)
![Step 14: undo](../../screenshots/lab10/image-25.png)
![Step 14: check](../../screenshots/lab10/image-26.png)
![Step 14: result](../../screenshots/lab10/image-27.png)

**CloudFront distribution (Step 15)**

The distribution `EMXHXLXDHBPDEZ` was created with both associations pointing to `:1` ARNs.

![Step 15: config](../../screenshots/lab10/image-28.png)
![Step 15: config check](../../screenshots/lab10/image-29.png)
![Step 15: create](../../screenshots/lab10/image-30.png)
![Step 15: verify](../../screenshots/lab10/image-31.png)

**Edge chain simulation (Step 16)**

The allow run passed all three stages and the deny run stopped at stage one with 403.

![Step 16: script](../../screenshots/lab10/image-32.png)
![Step 16: allow run](../../screenshots/lab10/image-33.png)
![Step 16: deny run](../../screenshots/lab10/image-34.png)
![Step 16: restore trace](../../screenshots/lab10/image-35.png)

**Regional notifier (Steps 17 to 21)**

The notifier was written, created, versioned and given the alias `live`. The alias moved to version 2 and back to version 1.

![Step 17: notifier code](../../screenshots/lab10/image-36.png)
![Step 18: create](../../screenshots/lab10/image-37.png)
![Step 18: alias](../../screenshots/lab10/image-38.png)
![Step 18: roll forward and back](../../screenshots/lab10/image-39.png)

The resource policy was scoped to one bucket and one account.

![Step 19: add permission](../../screenshots/lab10/image-40.png)
![Step 19: policy check](../../screenshots/lab10/image-41.png)
The bucket notification was created and a test file was uploaded.

![Step 20: notification](../../screenshots/lab10/image-42.png)
![Step 20: upload](../../screenshots/lab10/image-43.png)
![Step 20: verify](../../screenshots/lab10/image-44.png)

The notifier was invoked with a made-up S3 event and returned `"processed": 1`. The filter test objects were uploaded.

![Step 21: logs](../../screenshots/lab10/image-45.png)
![Step 21: invoke](../../screenshots/lab10/image-46.png)
![Step 21: filter test](../../screenshots/lab10/image-47.png)

**Restart, config file and verification (Steps 22 to 24)**

After the restart, the before and after states were identical, and the edge chain still worked.

![Step 22: before](../../screenshots/lab10/image-48.png)
![Step 22: restart](../../screenshots/lab10/image-49.png)
![Step 22: after](../../screenshots/lab10/image-50.png)
![Step 22: code check](../../screenshots/lab10/image-51.png)
The `lab-10.env` file had 25 exports, all filled in.

![Step 23: write env file](../../screenshots/lab10/image-52.png)
![Step 23: check env file](../../screenshots/lab10/image-53.png)

Git showed only Lab 10 source files as new.

![Step 24: Git status](../../screenshots/lab10/image-54.png)

The verification script finished with **PASS=44, FAIL=0**.

![Verification script](../../screenshots/lab10/image-55.png)
![Verification result](../../screenshots/lab10/image-56.png)

### 6.2 AWS Management Console Verification

This lab ran on Floci, a local emulator, which has no AWS Management Console. So no console screenshots were taken. Instead, I confirmed each resource with AWS CLI read commands. They are listed below with one line of explanation each.

| Resource | Evidence | What it showed |
|---|---|---|
| S3 bucket | `head-bucket` and `get-bucket-tagging` (Step 5) | The bucket `usms-student-data` existed with three tags. |
| IAM role | `get-role` (Step 6) | The role trusted both `lambda.amazonaws.com` and `edgelambda.amazonaws.com`. |
| Lambda functions | `get-function-configuration` (Steps 8 and 12) | Both edge functions were `Active` with the correct runtime, memory and timeout. |
| Lambda versions | `publish-version` and `list-versions-by-function` (Steps 11 and 18) | Version 1 existed for each function, and the notifier also had version 2. |
| Lambda alias | `list-aliases` (Step 18) | The alias `live` pointed to version 1. |
| Resource policy | `get-policy` (Step 19) | Only S3 from my bucket and account could call the notifier. |
| S3 notification | `get-bucket-notification-configuration` (Step 20) | The bucket was linked to the `live` alias with the right filter. |
| CloudFront distribution | `get-distribution` (Step 15) | The distribution `EMXHXLXDHBPDEZ` had both functions attached by version ARN. |

---

## 7. Analysis and Discussion

**What was achieved?** I built a complete transcript delivery setup: an S3 origin, two Lambda@Edge functions, a CloudFront distribution, and a regional notifier triggered by S3. I proved the setup survived a restart.

**Did the results match the expected outcome?** Yes. Allow and deny cases gave the expected results, the chain header showed both functions worked together, the restart check was identical, and the final verification gave 44 passes and 0 failures. Two things differed from the lab: the log output was not usable, and my verification script had 44 checks instead of 51.

**Errors encountered and how they were fixed:**

| Error | Cause | Fix |
|---|---|---|
| Could not connect to the endpoint | `localhost.floci.io` did not resolve. | Exported `AWS_ENDPOINT_URL=http://localhost:4566`. |
| IAM showed UNSUPPORTED in the probe | The role variable held a full ARN, not a name. | Used `${USMS_ROLE_LAMBDA##*/}` to get the name. |
| Zip file not found | `COURSE_ROOT` pointed to the wrong folder. | Set `COURSE_ROOT="$PWD"`. |
| Invoke seemed to hang (exit 130) | The first run of a runtime was slow, and I pressed Ctrl+C. | Used `--cli-read-timeout 300` and waited about 2 minutes. |
| Long commands were scrambled | The terminal mixed up long pastes. | Wrote files with short Python scripts and ran commands one at a time. |
| Logs were garbled or empty | Known limit of this Floci build. | Used the returned results as evidence instead. |

**Observations:**

- The first invoke of each runtime was slow, but later invokes were fast.
- Floci did not enforce IAM or resource policies, so I checked them by reading them.
- Floci did not reject `$LATEST` or an alias in a CloudFront association, so I checked the ARN format myself.
- Edge functions could be given environment variables on Lambda, but CloudFront would reject them, so a separate check was needed.

---

## 8. Reflection

**1. What did you learn about this AWS service?**
I learned that Lambda@Edge runs code at CloudFront trigger points. Viewer-request runs on every request, and origin-response runs only on a cache miss. Edge functions need a role that trusts two principals, must use a published version, and cannot use environment variables. I also learned how versions and aliases work for regional functions.

**2. What challenges did you encounter?**
The main challenges were the endpoint name that did not resolve, the wrong `COURSE_ROOT`, the slow first invoke, scrambled long commands, and the missing logs. Some real AWS rules were not enforced by Floci, so I had to check them by reading the configuration.

**3. How would you apply this service in a real-world cloud environment?**
I would use a viewer-request function to check login tokens before serving private files. I would use an origin-response function to add security headers to every response. I would use S3-triggered Lambda functions to send notifications or process new uploads.

**4. What additional concepts or features would you like to explore?**
I would like to explore connecting the notifier to Amazon SNS, using Origin Access Control to keep the bucket private, testing on real AWS to see Lambda@Edge run at real edge locations, and using CloudWatch for logs and monitoring.

---

## 9. Conclusion

In this practical, I created an S3 origin bucket, updated an IAM role, built and published two Lambda@Edge functions, created a CloudFront distribution, and added a regional S3-triggered notifier. All objectives were achieved. The final verification script gave PASS=44 and FAIL=0, and every resource survived a Floci restart.

I learned the rules for Lambda@Edge, including the two trust principals, version-qualified ARNs and the ban on environment variables. I also learned how versions, aliases and resource policies work. I developed skills in using the AWS CLI, writing and testing Lambda functions, troubleshooting setup problems, and writing verification scripts. This service is important because it lets applications run secure, fast and scalable logic close to the user without managing any servers.