# GenQuery Telemetry Test Plan

Comprehensive test cases for the telemetry system. Tests are organized by module and labeled per the project convention (`fast` for no-DB, `db-pres2025`/`db-iiams` for DB-dependent).

Telemetry is mandatory and always-on; there is no consent module and no enable/disable subcommands.

---

## 2. Buffer Module (`buffer.nu`)

### 2.1 `buffer-dir` — directory resolution

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.1.1 | Creates directory if missing | Set `$env.XDG_DATA_HOME` to a temp path with no `genq/telemetry` subdir. Call `buffer-dir`. | Returns path; directory exists on disk |
| 2.1.2 | Returns existing directory | Call `buffer-dir` twice. | Same path both times; no error |
| 2.1.3 | Respects XDG_DATA_HOME | Set `$env.XDG_DATA_HOME = "/tmp/test-xdg"`. Call `buffer-dir`. | Returns `/tmp/test-xdg/genq/telemetry` |
| 2.1.4 | Falls back to ~/.local/share | Unset `$env.XDG_DATA_HOME`. Call `buffer-dir`. | Returns `~/.local/share/genq/telemetry` (expanded) |

### 2.2 `append-span` — writing spans

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.2.1 | Creates NDJSON file for today | Append a span record. Check for file named `YYYY-MM-DD.ndjson` in buffer dir. | File exists; contains one JSON line |
| 2.2.2 | Appends to existing file | Append two spans in sequence. Read the file. | File has exactly 2 non-empty lines; each line is valid JSON |
| 2.2.3 | Span is valid JSON | Append `{ traceId: "abc", name: "test" }`. Read file and parse line. | Parsed record has `traceId == "abc"` and `name == "test"` |
| 2.2.4 | Single line per span (no pretty-print) | Append a span with nested attributes. Read file. | Each line contains no embedded newlines (single `\n` at end only) |

### 2.3 `read-buffer` — reading spans

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.3.1 | Returns empty list for empty buffer | Clear buffer dir. Call `read-buffer`. | Returns `[]` |
| 2.3.2 | Reads single file | Append 3 spans. Call `read-buffer`. | Returns list of 3 records |
| 2.3.3 | Reads across multiple files | Create `2026-04-23.ndjson` with 2 spans and `2026-04-24.ndjson` with 1 span. Call `read-buffer`. | Returns list of 3 records |
| 2.3.4 | Skips empty lines | Write a file with blank lines between JSON lines. Call `read-buffer`. | Returns only non-empty parsed records; no errors |
| 2.3.5 | Files returned in date order | Create files for 04-22, 04-24, 04-23. Call `read-buffer`. | Spans from 04-22 appear first, then 04-23, then 04-24 |

### 2.4 `rotate-buffer` — file retention

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.4.1 | Deletes files older than retention | Create files dated 60 days ago and today. Call `rotate-buffer 30`. | Old file deleted; today's file remains |
| 2.4.2 | Keeps files within retention | Create file dated 15 days ago. Call `rotate-buffer 30`. | File remains |
| 2.4.3 | Handles empty buffer dir | Call `rotate-buffer` on empty directory. | No error; returns cleanly |
| 2.4.4 | Skips non-date filenames | Create `notes.ndjson` in buffer dir. Call `rotate-buffer 1`. | File remains (not deleted); no error |
| 2.4.5 | Retention of 0 deletes all | Create file dated today. Call `rotate-buffer 0`. | File is deleted |

### 2.5 `clear-buffer` — delete all

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.5.1 | Deletes all NDJSON files | Create 3 files. Call `clear-buffer`. | Buffer dir exists but is empty |
| 2.5.2 | No error on empty buffer | Call `clear-buffer` on empty dir. | No error |

### 2.6 `buffer-stats` — summary

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 2.6.1 | Empty buffer returns zeroes | Clear buffer. Call `buffer-stats`. | `{ files: 0, total_bytes: 0, oldest: null, newest: null, span_count: 0 }` |
| 2.6.2 | Correct count with data | Append 5 spans across 2 files. Call `buffer-stats`. | `files == 2`, `span_count == 5`, `oldest` and `newest` are correct dates |
| 2.6.3 | Total bytes is nonzero | Append 1 span. Call `buffer-stats`. | `total_bytes > 0` |

---

