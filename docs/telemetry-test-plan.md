# GenQuery Telemetry Test Cookbook

A small set of recipes you run by hand to verify the telemetry pipeline end-to-end.
Each recipe gives you four things:

- **Run** — the exact commands to execute
- **Verify** — what to look at to judge the result
- **Pass** — what counts as success
- **Fail** — what indicates a regression and what it usually means

Run **Section 1** after any change to the telemetry client code (~3 min, no
network needed). Run **Section 1 + 2** after a `terraform apply` or before
tagging a release (~10 min). Run **all four** sections if you've touched the
hooks, the parser, or anything that handles span attributes.

## Prerequisites

- macOS host (paths assume `~/Library/Application Support/genq` and `~/Library/Caches/genq`).
- `aws` CLI authenticated to the account holding the telemetry stack.
- Bucket and endpoint URL handy:
  ```bash
  cd ~/Code/genq/infra/telemetry
  BUCKET=$(terraform output -raw s3_bucket)
  ENDPOINT=$(terraform output -raw api_endpoint)
  echo "$BUCKET / $ENDPOINT"
  ```
- A working DB selected in `config/default.toml` (e.g. `pres2025` or `iiams`).

---

## Section 1 — Local Sanity (no network)

### 1.1 Cold start runs without errors

**Run:**
```bash
cd ~/Code/genq
nu --env-config ~/.config/nushell/env.nu src/main.nu
```

**Verify (inside the genq REPL):**
```nushell
$env.GENQ_TELEMETRY_SESSION | columns
```

**Pass:** Returns a list containing `trace_id`, `span_id`, `start_time`,
`start_time_unix_nano`, `commands_run`, `error_count`, `resource`. genq
loaded with no error output.

**Fail:** Load printed a stack trace, or `$env.GENQ_TELEMETRY_SESSION` is
unset. The `try { telemetry-init } catch { }` wrapper in `main.nu` should
have caught any error silently — if a trace reaches the user, the wrapper
isn't doing its job.

---

### 1.2 Commands flow into the buffer with safe shape

**Run (in the genq REPL):**
```nushell
genq list people --rin 1 | first 1
genq config list
genq telemetry view
```

**Verify:** Read the output of `genq telemetry view`.

**Pass:**
- Header reports at least 1 session and 2 commands.
- Each command line shows the canonical name (`genq list people`,
  `genq config list`) with a duration in ms.
- Privacy floor: command names contain **no** `--rin`, no `1`, no path
  fragments, no person-name strings.

