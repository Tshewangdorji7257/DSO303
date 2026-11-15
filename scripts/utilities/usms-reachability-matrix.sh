#!/usr/bin/env bash
# USMS reachability matrix. Read-only report; always exits 0.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env" 2>/dev/null || true
source "$REPO_ROOT/configs/lab-02.env" 2>/dev/null || true
VPC="${1:-${USMS_VPC_ID:-}}"
[ -n "$VPC" ] && [ "$VPC" != "none" ] || { echo "usage: $0 [vpc-id]" >&2; exit 2; }
SG="/tmp/usms-matrix-sg-$$.json"
EC2="/tmp/usms-matrix-ec2-$$.json"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" --output json > "$SG"
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC" --output json > "$EC2"
python3 scripts/utilities/usms-reachability-matrix.py "$SG" "$EC2"
rm -f "$SG" "$EC2"
exit 0
