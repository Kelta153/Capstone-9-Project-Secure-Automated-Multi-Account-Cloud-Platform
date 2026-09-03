import json
import os
import time
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
ec2 = boto3.client("ec2")

FINDINGS_BUCKET = os.environ.get("FINDINGS_BUCKET")
SEVERITY_THRESHOLD = float(os.environ.get("SEVERITY_THRESHOLD", "7"))


def handler(event, context):
    """
    Invoked by Step Functions with an "action" field selecting behavior,
    and the raw GuardDuty finding under "finding". Kept as one Lambda
    (rather than three) to minimize packaging/deploy overhead, with the
    Step Functions state machine providing the orchestration structure.
    """
    action = event.get("action")
    finding = event.get("finding", {})

    if action == "validate":
        return _validate(finding)
    if action == "log":
        return _log(finding)
    if action == "isolate":
        return _isolate(finding)

    raise ValueError(f"Unknown action: {action}")


def _validate(finding):
    severity = finding.get("severity", 0)
    is_valid = severity >= SEVERITY_THRESHOLD
    return {
        "valid": is_valid,
        "severity": severity,
        "finding": finding,
    }


def _log(finding):
    finding_id = finding.get("id", f"unknown-{int(time.time())}")
    key = f"guardduty-findings/{finding_id}-{int(time.time())}.json"

    s3.put_object(
        Bucket=FINDINGS_BUCKET,
        Key=key,
        Body=json.dumps(finding, default=str).encode("utf-8"),
        ContentType="application/json",
    )

    return {"logged": True, "s3_key": key, "finding": finding}


def _isolate(finding):
    instance_id = (
        finding.get("resource", {})
        .get("instanceDetails", {})
        .get("instanceId")
    )

    if not instance_id:
        return {
            "isolated": False,
            "reason": "Finding did not reference an EC2 instance",
            "instance_id": None,
            "finding": finding,
        }

    try:
        ec2.create_tags(
            Resources=[instance_id],
            Tags=[
                {"Key": "Isolated", "Value": "true"},
                {"Key": "IsolatedReason", "Value": finding.get("type", "unknown")},
                {"Key": "IsolatedAt", "Value": str(int(time.time()))},
            ],
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "InvalidInstanceID.NotFound":
            return {
                "isolated": False,
                "reason": f"Instance {instance_id} not found (expected for sample findings)",
                "instance_id": instance_id,
                "finding": finding,
            }
        raise

    return {
        "isolated": True,
        "instance_id": instance_id,
        "finding": finding,
    }