## 3. Collector Module (`collector.nu`)

### 3.1 `build-resource` — OTel resource attributes

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 3.1.1 | Returns record with attributes key | Call `build-resource`. | Result has `attributes` key containing a list |
| 3.1.2 | Contains service.name = "genq" | Call `build-resource`. Find attribute with key `service.name`. | `value.stringValue == "genq"` |
| 3.1.3 | Contains service.version from config | Set `$env.GENQ_CONFIG.metadata.version = "v0.2.0"`. Call `build-resource`. | `service.version` attribute has `stringValue == "v0.2.0"` |
| 3.1.4 | service.version defaults to "unknown" | Remove metadata from config. Call `build-resource`. | `service.version` attribute has `stringValue == "unknown"` |
| 3.1.5 | Contains Nushell version | Call `build-resource`. Find `process.runtime.version`. | Matches output of `version | get version` |
| 3.1.6 | Contains host.os.type | Call `build-resource`. Find `host.os.type`. | Non-empty string (e.g. "macos", "linux") |
| 3.1.7 | Terminal defaults to "unknown" | Unset `$env.TERM_PROGRAM`. Call `build-resource`. | `genq.terminal` has `stringValue == "unknown"` |
| 3.1.8 | Extensions is array | Set config extensions to `["miams", "pres2025"]`. Call `build-resource`. | `genq.extensions` is `arrayValue` with 2 `stringValue` entries |

### 3.2 `new-session` — session initialization

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 3.2.1 | Returns record with required keys | Call `new-session`. | Record contains: `trace_id`, `span_id`, `start_time`, `start_time_unix_nano`, `commands_run`, `error_count`, `resource` |
| 3.2.2 | trace_id is 32-char hex | Call `new-session`. | `trace_id` matches regex `^[0-9a-f]{32}$` |
| 3.2.3 | span_id is 16-char hex | Call `new-session`. | `span_id` matches regex `^[0-9a-f]{16}$` |
| 3.2.4 | trace_id is unique per call | Call `new-session` twice. | Two different `trace_id` values |
| 3.2.5 | commands_run starts at 0 | Call `new-session`. | `commands_run == 0` |
| 3.2.6 | error_count starts at 0 | Call `new-session`. | `error_count == 0` |
| 3.2.7 | start_time is recent | Call `new-session`. Compare `start_time` to `date now`. | Difference is < 2 seconds |
| 3.2.8 | start_time_unix_nano is string | Call `new-session`. | `start_time_unix_nano` is a string of digits |
| 3.2.9 | resource contains attributes | Call `new-session`. | `resource.attributes` is a non-empty list |

### 3.3 `record-session-start` — initial session span (DB-dependent)

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 3.3.1 | Writes session span to buffer | Create session via `new-session`. Call `record-session-start`. Read buffer. | Buffer has 1 span with `name == "genq.session"` |
| 3.3.2 | Span has correct traceId | Create session. Record start. Read span. | `span.traceId == session.trace_id` |
| 3.3.3 | cold_start_ms is non-negative | Record start. Read span attributes. | `genq.session.cold_start_ms` intValue >= 0 |
| 3.3.4 | DB metadata populated with real DB | Set `$env.rmdb` to pres2025. Record start. Read span. | `genq.db.person_count > 0`, `genq.db.size_kb > 0`, `genq.db.filename == "pres2025.rmtree"` |
| 3.3.5 | DB metadata graceful on missing DB | Set `$env.rmdb` to nonexistent path. Record start. Read span. | `genq.db.person_count == "0"`, `genq.db.db_name == "none"`; no error |
| 3.3.6 | Span has _resource field | Record start. Read span. | Span contains `_resource` key with `attributes` list |
| 3.3.7 | parentSpanId is null | Record start. Read span. | `parentSpanId == null` (root span) |
| 3.3.8 | status code is 1 (OK) | Record start. Read span. | `status.code == 1` |

