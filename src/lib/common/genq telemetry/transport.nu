# Telemetry transport — HTTP upload to OTLP endpoint or Turso
#
# Reads buffered NDJSON spans and transmits them in batch.

use buffer.nu [read-buffer, clear-buffer]

# Wrap a list of span records into a valid OTLP/HTTP JSON traces payload.
export def format-otlp-payload [spans: list, resource: record] {
    {
        resourceSpans: [
            {
                resource: $resource
                scopeSpans: [
                    {
                        scope: { name: "genq.telemetry", version: "0.1.0" }
                        spans: ($spans | each {|s| $s | reject --optional _resource })
                    }
                ]
            }
        ]
    }
}

# Send buffered spans to an OTLP/HTTP endpoint (POST /v1/traces).
export def send-otlp [endpoint_url: string] {
    let spans = (read-buffer)

    if ($spans | is-empty) {
        print "No buffered telemetry data to send."
        return
    }

    # Extract resource from the first session span (all spans in a buffer share the same resource)
    let resource = ($spans
        | where {|s| ($s | get --optional _resource) != null }
        | first
        | get _resource
    )

    let payload = (format-otlp-payload $spans $resource)
    let url = $"($endpoint_url | str replace --regex '/$' '')/v1/traces"

    print $"Sending ($spans | length) spans to ($url)..."

    try {
        let response = ($payload | to json | http post
            --content-type "application/json"
            $url)

        print $"(ansi green)Success:(ansi reset) Telemetry data sent."
        clear-buffer
        print "Local buffer cleared."
    } catch {|e|
        print $"(ansi red)Error:(ansi reset) Failed to send telemetry: ($e.msg)"
        print "Buffered data has been preserved for retry."
    }
}

# Send buffered spans to Turso as INSERT statements via Hrana pipeline.
export def send-turso [] {
    let url = ($env.TURSO_DB_URL? | default "" | str replace --regex '^libsql://' 'https://')
    let token = ($env.TURSO_AUTH_TOKEN? | default "")

    if ($url | is-empty) or ($token | is-empty) {
        print $"(ansi yellow)Notice:(ansi reset) TURSO_DB_URL / TURSO_AUTH_TOKEN not set — cannot send."
        return
    }

    let spans = (read-buffer)

    if ($spans | is-empty) {
        print "No buffered telemetry data to send."
        return
    }

    # Separate session spans from command spans
    let session_spans = ($spans | where name == "genq.session")
    let command_spans = ($spans | where name != "genq.session")

    # Build Hrana pipeline requests
    mut requests = []

    for session in $session_spans {
        let attrs = ($session.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })
        $requests = ($requests | append {
            type: "execute"
            stmt: {
                sql: "INSERT OR IGNORE INTO usage_sessions (trace_id, genq_version, nu_version, platform, os_version, terminal, db_name, db_filename, db_person_count, db_size_kb, cold_start_ms, session_at, commands_run, error_count, locale, table_mode, date_format) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                args: [
                    (ta-text $session.traceId)
                    (ta-text ($attrs | get --optional "service.version" | get --optional stringValue | default "unknown"))
                    (ta-text ($attrs | get --optional "process.runtime.version" | get --optional stringValue | default "unknown"))
                    (ta-text ($attrs | get --optional "host.os.type" | get --optional stringValue | default "unknown"))
                    (ta-nullable-text ($attrs | get --optional "host.os.version" | get --optional stringValue))
                    (ta-nullable-text ($attrs | get --optional "genq.terminal" | get --optional stringValue))
                    (ta-nullable-text ($attrs | get --optional "genq.db.name" | get --optional stringValue))
                    (ta-nullable-text ($attrs | get --optional "genq.db.filename" | get --optional stringValue))
                    (ta-nullable-int ($attrs | get --optional "genq.db.person_count" | get --optional intValue))
                    (ta-nullable-int ($attrs | get --optional "genq.db.size_kb" | get --optional intValue))
                    (ta-nullable-int ($attrs | get --optional "genq.session.cold_start_ms" | get --optional intValue))
                    (ta-int ($session.startTimeUnixNano | into int | $in / 1000000 | into int))
                    (ta-nullable-int ($attrs | get --optional "genq.session.commands_run" | get --optional intValue))
                    (ta-nullable-int ($attrs | get --optional "genq.session.error_count" | get --optional intValue))
                    (ta-nullable-text ($attrs | get --optional "genq.locale" | get --optional stringValue))
                    (ta-nullable-text ($attrs | get --optional "genq.config.table_mode" | get --optional stringValue))
                    (ta-nullable-int ($attrs | get --optional "genq.config.date_format" | get --optional intValue))
                ]
            }
        })
    }

    for cmd in $command_spans {
        let attrs = ($cmd.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })
        $requests = ($requests | append {
            type: "execute"
            stmt: {
                sql: "INSERT OR IGNORE INTO usage_commands (span_id, trace_id, command, subcommand, db_name, result_rows, duration_ms, status, error_class, commanded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                args: [
                    (ta-text $cmd.spanId)
                    (ta-text $cmd.traceId)
                    (ta-text ($attrs | get --optional "genq.command" | get --optional stringValue | default "unknown"))
                    (ta-text ($attrs | get --optional "genq.subcommand" | get --optional stringValue | default "unknown"))
                    (ta-nullable-text ($attrs | get --optional "genq.db.name" | get --optional stringValue))
                    (ta-nullable-int ($attrs | get --optional "genq.result_rows" | get --optional intValue))
                    (ta-int ($attrs | get --optional "genq.duration_ms" | get --optional intValue | default "0" | into int))
                    (ta-text (if ($cmd.status.code == 1) { "ok" } else { "error" }))
                    (ta-nullable-text ($cmd | get --optional events | default [] | where name == "exception" | first | get --optional attributes | default [] | where key == "exception.type" | first | get --optional value.stringValue))
                    (ta-int ($cmd.startTimeUnixNano | into int | $in / 1000000 | into int))
                ]
            }
        })
    }

    $requests = ($requests | append { type: "close" })

    print $"Sending ($session_spans | length) sessions + ($command_spans | length) commands to Turso..."

    try {
        let response = ({ requests: $requests } | to json | http post
            --content-type "application/json"
            --headers { Authorization: $"Bearer ($token)" }
            $"($url)/v2/pipeline")

        print $"(ansi green)Success:(ansi reset) Telemetry data sent to Turso."
        clear-buffer
        print "Local buffer cleared."
    } catch {|e|
        print $"(ansi red)Error:(ansi reset) Failed to send to Turso: ($e.msg)"
        print "Buffered data has been preserved for retry."
    }
}

# --- Hrana typed-argument helpers (same pattern as tests/ingest-results.nu) ---

def ta-text [v: string] {
    { type: "text", value: $v }
}

def ta-int [v: int] {
    { type: "integer", value: ($v | into string) }
}

def ta-null [] {
    { type: "null" }
}

def ta-nullable-text [v] {
    if ($v == null) { ta-null } else { ta-text ($v | into string) }
}

def ta-nullable-int [v] {
    if ($v == null) { ta-null } else { ta-int ($v | into int) }
}
