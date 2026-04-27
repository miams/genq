# GenQuery Telemetry Infrastructure

Reference guide for the GenQuery telemetry system: Nushell client module, AWS serverless collector, and Grafana Cloud integration.

---

## Architecture

```
genq CLI (Nushell)
  │
  ├─ Session start → writes span to local NDJSON buffer
  │                  spawns background DB shape profile job (fire-and-forget)
  ├─ Command execution → writes command span to buffer
  │
  └─ genq telemetry send
        │
        ├─ POST /v1/traces   (OTLP/HTTP JSON)
        │
        └─ POST /v1/profiles (gzipped JSON, application/octet-stream)
                            │
                            ▼
        API Gateway HTTP API (us-east-1)
                            │
                            ▼
        Lambda (Python 3.12, arm64, 128MB) — single function, two routes
              │
              ├─ /v1/traces   ─→ S3 (traces/YYYY/MM/DD/HH-{id}.json.gz)
              │                ─→ forward → Grafana Cloud OTLP (Tempo)
              │
              └─ /v1/profiles ─→ S3 (profiles/<rm_unique_id>/<ts>-{id}.json.gz)
                                 (no Grafana forward — archive only)
```

---

## Configuration

### Client — `config/default.toml`

```toml
[telemetry]
auto_send = false                        # if true, upload on session end
endpoint_url = "https://n53fa2v117.execute-api.us-east-1.amazonaws.com"
retention_days = 30                      # local buffer + upload-history rotation
```

Telemetry is mandatory and always-on. There is no `enabled` field — privacy is
enforced by what is *not* collected, not by user permission gating.

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

### Check status

```bash
genq telemetry status     # shows endpoint, retention, buffer stats
```

### View buffered data

```bash
genq telemetry view       # prints buffered spans in human-readable format
```

### Send data

```bash
genq telemetry send       # uploads buffered NDJSON traces (POST /v1/traces)
                          # AND any pending DB shape profiles (POST /v1/profiles)
```

### Clear buffer

```bash
genq telemetry clear      # deletes local buffer files without uploading
```

### Show upload history

```bash
genq telemetry history    # prints transmission log: when, KB, spans, status
```

### Show DB shape profile state

```bash
genq telemetry profile    # shows current DB fingerprint, status, and pending snapshots
```

### How session-start works

When genq loads:

1. Generates a random 128-bit `trace_id` (no cross-session identity)
2. Collects OTel resource attributes: Nu version, OS, genq version, terminal, locale
3. Records DB filename only — no PRAGMA / `COUNT(*)` round-trips on the load path
4. Writes an initial `genq.session` span to the per-day NDJSON buffer in the
   OS-standard data directory (see "Local buffer location" below)
5. Stores session info in `$env.GENQ_TELEMETRY_SESSION` for command-level instrumentation
6. Spawns a background `job` that runs `genq telemetry profile-init` — captures
   the DB shape profile if the fingerprint has changed or the cached snapshot
   is older than 7 days; never blocks the prompt

All telemetry code is wrapped in `try/catch` — failures never break genq.

### How DB shape profiling works

The DB shape profile is a separate signal stream from traces. It captures
130+ scalar metrics and a handful of multi-row breakdowns describing the
*structure* of the active RootsMagic database (people / events / sources
counts, fact-type usage, geocoding ratios, time histograms). It exists to
answer "how big and how rich is this DB?" without paying that cost on every
command span.

Key properties:

- **Fingerprint-keyed**: each snapshot is keyed by `rm_unique_id` (RM's
  stable GUID) plus `latest_utcmoddate_julian` (max UTCModDate). The runner
  skips re-profiling when the fingerprint matches a recent local snapshot.
- **7-day TTL**: even if the fingerprint hasn't moved, a fresh snapshot is
  taken weekly.
- **Mega-query**: 130+ scalars run as a single SQLite SELECT (positional
  aliases `m_0001`…`m_NNNN` map back to metric names client-side); typical
  total wall time under 200 ms on Iiams (~12k people).
- **Background**: runs in `job spawn`; failures are silently absorbed.
- **Local-first**: snapshots are gzipped JSON in the data root's
  `profiles/<rm_unique_id>-<ts>.json.gz` before any network call. Successful
  uploads are moved to `sent/` under the *cache* root (the server has the
  authoritative copy — the local archive is purgeable). See "Local buffer
  location" below for the data/cache split per platform.

The metric catalog lives in
`src/lib/common/genq telemetry/profile-catalog.nu` — a plain list of
records (section, name, kind, query, notes). The runner is in
`profile.nu`. The user-facing viewer is `genq telemetry profile`.

### Local buffer location

The buffer (and upload-history log) lives in the OS-standard *data* directory;
the DB-shape-profile cache and uploaded-archive `sent/` directory live in the
OS-standard *cache* directory. Splitting the two means an aggressive cache
purge can never delete a span that hasn't shipped yet.

