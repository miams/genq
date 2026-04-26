# GenQuery Telemetry Design

**Status**: Design / pre-implementation  
**Author**: Michael Iams  
**Reference**: *Software Telemetry* — Jamie Riedesel (Manning, 2021)

---

## Purpose and Scope

This document defines the telemetry framework for GenQuery. The purpose of telemetry is:

- Understand which commands are actually used vs. exist but go unused
- Identify which platform/Nushell version combinations produce errors
- Find commands slow enough to be worth optimizing
- Detect regressions after releases

Telemetry is **purely technical and diagnostic**. It is explicitly not for marketing, product funnels, user profiling, or data sharing with third parties.

---

## The Four Diagnostic Questions

> Per Riedesel: every field collected must answer a specific question. If you cannot name the question, do not collect the field.

| # | Question | Signals required |
|---|---|---|
| 1 | Which commands are actually used day-to-day vs. which exist but go unused? | `command`, `subcommand`, session command counts |
| 2 | Which platform / Nu version combinations produce errors? | `platform`, `nu_version`, `genq_version`, `error_class` |
| 3 | Which commands are slow enough to be worth optimizing? | `command`, `duration_ms`, `result_rows`, `db_person_count` |
| 4 | After a release, did error rates or latency change? | `genq_version`, `status`, `duration_ms`, indexed by time |

---

## Privacy Principles

| Principle | Implementation |
|---|---|
| No PII | No names, paths (contain usernames), hostnames, or machine IDs |
| No cross-session identity | `session_id` is random per session, never persisted to disk |
| Data minimization | Each field is justified by one of the four questions above |
| Local first | Spans buffer to disk; transmission is a separate, observable step |
| Bounded retention | Local buffer files older than 30 days are deleted automatically |
| Transparent | `genq telemetry view` prints the exact buffered payload; `genq telemetry history` shows every upload attempt |
| Apple-compliant | `PrivacyInfo.xcprivacy` declared in genq-terminal app bundle |

Telemetry is **mandatory and always-on** for every GenQuery session. There is no
opt-in/opt-out switch — privacy is enforced by what is *not* collected (no PII,
no command arguments, no path content) rather than by user permission gating.
This is consistent with diagnostic telemetry in similar developer CLIs.

### Fields explicitly excluded

| Field | Reason excluded |
|---|---|
| `$env.HOME`, `$env.USER`, `$env.USERNAME` | Direct PII |
| `$env.rmdb` full path | Contains username and folder names |
| `sys host | get hostname` | Machine-identifying PII |
| `sys host | get name` | Machine name (PII) |
| `history | get cwd` | Working directory contains username |
| Command argument values | May contain person names, places, RINs |
| Error message text | May contain path fragments or data values |
| CPU brand / model | Too specific; potentially identifying |
| IP address | PII; not logged at collection point |

---

## OpenTelemetry Data Model

GenQuery uses the OpenTelemetry **trace data model** over **OTLP/HTTP (JSON encoding)**. This maps naturally to the CLI lifecycle:

```
Session          → OTel Trace     (session_id = trace_id, 128-bit random hex)
Session span     → Root Span      (session.start → session.end)
Command          → Child Span     (command.start → command.end)
Error            → Span Event     (attached to the command span)
Environment info → Span Attributes on the root span
```

This gives us:
- Free parent/child relationship between session and commands
- Standard attribute semantics (OTel semantic conventions where applicable)
- Compatibility with any OTel-capable backend (Honeycomb, Grafana Tempo, Jaeger, self-hosted Collector)

### Why traces over logs or metrics

| Signal | Why not for genq |
|---|---|
| Metrics | Require a long-running process to accumulate state; a CLI starts and exits in seconds |
| Logs (OTel log records) | Less semantically rich; lose parent/child relationships between session and commands |
| **Traces** | CLI session maps directly to a trace; commands map to spans; attributes carry metadata |

---

## Environment Data Inventory

### Safe to collect

#### From `version` command
| Field | Maps to OTel attribute | Answers question |
|---|---|---|
| `version` | `process.runtime.version` | Q2 |
| `build_os` | `host.os.type` | Q2 |
| `build_target` | `host.arch` (derived) | Q2 |

#### From `sys host`
| Field | Maps to OTel attribute | Answers question | Notes |
|---|---|---|---|
| `os_version` | `host.os.version` | Q2 | macOS version string |
| `kernel_version` | `host.os.kernel_version` | Q2 | Useful for platform bug correlation |
| ~~`hostname`~~ | — | — | **EXCLUDED** — PII |
| ~~`name`~~ | — | — | **EXCLUDED** — PII |

