# AWS DSO303 Practical Laboratory Report

## Lab 01 — Identity and Access Management (IAM)

---

## 1. Aim / Objective

The objectives of this practical exercise are:

* To understand the fundamental concepts of **AWS Identity and Access Management (IAM)**.
* To configure a local AWS-compatible environment using **Floci, Docker, and AWS CLI**.
* To create and manage IAM **users, groups, policies, and roles** using the AWS CLI.
* To understand the difference between **permissions policies and trust policies**.
* To implement access control following the **Principle of Least Privilege**.
* To create and manage **IAM access keys and temporary STS credentials**.
* To verify that IAM resources remain available after restarting the Floci environment.
* To practice securely handling credentials and protecting sensitive files using `.gitignore`.
* To verify the complete IAM environment using automated verification scripts.

The practical is divided into two parts: **Part A (Steps 1–15)** focuses on environment setup and persistence, while **Part B (Steps 16–33)** focuses on building the IAM foundation for the University Student Management System (USMS). 

---

## 2. Introduction

AWS Identity and Access Management (IAM) is a foundational AWS service used to securely control access to cloud resources. IAM allows administrators to create users, organize users into groups, assign permissions using policies, and provide temporary access through roles. IAM policies define which actions are allowed or denied on particular resources, while IAM roles can provide temporary credentials to applications, services, or users. In this practical, IAM concepts were implemented using the AWS CLI against **Floci**, a local AWS-compatible environment running through Docker. The practical also focused on security principles such as least privilege, controlled access, credential protection, and persistent cloud-resource configuration. IAM is important in cloud computing because it provides centralized identity and authorization management and helps prevent unauthorized access to cloud resources.

### Key Features

* IAM Users
* IAM Groups
* IAM Roles
* IAM Policies
* Customer Managed Policies
* Inline Policies
* Trust Policies
* Access Keys
* Temporary STS Credentials
* Fine-Grained Permissions
* Least-Privilege Access Control
* Identity and Access Management

---

## 3. Use Case

The practical is based on the **University Student Management System (USMS)** scenario. The USMS is a web application developed for the College of Science and Technology that manages student records, transcripts, enrolment notifications, and reports.

In a real cloud environment, different employees and applications would require different levels of access. Instead of giving every user administrator privileges, IAM can be used to assign permissions based on their responsibilities.

| IAM Group / Identity | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `usms-admins`        | Administrative management of the USMS cloud environment |
| `usms-developers`    | Development and infrastructure-related operations       |
| `usms-auditors`      | Auditing and monitoring activities                      |
| `usms-admin-01`      | Administrator identity                                  |
| `usms-dev-01`        | Developer identity                                      |
| `usms-audit-01`      | Auditor identity                                        |

This approach follows the **Principle of Least Privilege**, where users receive only the permissions required to perform their tasks.

The lab also creates roles for applications and services, including `usms-ec2-app-role`, `usms-lambda-exec-role`, and `usms-developer-role`. 

---

## 4. System Architecture / Design

The practical uses a local AWS-compatible environment instead of connecting directly to a real AWS account.

```text
                         Student / Cloud Engineer
                                  |
                                  |
                              AWS CLI
                                  |
                                  v
                     +-------------------------+
                     |     AWS CLI Profile     |
                     |         "floci"         |
                     +------------+------------+
                                  |
                                  | Endpoint
                                  v
                     +-------------------------+
                     |         Floci           |
                     |   Local AWS Emulator    |
                     +------------+------------+
                                  |
                                  v
                     +-------------------------+
                     |     IAM Service         |
                     +------------+------------+
                                  |
              +-----------------+------------------+
              |                 |                  |
              v                 v                  v
        IAM Users          IAM Groups         IAM Roles
              |                 |                  |
              |                 v                  |
              |          IAM Policies              |
              |                 |                  |
              +-----------------+------------------+
                                |
                                v
                    USMS Cloud Resources
                                |
              +-----------------+------------------+
              |                 |                  |
              v                 v                  v
             EC2             Lambda              Data
             Role             Role             Resources
```

### Architecture Explanation

The student interacts with the local environment using the **AWS CLI**. The AWS CLI is configured to use the `floci` profile and communicate with the Floci endpoint rather than a real AWS account.

Floci runs as a Docker-managed service and provides the local AWS-compatible environment. IAM resources are then created and managed through AWS CLI commands.

The IAM architecture contains users, groups, policies, and roles. Policies define what actions identities are permitted or denied to perform. Groups allow common permissions to be assigned to multiple users, while roles provide temporary identities for services or applications.

