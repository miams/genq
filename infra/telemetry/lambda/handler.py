"""
GenQuery Telemetry Collector

Receives two signal streams from genq clients via API Gateway HTTP API v2:

  POST /v1/traces    — OTLP/HTTP JSON spans (1..N spans per call)
                       Stored at  s3://<bucket>/traces/YYYY/MM/DD/HH-<reqid>.json.gz
                       and forwarded to Grafana Cloud's OTLP endpoint.

  POST /v1/profiles  — DB shape profile snapshots (one gzipped JSON per call,
                       client sends Content-Encoding: gzip).
                       Stored at  s3://<bucket>/profiles/<rm_unique_id>/
                       <captured-at>.json.gz  for fingerprint-keyed lookup.

All stdlib — no external dependencies.
"""

import json
import gzip
import os
import base64
import re
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
    raw_path = event.get("rawPath") or event.get("requestContext", {}).get("http", {}).get("path", "")

    # Route by path. Both /v1/traces and /v1/profiles share the same Lambda
    # — keeps deployment minimal and lets us evolve the schema in one place.
    if raw_path.endswith("/v1/profiles"):
        return _handle_profile(event, context)
    if raw_path.endswith("/v1/traces"):
        return _handle_trace(event, context)
    return {"statusCode": 404, "body": '{"error": "unknown route"}'}


def _read_body(event):
    """Return (raw_bytes, decoded_text) for the request body.

    API Gateway HTTP API v2 base64-encodes binary bodies (always sets
    isBase64Encoded=true when the client used Content-Encoding != identity).
    """
    body = event.get("body", "")
    is_b64 = event.get("isBase64Encoded", False)

    if not body:
        return b"", ""

    if is_b64:
        raw = base64.b64decode(body)
    else:
        raw = body.encode("utf-8")

    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    content_encoding = headers.get("content-encoding", "").lower()

    if content_encoding == "gzip":
        try:
            decoded = gzip.decompress(raw).decode("utf-8")
        except OSError as e:
            raise ValueError(f"gunzip failed: {e}") from e
    else:
        decoded = raw.decode("utf-8")

    return raw, decoded


def _handle_trace(event, context):
    try:
        raw, body = _read_body(event)
    except ValueError as e:
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})}

    if not body:
        return {"statusCode": 400, "body": '{"error": "empty body"}'}

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": '{"error": "invalid JSON"}'}

    if "resourceSpans" not in payload:
        return {"statusCode": 400, "body": '{"error": "missing resourceSpans"}'}

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

    if GRAFANA_OTLP_ENDPOINT and GRAFANA_INSTANCE_ID and GRAFANA_API_KEY:
        try:
            _forward_to_grafana(body)
        except Exception as e:
            print(f"Grafana forward failed: {e}")

    return {"statusCode": 200, "body": ""}


# Match RootsMagic's <UniqueID>...</UniqueID>: the embedded GUID is
# uppercase hex with no dashes (~36 chars in pres2025, varies in older
# DBs). Strict allow-list on S3 key segments to avoid path traversal.
_RM_UNIQUE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")


def _handle_profile(event, context):
    try:
        raw, body = _read_body(event)
    except ValueError as e:
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})}

    if not body:
        return {"statusCode": 400, "body": '{"error": "empty body"}'}

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": '{"error": "invalid JSON"}'}

    # Schema sanity. The client emits schemaVersion="1" with a fingerprint.
    if "schemaVersion" not in payload or "fingerprint" not in payload:
        return {
            "statusCode": 400,
            "body": '{"error": "missing schemaVersion or fingerprint"}',
        }

    rm_unique_id = (payload.get("fingerprint") or {}).get("rm_unique_id") or "unknown"
    if not _RM_UNIQUE_ID_RE.match(rm_unique_id):
        rm_unique_id = "unknown"

    captured_at = payload.get("capturedAtUnixNano") or str(int(datetime.now(timezone.utc).timestamp() * 1e9))

    s3_key = f"profiles/{rm_unique_id}/{captured_at}-{context.aws_request_id}.json.gz"

    # Store the gzipped bytes as-received when possible — saves a re-compress
    # round-trip and preserves the exact wire payload for audit.
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    if headers.get("content-encoding", "").lower() == "gzip":
        body_bytes = raw
    else:
        body_bytes = gzip.compress(body.encode("utf-8"))

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=body_bytes,
        ContentType="application/json",
        ContentEncoding="gzip",
    )

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
