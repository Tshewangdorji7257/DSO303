#!/usr/bin/env bash
# Emit one log event, two metric data points and one trace segment for the
# same fictional transcript, joined by trace id.
# Usage: usms-emit-telemetry.sh [faculty] [seconds]
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
source "$REPO_ROOT/configs/lab-13.env" 2>/dev/null || true
export AWS_ENDPOINT_URL=http://localhost:4566
export MSYS_NO_PATHCONV=1

FACULTY="${1:-science}"
SECONDS_TAKEN="${2:-0.42}"
GROUP="${USMS_LOG_GROUP_CENTRAL:-/usms/central/application}"
NAMESPACE="USMS/Application"
STREAM="emitter-$(date -u +%Y%m%d)"
TMP="outputs"

python3 - "$FACULTY" "$SECONDS_TAKEN" "$TMP" << 'PY'
import json, os, sys, time
faculty, secs, tmp = sys.argv[1], float(sys.argv[2]), sys.argv[3]
now = time.time()
trace_id = "1-%08x-%s" % (int(now), os.urandom(12).hex())
seg_id = os.urandom(8).hex()
json.dump([{"timestamp": int(now * 1000),
            "message": 'USMS_EVENT ' + json.dumps({"event": "transcript.processed",
                "faculty": faculty, "seconds": secs, "trace_id": trace_id})}],
          open(tmp + "/emit-log.json", "w"))
json.dump([
  {"MetricName": "TranscriptsProcessed", "Unit": "Count", "Value": 1,
   "Dimensions": [{"Name": "Faculty", "Value": faculty}, {"Name": "Stage", "Value": "notify"}]},
  {"MetricName": "TranscriptLagSeconds", "Unit": "Seconds", "Value": secs,
   "Dimensions": [{"Name": "Stage", "Value": "notify"}]}],
  open(tmp + "/emit-metrics.json", "w"))
json.dump({"name": "usms-transcript-notifier", "id": seg_id, "trace_id": trace_id,
           "start_time": round(now - secs, 3), "end_time": round(now, 3),
           "origin": "AWS::Lambda::Function",
           "annotations": {"faculty": faculty, "stage": "notify",
                           "emitted_by": "usms-emit-telemetry"}},
          open(tmp + "/emit-segment.json", "w"))
open(tmp + "/emit-ids.txt", "w").write("%s %s" % (trace_id, seg_id))
PY

read -r TRACE_ID SEG_ID < outputs/emit-ids.txt

aws logs create-log-stream --log-group-name "$GROUP" --log-stream-name "$STREAM" 2>/dev/null || true

aws logs put-log-events \
  --log-group-name "$GROUP" --log-stream-name "$STREAM" \
  --log-events "file://outputs/emit-log.json" \
  --query 'rejectedLogEventsInfo' --output json >/dev/null \
  && echo "  log     ok   $GROUP"

aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data "file://outputs/emit-metrics.json" \
  && echo "  metric  ok   $NAMESPACE"

if aws xray put-trace-segments --trace-segment-documents "$(cat outputs/emit-segment.json)" \
     >/dev/null 2>&1; then
  echo "  trace   ok   $TRACE_ID"
else
  echo "  trace   SKIPPED (X-Ray unavailable on this build) $TRACE_ID"
fi

printf '%s %s emitter/%s\n' "$TRACE_ID" "$SEG_ID" "$FACULTY" >> outputs/lab-13-trace-ids.txt
echo
echo "trace id: $TRACE_ID"