**Fail:** Zero sessions/commands (hooks didn't fire), or argument values
visible in command names. The latter means `parse-genq-subcommand` regressed
and is leaking arg data into spans.

---

### 1.3 Status reports a configured endpoint and live buffer

**Run (in the genq REPL):**
```nushell
genq telemetry status
```

**Pass:** Output shows
- `Endpoint URL:` followed by an `https://...execute-api...amazonaws.com` URL,
- `Retention: 30 days`,
- `Spans:` with a non-zero count (carrying forward from 1.2),
- a `Date range:` line.
- **No** `Enabled:` line (telemetry is mandatory; a toggle should not exist).

**Fail:** Endpoint URL is `(not set)`, or an `Enabled:` line appears, or
`Spans: 0` despite running commands in 1.2.

---

### 1.4 Background profile job captures a snapshot

The first time you cold-start against a DB whose fingerprint isn't cached,
`profile-init` runs in a background `job` and writes a `.json.gz` file
within ~2 seconds. Subsequent cold-starts within 7 days against the same
DB skip the work.

**Run (in your shell, after at least one cold start since the last DB
modification):**
```bash
ls -lt "$HOME/Library/Application Support/genq/telemetry/profiles/"*.json.gz 2>/dev/null | head -3
```

**Pass:** At least one `<rm_unique_id>-<unix-nano>.json.gz` file exists.
On a fresh install you'll see one with mtime within the last few minutes.

**Fail:** Directory doesn't exist *and* you've never successfully run
profile-init, or the file count is zero on a freshly-installed setup.
(Zero count after a cached fingerprint hit is **not** a fail — see 1.6.)

---

### 1.5 Most recent profile is well-formed

The Lambda 400-rejects profiles missing `schemaVersion` or `fingerprint`,
so it's worth a one-time spot check before the first send after schema-
touching changes.

**Run:**
```bash
NEWEST=$(ls -1t "$HOME/Library/Application Support/genq/telemetry/profiles/"*.json.gz | head -1)
gzip -dc "$NEWEST" | jq 'keys'
gzip -dc "$NEWEST" | jq '.fingerprint'
gzip -dc "$NEWEST" | jq '.schemaVersion'
```

**Pass:**
- `keys` prints `["capturedAtUnixNano", "fingerprint", "multiRows", "scalars", "schemaVersion", "timing"]`
- `.fingerprint` prints `{ "rm_unique_id": "<hex>", "latest_utcmoddate_julian": "<num>" }` with both values non-empty.
- `.schemaVersion` prints `"1"`.

**Fail:** `schemaVersion` missing → Lambda will 400-reject this file.
Empty `rm_unique_id` → upload will land under `profiles/unknown/`;
investigate the `rm_unique_id` query in `profile-catalog.nu`.

---

### 1.6 Fingerprint cache prevents duplicate profiles

**Run:**
```bash
COUNT_BEFORE=$(ls "$HOME/Library/Application Support/genq/telemetry/profiles/"*.json.gz 2>/dev/null | wc -l | tr -d ' ')
echo "before: $COUNT_BEFORE"
```

Cold-start a fresh genq REPL in another terminal, wait ~5 seconds at the
prompt, then exit:
```bash
nu --env-config ~/.config/nushell/env.nu src/main.nu
# (wait 5s, then type `exit`)
```

Re-count:
```bash
COUNT_AFTER=$(ls "$HOME/Library/Application Support/genq/telemetry/profiles/"*.json.gz 2>/dev/null | wc -l | tr -d ' ')
echo "after: $COUNT_AFTER"
```

**Pass:** `COUNT_AFTER == COUNT_BEFORE`. The fingerprint cache returned
`false` from `should-profile` and the background job exited without
writing a new file.

**Fail:** Count grew, even though the DB hasn't been modified and the
previous profile is younger than 7 days. The cache lookup or fingerprint
comparison broke.

---

## Section 2 — Round-trip with AWS

These tests need the deployed backend (`terraform apply` succeeded) and a
working internet connection.

### 2.1 `genq telemetry send` succeeds

**Run (in a genq REPL with at least one buffered span and one pending
profile from Section 1):**
```nushell
genq telemetry send
```

**Pass:** Output contains
- `Sending N spans to <endpoint>/v1/traces...` followed by `Success: Telemetry data sent.` and `Local buffer cleared.`
- `Uploading M profile(s) to <endpoint>/v1/profiles...` followed by one or more `✓ <filename>.json.gz — <bytes> bytes` lines.

**Fail:** `Error:` line for either stream (endpoint reachable but rejected
the payload — check Lambda logs in 2.6), or `Deferred:` for either
(network problem — re-run when online).

---

### 2.2 History records both signal streams

**Run (in the genq REPL):**
```nushell
genq telemetry history | first 5
```

**Pass:** The most recent rows show `Status: success`. Compared to before
2.1, the table grew by **at least two rows** (one for traces, one or more
for profiles).

**Fail:** Any new row shows `failed` or `deferred`. Or the row count
didn't grow by ≥ 2 — the profile send path didn't record an upload entry.

---

### 2.3 S3 has a fresh trace object

**Run:**
```bash
BUCKET=$(terraform -chdir=$HOME/Code/genq/infra/telemetry output -raw s3_bucket)
aws s3 ls "s3://$BUCKET/traces/" --recursive | tail -3
```

**Pass:** The most recent key matches
`traces/YYYY/MM/DD/HH-<uuid>.json.gz` and its timestamp is within the
last few minutes.

**Fail:** No new objects since 2.1, or the key shape doesn't match (e.g.
no date partitioning).

---

### 2.4 S3 has a fresh profile object under a real `rm_unique_id`

**Run:**
```bash
aws s3 ls "s3://$BUCKET/profiles/" --recursive | tail -3
```

**Pass:** The most recent key is under `profiles/<HEX_RM_UNIQUE_ID>/` —
**not** under `profiles/unknown/`. Timestamp within the last few minutes.

**Fail:** Object lands under `profiles/unknown/`. The Lambda's
`_RM_UNIQUE_ID_RE` regex (`^[A-Za-z0-9_-]{1,128}$`) rejected what the
client sent. Inspect a recent client profile (`gzip -dc … | jq
.fingerprint.rm_unique_id`) to see what's slipping through.

---

### 2.5 Profile S3 object is byte-identical to the client gzip

The Lambda preserves the gzip bytes as-received for `/v1/profiles`
(`handler.py:159–163`). This test verifies that.

**Run:**
```bash
NEWEST_S3_KEY=$(aws s3 ls "s3://$BUCKET/profiles/" --recursive | sort -k1,2 | tail -1 | awk '{print $4}')
LOCAL_SENT=$(ls -1t "$HOME/Library/Caches/genq/telemetry/profiles/sent/"*.json.gz | head -1)
aws s3 cp "s3://$BUCKET/$NEWEST_S3_KEY" /tmp/s3-profile.json.gz
md5 -q /tmp/s3-profile.json.gz
md5 -q "$LOCAL_SENT"
```

**Pass:** Both `md5 -q` outputs are identical strings.

**Fail:** Hashes differ. The Lambda is re-compressing instead of
preserving the body — verify the `Content-Encoding: gzip` branch in
`_handle_profile`.

---

### 2.6 Lambda logs are clean

**Run:**
```bash
aws logs tail /aws/lambda/genq-telemetry-collector --since 5m
```

**Pass:** Activity from the request_id values seen in 2.3 / 2.4 is
present, with no `Traceback`, no `ERROR`, no `Grafana forward failed:`
lines. If your Grafana env vars are wired (`-var grafana_otlp_endpoint=…`
on apply), expect `Grafana response: 200` on each trace request.