### 3.4 `record-command` — command span

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 3.4.1 | Writes command span to buffer | Create session. Record a command. Read buffer. | Buffer contains a span with `name == "genq list people"` |
| 3.4.2 | parentSpanId links to session | Record command with session. Read span. | `parentSpanId == session.span_id` |
| 3.4.3 | traceId matches session | Record command. Read span. | `traceId == session.trace_id` |
| 3.4.4 | Duration calculated correctly | Record command with 100ms gap between start and end times. | `genq.duration_ms` intValue is approximately `100` |
| 3.4.5 | Status OK has code 1 | Record command with `status: "ok"`. | `status.code == 1` |
| 3.4.6 | Status error has code 2 | Record command with `status: "error"`. | `status.code == 2` |
| 3.4.7 | Error class attaches exception event | Record command with `error_class: "db.not_found"`. | Span has `events[0].name == "exception"` with `exception.type == "db.not_found"` |
| 3.4.8 | No events when status OK | Record command with `status: "ok"`, no error_class. | Span has no `events` key |
| 3.4.9 | result_rows defaults to 0 | Record command without specifying result_rows. | `genq.result_rows` intValue is `"0"` |
| 3.4.10 | spanId is unique per command | Record two commands. Read both spans. | Two different `spanId` values |

### 3.5 `record-session-end` — session-end summary span

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 3.5.1 | Writes span with name "genq.session.end" | Create session, sleep 50ms, call `record-session-end`. Read buffer. | Last span has `name == "genq.session.end"` |
| 3.5.2 | parentSpanId links to session.span_id | Call `record-session-end`. | Span's `parentSpanId == session.span_id` |
| 3.5.3 | Duration is non-negative | Sleep 100ms between session creation and end. | `genq.session.duration_ms` intValue is >= 100 |
| 3.5.4 | commands_run reflects session field | Set `session.commands_run = 5`. Call `record-session-end`. | `genq.session.commands_run` intValue is `"5"` |
| 3.5.5 | Defaults missing counters to 0 | Pass session record without `commands_run` / `error_count` keys. | Both attributes have intValue `"0"` |
| 3.5.6 | Multiple emits produce distinct spanIds | Call `record-session-end` twice. Read buffer. | Two distinct end spans with different `spanId` values |

---

## 4. Transport Module (`transport.nu`)

### 4.1 `format-otlp-payload` — envelope construction

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 4.1.1 | Returns valid OTLP structure | Build payload with 2 spans and a resource. | Result has `resourceSpans[0].resource.attributes` and `resourceSpans[0].scopeSpans[0].spans` with 2 entries |
| 4.1.2 | Strips _resource from spans | Include a span with `_resource` field. Format payload. | No span in output contains `_resource` key |
| 4.1.3 | Scope metadata is correct | Format payload. | `scopeSpans[0].scope.name == "genq.telemetry"` and `scope.version == "0.1.0"` |
| 4.1.4 | Empty span list produces valid structure | Format with `[]` spans. | `resourceSpans[0].scopeSpans[0].spans == []` |

### 4.2 `send-otlp` — HTTP upload

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 4.2.1 | Prints notice on empty buffer | Clear buffer. Call `send-otlp`. | Prints "No buffered telemetry data to send." |
| 4.2.2 | Constructs correct URL | Call with `"https://example.com/"`. Observe constructed URL. | Posts to `https://example.com/v1/traces` (trailing slash stripped) |
| 4.2.3 | Clears buffer on success | Buffer has spans. Send to a reachable endpoint (or mock). | Buffer is empty after success |
| 4.2.4 | Preserves buffer on failure | Buffer has spans. Send to unreachable endpoint. | Buffer still has spans; error message printed |

### 4.3 `record-upload` + history (`history.nu`)

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 4.3.1 | Records success entry | Call `record-upload "https://x" 5 1024 "success" ""`. Call `read-history`. | One entry with status `success`, span_count 5, bytes 1024 |
| 4.3.2 | Records deferred entry | Call `record-upload "https://x" 5 0 "deferred" "could not resolve"`. | One entry with status `deferred` and the error message preserved |
| 4.3.3 | Appends across multiple calls | Call `record-upload` 3 times. Call `read-history`. | Returns 3 entries |
| 4.3.4 | Files in `uploads/` subdirectory | Call `record-upload`. | File exists at `<buffer-dir>/uploads/YYYY-MM-DD.ndjson`; main buffer dir glob does NOT pick it up |
| 4.3.5 | `classify-error` detects offline signals | Call with each of: `"Could not resolve"`, `"connection refused"`, `"network is unreachable"`, `"operation timed out"`. | All return `"deferred"` |
| 4.3.6 | `classify-error` falls through to failed | Call with `"HTTP 500 internal error"`. | Returns `"failed"` |
| 4.3.7 | `rotate-history` deletes old files | Create `uploads/` file dated 60 days ago. Call `rotate-history 30`. | Old file deleted; recent files remain |