---

# 5. Implementation Procedure

## Part A: Environment Setup

### Step 1: Identify the System

The operating system, architecture, shell and home directory were identified using:

```bash
uname -s -m
echo "shell = $SHELL"
echo "home  = $HOME"
```

This step ensures that the correct environment is being used before beginning the practical. The lab expects a WSL environment when using the provided commands. 

---

## Step 2 — Verify Docker and Docker Compose

Docker and Docker Compose were verified using:

```bash
docker --version
docker info --format '{{.ServerVersion}}'
docker compose version
```

Docker is required because Floci runs as a Docker container, while Docker Compose is used to manage the Floci environment. 


---

## Step 3 — Prepare the Course Directory

The course directory was created and used as the main working directory:

```bash
mkdir -p ~/aws-floci-course
cd ~/aws-floci-course
```

The directory contains the files and folders required for the practical.

The major directories include:

```text
aws-floci-course/
├── labs/
├── policies/
├── configs/
├── scripts/
│   ├── setup/
│   ├── utilities/
│   └── cleanup/
├── templates/
├── outputs/
├── screenshots/
└── notes/
```

The `outputs/` directory is specifically protected because it can contain access keys and other sensitive output. 

---

## Step 4 — Configure Git Repository

Git was initialized for the project:

```bash
git init
```

The repository was used to maintain the practical files and configuration while sensitive files were excluded.

---

## Step 5 — Configure `.gitignore`

A `.gitignore` file was created before storing credentials or sensitive output.

The purpose was to ensure that files such as access keys and environment files were not accidentally committed to Git.

The lab specifically requires `outputs/` to remain outside Git because it can contain real-looking access key information. 

---

## Step 6 — Configure Floci

Floci was configured using Docker Compose with persistent storage.

The environment uses:

```text
FLOCI_STORAGE_MODE=hybrid
```

and a host directory is mounted to provide durable storage.

The lab requires persistence to be proven by creating a resource, restarting Floci and checking that the resource still exists. 

---

## Step 7 — Start Floci

The Floci environment was started using the provided setup script:

```bash
source ~/aws-floci-course/configs/course.env
./scripts/setup/floci-up.sh
```

The service was made available locally on port:

```text
4566
```

![alt text](image.png)

---

## Step 8 — Configure the AWS CLI

The AWS CLI was configured to communicate with the local Floci endpoint.

The `floci` profile was used for the practical so that commands were directed to the local environment instead of a real AWS account.

The environment was then checked using the provided identity verification script.

---

## Step 9 — Verify the AWS Identity

The current AWS identity was checked using:

```bash
./scripts/utilities/whoami.sh
```

The expected Floci account is:

```text
000000000000
```

This provides evidence that the AWS CLI is operating against the local Floci environment.


![alt text](image-1.png)


---

## Step 10 — Verify Floci Storage

The storage configuration was checked using:

```bash
./scripts/utilities/floci-storage-check.sh
```

The purpose of this step was to verify that the Floci storage configuration was correctly established.

---

## Step 11 — Verify Environment Isolation

The environment was checked to ensure that the AWS CLI was communicating with Floci rather than a real AWS account.

This is an important safety step because the practical uses AWS CLI commands that would otherwise affect real AWS resources.

---

## Step 12 — Create and Verify Persistent Resources

A test IAM resource was created before restarting Floci.

Floci was restarted and the resource was queried again.

The resource remaining available after the restart demonstrated that persistent storage was correctly configured.

---

## Step 13 — Restart Floci

The Floci service was stopped and restarted using the provided scripts.

The persistence configuration ensured that previously created IAM resources were not lost.

---

## Step 14 — Prove Persistence

The previously created resource was queried after restarting Floci.

The successful retrieval demonstrated:

```text
Create resource
      ↓
Restart Floci
      ↓
Query resource
      ↓
Resource still exists
```

This proved that the IAM environment was persistent. The lab identifies this persistence test as an important checkpoint before proceeding to Part B. 

![alt text](image-3.png)
![alt text](image-2.png)
![alt text](image-4.png)


---

## Step 15 — Completed Part A

At the end of Part A, the environment contained:

* Docker and Docker Compose
* Floci
* Persistent storage
* AWS CLI v2
* `floci` AWS CLI profile
* Project directory
* Git repository
* `.gitignore`
* Utility scripts

The environment was therefore ready for the IAM implementation.

---

# Part B — Building the IAM Foundation

## Step 16 — Understand IAM Concepts

The four main IAM building blocks were studied:

```text
User    → Identity for a person or long-lived program

Group   → Container for users

Role    → Temporary identity assumed by a service/user

Policy  → JSON document defining Allow/Deny permissions
```

A user can have permanent credentials, while a role is normally assumed and provides temporary credentials. Groups allow policies to be shared among multiple users. 

The difference between permission and trust policies was also studied.

| Policy             | Purpose                         |
| ------------------ | ------------------------------- |
| Permissions Policy | Defines what an identity can do |
| Trust Policy       | Defines who can assume a role   |

Every IAM role requires an appropriate trust policy and permissions policy. 

---

## Step 17 — Understand ARN Structure

Amazon Resource Names (ARNs) were studied because they uniquely identify AWS resources.

Example:

```text
arn:aws:iam::000000000000:policy/USMSDeveloperBase
```

ARNs are used when attaching policies and referring to specific AWS resources.

---

## Step 18 — Create IAM Groups

The following groups were created:

```text
usms-admins
usms-developers
usms-auditors
```

Groups were used to organize users according to their responsibilities.

---

## Step 19 — Create IAM Users

The following users were created:

```text
usms-admin-01
usms-dev-01
usms-audit-01
```

These users represent different personnel working on the USMS project.

---

## Step 20 — Add Users to Groups

Users were assigned to the appropriate groups.

This provides centralized permission management because policies can be attached to groups rather than directly to every user.

---

## Step 21 — Tag IAM Users

IAM users were assigned appropriate tags to identify their role and project.

Example:

```text
Key=Role
Value=Developer
```

and:

```text
Key=Project
Value=USMS
```

Tags can help organize and identify resources.

---

## Step 22 — Create the `USMSDeveloperBase` Policy

A customer-managed policy called:

```text
USMSDeveloperBase
```

was created.

The policy provides read access to infrastructure and selected permissions required for building networking resources while also restricting dangerous identity changes.

The policy includes an explicit deny for actions such as:

```text
iam:CreateUser
iam:DeleteUser
iam:CreateAccessKey
iam:AttachUserPolicy
iam:PutUserPolicy
```

The lab emphasizes that an explicit `Deny` takes priority over an `Allow`, making it useful as a privilege-escalation protection mechanism. 

The policy JSON was validated before being submitted:

```bash
python3 -m json.tool usms-developer-base-policy.json > /dev/null && echo "Valid JSON"
```

The policy was then created using:

```bash
aws iam create-policy \
  --policy-name USMSDeveloperBase \
  --description "Read infrastructure + build VPC networking for USMS. Denies identity escalation." \
  --policy-document file://usms-developer-base-policy.json
```

---

## Step 23 — Attach the Developer Policy

The customer-managed policy was attached to the required groups.

Example:

```bash
aws iam attach-group-policy \
  --group-name usms-developers \
  --policy-arn "$DEV_POLICY_ARN"

aws iam attach-group-policy \
  --group-name usms-admins \
  --policy-arn "$DEV_POLICY_ARN"
```

Using a customer-managed policy allows the same policy to be reused by multiple groups. 

---

## Step 24 — Create Additional IAM Policies

Additional policies were created for the USMS environment, including:

```text
USMSStudentDataReadWrite
USMSAssumeAppRoles
USMSLambdaBasic
```

These policies provide specific permissions required by different users and services.

---

## Step 25 — Create an Inline Policy

An inline policy was configured for:

```text
usms-dev-01
```

The policy was:

```text
USMSSelfManageCredentials
```

Inline policies are embedded directly into an IAM identity and are not standalone reusable policy objects. 

---

## Step 26 — Create IAM Roles

The following roles were created:

```text
usms-ec2-app-role
usms-lambda-exec-role
usms-developer-role
```

Roles are used for temporary access and are particularly useful for AWS services and applications because they avoid the need to embed long-term credentials.

---

## Step 27 — Configure Trust Policies

Trust policies were created for the IAM roles.

A trust policy determines:

```text
Who can assume the role?
```

while the attached permissions policy determines:

```text
What can the role do?
```

This distinction is important when designing secure AWS environments.

---

## Step 28 — Attach Policies to Roles

The required permissions policies were attached to the appropriate roles.

The roles were then inspected to confirm that their permissions and trust relationships were correctly configured.

---

## Step 29 — Create EC2 Instance Profile

An instance profile was created for the EC2 application role:

```text
usms-ec2-app-profile
```

The role was added to the instance profile.

The relevant AWS CLI operations include:

```bash
aws iam create-instance-profile \
  --instance-profile-name usms-ec2-app-profile

aws iam add-role-to-instance-profile \
  --instance-profile-name usms-ec2-app-profile \
  --role-name usms-ec2-app-role
```

Instance profiles allow an EC2 instance to use an IAM role.

---

## Step 30 — Configure and Verify STS AssumeRole

STS was used to demonstrate temporary role credentials.

The basic operation is:

```bash
aws sts assume-role \
  --role-arn <role-arn> \
  --role-session-name <session-name>
```

Unlike permanent access keys, temporary credentials expire after a defined period.

The lab identifies STS role assumption as one of the IAM mechanisms observable in Floci. 

---

## Step 31 — Create Access Keys

An access key was created for:

```text
usms-dev-01
```

The output was redirected directly to a protected file:

```bash
aws iam create-access-key \
  --user-name usms-dev-01 \
  > outputs/usms-dev-01-access-key.json
```

The file permissions were restricted:

```bash
chmod 600 outputs/usms-dev-01-access-key.json
```

The access key metadata was then checked without displaying the secret:

```bash
aws iam list-access-keys \
  --user-name usms-dev-01 \
  --query 'AccessKeyMetadata[*].{Key:AccessKeyId,Status:Status,Created:CreateDate}' \
  --output table
```

The lab emphasizes that the secret access key is shown only once and should never be committed to Git or shared. 

---

## Step 32 — Verify IAM Configuration

The complete IAM environment was checked using AWS CLI commands and the verification script.

The final environment contained:

```text
Groups
├── usms-admins
├── usms-developers
└── usms-auditors

Users
├── usms-admin-01
├── usms-dev-01
└── usms-audit-01

Policies
├── USMSDeveloperBase
├── USMSStudentDataReadWrite
├── USMSAssumeAppRoles
└── USMSLambdaBasic

Roles
├── usms-ec2-app-role
├── usms-lambda-exec-role
└── usms-developer-role

Instance Profile
└── usms-ec2-app-profile
```

The lab's final verification script checks the required artifacts and reports whether the implementation has passed. 

---

## Step 33 — Record and Commit the Work

The final status of the repository was checked:

```bash
git status --short
```

Sensitive files such as `.env` and files under `outputs/` were confirmed to be excluded.

The work was then committed:

```bash
git add .
git commit -q -m "feat(lab-01): IAM foundation for USMS (users, groups, policies, roles)"
git log --oneline
```

The lab requires `.gitignore` to be established before sensitive information can be committed. 

---

# 6. Results and Evidence

## 6.1 CLI Output

The practical was successfully implemented using AWS CLI commands against the local Floci environment.

### 1. System and Docker Verification

![alt text](image-24.png)

**Description:**
The image shows the Linux/WSL environment and Docker/Docker Compose versions used for the practical.

---

### 2. Floci Running

![alt text](image-5.png)

**Description:**
The image shows that Floci is running successfully through Docker Compose.

---

### 3. AWS CLI Identity Verification

![alt text](image-6.png)

**Description:**
The image shows that the AWS CLI is connected to the local Floci environment and uses the expected account.

---

### 4. Storage Persistence Verification

![alt text](image-3.png)
![alt text](image-2.png)
![alt text](image-4.png)

**Description:**
The image shows that Floci storage is configured correctly and that IAM resources can persist after restarting the environment.

---

### 5. IAM Groups

![alt text](image-7.png)

**Description:**
The images shows the creation and listing of the USMS IAM groups.

---

### 6. IAM Users

![alt text](image-8.png)
![alt text](image-9.png)

**Description:**
The image shows the USMS IAM users created using the AWS CLI.

---

### 7. Group Membership

![alt text](image-10.png)
![alt text](image-11.png)

**Description:**
The image shows that the IAM users were successfully added to their appropriate groups.

---

### 8. `USMSDeveloperBase` Policy

![alt text](image-12.png)
![alt text](image-13.png)
![alt text](image-14.png)

**Description:**
The image shows the creation and configuration of the customer-managed `USMSDeveloperBase` policy.

---

### 9. Policy Attachments

![alt text](image-15.png)


**Description:**
The image shows that the required policies were attached to the appropriate IAM groups.

---

### 10. IAM Roles

![alt text](image-16.png)

**Description:**
The image shows the IAM roles created for the USMS application and services.

---

### 11. Instance Profile

![alt text](image-17.png)

**Description:**
The image shows that the EC2 instance profile was created and associated with the appropriate IAM role.

---

### 12. STS AssumeRole

![alt text](image-18.png)
![alt text](image-19.png)

