"""
GenQuery Telemetry Collector

Receives OTLP/HTTP JSON traces from genq clients via API Gateway.
1. Validates the payload has resourceSpans
2. Compresses (gzip) and stores in S3 with date-partitioned keys
3. Forwards the original payload to Grafana Cloud's OTLP endpoint

All stdlib — no external dependencies.
"""

import json
import gzip
import os
import base64
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError

import boto3

s3 = boto3.client("s3")

S3_BUCKET = os.environ["S3_BUCKET"]
GRAFANA_OTLP_ENDPOINT = os.environ.get("GRAFANA_OTLP_ENDPOINT", "")
GRAFANA_INSTANCE_ID = os.environ.get("GRAFANA_INSTANCE_ID", "")
GRAFANA_API_KEY = os.environ.get("GRAFANA_API_KEY", "")


def lambda_handler(event, context):
    # Parse body from API Gateway v2 payload
    body = event.get("body", "")
    if event.get("isBase64Encoded", False):
        body = base64.b64decode(body).decode("utf-8")

    if not body:
        return {"statusCode": 400, "body": '{"error": "empty body"}'}

    # Validate it looks like OTLP traces
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": '{"error": "invalid JSON"}'}

    if "resourceSpans" not in payload:
        return {
            "statusCode": 400,
            "body": '{"error": "missing resourceSpans"}',
        }

    # Store compressed in S3 with date-partitioned key
    now = datetime.now(timezone.utc)
    s3_key = (
        f"traces/{now.year}/{now.month:02d}/{now.day:02d}/"
        f"{now.hour:02d}-{context.aws_request_id}.json.gz"
    )

    compressed = gzip.compress(body.encode("utf-8"))

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=compressed,
        ContentType="application/json",
        ContentEncoding="gzip",
    )

    # Forward to Grafana Cloud (best-effort — data is safe in S3 regardless)
    if GRAFANA_OTLP_ENDPOINT and GRAFANA_INSTANCE_ID and GRAFANA_API_KEY:
        try:
            _forward_to_grafana(body)
        except Exception as e:
            # Log but don't fail — S3 has the data
            print(f"Grafana forward failed: {e}")

    return {"statusCode": 200, "body": ""}


def _forward_to_grafana(body: str):
    """POST traces to Grafana Cloud's OTLP endpoint with Basic auth."""
    url = f"{GRAFANA_OTLP_ENDPOINT.rstrip('/')}/otlp/v1/traces"
    credentials = base64.b64encode(
        f"{GRAFANA_INSTANCE_ID}:{GRAFANA_API_KEY}".encode()
    ).decode()

    req = Request(
        url,
        data=body.encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Basic {credentials}",
        },
        method="POST",
    )

    try:
        with urlopen(req, timeout=5) as resp:
            print(f"Grafana response: {resp.status}")
    except URLError as e:
        raise RuntimeError(f"Grafana OTLP POST failed: {e}") from e