```
# Data root — span buffer + upload history
~/Library/Application Support/genq/telemetry/YYYY-MM-DD.ndjson   (macOS)
$XDG_DATA_HOME/genq/telemetry/YYYY-MM-DD.ndjson                  (Linux — default ~/.local/share)
%APPDATA%\genq\telemetry\YYYY-MM-DD.ndjson                       (Windows)

# Cache root — fingerprint cache + sent profile archives
~/Library/Caches/genq/telemetry/                                 (macOS)
$XDG_CACHE_HOME/genq/telemetry/                                  (Linux — default ~/.cache)
%LOCALAPPDATA%\genq\telemetry\                                   (Windows)
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
| API Gateway HTTP API (v2) | Receives `POST /v1/traces` and `POST /v1/profiles` | ~$1/million requests |
| Lambda (Python 3.12, arm64, 128MB) | Routes `/v1/traces` (compress+store+forward) and `/v1/profiles` (store as-received) | Free tier covers ~1M invocations/month |
| S3 bucket | Compressed trace + profile archive (`traces/...` and `profiles/<rm_unique_id>/...`) | ~$0.023/GB/month (Standard) |
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
# exit and re-enter to trigger a fresh session span
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
# Traces
aws s3 ls s3://genq-telemetry-20260424200504803600000001/traces/2026/ --recursive
# Should show .json.gz files partitioned by date

# DB shape profiles
aws s3 ls s3://genq-telemetry-20260424200504803600000001/profiles/ --recursive
# Should show .json.gz files keyed by <rm_unique_id>
```

Inspect a stored trace:

```bash
aws s3 cp s3://BUCKET/traces/2026/04/24/HH-REQUEST_ID.json.gz - | gunzip | jq .
```

Inspect a stored DB shape profile:

```bash
aws s3 cp s3://BUCKET/profiles/<rm_unique_id>/<ts>-<request_id>.json.gz - | gunzip | jq .
# Look for { schemaVersion, fingerprint, scalars, multi_rows, timing }
```

### 3. Grafana Cloud — confirm traces arrive

1. Open Grafana Cloud > **Explore**
2. Select **Tempo** as the data source
3. Query: `{ resource.service.name = "genq" }`
4. You should see traces with:
   - Root span: `genq.session` with `cold_start_ms`, `db.name`, `db.filename`
   - Child spans: `genq list people`, etc. (when command instrumentation is added)

   DB shape attributes (`person_count`, `size_kb`, etc.) live on the
   **profile** signal in S3 — not on Tempo spans.

### 4. Lambda logs — debug issues

```bash
aws logs tail /aws/lambda/genq-telemetry-collector --follow
```

### 5. Existing tests — confirm no regressions

```bash
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fast
# All tests should pass
```

---

## Privacy

- **Mandatory and always-on** — privacy is enforced by what is *not* collected
- **No PII** — no usernames, paths, hostnames, or machine IDs
- **No cross-session identity** — `trace_id` is random per session, never persisted
- **No database content** — only structural metadata (counts, ratios, schema shape) — never names, places, dates, notes, or other record content
- **Controlled error vocabulary** — error types are enum values, not free-form messages
- **Transparent** — `genq telemetry view` shows the buffer; `genq telemetry history` shows every upload attempt

See `docs/telemetry-design.md` for the full privacy specification.

---

## File Reference

### Client (Nushell)

| File | Purpose |
|---|---|
| `src/lib/common/genq telemetry/mod.nu` | Public API (status, send, clear, view, history, profile) |
| `src/lib/common/genq telemetry/collector.nu` | OTel resource/span builders |
| `src/lib/common/genq telemetry/buffer.nu` | NDJSON span buffer I/O and rotation |
| `src/lib/common/genq telemetry/history.nu` | Upload history I/O and rotation |
| `src/lib/common/genq telemetry/transport.nu` | OTLP/HTTP upload (`send-otlp` for traces, `send-profiles` for shape snapshots) |
| `src/lib/common/genq telemetry/profile-catalog.nu` | DB shape metric definitions (152+ entries, source of truth) |
| `src/lib/common/genq telemetry/profile.nu` | Profile runner: mega-query, fingerprint cache, persistence |
| `config/default.toml` | `[telemetry]` configuration section |

### Infrastructure (Terraform)

| File | Purpose |
|---|---|
| `infra/telemetry/main.tf` | Provider and backend config |
| `infra/telemetry/variables.tf` | Input variables (Grafana credentials, region) |
| `infra/telemetry/api_gateway.tf` | HTTP API Gateway with `POST /v1/traces` and `POST /v1/profiles` routes |
| `infra/telemetry/lambda.tf` | Lambda function, IAM role, CloudWatch logs |
| `infra/telemetry/s3.tf` | S3 bucket with lifecycle rules |
| `infra/telemetry/outputs.tf` | API endpoint URL and bucket name |
| `infra/telemetry/lambda/handler.py` | Lambda code — routes `/v1/traces` (compress, store, forward) and `/v1/profiles` (validate, store as-received) |