**Description:**
The image shows the successful generation of temporary credentials through the STS `AssumeRole` operation.

---

### 13. Access Key Metadata

![alt text](image-20.png)

**Description:**
The image shows that an access key was created for `usms-dev-01`. The secret access key should not be visible in the submitted screenshot.

---

### 14. Final Verification

![alt text](image-21.png)
![alt text](image-22.png)
![alt text](image-23.png)

**Description:**
The image shows the final Lab 01 verification output confirming that the required IAM artifacts were created successfully.

---

## 6.2 AWS Management Console Verification

This practical was performed using **Floci as a local AWS-compatible environment**, rather than a real AWS account. Therefore, the standard AWS Management Console does not provide the primary verification method for this practical.

Instead, verification was performed using the AWS CLI and Floci environment.

The main verification activities included:

* IAM users
* IAM groups
* Group memberships
* Customer-managed policies
* Inline policies
* IAM roles
* Trust policies
* Instance profiles
* Access keys
* STS role assumption
* Persistent storage
* Final verification script

> **Insert Floci/IAM verification screenshots here if available.**

---

# 7. Analysis and Discussion

The practical successfully demonstrated the fundamental concepts of AWS Identity and Access Management in a local AWS-compatible environment. IAM users, groups, policies, roles, and instance profiles were created and configured for the University Student Management System. The use of groups allowed permissions to be managed centrally instead of assigning identical permissions individually to each user.

One important observation was the difference between IAM permissions policies and trust policies. A permissions policy specifies the actions that an identity is allowed or denied to perform, while a trust policy determines which principal can assume an IAM role. Both are required when implementing role-based access.

The practical also demonstrated the importance of the Principle of Least Privilege. Instead of providing unrestricted administrator access, specific permissions were granted for the requirements of developers, auditors, applications, and services. The `USMSDeveloperBase` policy also contained explicit deny statements to prevent potentially dangerous identity changes. Explicit denies take precedence over allows, providing an additional security control. 

Another important observation was credential security. Access keys were stored in the protected `outputs/` directory, and the directory was excluded from Git. The secret access key was never intended to be included in screenshots or committed to the repository. 

The practical also demonstrated persistence. IAM resources remained available after restarting the Floci environment, proving that the storage configuration was working correctly. This was important because without persistence, the IAM environment would be lost when the local AWS emulator was restarted. 

---

# 8. Reflection

### 1. What did you learn about this AWS service?

I learned that AWS IAM is responsible for controlling authentication and authorization in an AWS environment. I learned how users, groups, policies, and roles work together to provide controlled access to resources. I also learned that policies can explicitly allow or deny actions and that roles can provide temporary credentials.

### 2. What challenges did you encounter?

The main challenges involved configuring the local Floci environment, ensuring that Docker and Docker Compose were working correctly, configuring the AWS CLI to communicate with Floci, and understanding the relationship between users, groups, policies, and roles. Handling access keys also required careful attention because sensitive credentials must not be displayed or committed to Git.

### 3. How would you apply this service in a real-world cloud environment?

In a real-world cloud environment, IAM can be used to create separate identities for administrators, developers, testers, auditors, and applications. Permissions can be assigned through groups and roles according to job responsibilities. This helps enforce least privilege and reduces the risk of unauthorized access.

### 4. What additional concepts or features would you like to explore?

The following IAM features would be useful to explore further:

* Multi-Factor Authentication (MFA)
* IAM Identity Center
* Cross-account IAM roles
* Identity federation
* Permission boundaries
* Attribute-Based Access Control (ABAC)
* IAM Access Analyzer
* CloudTrail auditing
* Service Control Policies (SCPs)

The practical notes that several of these features, including MFA, permission boundaries, SCPs, IAM Access Analyzer, and CloudTrail, are conceptual or require real AWS enforcement beyond what is observable in Floci. 

---

# 9. Conclusion

The objectives of the practical were successfully achieved. The local Floci environment was configured using Docker and AWS CLI, and the environment was verified for persistence and isolation. The practical provided hands-on experience with AWS IAM concepts including users, groups, customer-managed policies, inline policies, roles, trust policies, instance profiles, access keys, and STS temporary credentials.

The practical also reinforced important cloud security principles such as **least privilege, centralized permission management, explicit denial, role-based access, and secure credential handling**. Through the USMS scenario, the practical demonstrated how IAM can be used to organize users and applications according to their responsibilities while reducing unnecessary privileges. The skills developed in this laboratory provide a foundation for the following AWS practicals, including the VPC infrastructure that will be built in the next laboratory.

