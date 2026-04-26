# Telemetry data collector — builds OTel resource attributes, session spans, and command spans
#
# All functions return plain Nushell records that can be serialized to JSON.
# No network I/O or side effects; callers decide when/where to persist.

use buffer.nu [append-span]

# Build OTel resource attributes from the current environment.
# These are static for the lifetime of a session.
export def build-resource [] {
    let ver = (version)
    let host = (sys host)

    let attrs = [
        { key: "service.name",            value: { stringValue: "genq" } }
        { key: "service.version",         value: { stringValue: ($env.GENQ_CONFIG?.metadata?.version? | default "unknown") } }
        { key: "telemetry.sdk.language",   value: { stringValue: "nushell" } }
        { key: "host.os.type",            value: { stringValue: $ver.build_os } }
        { key: "host.arch",               value: { stringValue: $ver.build_target } }
        { key: "host.os.version",         value: { stringValue: ($host.os_version? | default "") } }
        { key: "host.os.kernel_version",  value: { stringValue: ($host.kernel_version? | default "") } }
        { key: "process.runtime.version", value: { stringValue: $ver.version } }
        { key: "genq.terminal",           value: { stringValue: ($env.TERM_PROGRAM? | default "unknown") } }
        { key: "genq.locale",             value: { stringValue: ($env.LANG? | default "unknown") } }
        { key: "genq.extensions",         value: { arrayValue: { values: (
            $env.GENQ_CONFIG?.extensions?.enabled? | default []
            | each {|e| { stringValue: $e } }
        ) } } }
    ]

    { attributes: $attrs }
}

# Start a new telemetry session. Returns a session record to store in $env.
export def new-session [] {
    let trace_id = (random uuid | str replace -a '-' '')
    let span_id = (random uuid | str replace -a '-' '' | str substring 0..16)
    let start = (date now)

    {
        trace_id: $trace_id
        span_id: $span_id
        start_time: $start
        start_time_unix_nano: (($start | into int) | into string)
        commands_run: 0
        error_count: 0
        resource: (build-resource)
    }
}

# Build the initial session-start span and append it to the buffer.
# This is called once at genq load time to record the session beginning.
export def record-session-start [session: record] {
    let cold_start_ms = ((date now) - $session.start_time) / 1ms | into int

    # Gather DB metadata (read-only PRAGMAs — safe and fast)
    let db_meta = (try {
        if ($env.rmdb? | default "" | path exists) {
            let person_count = (open $env.rmdb | query db "SELECT COUNT(*) as c FROM PersonTable" | get 0.c)
            let page_info = (open $env.rmdb | query db "PRAGMA page_count" | get 0.page_count)
            let page_size = (open $env.rmdb | query db "PRAGMA page_size" | get 0.page_size)
            let size_kb = (($page_info * $page_size) / 1024 | into int)
            let filename = ($env.rmdb | path basename)
            let db_name = ($env.GENQ_CONFIG?.database?.active? | default "unknown")
            {
                person_count: $person_count
                size_kb: $size_kb
                filename: $filename
                db_name: $db_name
            }
        } else {
            { person_count: 0, size_kb: 0, filename: "", db_name: "none" }
        }
    } catch {
        { person_count: 0, size_kb: 0, filename: "", db_name: "error" }
    })

    let span = {
        traceId: $session.trace_id
        spanId: $session.span_id
        parentSpanId: null
        name: "genq.session"
        kind: 1
        startTimeUnixNano: $session.start_time_unix_nano
        endTimeUnixNano: $session.start_time_unix_nano
        attributes: [
            { key: "genq.session.cold_start_ms",  value: { intValue: ($cold_start_ms | into string) } }
            { key: "genq.db.name",                value: { stringValue: $db_meta.db_name } }
            { key: "genq.db.filename",            value: { stringValue: $db_meta.filename } }
            { key: "genq.db.person_count",        value: { intValue: ($db_meta.person_count | into string) } }
            { key: "genq.db.size_kb",             value: { intValue: ($db_meta.size_kb | into string) } }
            { key: "genq.config.table_mode",      value: { stringValue: ($env.GENQ_CONFIG?.display?.table_mode? | default "rounded") } }
            { key: "genq.config.date_format",     value: { intValue: ($env.GENQ_CONFIG?.display?.date_format? | default 1 | into string) } }
            { key: "genq.session.commands_run",   value: { intValue: "0" } }
            { key: "genq.session.error_count",    value: { intValue: "0" } }
        ]
        status: { code: 1 }
        _resource: $session.resource
    }

    append-span $span
}

# Build and buffer a session-end summary span.
# Called after each command (per-prompt) so the latest emit reflects current
# cumulative session counters. Backend logic treats the latest session-end
# span per traceId as authoritative.
export def record-session-end [session: record] {
    let now = (date now)
    let now_nano = ($now | into int | into string)
    let duration_ms = (($now - $session.start_time) / 1ms | into int)
    let commands_run = ($session | get --optional commands_run | default 0)
    let error_count = ($session | get --optional error_count | default 0)
    let end_span_id = (random uuid | str replace -a '-' '' | str substring 0..16)

    let span = {
        traceId: $session.trace_id
        spanId: $end_span_id
        parentSpanId: $session.span_id
        name: "genq.session.end"
        kind: 1
        startTimeUnixNano: $session.start_time_unix_nano
        endTimeUnixNano: $now_nano
        attributes: [
            { key: "genq.session.duration_ms",   value: { intValue: ($duration_ms | into string) } }
            { key: "genq.session.commands_run",  value: { intValue: ($commands_run | into string) } }
            { key: "genq.session.error_count",   value: { intValue: ($error_count | into string) } }
        ]
        status: { code: 1 }
    }

    append-span $span
}

# Build and buffer a command span (child of the session).
export def record-command [
    session: record
    command: string
    subcommand: string
    start_time: datetime
    end_time: datetime
    result_rows: int = 0
    status: string = "ok"
    error_class?: string
] {
    let span_id = (random uuid | str replace -a '-' '' | str substring 0..16)
    let duration_ms = (($end_time - $start_time) / 1ms | into int)

    let attrs = [
        { key: "genq.command",     value: { stringValue: $command } }
        { key: "genq.subcommand",  value: { stringValue: $subcommand } }
        { key: "genq.result_rows", value: { intValue: ($result_rows | into string) } }
        { key: "genq.db.name",     value: { stringValue: ($env.GENQ_CONFIG?.database?.active? | default "unknown") } }
        { key: "genq.duration_ms", value: { intValue: ($duration_ms | into string) } }
    ]

    mut span = {
        traceId: $session.trace_id
        spanId: $span_id
        parentSpanId: $session.span_id
        name: $"genq ($subcommand)"
        kind: 1
        startTimeUnixNano: ($start_time | into int | into string)
        endTimeUnixNano: ($end_time | into int | into string)
        attributes: $attrs
        status: { code: (if $status == "ok" { 1 } else { 2 }) }
    }

    # Attach error event if applicable
    if ($error_class != null) {
        $span = ($span | insert events [
            {
                timeUnixNano: ($end_time | into int | into string)
                name: "exception"
                attributes: [
                    { key: "exception.type", value: { stringValue: $error_class } }
                    { key: "exception.escaped", value: { boolValue: false } }
                ]
            }
        ])
    }

    append-span $span
}