**Fail:** Any traceback, or `Grafana forward failed: <non-200>`.
A traceback indicates a code bug; a Grafana failure usually means the
API key rotated or the endpoint URL is wrong.

---

### 2.7 Trace appears in Grafana Cloud Tempo

**Run:** Open Grafana Cloud → **Explore** → **Tempo** datasource. Run TraceQL:

```
{ resource.service.name = "genq" }
```

**Pass:** Within ~1 minute, the trace from 2.1 appears. Click it: root
span name is `genq.session`, child spans match the commands you ran
during the session.

**Fail:** No traces after 2 minutes (Grafana forwarding broken — check
Lambda env vars and CloudWatch). Or trace exists but a child command
span you ran is missing (hook fires inconsistently — check
`pre_prompt` wiring).

---

## Section 3 — Failure Modes

### 3.1 Empty-buffer send is a clean no-op

**Run (in the genq REPL):**
```nushell
genq telemetry clear
genq telemetry send
```

**Pass:** Prints `No buffered telemetry data to send.` (and equivalent
profile-side line if no pending profiles). No errors. No HTTP request
attempted.

**Fail:** Any error message, or the upload-history file gains a new
entry (it shouldn't — nothing was sent).

---

### 3.2 Offline send is classified `deferred` and preserves the buffer

**Run (in the genq REPL):**
```nushell
genq list people | first 1     # generate a span to send
$env.GENQ_CONFIG = ($env.GENQ_CONFIG | upsert telemetry.endpoint_url "https://does-not-exist.invalid")
genq telemetry send
genq telemetry history | first 1
genq telemetry status
```

**Pass:**
- `genq telemetry send` prints `Deferred:` (yellow) for the trace
  upload, with a message about DNS resolution.
- `Buffered data has been preserved for retry.` is printed.
- `genq telemetry history`'s top row shows `Status: deferred`.
- `genq telemetry status` still reports `Spans: ≥ 1` — buffer was
  not cleared.

**Fail:** Status classified as `failed` instead of `deferred` (means
`classify-error` in `history.nu` regressed and isn't recognising
DNS-failure error strings). Or buffer was cleared anyway (transport
incorrectly clears on non-success).

Restore the real endpoint by exiting and re-launching the REPL.

---

### 3.3 Lambda 400s on a malformed profile

A paranoid one-off — the client never produces malformed profiles, but
this confirms the Lambda's input validation is wired.

**Run:**
```bash
ENDPOINT=$(terraform -chdir=$HOME/Code/genq/infra/telemetry output -raw api_endpoint)
echo '{"foo":"bar"}' | gzip | curl -sS -X POST \
  -H "Content-Type: application/octet-stream" \
  -H "Content-Encoding: gzip" \
  --data-binary @- \
  -w "\nHTTP %{http_code}\n" \
  "$ENDPOINT/v1/profiles"
```

**Pass:** Output ends with `HTTP 400`, body is
`{"error": "missing schemaVersion or fingerprint"}`.

**Fail:** Any other status code, or a different error message.

---

## Section 4 — Privacy Spot-Checks

### 4.1 Subcommand parser strips arg values

**Run (in the genq REPL):**
```nushell
genq telemetry clear
genq list people --rin 1234 | first 1
genq census year 1910 | first 1
genq telemetry view
```

**Pass:** The Commands section of the view output shows command names
**without** the values:
- `genq list people` (no `--rin`, no `1234`)
- `genq census year` (no `1910`)

**Fail:** Any digit, flag value, or path fragment appears in a command
name. That's a parser regression — fix in `parse-genq-subcommand`
before doing anything else.

---

### 4.2 Buffered span attributes contain no PII

**Run:**
```bash
TODAY=$(date +%Y-%m-%d)
BUFFER="$HOME/Library/Application Support/genq/telemetry/$TODAY.ndjson"
jq -r '.attributes[]? | "\(.key) = \(.value | tostring)"' "$BUFFER" | sort -u
```

**Pass:** The unique attribute keys are limited to:
- `genq.command`, `genq.subcommand`, `genq.duration_ms`, `genq.result_rows`
- `genq.db.name`, `genq.db.filename`
- `genq.session.cold_start_ms`, `genq.session.duration_ms`,
  `genq.session.commands_run`, `genq.session.error_count`
- `genq.config.table_mode`, `genq.config.date_format`

No values contain `/Users/`, `/home/`, an `@` sign, or anything that
looks like a hostname or a file path beyond the bare `<file>.rmtree`
basename of `genq.db.filename`.

**Fail:** Any unexpected key, or any value containing path-shaped or
identity-shaped data. Cross-reference the field with
`docs/telemetry-design.md` § "Fields explicitly excluded".

---

## When to run what

| After this kind of change | Run |
|---|---|
| Edit any file under `src/lib/common/genq telemetry/` | Section 1 |
| Edit `src/main.nu` (telemetry-init, hooks) | Section 1 + 4 |
| Edit `infra/telemetry/lambda/handler.py` and `terraform apply` | Section 1 + 2 |
| Touch the schema (`profile-catalog.nu` columns, span attributes) | Section 1 + 2 + 4 |
| Tag a release | All four sections |
