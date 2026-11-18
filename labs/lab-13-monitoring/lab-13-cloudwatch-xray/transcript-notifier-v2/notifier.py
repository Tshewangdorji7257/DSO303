"""usms-transcript-notifier, version 2 - instrumented."""

import json
import os
import time
import urllib.parse

BUCKET_HINT = os.environ.get("USMS_BUCKET", "usms-student-data")
CHANNEL = os.environ.get("USMS_NOTIFY_CHANNEL", "stdout")
NAMESPACE = os.environ.get("USMS_METRIC_NAMESPACE", "USMS/Application")
FACULTY_DEFAULT = os.environ.get("USMS_FACULTY_DEFAULT", "unknown")


def trace_id(context):
    header = os.environ.get("_X_AMZN_TRACE_ID", "")
    for part in header.split(";"):
        if part.startswith("Root="):
            return part[len("Root="):]
    return getattr(context, "aws_request_id", "no-trace")


def describe(record):
    s3 = record.get("s3", {})
    raw_key = s3.get("object", {}).get("key", "")
    return {
        "event": record.get("eventName"),
        "bucket": s3.get("bucket", {}).get("name"),
        "key": urllib.parse.unquote_plus(raw_key),
        "size": s3.get("object", {}).get("size"),
    }


def faculty_of(key):
    parts = key.split("/")
    if len(parts) >= 3 and parts[0] == "transcripts":
        candidate = parts[1]
        if candidate.isalpha() and len(candidate) <= 20:
            return candidate.lower()
    return FACULTY_DEFAULT


def publish(metric, value, unit, dimensions):
    try:
        import boto3
        boto3.client("cloudwatch").put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[{
                "MetricName": metric,
                "Value": value,
                "Unit": unit,
                "Dimensions": [{"Name": k, "Value": v} for k, v in dimensions.items()],
            }],
        )
        return True
    except Exception as exc:
        print("USMS_METRIC_ERROR %s %s" % (metric, type(exc).__name__))
        return False


def notify(payload):
    print("USMS_NOTIFY " + json.dumps(payload, sort_keys=True))


def handler(event, context):
    started = time.time()
    tid = trace_id(context)
    records = event.get("Records", [])

    print("usms-transcript-notifier v2: %d record(s), channel=%s, trace=%s"
          % (len(records), CHANNEL, tid))

    processed = []
    for record in records:
        info = describe(record)
        info["trace_id"] = tid

        if not info["key"].startswith("transcripts/"):
            print("skipping non-transcript object: %s" % info["key"])
            continue

        info["readable"] = False
        try:
            import boto3
            boto3.client("s3").head_object(Bucket=info["bucket"], Key=info["key"])
            info["readable"] = True
        except Exception as exc:
            info["read_error"] = type(exc).__name__

        faculty = faculty_of(info["key"])
        info["faculty"] = faculty

        info["metric_published"] = publish(
            "TranscriptsProcessed", 1.0, "Count",
            {"Faculty": faculty, "Stage": "notify"})

        notify(info)
        processed.append(info["key"])

    elapsed = time.time() - started
    publish("TranscriptLagSeconds", elapsed, "Seconds", {"Stage": "notify"})

    print("USMS_SUMMARY " + json.dumps(
        {"processed": len(processed), "seconds": round(elapsed, 4), "trace_id": tid},
        sort_keys=True))

    return {"processed": len(processed), "keys": processed,
            "trace_id": tid, "seconds": round(elapsed, 4)}