---

## 5. CLI Commands (`mod.nu`)

### 5.1 `genq telemetry` — help

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.1.1 | Prints help text | Run `genq telemetry`. | Output contains "Commands:" and lists status, send, clear, view, history. Does NOT mention enable/disable. |

### 5.2 `genq telemetry status`

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.2.1 | Shows endpoint URL | Run `genq telemetry status`. | Output contains "Endpoint URL:" with configured value |
| 5.2.2 | Shows retention | Run `genq telemetry status`. | Output contains "Retention:" followed by "30 days" |
| 5.2.3 | Shows buffer stats | Buffer some spans. Run `genq telemetry status`. | Output shows `Files:`, `Total size:`, `Spans:` with nonzero values |
| 5.2.4 | Shows date range when data exists | Buffer spans. Run `genq telemetry status`. | Output contains "Date range:" with today's date |
| 5.2.5 | No "Enabled:" line | Run `genq telemetry status`. | Output does NOT contain "Enabled:" — telemetry is mandatory |

### 5.4 `genq telemetry view`

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.4.1 | Empty buffer message | Clear buffer. Run `genq telemetry view`. | Prints "No buffered telemetry data." |
| 5.4.2 | Shows session details | Buffer a session span. Run `genq telemetry view`. | Output contains "Session:", trace ID prefix, DB name, cold start ms |
| 5.4.3 | Shows command details | Buffer a command span. Run `genq telemetry view`. | Output contains the command name, duration, and status (ok/err) |
| 5.4.4 | Shows counts | Buffer 2 sessions + 3 commands. Run `genq telemetry view`. | Header shows "2 session(s), 3 command(s)" |
| 5.4.5 | Uses latest session.end summary | Buffer session + 2 session.end spans for the same trace. Run `genq telemetry view`. | Duration / Commands / Errors reflect the LATEST session.end |

### 5.5 `genq telemetry send`

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.5.1 | Error on missing OTLP endpoint | Set `endpoint_url = ""`. Run `genq telemetry send`. | Prints "No endpoint URL configured." |
| 5.5.2 | Records success in upload history | Send to reachable mock endpoint. Run `genq telemetry history`. | History shows one entry with `Status: success` |
| 5.5.3 | Records deferred when offline | Send to unresolvable host (e.g. `endpoint_url = "https://does-not-exist.invalid"`). | History shows entry with `Status: deferred`; buffer preserved |

### 5.6 `genq telemetry clear`

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.6.1 | Clears all files | Buffer 5 spans. Run `genq telemetry clear`. | `buffer-stats` shows `files: 0, span_count: 0` |
| 5.6.2 | Prints confirmation | Run `genq telemetry clear`. | Prints "Local telemetry buffer cleared." |

### 5.7 `genq telemetry history`

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 5.7.1 | Empty history message | Clear uploads/ subdir. Run `genq telemetry history`. | Prints "No upload history yet." |
| 5.7.2 | Shows columns | Append a record. Run `genq telemetry history`. | Output table has columns: When, KB, Spans, Status |
| 5.7.3 | Sorts newest first | Record three uploads in sequence. Run `genq telemetry history`. | First row is the most recent timestamp |
| 5.7.4 | KB rounded to 1 decimal | Append entry with `bytes = 4521`. Run `genq telemetry history`. | KB column shows `4.4` |
| 5.7.5 | Status reflects classification | Append entries with status `success`/`deferred`/`failed`. Run `genq telemetry history`. | Each row shows the corresponding status string |

---

## 6. Session Init (`main.nu` — `telemetry-init`)

