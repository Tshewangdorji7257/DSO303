Yes. Since you **have not performed the lab yet**, Section 5 should not be written as if the work has already been completed. It should function as a **follow-along practical guide**: you read one step, run the commands, verify the result, take the screenshot, and then move to the next step.

Below is the replacement **Section 5 — Implementation Procedure** in `.md` format. It follows the actual Lab 01 instructions and keeps the important checkpoints and evidence points. The lab itself is explicitly divided into **Part A (Steps 1–15)** and **Part B (Steps 16–33)**. 

---

# 5. Implementation Procedure

> **Important:** Perform the steps in the order shown below. Do not skip Part A and directly start creating IAM resources. The IAM foundation depends on the Floci environment being configured with persistent storage. 

## 5.1 Part A — Environment Setup

Part A prepares the local AWS environment using **WSL/Linux, Docker, Docker Compose, Floci, AWS CLI, and Git**.

---

## Step 1 — Identify the System

### Purpose

First, identify the operating system, architecture, shell, and home directory.

### Run

```bash
uname -s -m
echo "shell = $SHELL"
echo "home  = $HOME"
```

### Expected result

Your output should look similar to:

```text
Linux x86_64
shell = /bin/bash
home  = /home/student
```

The exact values will depend on your system.

### Important

Write down the value of `$HOME`.

For example:

```text
/home/student
```

You will need the absolute home directory later when configuring persistent Floci storage. The lab specifically warns against replacing an absolute path with `~` in configuration files. 

### Screenshot

> **Screenshot 5.1 — System Information**
> Capture the terminal showing `uname`, `$SHELL`, and `$HOME`.

---

# Step 2 — Verify Docker and Docker Compose

### Purpose

Floci runs inside Docker, so Docker and Docker Compose must be working before continuing.

### Run

```bash
docker --version
docker info --format '{{.ServerVersion}}'
docker compose version
```

### Expected result

Example:

```text
Docker version 27.x.x
27.x.x
Docker Compose version v2.x.x
```

The version numbers may be different.

### Test Docker

```bash
docker run --rm hello-world
```

You should see:

```text
Hello from Docker!
```

### Important

The lab requires **Docker Compose v2**, which uses:

```bash
docker compose
```

not:

```bash
docker-compose
```

The practical distinguishes the Docker client from the Docker daemon: `docker --version` can work even when the daemon is stopped, while `docker info` tests whether the daemon is actually reachable. 

### Screenshot

> **Screenshot 5.2 — Docker Verification**
> Capture `docker --version`, `docker compose version`, and successful `hello-world` output.

---

# Step 3 — Install the Floci CLI

### Purpose

Floci is the local AWS emulator used instead of a real AWS account.

The lab uses Floci because it allows AWS-style infrastructure to be created locally without using a real AWS account. 

### If using WSL/Linux

Run:

```bash
curl -fsSL https://floci.io/install.sh -o floci-install.sh
less floci-install.sh
sh floci-install.sh
```

If you already trust the installer and want to use the shorter installation method:

```bash
curl -fsSL https://floci.io/install.sh | sh
```

### Verify

```bash
floci version
```

### Expected

Something similar to:

```text
floci CLI  1.x.x
server     not running
```

`server not running` is normal at this stage because Floci has not been started yet.

### If `floci` is not found

Run:

```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Then:

```bash
floci version
```

### Screenshot

> **Screenshot 5.3 — Floci Installation**
> Capture the `floci version` output.

---

# Step 4 — Run Floci Diagnostics

### Purpose

Check that your machine is ready to run Floci.

### Run

```bash
floci doctor
```

### Expected

You should see checks similar to:

```text
✔ docker installed
✔ docker daemon reachable
✔ port 4566 available
✔ image floci/floci:latest available
```

The exact output depends on your Floci version. 

### Screenshot

> **Screenshot 5.4 — Floci Doctor**
> Capture the successful diagnostic output.

---

# Step 5 — Create the Course Directory

### Purpose

Create the complete project structure before starting Floci.

### Run

```bash
cd ~

mkdir -p aws-floci-course/{labs/lab-01-iam,policies,configs,templates,outputs,screenshots,notes}

mkdir -p aws-floci-course/scripts/{setup,utilities,cleanup}

cd ~/aws-floci-course

pwd
```

### Verify

```bash
find . -type d | sort
```

You should have a structure similar to:

```text
.
./configs
./labs
./labs/lab-01-iam
./notes
./outputs
./policies
./screenshots
./scripts
./scripts/cleanup
./scripts/setup
./scripts/utilities
./templates
```

The complete course structure is designed so that policies, configuration, scripts, screenshots, notes, and sensitive output are separated. 

### Screenshot

> **Screenshot 5.5 — Project Directory Structure**
> Capture the `find` output.

---

# Step 6 — Create `.gitignore` Before Any Secret Exists

### Purpose

The lab deliberately creates `.gitignore` **before creating credentials**.

This prevents access keys and other sensitive information from accidentally entering Git. 

### Run

Make sure you are inside:

```bash
cd ~/aws-floci-course
```

Create `.gitignore`:

```bash
cat > .gitignore << 'EOF'
# ============================================================
# aws-floci-course/.gitignore
# ============================================================