#### From `$env`
| Field | Maps to OTel attribute | Answers question | Notes |
|---|---|---|---|
| `$env.GENQ_CONFIG.metadata.version` | `service.version` | Q4 | genq release version |
| `$env.GENQ_CONFIG.database.active` | `genq.db.name` | Q1, Q3 | DB name ("production", "demo") — not path |
| `$env.GENQ_CONFIG.display.table_mode` | `genq.config.table_mode` | Q1 | Config context |
| `$env.GENQ_CONFIG.display.date_format` | `genq.config.date_format` | Q1 | Config context |
| `$env.GENQ_CONFIG.extensions.enabled` | `genq.extensions` | Q1 | Which extensions loaded |
| `$env.TERM_PROGRAM` | `genq.terminal` | Q2 | "genquery-terminal", "iTerm2", etc. |
| `$env.LANG` | `genq.locale` | Q2 | Useful for date parsing bugs |

#### From RootsMagic database (via SQLite PRAGMA — read-only, no content)
| Query | Maps to OTel attribute | Answers question | Notes |
|---|---|---|---|
| `SELECT COUNT(*) FROM PersonTable` | `genq.db.person_count` | Q3 | Query time scales with DB size |
| `PRAGMA page_count * page_size` | `genq.db.size_kb` | Q3 | Rounded to nearest KB |
| `SELECT MAX(UTCModDate) FROM PersonTable` | `genq.db.last_modified_epoch` | Q3 | DB freshness (epoch int, not path) |
| Filename only (`path basename $env.rmdb`) | `genq.db.filename` | Q2 | "Iiams.rmtree" only — no path |

#### Session-generated
| Field | Maps to OTel attribute | Answers question | Notes |
|---|---|---|---|
| Random 128-bit hex | `traceId` | — | Generated fresh each session; never persisted |
| Cold-start duration | `genq.session.cold_start_ms` | Q3 | Time from invocation to first command ready |
| `date now` | `startTimeUnixNano` | Q4 | Session start timestamp |

---

## Event Schema

### OTel Resource (static per session — sent once)

```json
{
  "resource": {
    "attributes": [
      {"key": "service.name",            "value": {"stringValue": "genq"}},
      {"key": "service.version",         "value": {"stringValue": "v0.2.0"}},
      {"key": "telemetry.sdk.language",  "value": {"stringValue": "nushell"}},
      {"key": "host.os.type",            "value": {"stringValue": "macos-aarch64"}},
      {"key": "host.os.version",         "value": {"stringValue": "15.4.0"}},
      {"key": "host.os.kernel_version",  "value": {"stringValue": "25.4.0"}},
      {"key": "process.runtime.version", "value": {"stringValue": "0.112.1"}},
      {"key": "genq.terminal",           "value": {"stringValue": "genquery-terminal"}},
      {"key": "genq.locale",             "value": {"stringValue": "en_US.UTF-8"}},
      {"key": "genq.extensions",         "value": {"arrayValue": {"values": [
        {"stringValue": "miams"}, {"stringValue": "pres2025"}
      ]}}}
    ]
  }
}
```

### Session Span (root span)

```json
{
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7",
  "parentSpanId": null,
  "name": "genq.session",
  "kind": 1,
  "startTimeUnixNano": "1714000000000000000",
  "endTimeUnixNano":   "1714000330145000000",
  "attributes": [
    {"key": "genq.session.cold_start_ms",  "value": {"intValue": "245"}},
    {"key": "genq.db.name",                "value": {"stringValue": "production"}},
    {"key": "genq.db.filename",            "value": {"stringValue": "Iiams.rmtree"}},
    {"key": "genq.db.person_count",        "value": {"intValue": "11692"}},
    {"key": "genq.db.size_kb",             "value": {"intValue": "8192"}},
    {"key": "genq.db.last_modified_epoch", "value": {"intValue": "738950400"}},
    {"key": "genq.config.table_mode",      "value": {"stringValue": "rounded"}},
    {"key": "genq.config.date_format",     "value": {"intValue": "1"}},
    {"key": "genq.session.commands_run",   "value": {"intValue": "5"}},
    {"key": "genq.session.error_count",    "value": {"intValue": "0"}}
  ],
  "status": {"code": 1}
}
```

### Command Span (child span — one per command invocation)