### 6.1 Always-on initialization

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 6.1.1 | Creates session span on load | Load main.nu. | NDJSON file created with 1 span; `name == "genq.session"` |
| 6.1.2 | Sets GENQ_TELEMETRY_SESSION env | Load main.nu. | `$env.GENQ_TELEMETRY_SESSION` contains `trace_id`, `span_id`, `start_time`, `start_time_unix_nano`, `commands_run`, `error_count`, `resource` |
| 6.1.3 | Initializes counters at 0 | Load main.nu. | `$env.GENQ_TELEMETRY_SESSION.commands_run == 0` and `error_count == 0` |
| 6.1.4 | cold_start_ms is reasonable | Load main.nu. Read session span. | `genq.session.cold_start_ms` is between 0 and 5000 |
| 6.1.5 | DB metadata populated | Load main.nu with valid `$env.rmdb`. Read span. | `genq.db.person_count > 0` |
| 6.1.6 | Rotates old buffer files | Create a file dated 60 days ago. Load main.nu with retention_days=30. | Old file deleted; today's file exists |
| 6.1.7 | Rotates old upload-history files | Create `uploads/` file dated 60 days ago. Load main.nu. | Old upload-history file deleted; today's preserved |

### 6.2 Hook installation

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 6.2.1 | Appends to existing pre_execution hooks | Set `$env.config.hooks.pre_execution = [{|| print "user"}]`. Load main.nu. | Hook list now has 2 entries (user's + telemetry's) |
| 6.2.2 | Appends to existing pre_prompt hooks | Set `$env.config.hooks.pre_prompt = [{|| print "user"}]`. Load main.nu. | Hook list now has 2 entries |
| 6.2.3 | Preserves display_output hook | Load main.nu. Inspect `$env.config.hooks.display_output`. | display_output hook unchanged from main.nu's table-numbering closure |

### 6.3 Error resilience

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 6.3.1 | Telemetry failure never breaks genq | Corrupt the buffer directory (e.g., set to a file instead of dir). Load main.nu. | genq loads successfully; try/catch absorbs error |
| 6.3.2 | DB unavailable doesn't block init | Set `$env.rmdb` to nonexistent file. Load main.nu. | Session span written with `person_count: 0`, `db_name: "none"` |

---

## 7. Version Command (`main.nu` — `genq version`)

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 7.1 | Reads from config metadata.version | Set `$env.GENQ_CONFIG.metadata.version = "v0.2.0"`. Run `genq version`. | Prints `v0.2.0` |
| 7.2 | Falls back to VERSION file | Remove metadata from config. Create `$GENQ_HOME/VERSION` containing `v0.1.5`. Run `genq version`. | Prints `v0.1.5` |
| 7.3 | Falls back to git describe | Remove metadata and VERSION file. Run from git repo. | Prints a git tag or SHA |
| 7.4 | Returns "unknown" as last resort | Remove metadata, VERSION file, and git. | Prints `unknown` |
| 7.5 | Does not trigger xcode-select | Run `genq version` on machine without Xcode CLI tools, with version in config. | Prints version from config; no xcode-select dialog |

---

## 8. Packaging (`scripts/genquery-start`)

### 8.1 First-run setup

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 8.1.1 | Creates GENQ_HOME directories | Remove `~/Documents/GenQuery`. Set `GHOSTTY_RESOURCES_DIR`. Run script. | `~/Documents/GenQuery/{data,config,vault,sql}` directories created |
| 8.1.2 | Copies sample database | Run script with no existing pres2025.rmtree. | `~/Documents/GenQuery/data/pres2025.rmtree` exists |
| 8.1.3 | Does not overwrite existing database | Place custom file at pres2025.rmtree. Run script. | File unchanged (not overwritten) |
| 8.1.4 | Syncs SQL files from bundle | Run script. | `~/Documents/GenQuery/sql/all-citations.sql` exists |
| 8.1.5 | Generates config with version | Run script with `VERSION` file containing `v0.2.0`. | Config has `[metadata]` with `version = "v0.2.0"` |
| 8.1.6 | Generated config has telemetry section | Run script on fresh install. | Config has `[telemetry]` with `enabled = false` and the production `endpoint_url` |
| 8.1.7 | Generates config.nu with banner suppressed | Run script on fresh install. | `~/Documents/GenQuery/config/config.nu` exists; contains `$env.config.show_banner = false` |
| 8.1.8 | Does not overwrite existing config.nu | Create custom config.nu. Run script. | File unchanged |

