#!/usr/bin/env bash
# Lab 08 cleanup. WRITTEN, NOT RUN. Removes only objects this lab created.
set -uo pipefail
NS=usms
kubectl delete -f manifests/lab-08/ --ignore-not-found
kubectl label node --all workload- tier- 2>/dev/null || true
echo "Note: usms-gateway reverts to ClusterIP only if you re-apply Lab 7's Service manifest."