outputs/*
!outputs/.gitkeep

.env
.env.local

floci-data/
data/
.floci/

*.pem
*.key
*-access-key.json
*credentials*

.DS_Store
Thumbs.db
*.swp
.vscode/
.idea/
EOF
```

Create the placeholder:

```bash
touch outputs/.gitkeep
```

### Initialize Git

```bash
git init -q
git add .gitignore outputs/.gitkeep
git status --short
```

Expected:

```text
A  .gitignore
A  outputs/.gitkeep
```

### Test that secrets are ignored

```bash
echo '{"secret":"pretend-this-is-real"}' > outputs/fake-key.json

git status --short

git check-ignore -v outputs/fake-key.json

rm outputs/fake-key.json
```

The fake key should be ignored.

### Commit

```bash
git commit -q -m "chore: ignore secrets before the repo can hold any"

git log --oneline
```

### Important

Use:

```text
outputs/*
```

and **not**:

```text
outputs/
```

because the lab needs `outputs/.gitkeep` to remain trackable. 

### Screenshot

> **Screenshot 5.6 — Git Secret Protection**
> Capture `git status` and `git check-ignore -v outputs/fake-key.json`.

---

# Step 7 — Understand Floci Storage

Before starting Floci, understand the storage modes.

| Storage Mode | Meaning                                      |
| ------------ | -------------------------------------------- |
| `memory`     | Data disappears when the container stops     |
| `hybrid`     | Memory reads + asynchronous disk persistence |
| `persistent` | Synchronous disk writes                      |
| `wal`        | Write-ahead logging                          |

The lab uses:

```text
hybrid
```

because development needs persistent data without the overhead of synchronous writes. The default Floci mode is `memory`, so persistence must be explicitly configured. 

### Important settings

```text
FLOCI_STORAGE_MODE=hybrid
FLOCI_STORAGE_PERSISTENT_PATH=/app/data
FLOCI_STORAGE_HOST_PERSISTENT_PATH=<absolute host path>
FLOCI_DOCKER_RESOURCE_NAMESPACE=floci-course
```

The host path must be an **absolute path**. 

For example:

```text
/home/student/floci-data
```

---

# Step 8 — Create `course.env` and `docker-compose.yml`

## 8.1 Create `configs/course.env`

Run:

```bash
cd ~/aws-floci-course

cat > configs/course.env << 'EOF'
# USMS Course — shared configuration

export FLOCI_HOST_DATA_DIR="$HOME/floci-data"

export FLOCI_STORAGE_MODE="hybrid"

export FLOCI_CONTAINER_NAME="floci"
export FLOCI_COMPOSE_PROJECT="floci-course"

export AWS_PROFILE=floci
export FLOCI_ENDPOINT=http://localhost:4566
export AWS_REGION_COURSE=us-east-1
export ACCOUNT_ID=000000000000

export PROJECT=usms
export COURSE_ROOT="$HOME/aws-floci-course"
EOF
```

Load it:

```bash
source configs/course.env
```

Check:

```bash
echo "$FLOCI_HOST_DATA_DIR"
echo "$FLOCI_STORAGE_MODE"
echo "$FLOCI_ENDPOINT"
echo "$ACCOUNT_ID"
```

Expected:

```text
/home/student/floci-data
hybrid
http://localhost:4566
000000000000
```

---

## 8.2 Create `docker-compose.yml`

Run:

```bash
cat > docker-compose.yml << 'EOF'
name: floci-course

services:
  floci:
    image: floci/floci:latest
    container_name: floci
    restart: unless-stopped

    ports:
      - "4566:4566"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${FLOCI_HOST_DATA_DIR:?run ./scripts/setup/floci-up.sh instead of docker compose directly}:/app/data

    environment:
      FLOCI_STORAGE_MODE: ${FLOCI_STORAGE_MODE:-hybrid}
      FLOCI_STORAGE_PERSISTENT_PATH: /app/data
      FLOCI_STORAGE_HOST_PERSISTENT_PATH: ${FLOCI_HOST_DATA_DIR}

      FLOCI_STORAGE_PRUNE_VOLUMES_ON_DELETE: "false"
      FLOCI_DOCKER_RESOURCE_NAMESPACE: floci-course

      FLOCI_HOSTNAME: floci
      FLOCI_SERVICES_DOCKER_NETWORK: floci-course_default

      FLOCI_SERVICES_ECR_REGISTRY_BASE_PORT: "5100"
      FLOCI_SERVICES_ECR_REGISTRY_MAX_PORT: "5104"
      FLOCI_SERVICES_ELASTICACHE_PROXY_BASE_PORT: "6379"
      FLOCI_SERVICES_ELASTICACHE_PROXY_MAX_PORT: "6383"
      FLOCI_SERVICES_RDS_PROXY_BASE_PORT: "7001"
      FLOCI_SERVICES_RDS_PROXY_MAX_PORT: "7005"
      FLOCI_SERVICES_LAMBDA_RUNTIME_API_BASE_PORT: "9200"
      FLOCI_SERVICES_LAMBDA_RUNTIME_API_MAX_PORT: "9209"
      FLOCI_SERVICES_OPENSEARCH_PROXY_BASE_PORT: "9400"
      FLOCI_SERVICES_OPENSEARCH_PROXY_MAX_PORT: "9404"

    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:4566/_floci/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 30
      start_period: 20s
EOF
```

### Check the Compose file

```bash
docker compose config >/dev/null && echo "compose file is valid"
```

If you get an error saying `FLOCI_HOST_DATA_DIR` is missing, that is expected **before** running the startup script because `.env` has not yet been generated. The lab deliberately uses this check to prevent accidental incorrect mounts. 

---

# Step 9 — Create Floci Start/Stop Scripts

## 9.1 Create `floci-up.sh`

```bash
cat > scripts/setup/floci-up.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/configs/course.env"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || die "docker not found on PATH"
docker info >/dev/null 2>&1 || die "Docker is not running."

case "$FLOCI_HOST_DATA_DIR" in
  /*) ;;
  *) die "FLOCI_HOST_DATA_DIR must be ABSOLUTE" ;;
esac

if docker container inspect "$FLOCI_CONTAINER_NAME" >/dev/null 2>&1; then
  owner="$(docker container inspect "$FLOCI_CONTAINER_NAME" \
    --format '{{ index .Config.Labels "com.docker.compose.project" }}' 2>/dev/null || true)"

  if [ "$owner" != "$FLOCI_COMPOSE_PROJECT" ]; then
    warn "A container named '$FLOCI_CONTAINER_NAME' exists but Compose did not create it."
    die "Refusing to continue."
  fi
fi

mkdir -p "$FLOCI_HOST_DATA_DIR"

cat > "$REPO_ROOT/.env" <<ENVEOF
FLOCI_HOST_DATA_DIR=$FLOCI_HOST_DATA_DIR
FLOCI_STORAGE_MODE=$FLOCI_STORAGE_MODE
ENVEOF

log "Starting Floci (storage mode: $FLOCI_STORAGE_MODE)"

docker compose up -d

log "Waiting for Floci..."

deadline=$(( $(date +%s) + 180 ))

until curl -sf "http://localhost:4566/_floci/health" >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    docker compose logs --tail 50 floci >&2 || true
    die "Floci did not become healthy within 180s."
  fi
  sleep 2
done

mount_src="$(docker container inspect "$FLOCI_CONTAINER_NAME" \
  --format '{{ range .Mounts }}{{ if eq .Destination "/app/data" }}{{ .Type }}:{{ .Source }}{{ end }}{{ end }}')"

case "$mount_src" in
  bind:*) log "Verified /app/data -> ${mount_src#bind:}" ;;
  "") die "/app/data is not mounted." ;;
  *) warn "/app/data is a '$mount_src', not a host bind mount." ;;
esac

log "Floci is up at $FLOCI_ENDPOINT"
EOF

chmod +x scripts/setup/floci-up.sh
```

---

## 9.2 Create `floci-down.sh`

```bash
cat > scripts/setup/floci-down.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/configs/course.env"

docker compose stop

printf '\033[1;34m==>\033[0m Floci stopped. State preserved in %s\n' "$FLOCI_HOST_DATA_DIR"
EOF

chmod +x scripts/setup/floci-down.sh
```

### Start Floci

```bash
./scripts/setup/floci-up.sh
```

Expected:

```text
==> Starting Floci (storage mode: hybrid)
✔ Container floci Started
==> Verified /app/data -> /home/student/floci-data
==> Floci is up at http://localhost:4566
```

### Verify

```bash
docker compose ps
floci status
curl -s http://localhost:4566/_floci/health | head -c 300 ; echo
```

### Important — do NOT run

```bash
docker compose down -v
```

Do not run:

```bash
floci start
```

for this course environment.

The lab uses Docker Compose because the Compose configuration preserves the storage settings across restarts. 

### Screenshot

> **Screenshot 5.7 — Floci Running**
> Capture `docker compose ps`, `floci status`, and health output.

---

# Step 10 — Install AWS CLI v2

### Install on Linux x86_64

```bash
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip

unzip -q awscliv2.zip

sudo ./aws/install

rm -rf aws awscliv2.zip
```

### Verify

```bash
aws --version
```

You should see:

```text
aws-cli/2.x.x
```

The practical requires AWS CLI v2. 

### Screenshot

> **Screenshot 5.8 — AWS CLI Version**

---

# Step 11 — Understand AWS CLI Profiles

The Floci environment uses:

| Setting           | Value                   |
| ----------------- | ----------------------- |
| Access Key ID     | `test`                  |
| Secret Access Key | `test`                  |
| Region            | `us-east-1`             |
| Endpoint          | `http://localhost:4566` |

These are **dummy Floci credentials**, not real AWS credentials. 

The lab uses the AWS CLI profile:

```text
floci
```

---

# Step 12 — Create the `floci` AWS CLI Profile

Run:

```bash
aws configure set aws_access_key_id test --profile floci

aws configure set aws_secret_access_key test --profile floci

aws configure set region us-east-1 --profile floci

aws configure set output json --profile floci

aws configure set endpoint_url http://localhost:4566 --profile floci
```

### Verify

```bash
cat ~/.aws/config
cat ~/.aws/credentials
```

You should have:

```text
[profile floci]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
```

and:

```text
[floci]
aws_access_key_id = test
aws_secret_access_key = test
```

### Set profile automatically

```bash
source configs/course.env

echo 'source ~/aws-floci-course/configs/course.env' >> ~/.bashrc
```

The course deliberately uses a named profile rather than mixing AWS environment variables with profiles. 

### Screenshot

> **Screenshot 5.9 — AWS CLI Floci Profile**

---

# Step 13 — Verify AWS CLI Connection

Run:

```bash
aws sts get-caller-identity --profile floci
```

Expected:

```json
{
    "Account": "000000000000"
}
```

The important value is:

```text
000000000000
```

This is Floci's dummy account ID. 

---

## Create `whoami.sh`

```bash
cat > scripts/utilities/whoami.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"

echo "AWS_PROFILE         = ${AWS_PROFILE:-<unset>}"
echo "AWS_ENDPOINT_URL    = ${AWS_ENDPOINT_URL:-<unset, using profile>}"
echo "configured endpoint = $(aws configure get endpoint_url || echo '<none>')"
echo "configured region   = $(aws configure get region || echo '<none>')"
echo "---"

aws sts get-caller-identity --output table

acct="$(aws sts get-caller-identity --query Account --output text)"

if [ "$acct" = "$ACCOUNT_ID" ]; then
  printf '\033[1;32m[ok] Account %s — this is Floci, not real AWS.\033[0m\n' "$acct"
else
  printf '\033[1;31m[DANGER] Account %s is NOT the Floci account.\033[0m\n' "$acct"
  exit 1
fi
EOF

chmod +x scripts/utilities/whoami.sh
```

Run:

```bash
./scripts/utilities/whoami.sh
```

### Screenshot

> **Screenshot 5.10 — Floci Identity Verification**

---

# Step 14 — Prove Isolation and Persistence

This step proves **two different things**:

1. Commands are going to Floci.
2. Data survives a restart.

The lab explicitly distinguishes isolation from persistence. 

---

## 14.1 Prove the Endpoint

Run:

```bash
aws sts get-caller-identity --profile floci --debug 2>&1 \
  | grep -i "endpoint\|Making request" \
  | head -5
```

Look for:

```text
http://localhost:4566
```

and **not**:

```text
amazonaws.com
```

---

## 14.2 Stop Floci

```bash
./scripts/setup/floci-down.sh
```

Then:

```bash
aws sts get-caller-identity --profile floci
```

Expected:

```text
Could not connect to the endpoint URL:
"http://localhost:4566/"
```

This proves the CLI depends on the local Floci endpoint.

---

## 14.3 Start Floci Again

```bash
./scripts/setup/floci-up.sh
```

---

## 14.4 Create a Persistence Test User

```bash
aws iam create-user \
  --user-name persistence-check \
  --output text \
  --query 'User.Arn'
```

Expected:

```text
arn:aws:iam::000000000000:user/persistence-check
```

---

## 14.5 Restart Floci

```bash
docker compose restart floci

sleep 5

until curl -sf http://localhost:4566/_floci/health >/dev/null 2>&1; do
  sleep 2
done
```

---

## 14.6 Check the User

```bash
aws iam get-user \
  --user-name persistence-check \
  --query 'User.UserName' \
  --output text
```

Expected:

```text
persistence-check
```

This proves that the user survived the restart.

---

## 14.7 Check the Storage Directory

```bash
ls -la ~/floci-data
du -sh ~/floci-data
```

The directory should contain files and should not be empty. 

---

## 14.8 Delete the Test User

```bash
aws iam delete-user --user-name persistence-check
```

### Screenshot

> **Screenshot 5.11 — Persistence Test**
> Capture the user creation, restart, and successful `get-user` result.

---

# Step 15 — Storage Diagnostics and Commit Part A

## Create the storage diagnostic script

```bash
cat > scripts/utilities/floci-storage-check.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"

ok()   { printf '\033[1;32m  [ok]\033[0m   %s\n' "$*"; }
bad()  { printf '\033[1;31m  [FAIL]\033[0m %s\n' "$*"; }
note() { printf '         %s\n' "$*"; }
hdr()  { printf '\n\033[1;34m=== %s\033[0m\n' "$*"; }

envof() {
  docker container inspect "$FLOCI_CONTAINER_NAME" \
    --format '{{ range .Config.Env }}{{ println . }}{{ end }}' |
    sed -n "s/^$1=//p"
}

hdr "1. Container, and who created it"

if ! docker container inspect "$FLOCI_CONTAINER_NAME" >/dev/null 2>&1; then
  bad "No container named '$FLOCI_CONTAINER_NAME'."
  exit 1
fi

note "status: $(docker container inspect "$FLOCI_CONTAINER_NAME" --format '{{.State.Status}}')"

proj="$(docker container inspect "$FLOCI_CONTAINER_NAME" \
  --format '{{ index .Config.Labels "com.docker.compose.project" }}')"

if [ "$proj" = "$FLOCI_COMPOSE_PROJECT" ]; then
  ok "Created by Compose project '$FLOCI_COMPOSE_PROJECT'."
else
  bad "NOT created by Compose."
fi

hdr "2. Storage mode"

mode="$(envof FLOCI_STORAGE_MODE)"
mode="${mode:-<unset>}"

if [ "$mode" = "memory" ] || [ "$mode" = "<unset>" ]; then
  bad "FLOCI_STORAGE_MODE=$mode"
else
  ok "FLOCI_STORAGE_MODE=$mode (durable)"
fi

hdr "3. Is /app/data a real host directory?"

m="$(docker container inspect "$FLOCI_CONTAINER_NAME" \
  --format '{{ range .Mounts }}{{ if eq .Destination "/app/data" }}{{ .Type }} {{ .Source }}{{ end }}{{ end }}')"

if [ -z "$m" ]; then
  bad "/app/data is not mounted."
else
  set -- $m
  if [ "$1" = "bind" ]; then
    ok "bind mount -> $2"
  else
    bad "/app/data is a Docker volume."
  fi
fi

hdr "4. Sidecar storage"

hp="$(envof FLOCI_STORAGE_HOST_PERSISTENT_PATH)"

if [ -z "$hp" ]; then
  bad "FLOCI_STORAGE_HOST_PERSISTENT_PATH is unset."
elif [ "${hp#/}" = "$hp" ]; then
  bad "Path is not absolute."
else
  ok "FLOCI_STORAGE_HOST_PERSISTENT_PATH=$hp"
fi

hdr "5. Floci-managed volumes"

vols="$(docker volume ls -q --filter label=floci=true || true)"

if [ -z "$vols" ]; then
  note "(none)"
else
  printf '%s\n' "$vols"
fi

hdr "6. Host state directory"

if [ -d "$FLOCI_HOST_DATA_DIR" ]; then
  ok "$FLOCI_HOST_DATA_DIR exists"
  du -sh "$FLOCI_HOST_DATA_DIR"
else
  bad "$FLOCI_HOST_DATA_DIR does not exist."
fi

printf '\n'
EOF

chmod +x scripts/utilities/floci-storage-check.sh
```

Run:

```bash
./scripts/utilities/floci-storage-check.sh
```

You should have successful `[ok]` results.

The lab recommends keeping this output because it is useful evidence for the report and troubleshooting. 

---

## Create the README

```bash
cat > README.md << 'EOF'
# AWS CLI + Floci — USMS Course Project

Infrastructure for the University Student Management System (USMS),
built lab by lab with the AWS CLI against Floci.

## Quick start

source configs/course.env
./scripts/setup/floci-up.sh
./scripts/utilities/whoami.sh

## Daily workflow

./scripts/setup/floci-up.sh
# ... lab work ...
./scripts/setup/floci-down.sh

## Never run these

- docker compose down -v
- docker volume prune
- floci start
- rm -rf ~/floci-data

## Labs

| Lab | Topic | Status |
|---|---|---|
| 01 | IAM | [x] complete |
| 02 | VPC | [ ] not started |

## Conventions

- All resources are prefixed `usms-`
- Region: `us-east-1`
- Floci account: `000000000000`
- Storage mode: `hybrid`
- Secrets live in `outputs/`
EOF
```

---

## Commit Part A

Check:

```bash
git status --short
```

Make sure **no `.env` or access-key file** is listed.

Then:

```bash
git add .

git commit -m "feat(lab-01): environment bootstrap with durable Floci storage"

git log --oneline
```

### Checkpoint — Part A

At this point you should have:

```text
Docker
├── Running
└── Compose v2

Floci
├── Running through Docker Compose
├── Port 4566
├── hybrid storage
└── Persistent storage verified

AWS CLI
├── Version 2
└── floci profile configured

Git
├── Repository created
├── .gitignore configured
└── secrets protected
```

---

# 5.2 Part B — Building the IAM Foundation

Do **not** start Part B until Part A is working and persistence has been proven. 

---

# Step 16 — Understand IAM and ARNs

Before running commands, understand:

```text
USER
→ Identity for a person/program

GROUP
→ Container for users

ROLE
→ Temporary identity assumed by a user/service

POLICY
→ JSON document defining Allow/Deny permissions
```

A **permissions policy** answers:

```text
What can this identity do?
```

A **trust policy** answers:

```text
Who can assume this role?
```

Every role requires both. 

### Understand an ARN

Example:

```text
arn:aws:iam::000000000000:user/usms-dev-01
```

Breakdown:

```text
arn
│
├── aws              partition
├── iam              service
├── 000000000000     account
├── user             resource type
└── usms-dev-01      resource name
```

IAM is global, so the region portion is empty. 

---

# Step 17 — Inspect the Empty IAM Account

Go to:

```bash
cd ~/aws-floci-course/labs/lab-01-iam
```

Run:

```bash
aws iam list-users
```

Expected:

```json
{
    "Users": []
}
```

Also test:

```bash
aws iam list-users --output json
aws iam list-users --output table
aws iam list-users --output text
```

Then:

```bash
aws iam list-roles --output table
```

### Screenshot

> **Screenshot 5.12 — Initial IAM State**

---

# Step 18 — Create IAM Groups

Run:

```bash
aws iam create-group --group-name usms-admins

aws iam create-group --group-name usms-developers

aws iam create-group --group-name usms-auditors
```

Verify:

```bash
aws iam list-groups \
  --query 'Groups[*].[GroupName,Arn]' \
  --output table
```

Expected groups:

```text
usms-admins
usms-developers
usms-auditors
```

### Screenshot

> **Screenshot 5.13 — IAM Groups**

---

# Step 19 — Create IAM Users

Create the administrator:

```bash
ADMIN_ARN=$(aws iam create-user \
  --user-name usms-admin-01 \
  --tags Key=Project,Value=USMS Key=Role,Value=Administrator \
  --query 'User.Arn' \
  --output text)
```

Create developer:

```bash
DEV_ARN=$(aws iam create-user \
  --user-name usms-dev-01 \
  --tags Key=Project,Value=USMS Key=Role,Value=Developer \
  --query 'User.Arn' \
  --output text)
```

Create auditor:

```bash
AUDIT_ARN=$(aws iam create-user \
  --user-name usms-audit-01 \
  --tags Key=Project,Value=USMS Key=Role,Value=Auditor \
  --query 'User.Arn' \
  --output text)
```

Display the ARNs:

```bash
echo "$ADMIN_ARN"
echo "$DEV_ARN"
echo "$AUDIT_ARN"
```

Expected:

```text
arn:aws:iam::000000000000:user/usms-admin-01
arn:aws:iam::000000000000:user/usms-dev-01
arn:aws:iam::000000000000:user/usms-audit-01
```

Verify:

```bash
aws iam list-users \
  --query 'Users[*].{User:UserName,Created:CreateDate,Arn:Arn}' \
  --output table
```

Check developer tags:

```bash
aws iam get-user --user-name usms-dev-01

aws iam list-user-tags \
  --user-name usms-dev-01 \
  --output table
```

### Practice task

The original lab also asks you to practice creating:

```text
usms-intern-01
```

with:

```text
Role=Intern
```

If you do this practice task, remember that the final required inventory is centered on the three main users. 

### Screenshot

> **Screenshot 5.14 — IAM Users**

---

# Step 20 — Add Users to Groups

Run:

```bash
aws iam add-user-to-group \
  --group-name usms-admins \
  --user-name usms-admin-01

aws iam add-user-to-group \
  --group-name usms-developers \
  --user-name usms-dev-01

aws iam add-user-to-group \
  --group-name usms-auditors \
  --user-name usms-audit-01
```

Verify from the group side:

```bash
aws iam get-group \
  --group-name usms-developers \
  --query 'Users[*].UserName' \
  --output text
```

Verify from the user side:

```bash
aws iam list-groups-for-user \
  --user-name usms-dev-01 \
  --query 'Groups[*].GroupName' \
  --output text
```

Expected:

```text
usms-dev-01
usms-developers
```

### Screenshot

> **Screenshot 5.15 — User Group Membership**

---

# Step 21 — Attach ReadOnlyAccess

First check available AWS-managed policies:

```bash
aws iam list-policies \
  --scope AWS \
  --max-items 10 \
  --query 'Policies[*].[PolicyName,Arn]' \
  --output table
```

Try:

```bash
aws iam attach-group-policy \
  --group-name usms-auditors \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

Verify:

```bash
aws iam list-attached-group-policies \
  --group-name usms-auditors \
  --output table
```

### If `ReadOnlyAccess` is not available

Create:

```bash
cat > ~/aws-floci-course/policies/usms-readonly-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyEverything",
      "Effect": "Allow",
      "Action": [
        "iam:Get*",
        "iam:List*",
        "ec2:Describe*",
        "s3:Get*",
        "s3:List*",
        "logs:Describe*",
        "logs:Get*",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

Create:

```bash
RO_ARN=$(aws iam create-policy \
  --policy-name USMSReadOnly \
  --policy-document file://$HOME/aws-floci-course/policies/usms-readonly-policy.json \
  --query 'Policy.Arn' \
  --output text)
```

Attach:

```bash
aws iam attach-group-policy \
  --group-name usms-auditors \
  --policy-arn "$RO_ARN"
```

The lab explicitly notes that some Floci versions may not contain `ReadOnlyAccess`. 

### Screenshot

> **Screenshot 5.16 — Auditor Read-Only Policy**

---

# Step 22 — Create `USMSDeveloperBase`

Go to:

```bash
cd ~/aws-floci-course/policies
```

Create the policy:

```bash
cat > usms-developer-base-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadInfrastructure",
      "Effect": "Allow",
      "Action": [
        "iam:Get*",
        "iam:List*",
        "ec2:Describe*",
        "s3:List*",
        "s3:GetBucketLocation",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "logs:Describe*",
        "logs:GetLogEvents",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "BuildNetworkingForLab02",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:CreateSubnet",
        "ec2:CreateRouteTable",
        "ec2:CreateRoute",
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:AssociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateTags",
        "ec2:ModifyVpcAttribute"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    },
    {
      "Sid": "DenyDangerousIdentityChanges",
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:CreateAccessKey",
        "iam:AttachUserPolicy",
        "iam:PutUserPolicy",
        "aws-portal:*",
        "organizations:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

Validate:

```bash
python3 -m json.tool usms-developer-base-policy.json > /dev/null && echo "Valid JSON"
```

Create the policy:

```bash
DEV_POLICY_ARN=$(aws iam create-policy \
  --policy-name USMSDeveloperBase \
  --description "Read infrastructure + build VPC networking for USMS. Denies identity escalation." \
  --policy-document file://usms-developer-base-policy.json \
  --query 'Policy.Arn' \
  --output text)
```

Display:

```bash
echo "$DEV_POLICY_ARN"
```

Expected:

```text
arn:aws:iam::000000000000:policy/USMSDeveloperBase
```

Attach to developers:

```bash
aws iam attach-group-policy \
  --group-name usms-developers \
  --policy-arn "$DEV_POLICY_ARN"
```

Attach to admins:

```bash
aws iam attach-group-policy \
  --group-name usms-admins \
  --policy-arn "$DEV_POLICY_ARN"
```

Verify:

```bash
aws iam list-attached-group-policies \
  --group-name usms-developers \
  --output table
```

And:

```bash
aws iam get-policy \
  --policy-arn "$DEV_POLICY_ARN" \
  --query 'Policy.{Name:PolicyName,Attached:AttachmentCount,Default:DefaultVersionId}' \
  --output table
```

Expected:

```text
Attached = 2
Default  = v1
Name     = USMSDeveloperBase
```

The policy intentionally contains an explicit `Deny` for dangerous IAM operations. 

### Screenshot

> **Screenshot 5.17 — USMSDeveloperBase Policy**

---

# Step 23 — Create the Student Data S3 Policy

Run:

```bash
cat > usms-student-data-rw-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListTheBucketItself",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::usms-student-data"
    },
    {
      "Sid": "ReadWriteObjectsInsideTheBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::usms-student-data/*"
    },
    {
      "Sid": "NeverDeleteTheBucket",
      "Effect": "Deny",
      "Action": [
        "s3:DeleteBucket"
      ],
      "Resource": "arn:aws:s3:::usms-student-data"
    }
  ]
}
EOF
```

Create the policy:

```bash
S3_POLICY_ARN=$(aws iam create-policy \
  --policy-name USMSStudentDataReadWrite \
  --description "Read/write student transcripts in the USMS bucket. Bucket deletion denied." \
  --policy-document file://usms-student-data-rw-policy.json \
  --query 'Policy.Arn' \
  --output text)
```

Display:

```bash
echo "$S3_POLICY_ARN"
```

Verify:

```bash
aws iam list-policies \
  --scope Local \
  --query 'Policies[*].{Name:PolicyName,Attached:AttachmentCount}' \
  --output table
```

Remember:

```text
arn:aws:s3:::usms-student-data
```

is the bucket itself, while:

```text
arn:aws:s3:::usms-student-data/*
```

refers to objects inside the bucket. The actual bucket will be created in a later lab. 

### Screenshot

> **Screenshot 5.18 — Student Data Policy**

---

# Step 24 — Generate CLI Skeletons

Go to:

```bash
cd ~/aws-floci-course/templates
```

Run:

```bash
aws iam create-role --generate-cli-skeleton > create-role-skeleton.json

cat create-role-skeleton.json
```

Then generate the additional skeletons:

```bash
aws iam create-policy --generate-cli-skeleton > create-policy-skeleton.json

aws ec2 create-vpc --generate-cli-skeleton > create-vpc-skeleton.json
```

List them:

```bash
ls -l
```

The skeleton command does not contact AWS; it generates the parameter template locally. 

### Screenshot

> **Screenshot 5.19 — CLI Skeletons**

---

# Step 25 — Create the Inline Credential Policy

Go to:

```bash
cd ~/aws-floci-course/policies
```

Create:

```bash
cat > usms-self-manage-credentials.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageOwnAccessKeys",
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:ListAccessKeys",
        "iam:UpdateAccessKey",
        "iam:GetAccessKeyLastUsed"
      ],
      "Resource": "arn:aws:iam::000000000000:user/${aws:username}"
    },
    {
      "Sid": "ManageOwnPasswordAndMFA",
      "Effect": "Allow",
      "Action": [
        "iam:ChangePassword",
        "iam:GetUser",
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:ListMFADevices",
        "iam:ResyncMFADevice"
      ],
      "Resource": [
        "arn:aws:iam::000000000000:user/${aws:username}",
        "arn:aws:iam::000000000000:mfa/${aws:username}"
      ]
    }
  ]
}
EOF
```

### Important

Keep:

```text
<< 'EOF'
```

with quotes.

Otherwise the shell could try to interpret:

```text
${aws:username}
```

and damage the policy.

Verify:

```bash
grep aws:username usms-self-manage-credentials.json
```

Then attach the inline policy:

```bash
aws iam put-user-policy \
  --user-name usms-dev-01 \
  --policy-name USMSSelfManageCredentials \
  --policy-document file://usms-self-manage-credentials.json
```

Verify:

```bash
aws iam list-user-policies \
  --user-name usms-dev-01
```

and:

```bash
aws iam get-user-policy \
  --user-name usms-dev-01 \
  --policy-name USMSSelfManageCredentials
```

The lab intentionally uses an inline policy here to demonstrate how inline policies differ from managed policies. 

### Screenshot

> **Screenshot 5.20 — Inline Policy**

---

# Step 26 — Inspect the IAM Environment

Go to:

```bash
cd ~/aws-floci-course/labs/lab-01-iam
```

Set:

```bash
IAM_USER=usms-dev-01
```

Check groups:

```bash
aws iam list-groups-for-user \
  --user-name $IAM_USER \
  --query 'Groups[*].GroupName' \
  --output text
```

Check attached policies:

```bash
aws iam list-attached-user-policies \
  --user-name $IAM_USER \
  --query 'AttachedPolicies[*].PolicyName' \
  --output text
```

Check inline policies:

```bash
aws iam list-user-policies \
  --user-name $IAM_USER \
  --query 'PolicyNames' \
  --output text
```

Check access keys:

```bash
aws iam list-access-keys \
  --user-name $IAM_USER \
  --query 'AccessKeyMetadata[*].AccessKeyId' \
  --output text
```

### Save IAM snapshot

```bash
aws iam get-account-authorization-details \
  > ~/aws-floci-course/outputs/lab-01-iam-snapshot.json
```

Check:

```bash
wc -l ~/aws-floci-course/outputs/lab-01-iam-snapshot.json
```

The output is protected by `.gitignore`, so it will not be committed. 

### Screenshot

> **Screenshot 5.21 — IAM Inspection**

---

# Step 27 — Create Policy Version 2

Go to:

```bash
cd ~/aws-floci-course/policies
```

Run:

```bash
python3 - << 'PY'
import json
import pathlib

p = pathlib.Path("usms-developer-base-policy.json")

doc = json.loads(p.read_text())

for st in doc["Statement"]:
    if st.get("Sid") == "BuildNetworkingForLab02":
        st["Action"] += [
            "ec2:DeleteVpc",
            "ec2:DescribeAvailabilityZones"
        ]

pathlib.Path(
    "usms-developer-base-policy-v2.json"
).write_text(
    json.dumps(doc, indent=2)
)

print("wrote usms-developer-base-policy-v2.json")
PY
```

Create version 2:

```bash
aws iam create-policy-version \
  --policy-arn arn:aws:iam::000000000000:policy/USMSDeveloperBase \
  --policy-document file://usms-developer-base-policy-v2.json \
  --set-as-default
```

Verify:

```bash
aws iam list-policy-versions \
  --policy-arn arn:aws:iam::000000000000:policy/USMSDeveloperBase \
  --query 'Versions[*].{Version:VersionId,Default:IsDefaultVersion,Created:CreateDate}' \
  --output table
```

Expected:

```text
v2   True
v1   False
```

The purpose is to demonstrate that customer-managed policies can have versions and that a new version can become the default without replacing the policy itself. 

### Screenshot

> **Screenshot 5.22 — IAM Policy Versions**

---

# Step 28 — Create the EC2 Role

Go to:

```bash
cd ~/aws-floci-course/policies
```

Create the EC2 trust policy:

```bash
cat > trust-ec2.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEC2ToAssumeThisRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create the role:

```bash
EC2_ROLE_ARN=$(aws iam create-role \
  --role-name usms-ec2-app-role \
  --description "Role for the USMS application server (Lab 03). Grants S3 access to student data." \
  --assume-role-policy-document file://trust-ec2.json \
  --tags Key=Project,Value=USMS \
  --query 'Role.Arn' \
  --output text)
```

Display:

```bash
echo "$EC2_ROLE_ARN"
```

Attach the student-data policy:

```bash
aws iam attach-role-policy \
  --role-name usms-ec2-app-role \
  --policy-arn arn:aws:iam::000000000000:policy/USMSStudentDataReadWrite
```

Verify:

```bash
aws iam get-role \
  --role-name usms-ec2-app-role \
  --query 'Role.{Name:RoleName,Arn:Arn,Trust:AssumeRolePolicyDocument.Statement[0].Principal}' \
  --output json
```

Then:

```bash
aws iam list-attached-role-policies \
  --role-name usms-ec2-app-role \
  --output table
```

---

## Create the EC2 Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name usms-ec2-app-profile
```

Add the role:

```bash
aws iam add-role-to-instance-profile \
  --instance-profile-name usms-ec2-app-profile \
  --role-name usms-ec2-app-role
```

Verify:

```bash
aws iam get-instance-profile \
  --instance-profile-name usms-ec2-app-profile \
  --query 'InstanceProfile.{Profile:InstanceProfileName,Roles:Roles[*].RoleName}' \
  --output json
```

Expected:

```json
{
    "Profile": "usms-ec2-app-profile",
    "Roles": [
        "usms-ec2-app-role"
    ]
}
```

The instance profile is what will later allow an EC2 instance to receive the role. 

### Screenshot

> **Screenshot 5.23 — EC2 Role and Instance Profile**

---

# Step 29 — Create the Lambda Execution Role

Create the trust policy:

```bash
cat > trust-lambda.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaToAssumeThisRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create the policy:

```bash
cat > usms-lambda-basic-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WriteOwnLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:000000000000:*"
    },
    {
      "Sid": "ReadStudentDataForNotifications",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::usms-student-data/*"
    }
  ]
}
EOF
```

Create policy:

```bash
LAMBDA_POLICY_ARN=$(aws iam create-policy \
  --policy-name USMSLambdaBasic \
  --policy-document file://usms-lambda-basic-policy.json \
  --query 'Policy.Arn' \
  --output text)
```

Create role:

```bash
LAMBDA_ROLE_ARN=$(aws iam create-role \
  --role-name usms-lambda-exec-role \
  --description "Execution role for USMS notification functions (Lab 05)." \
  --assume-role-policy-document file://trust-lambda.json \
  --tags Key=Project,Value=USMS \
  --query 'Role.Arn' \
  --output text)
```

Attach:

```bash
aws iam attach-role-policy \
  --role-name usms-lambda-exec-role \
  --policy-arn "$LAMBDA_POLICY_ARN"
```

Display:

```bash
echo "$LAMBDA_ROLE_ARN"
```

Verify:

```bash
aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `usms-`)].{Role:RoleName,Arn:Arn}' \
  --output table
```

The Lambda role uses a different trust principal:

```text
lambda.amazonaws.com
```

while the EC2 role uses:

```text
ec2.amazonaws.com
```

This demonstrates that trust policies determine which AWS service can assume a role. 

### Screenshot

> **Screenshot 5.24 — Lambda Role**

---

# Step 30 — Create Developer Role and Use STS

## 30.1 Create the Trust Policy

```bash
cat > trust-account-developers.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowUSMSDevelopersToAssume",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::000000000000:user/usms-dev-01"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create role:

```bash
DEVROLE_ARN=$(aws iam create-role \
  --role-name usms-developer-role \
  --description "Elevated build permissions, assumed temporarily by USMS developers." \
  --assume-role-policy-document file://trust-account-developers.json \
  --max-session-duration 3600 \
  --query 'Role.Arn' \
  --output text)
```

Attach the developer policy:

```bash
aws iam attach-role-policy \
  --role-name usms-developer-role \
  --policy-arn arn:aws:iam::000000000000:policy/USMSDeveloperBase
```

---

## 30.2 Create the AssumeRole Policy

```bash
cat > usms-assume-app-roles-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeUSMSRoles",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::000000000000:role/usms-developer-role"
      ]
    }
  ]
}
EOF
```

Create:

```bash
ASSUME_POLICY_ARN=$(aws iam create-policy \
  --policy-name USMSAssumeAppRoles \
  --policy-document file://usms-assume-app-roles-policy.json \
  --query 'Policy.Arn' \
  --output text)
```

Attach to developers:

```bash
aws iam attach-group-policy \
  --group-name usms-developers \
  --policy-arn "$ASSUME_POLICY_ARN"
```

Attach to admins:

```bash
aws iam attach-group-policy \
  --group-name usms-admins \
  --policy-arn "$ASSUME_POLICY_ARN"
```

---

## 30.3 Assume the Role

```bash
aws sts assume-role \
  --role-arn "$DEVROLE_ARN" \
  --role-session-name usms-dev-01-lab01 \
  --duration-seconds 3600 \
  > ~/aws-floci-course/outputs/assumed-role.json
```

View:

```bash
cat ~/aws-floci-course/outputs/assumed-role.json
```

You should see:

```text
AccessKeyId
SecretAccessKey
SessionToken
Expiration
AssumedRoleUser
```

**Do not upload or submit this secret output.**

---

## 30.4 Test the Temporary Credentials

Make sure `jq` is installed:

```bash
sudo apt install -y jq
```

Then:

```bash
cd ~/aws-floci-course

export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' outputs/assumed-role.json)

export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' outputs/assumed-role.json)

export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' outputs/assumed-role.json)
```

Run:

```bash
aws sts get-caller-identity \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

Then **return to your normal Floci profile**:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

./scripts/utilities/whoami.sh
```

The lab emphasizes that temporary credentials include three credential values and expire automatically. 

### Screenshot

> **Screenshot 5.25 — STS Temporary Credentials**
> Capture only safe identity information. Do not expose secret credentials.

---

# Step 31 — Create Access Keys Safely

### Important

This step creates a secret access key.

**Never paste the secret access key into ChatGPT, email, GitHub, screenshots, or your report.**

Go to:

```bash
cd ~/aws-floci-course
```

Create the key directly into the protected output directory:

```bash
aws iam create-access-key \
  --user-name usms-dev-01 \
  > outputs/usms-dev-01-access-key.json
```

Set permissions:

```bash
chmod 600 outputs/usms-dev-01-access-key.json
```

Verify the key without showing the secret:

```bash
aws iam list-access-keys \
  --user-name usms-dev-01 \
  --query 'AccessKeyMetadata[*].{Key:AccessKeyId,Status:Status,Created:CreateDate}' \
  --output table
```

Verify Git protection:

```bash
git status --porcelain

git check-ignore -v outputs/usms-dev-01-access-key.json

ls -l outputs/usms-dev-01-access-key.json
```

The file should have permissions similar to:

```text
-rw------- 
```

The lab specifically requires that the secret never appear in terminal screenshots or Git. 

### Optional — create `usms-dev` profile

```bash
KEY_ID=$(jq -r '.AccessKey.AccessKeyId' \
  outputs/usms-dev-01-access-key.json)

KEY_SECRET=$(jq -r '.AccessKey.SecretAccessKey' \
  outputs/usms-dev-01-access-key.json)
```

Then:

```bash
aws configure set aws_access_key_id "$KEY_ID" --profile usms-dev

aws configure set aws_secret_access_key "$KEY_SECRET" --profile usms-dev

aws configure set region us-east-1 --profile usms-dev

aws configure set output json --profile usms-dev

aws configure set endpoint_url http://localhost:4566 --profile usms-dev
```

Test:

```bash
aws sts get-caller-identity --profile usms-dev
```

### Screenshot

> **Screenshot 5.26 — Access Key Metadata**
> Show only the access-key ID/status. **Never show the secret access key.**

---

# Step 32 — Test Permissions with the Policy Simulator

Run:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/usms-dev-01 \
  --action-names "ec2:CreateVpc" "iam:CreateUser" "s3:GetObject" \
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}' \
  --output table
```

On real AWS, the expected conceptual result is:

```text
ec2:CreateVpc   → allowed
iam:CreateUser  → explicitDeny
s3:GetObject    → implicitDeny
```

Meaning:

| Result         | Meaning                               |
| -------------- | ------------------------------------- |
| `allowed`      | An Allow statement permits the action |
| `explicitDeny` | A Deny statement blocks the action    |
| `implicitDeny` | No Allow exists                       |

The lab warns that Floci may return `UnsupportedOperation`, `InvalidAction`, or a simplified result for this command. If that happens, treat the result as **conceptual/real-AWS behavior** rather than a failure of the rest of the lab. 

### Screenshot

> **Screenshot 5.27 — Policy Simulator**

---

# Step 33 — Save the Lab State

The final step prepares the IAM information for the next practical.

Go to:

```bash
cd ~/aws-floci-course
```

Create:

```bash
configs/lab-01.env
```

The file should contain the ARNs created during the lab.

Use:

```bash
cat > configs/lab-01.env << EOF
# Lab 01 — IAM outputs
# Contains ARNs only. NO SECRETS.

export USMS_ACCOUNT_ID=000000000000

export USMS_ADMIN_USER=usms-admin-01
export USMS_DEV_USER=usms-dev-01
export USMS_AUDIT_USER=usms-audit-01

export USMS_ADMIN_ARN=$ADMIN_ARN
export USMS_DEV_ARN=$DEV_ARN
export USMS_AUDIT_ARN=$AUDIT_ARN

export USMS_DEV_POLICY_ARN=$DEV_POLICY_ARN
export USMS_S3_POLICY_ARN=$S3_POLICY_ARN

export USMS_EC2_ROLE_ARN=$EC2_ROLE_ARN
export USMS_LAMBDA_ROLE_ARN=$LAMBDA_ROLE_ARN
export USMS_DEV_ROLE_ARN=$DEVROLE_ARN

export USMS_ASSUME_POLICY_ARN=$ASSUME_POLICY_ARN
export USMS_LAMBDA_POLICY_ARN=$LAMBDA_POLICY_ARN

export USMS_EC2_INSTANCE_PROFILE=usms-ec2-app-profile
EOF
```

### Important

This file contains ARNs and names, **not secret access keys**, so it can be committed.

Load it:

```bash
source configs/lab-01.env
```

Check:

```bash
cat configs/lab-01.env
```

---

# 5.3 Final Verification

Start Floci if it is not running:

```bash
source ~/aws-floci-course/configs/course.env

./scripts/setup/floci-up.sh
```

Run the final verification script provided by the lab:

```bash
cd ~/aws-floci-course

source ~/aws-floci-course/configs/lab-01.env

./scripts/utilities/verify-lab-01.sh
```

The final verification checks the environment and IAM artifacts. The desired result is:

```text
FAIL=0
```

The lab's final evidence checklist includes:

```text
whoami.sh output
floci-storage-check.sh output
Step 14 persistence proof
verify-lab-01.sh with FAIL=0
```



### Screenshot

> **Screenshot 5.28 — Final Lab Verification**
> Capture the complete verification output showing all required checks passing.

---

# 5.4 Final Git Check

Before committing, run:

```bash
git status --short
```

### Check carefully

You should **NOT** see:

```text
.env
outputs/usms-dev-01-access-key.json
outputs/assumed-role.json
```

Then:

```bash
git add .

git commit -m "feat(lab-01): IAM foundation for USMS (users, groups, policies, roles)"

git log --oneline
```

The lab expects the `.gitignore` commit to be the earliest commit so that secret protection existed before sensitive files were created. 

---

# 5.5 Final Lab 01 Checklist

Before moving to Lab 02, confirm:

```text
[ ] Step 1  — System identified
[ ] Step 2  — Docker verified
[ ] Step 3  — Floci installed
[ ] Step 4  — Floci doctor passed
[ ] Step 5  — Project directories created
[ ] Step 6  — .gitignore created and tested
[ ] Step 7  — Storage mode understood
[ ] Step 8  — docker-compose.yml created
[ ] Step 9  — Floci started through Compose
[ ] Step 10 — AWS CLI v2 installed
[ ] Step 11 — AWS CLI profile understood
[ ] Step 12 — floci profile created
[ ] Step 13 — AWS CLI connected to Floci
[ ] Step 14 — Isolation and persistence proven
[ ] Step 15 — Storage diagnostic + Part A commit

[ ] Step 16 — IAM concepts understood
[ ] Step 17 — Empty IAM account inspected
[ ] Step 18 — IAM groups created
[ ] Step 19 — IAM users created
[ ] Step 20 — Users added to groups
[ ] Step 21 — ReadOnlyAccess attached
[ ] Step 22 — USMSDeveloperBase created
[ ] Step 23 — Student data policy created
[ ] Step 24 — CLI skeleton generated
[ ] Step 25 — Inline policy created
[ ] Step 26 — IAM configuration inspected
[ ] Step 27 — Policy version 2 created
[ ] Step 28 — EC2 role + instance profile created
[ ] Step 29 — Lambda role created
[ ] Step 30 — Developer role + STS tested
[ ] Step 31 — Access key created safely
[ ] Step 32 — Policy simulator tested
[ ] Step 33 — Lab state saved

[ ] Final verification completed
[ ] FAIL=0
[ ] No secrets committed
[ ] Final Git commit created
```

## Evidence to collect for your report

| Screenshot | Evidence              |
| ---------- | --------------------- |
| 5.1        | System information    |
| 5.2        | Docker/Compose        |
| 5.3        | Floci installation    |
| 5.4        | Floci doctor          |
| 5.5        | Directory structure   |
| 5.6        | Git secret protection |
| 5.7        | Floci running         |
| 5.8        | AWS CLI v2            |
| 5.9        | AWS CLI profile       |
| 5.10       | Floci identity        |
| 5.11       | Persistence           |
| 5.12       | Empty IAM account     |
| 5.13       | IAM groups            |
| 5.14       | IAM users             |
| 5.15       | Group membership      |
| 5.16       | Auditor policy        |
| 5.17       | Developer policy      |
| 5.18       | S3 policy             |
| 5.19       | CLI skeleton          |
| 5.20       | Inline policy         |
| 5.21       | IAM inspection        |
| 5.22       | Policy versions       |
| 5.23       | EC2 role/profile      |
| 5.24       | Lambda role           |
| 5.25       | STS role assumption   |
| 5.26       | Access key metadata   |
| 5.27       | Policy simulator      |
| 5.28       | Final verification    |

> **Security reminder:** Never put `SecretAccessKey`, `SessionToken`, or the contents of `outputs/usms-dev-01-access-key.json` into your report or screenshots. The lab intentionally puts these files under `outputs/`, which is protected by `.gitignore`. 

This version is intended to be used **while doing the lab**, not as a description of work already completed. After you finish each step, you can replace the corresponding `> **Screenshot ...**` placeholder with your actual screenshot and later use those screenshots in Section 6 of the report.