### 8.2 Upgrade path (existing install)

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 8.2.1 | Updates metadata.version in existing config | Existing config has `version = "v0.1.0"`. Bundle VERSION has `v0.2.0`. Run script. | Config now has `version = "v0.2.0"` |
| 8.2.2 | Adds [metadata] if missing | Existing config has no `[metadata]` section. Run script. | `[metadata]` with version added to top of file |
| 8.2.3 | Adds [telemetry] if missing | Existing config has no `[telemetry]` section. Run script. | `[telemetry]` section appended with defaults |
| 8.2.4 | Does not duplicate [telemetry] | Existing config already has `[telemetry]`. Run script. | Only one `[telemetry]` section exists |
| 8.2.5 | SQL files updated on upgrade | Existing SQL files are older. Run script. | SQL files overwritten with bundle versions |
| 8.2.6 | Preserves user config changes | User changed `database.active = "production"` and `display.table_mode = "compact"`. Run script. | Those values preserved; only version and telemetry updated |

### 8.3 env.nu generation

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 8.3.1 | NU_LIB_DIRS points to bundle | Run script with known bundle path. Read `config/env.nu`. | `NU_LIB_DIRS` contains `{BUNDLE}/src/lib` and `{BUNDLE}/src/lib/ext` |
| 8.3.2 | GENQ_HOME set correctly | Run script. Read `config/env.nu`. | `$env.GENQ_HOME` equals `~/Documents/GenQuery` |
| 8.3.3 | env.nu regenerated on every launch | Modify env.nu manually. Run script. | File overwritten with current bundle paths |

---

## 9. AWS Lambda Handler (`handler.py`)

### 9.1 Input validation

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 9.1.1 | Rejects empty body | POST with empty body. | 400 response: `{"error": "empty body"}` |
| 9.1.2 | Rejects invalid JSON | POST with body `not-json`. | 400 response: `{"error": "invalid JSON"}` |
| 9.1.3 | Rejects missing resourceSpans | POST with `{"foo": "bar"}`. | 400 response: `{"error": "missing resourceSpans"}` |
| 9.1.4 | Accepts valid OTLP payload | POST with `{"resourceSpans": []}`. | 200 response |

### 9.2 S3 storage

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 9.2.1 | Stores gzip-compressed JSON | Send valid payload. Download S3 object. Decompress. | Content matches original payload |
| 9.2.2 | S3 key is date-partitioned | Send payload at 2026-04-24 14:30 UTC. | Key matches pattern `traces/2026/04/24/14-{request_id}.json.gz` |
| 9.2.3 | ContentType is application/json | Send payload. Check S3 object metadata. | `ContentType == "application/json"` |
| 9.2.4 | ContentEncoding is gzip | Send payload. Check S3 object metadata. | `ContentEncoding == "gzip"` |

### 9.3 Grafana Cloud forwarding

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 9.3.1 | Forwards to Grafana OTLP endpoint | Send valid payload. Check Grafana Cloud / Lambda logs. | Log shows "Grafana response: 200" (or similar) |
| 9.3.2 | Grafana failure does not fail Lambda | Set invalid Grafana endpoint. Send payload. | 200 response; S3 object created; log shows "Grafana forward failed" |
| 9.3.3 | Skips Grafana if env vars missing | Unset `GRAFANA_OTLP_ENDPOINT`. Send payload. | 200 response; S3 object created; no Grafana attempt |
| 9.3.4 | Uses Basic auth with correct credentials | Check forwarded request headers. | `Authorization: Basic base64(instance_id:api_key)` |

### 9.4 Base64 encoding

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 9.4.1 | Handles base64-encoded body | Send event with `isBase64Encoded: true` and base64 body. | Payload decoded correctly; S3 content matches original |

---

## 11. Hooks + Subcommand Parser (`mod.nu` / `main.nu`)

### 11.1 `parse-genq-subcommand` — privacy-safe parsing

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 11.1.1 | Returns null for non-genq command | Call with `"ls -la"`. | Returns `null` |
| 11.1.2 | Parses simple genq command | Call with `"genq list people"`. | Returns `{ command: "list", subcommand: "list people" }` |
| 11.1.3 | Strips flags | Call with `"genq list people --rin 1234"`. | Returns `{ command: "list", subcommand: "list people" }` (no `--rin`, no `1234`) |
| 11.1.4 | Strips RINs and arg values | Call with `"genq census rin 1575"`. | Returns `{ command: "census", subcommand: "census rin" }` (no `1575`) |
| 11.1.5 | Stops at pipe | Call with `"genq list people \| first 5"`. | Returns `{ command: "list", subcommand: "list people" }` |
| 11.1.6 | Caps at 3 alphabetic tokens | Call with `"genq one two three four five"`. | Subcommand has at most 3 words after `"genq"` (i.e., `"one two three"`) |
| 11.1.7 | Returns null when only "genq" present | Call with `"genq"`. | Returns `null` (no subcommand to record) |
| 11.1.8 | Lowercases command tokens | Call with `"genq LIST people"`. | Subcommand contains `"list people"` (lowercased) |