The schema follows the user's model of `history | last 1 | update start_timestamp { format date "%Y-%m-%d %H:%M:%S" } | to ndjson`, extended with OTel attributes. In interactive sessions the `history` command provides `start_timestamp`, `command`, and `duration` natively. In scripted/non-interactive sessions, timing is self-instrumented at dispatch.

```json
{
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "a3ce929d0e0e4736",
  "parentSpanId": "00f067aa0ba902b7",
  "name": "genq list people",
  "kind": 1,
  "startTimeUnixNano": "1714000015000000000",
  "endTimeUnixNano":   "1714000015145000000",
  "attributes": [
    {"key": "genq.command",        "value": {"stringValue": "list"}},
    {"key": "genq.subcommand",     "value": {"stringValue": "list people"}},
    {"key": "genq.result_rows",    "value": {"intValue": "11692"}},
    {"key": "genq.db.name",        "value": {"stringValue": "production"}},
    {"key": "genq.duration_ms",    "value": {"intValue": "145"}}
  ],
  "status": {"code": 1}
}
```

**What is NOT in the command span:**
- Flag values (e.g., `--rin 1234` — the RIN is omitted; only flag presence is noted)
- Arguments that could contain person names or database content
- The raw command string (only the normalized command/subcommand name)

### Error Event (attached to a command span)

```json
{
  "timeUnixNano": "1714000015050000000",
  "name": "exception",
  "attributes": [
    {"key": "exception.type",    "value": {"stringValue": "db.not_found"}},
    {"key": "exception.escaped", "value": {"boolValue": false}}
  ]
}
```

Error *type* is a controlled vocabulary, not free-form message text. Defined error classes:
- `db.not_found` — database file missing or inaccessible
- `db.locked` — SQLite WAL lock contention
- `sql.query_failed` — query execution error
- `config.invalid` — configuration file unreadable or malformed
- `command.not_found` — unknown command/subcommand
- `runtime.unexpected` — uncategorized error

---

## Local Buffering and NDJSON Format

Events are written to a local NDJSON sidecar file on the critical path — **no network I/O during command execution**.

```
~/.local/share/genq/telemetry/YYYY-MM-DD.ndjson   (Linux/macOS)
%APPDATA%\genq\telemetry\YYYY-MM-DD.ndjson         (Windows)
```

Each line is a single OTel span serialized to JSON and appended atomically. The session span is written at session end; command spans are written at command completion.

```nushell
use std/formats *   # enables | to ndjson and | from ndjson
```

File rotation: one file per calendar day. Files older than 30 days are deleted automatically at session start if telemetry is enabled.

### On Compression

**Recommendation: no compression in v1.**

A typical genq session generates 3–15 spans totaling 2–8 KB of NDJSON. At this volume:
- gzip reduces payload to ~600 bytes–2 KB — saving ~75%, but on tiny absolute sizes
- Nushell's `http post` does not natively support `Content-Encoding: gzip`
- Adding a `gzip` shell-out introduces platform-specific complexity and a dependency
- The HTTPS transport already compresses at the TLS layer for text content

Revisit compression if telemetry volume grows significantly (many users, high-frequency use). At that point, batch gzip before the upload HTTP call is straightforward to add.

---

## Transport

Buffered NDJSON spans are uploaded to an **OTLP/HTTP receiver** at
`POST /v1/traces` with `Content-Type: application/json`. The configured
endpoint (`telemetry.endpoint_url`) terminates at an AWS Lambda OTLP
collector that forwards traces to S3 (raw archive) and Grafana Cloud Tempo
(query layer). Operators may point this at any OTLP-capable receiver.

Transmission is triggered by:
1. `genq telemetry send` — explicit user-initiated upload
2. Automatic on session end (if `telemetry.auto_send = true` in config, default: false)

Transmission is never on the critical command path.

---

## Configuration

### Config block

```toml
[telemetry]
auto_send = false        # if true, upload on session end; if false, manual only
endpoint_url = "..."     # OTLP/HTTP receiver (POST /v1/traces)
retention_days = 30      # local NDJSON buffer + upload-history files older than this are deleted
```

There is no `enabled` field. Telemetry runs unconditionally for every session.
Operators with strict outbound-network policies can leave `auto_send = false`
and never run `genq telemetry send` — local buffering remains, but no data
leaves the host.

### `genq telemetry` subcommands

