# GenQuery Telemetry Infrastructure

Reference guide for the GenQuery telemetry system: Nushell client module, AWS serverless collector, and Grafana Cloud integration.

---

## Architecture

```
genq CLI (Nushell)
  │
  ├─ Session start → writes span to local NDJSON buffer
  ├─ Command execution → writes command span to buffer
  │
  └─ genq telemetry send
        │
        POST /v1/traces (OTLP/HTTP JSON)
        │
        ▼
  API Gateway HTTP API (us-east-1)
        │
        ▼
  Lambda (Python 3.12, arm64, 128MB)
        │
        ├─ gzip compress → S3 (traces/YYYY/MM/DD/HH-{id}.json.gz)
        │
        └─ forward → Grafana Cloud OTLP (Tempo)
```

---

## Configuration

### Client — `config/default.toml`

```toml
[telemetry]
enabled = false                          # opt-in only
auto_send = false                        # reserved for future use
endpoint_mode = "otlp"                   # "otlp" or "turso"
endpoint_url = "https://n53fa2v117.execute-api.us-east-1.amazonaws.com"
retention_days = 30                      # local buffer rotation
```

### AWS — Terraform variables

| Variable | Description | Example |
|---|---|---|
| `aws_region` | AWS region (default: us-east-1) | `us-east-1` |
| `grafana_otlp_endpoint` | Grafana Cloud OTLP gateway (no `/otlp` suffix) | `https://otlp-gateway-prod-us-east-3.grafana.net` |
| `grafana_instance_id` | Grafana Cloud stack ID (numeric) | `1609051` |
| `grafana_api_key` | Grafana Cloud API token (TracesPublisher scope) | `glc_eyJ...` |
| `s3_retention_days` | Days before S3 objects expire (default: 365) | `365` |

### Grafana Cloud setup

1. Go to **Connections** > **OpenTelemetry (OTLP)**
2. Select **OpenTelemetry SDK** > **Python** > **Serverless**
3. Generate a token with **TracesPublisher** scope
4. Extract the three values from the generated config:
   - Endpoint: the `OTEL_EXPORTER_OTLP_ENDPOINT` URL (strip the `/otlp` suffix for Terraform)
   - Instance ID and API key: decode the Basic auth header (`echo "<base64>" | base64 -d` gives `instance_id:api_key`)

---

## Nushell Client Commands

### Enable / disable

```bash
nu --env-config ~/.config/nushell/env.nu src/main.nu
genq telemetry enable     # opt in, writes enabled=true to config
genq telemetry disable    # opt out, deletes all buffered data
```

### Check status

```bash
genq telemetry status     # shows enabled state, endpoint, buffer stats
```

### View buffered data

```bash
genq telemetry view       # prints buffered spans in human-readable format
```

### Send data

```bash
genq telemetry send       # uploads buffered NDJSON to configured endpoint
```

### Clear buffer

```bash
genq telemetry clear      # deletes local buffer files without uploading
```

### How session-start works

When genq loads with `telemetry.enabled = true`:

1. Generates a random 128-bit `trace_id` (no cross-session identity)
2. Collects OTel resource attributes: Nu version, OS, genq version, terminal, locale
3. Queries DB metadata via read-only PRAGMAs: person count, DB size, filename
4. Writes an initial `genq.session` span to `~/.local/share/genq/telemetry/YYYY-MM-DD.ndjson`
5. Stores session info in `$env.GENQ_TELEMETRY_SESSION` for command-level instrumentation

All telemetry code is wrapped in `try/catch` — failures never break genq.

### Local buffer location

```
~/.local/share/genq/telemetry/YYYY-MM-DD.ndjson   # macOS / Linux
%APPDATA%\genq\telemetry\YYYY-MM-DD.ndjson         # Windows
```

Files older than `retention_days` are deleted at session start.

---

## Terraform Deployment

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials
- Grafana Cloud account with OTLP token

### Deploy

```bash
cd infra/telemetry

terraform init

# Option A: pass variables on command line
terraform apply \
  -var grafana_otlp_endpoint="https://otlp-gateway-prod-us-east-3.grafana.net" \
  -var grafana_instance_id="1609051" \
  -var grafana_api_key="glc_..."

# Option B: use environment variables (recommended for secrets)
export TF_VAR_grafana_api_key="glc_..."
terraform apply \
  -var grafana_otlp_endpoint="https://otlp-gateway-prod-us-east-3.grafana.net" \
  -var grafana_instance_id="1609051"
```