### 11.2 `record-from-hook` — hook entry point

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 11.2.1 | No-op when session env unset | Unset `$env.GENQ_TELEMETRY_SESSION`. Call `record-from-hook`. | No buffer write; no error |
| 11.2.2 | Skips non-genq commandlines | Set session. Call `record-from-hook ... "ls -la"`. | No command span written; counters unchanged |
| 11.2.3 | Records command span for genq | Set session. Call `record-from-hook` with `"genq list people"`. | Buffer has a command span with `name == "genq list people"` |
| 11.2.4 | Increments commands_run | Set session with `commands_run = 0`. Call `record-from-hook` once. | `$env.GENQ_TELEMETRY_SESSION.commands_run == 1` |
| 11.2.5 | Emits session.end after each command | Call `record-from-hook` once. Read buffer. | One `genq.session.end` span exists for this trace |
| 11.2.6 | Multiple calls accumulate counters | Call `record-from-hook` 3 times. | `commands_run == 3`; 3 command spans + 3 session.end spans buffered |

### 11.3 Hook integration with main.nu

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 11.3.1 | pre_execution captures pending state | Load main.nu. Manually invoke `$env.config.hooks.pre_execution.0` (the appended one). Inspect `$env.GENQ_TELEMETRY_PENDING`. | `pending.commandline` and `pending.start_time` are set |
| 11.3.2 | pre_prompt clears pending state | After 11.3.1, manually invoke the appended pre_prompt closure. | `$env.GENQ_TELEMETRY_PENDING == null` |
| 11.3.3 | Existing user pre_execution preserved | Set `$env.config.hooks.pre_execution = [{|| print "user-1"}]`. Source main.nu. | Hook list has 2 entries; first is user's, second is telemetry's |
| 11.3.4 | Existing user pre_prompt preserved | Same pattern as 11.3.3 for pre_prompt. | Both closures present, in append order |

---

## 10. End-to-End Integration

| # | Test | Steps | Expected Result |
|---|------|-------|-----------------|
| 10.1 | Full cycle: use, view, send | Launch genq -> run `genq list people \| first 5` -> `genq telemetry view` -> `genq telemetry send` | Session span appears in view; send succeeds; buffer cleared; data in S3 |
| 10.2 | Data appears in Grafana Tempo | After 10.1, query Grafana Explore with Tempo: `{ resource.service.name = "genq" }` | Trace visible with `genq.session` root span |
| 10.3 | Multiple sessions aggregate | Launch genq 3 times. Run `genq telemetry view`. | Shows 3 session spans |
| 10.4 | Clear deletes local buffer | After 10.3, run `genq telemetry clear`. Check buffer dir. | NDJSON files removed; uploads/ history preserved |
| 10.5 | Cold start telemetry overhead is minimal | Time genq cold start with main.nu. | telemetry-init adds < 500ms to startup |
| 10.6 | Telemetry survives app bundle update | Install v0.2.0 DMG. Run a session. Install v0.3.0 DMG. Launch. | Buffer preserved; new session uses updated `service.version` |

---

## Test Execution Quick Reference

```bash
# Run all fast telemetry tests (no DB required)
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fast

# Run DB-dependent telemetry tests (pres2025)
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db pres2025

# Manual end-to-end test
nu --env-config ~/.config/nushell/env.nu src/main.nu
genq telemetry status
genq telemetry view
genq telemetry send
genq telemetry history

# Verify S3 storage
aws s3 ls s3://genq-telemetry-20260424200504803600000001/traces/ --recursive

# Verify Grafana
# Open Grafana Cloud > Explore > Tempo > { resource.service.name = "genq" }

# Verify Lambda logs
aws logs tail /aws/lambda/genq-telemetry-collector --follow
```