| Command | Description |
|---|---|
| `genq telemetry status` | Show endpoint configuration and buffer statistics |
| `genq telemetry send` | Upload buffered NDJSON to configured backend |
| `genq telemetry clear` | Delete local buffer files without uploading |
| `genq telemetry view` | Print buffered events to stdout in readable form |
| `genq telemetry history` | Show transmission log: when, KB, span count, status |

Upload status in `genq telemetry history` is one of:
- `success` — endpoint accepted the payload
- `deferred` — host appears offline (DNS failure, connection refused, network unreachable, timeout); buffer preserved for retry
- `failed` — endpoint reachable but rejected the payload (HTTP error, malformed); buffer preserved for retry

### Hooks

Telemetry is wired in via Nushell's `pre_execution` and `pre_prompt` hooks,
appended to any user-configured hooks (existing hooks are preserved):

- `pre_execution` — captures the commandline + start time at command dispatch
- `pre_prompt` — finalizes the previous command: parses commandline, records a
  command span, increments session counters, and emits a fresh
  `genq.session.end` summary span

Only commands beginning with `genq` are recorded. Subcommand parsing extracts
up to three lowercase-alphabetic tokens (e.g. `genq list people --rin 1234`
records `command="list", subcommand="list people"`); flag values, RINs, paths,
and any non-alphabetic argument are stripped at parse time.

---

## Apple Privacy Compliance

### `PrivacyInfo.xcprivacy` (required for genq-terminal)

A privacy manifest must be added to `genq-terminal/macos/Sources/Resources/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- No cross-app or cross-website tracking -->
  <key>NSPrivacyTracking</key>
  <false/>

  <!-- No tracking domains -->
  <key>NSPrivacyTrackingDomains</key>
  <array/>

  <!-- Data types collected (only if telemetry enabled by user) -->
  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeOtherDiagnosticData</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
  </array>

  <!-- Required Reasons APIs used -->
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- File timestamp access (for telemetry file rotation) -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>  <!-- Show to user, within the app -->
      </array>
    </dict>
    <!-- Disk space (for buffer file management) -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>E174.1</string>  <!-- Write or delete file managed by app -->
      </array>
    </dict>
  </array>
</dict>
</plist>
```

---

## Implementation Plan

### Phase 0 — Infrastructure (no user impact)
- [ ] Create `PrivacyInfo.xcprivacy` and add to genq-terminal Xcode project
- [x] Create `src/lib/common/genq telemetry/mod.nu` module

### Phase 1 — Local buffering (no network)
- [x] Implement session-start span emission — resource + session attributes, generates `trace_id`, writes to local NDJSON buffer
- [x] Implement `record-command` — pre_execution/pre_prompt hooks record command spans with timing + status
- [x] Implement `record-session-end` — emits `genq.session.end` summary span per pre_prompt with cumulative counters
- [x] Implement buffer file rotation (daily files, 30-day retention)
- [x] Implement `genq telemetry view` — readable print of buffer

### Phase 2 — Configuration
- [x] Add `[telemetry]` block to `config/default.toml`
- [x] Implement `genq telemetry status/clear/view`
- [x] Telemetry is mandatory — no enable/disable subcommands

### Phase 3 — Transmission
- [x] Implement OTLP/HTTP upload (format spans → `POST /v1/traces` JSON)
- [x] Implement `genq telemetry send`
- [x] Implement `genq telemetry history` — transmission log with success/deferred/failed status
- [ ] Optional: implement `auto_send` on session end

### Phase 4 — Analysis
- [ ] Define Grafana Cloud Tempo dashboards: `command_frequency`, `slow_commands`, `error_rate_by_version`, `platform_matrix`
- [ ] Document useful TraceQL queries

---

## Open Questions

| Question | Decision needed |
|---|---|
| Does `history` provide `duration` in non-interactive/scripted sessions? | Tested: no — only in login shell with SQLite history. Self-instrumented timing is required. |
| Should `genq.db.person_count` be queried at session start (adds one PRAGMA call) or deferred? | Recommend: deferred to session end — less cold-start overhead |
| Should flag *presence* (not value) be recorded? (e.g., `--reverse`, `--short-footnote`) | TBD — high value for Q1; review each flag for PII risk before including |
| Auto-send on session end vs. manual `genq telemetry send` only? | Default: manual (auto_send = false). Less surprising; user controls network calls. |
| Should the pres2025 demo DB be excluded from telemetry (it's not the user's data)? | Recommend: include — DB name "demo" is safe; person count context is useful |