### Outputs

| Output | Description |
|---|---|
| `api_endpoint` | API Gateway URL — set as `telemetry.endpoint_url` in `config/default.toml` |
| `s3_bucket` | S3 bucket name for compressed trace storage |

### Destroy

```bash
cd infra/telemetry
terraform destroy
```

---

## AWS Resources Created

| Resource | Purpose | Cost |
|---|---|---|
| API Gateway HTTP API (v2) | Receives `POST /v1/traces` | ~$1/million requests |
| Lambda (Python 3.12, arm64, 128MB) | Compresses, stores, forwards | Free tier covers ~1M invocations/month |
| S3 bucket | Compressed trace archive | ~$0.023/GB/month (Standard) |
| CloudWatch log groups (2) | API Gateway + Lambda logs | 7-day retention |
| IAM role + policies | Lambda execution + S3 write | No cost |

**Estimated monthly cost at personal usage (~5 sessions/day): < $0.01**

### S3 lifecycle

| Age | Storage class |
|---|---|
| 0 - 30 days | Standard |
| 30 - 90 days | Standard-IA |
| 90 - 365 days | Glacier Instant Retrieval |
| 365+ days | Deleted |

---

## Verification

### 1. Client-side — confirm spans are buffered

```bash
nu --env-config ~/.config/nushell/env.nu src/main.nu
genq telemetry enable
# exit and re-enter to trigger a session span
genq telemetry view
# Should show a session with DB name, cold start ms, etc.
```

### 2. Send to AWS — confirm Lambda + S3

```bash
genq telemetry send
# Should print: "Success: Telemetry data sent."
```

Verify S3 storage:

```bash
aws s3 ls s3://genq-telemetry-20260424200504803600000001/traces/2026/ --recursive
# Should show .json.gz files partitioned by date
```

Inspect a stored trace:

```bash
aws s3 cp s3://BUCKET/traces/2026/04/24/HH-REQUEST_ID.json.gz - | gunzip | jq .
```

### 3. Grafana Cloud — confirm traces arrive

1. Open Grafana Cloud > **Explore**
2. Select **Tempo** as the data source
3. Query: `{ resource.service.name = "genq" }`
4. You should see traces with:
   - Root span: `genq.session` with `cold_start_ms`, `db.name`, `db.person_count`
   - Child spans: `genq list people`, etc. (when command instrumentation is added)

### 4. Lambda logs — debug issues

```bash
aws logs tail /aws/lambda/genq-telemetry-collector --follow
```

### 5. Existing tests — confirm no regressions

```bash
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fast
# All tests should pass (telemetry is disabled by default)
```

---

## Privacy

- **Opt-in only** — no data collected until `genq telemetry enable`
- **No PII** — no usernames, paths, hostnames, or machine IDs
- **No cross-session identity** — `trace_id` is random per session, never persisted
- **No database content** — only metadata (person count, DB size, filename)
- **Controlled error vocabulary** — error types are enum values, not free-form messages
- **Transparent** — `genq telemetry view` shows exactly what would be sent

See `docs/telemetry-design.md` for the full privacy specification.

---

## File Reference

### Client (Nushell)

| File | Purpose |
|---|---|
| `src/lib/common/genq telemetry/mod.nu` | Public API (status, enable, disable, send, clear, view) |
| `src/lib/common/genq telemetry/collector.nu` | OTel resource/span builders |
| `src/lib/common/genq telemetry/buffer.nu` | NDJSON file I/O and rotation |
| `src/lib/common/genq telemetry/transport.nu` | HTTP upload (OTLP + Turso) |
| `src/lib/common/genq telemetry/consent.nu` | Opt-in state management |
| `config/default.toml` | `[telemetry]` configuration section |
| `tests/analytics/schema.sql` | `usage_sessions` + `usage_commands` table definitions |

### Infrastructure (Terraform)

| File | Purpose |
|---|---|
| `infra/telemetry/main.tf` | Provider and backend config |
| `infra/telemetry/variables.tf` | Input variables (Grafana credentials, region) |
| `infra/telemetry/api_gateway.tf` | HTTP API Gateway with POST /v1/traces route |
| `infra/telemetry/lambda.tf` | Lambda function, IAM role, CloudWatch logs |
| `infra/telemetry/s3.tf` | S3 bucket with lifecycle rules |
| `infra/telemetry/outputs.tf` | API endpoint URL and bucket name |
| `infra/telemetry/lambda/handler.py` | Lambda code (receive, compress, forward) |
