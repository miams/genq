# GenQuery Telemetry Module
#
# Collects anonymous diagnostic data to answer four questions:
#   1. Which commands are actually used?
#   2. Which platform/Nu version combinations produce errors?
#   3. Which commands are slow enough to optimize?
#   4. After a release, did error rates or latency change?
#
# Privacy: no PII, no cross-session identity, daily file rotation, 30-day retention.
# Telemetry is mandatory and always-on — see docs/telemetry-design.md.

use collector.nu [new-session, record-session-start, record-command, record-session-end, build-resource]
use buffer.nu [read-buffer, clear-buffer, rotate-buffer, buffer-stats, append-span]
use transport.nu [send-otlp, send-profiles]
use history.nu [read-history, rotate-history, history-dir]
use profile.nu [list-profiles, read-profile, should-profile, compute-fingerprint]
export use profile.nu profile-init

# Telemetry management for GenQuery.
@category "genq-common"
export def main [] {
    print $"(ansi cyan_bold)GenQuery Telemetry(ansi reset)"
    print ""
    print "Commands:"
    print "  genq telemetry status   — Show current telemetry state"
    print "  genq telemetry send     — Upload buffered data to backend"
    print "  genq telemetry clear    — Delete local buffer without uploading"
    print "  genq telemetry view     — Print buffered events"
    print "  genq telemetry history  — Show upload transmission log"
    print "  genq telemetry profile  — Show DB shape profile status"
    print ""
    print "Telemetry is anonymous and mandatory. No PII is collected."
    print "See docs/telemetry-design.md for privacy details."
}

# Show telemetry endpoint configuration and buffer statistics.
@category "genq-common"
export def status [] {
    let stats = (buffer-stats)
    let endpoint = ($env.GENQ_CONFIG?.telemetry?.endpoint_url? | default "(not set)")
    let retention = ($env.GENQ_CONFIG?.telemetry?.retention_days? | default 30)

    print $"(ansi cyan_bold)Telemetry Status(ansi reset)"
    print ""
    print $"  Endpoint URL:   ($endpoint)"
    print $"  Retention:      ($retention) days"
    print ""
    print $"(ansi cyan_bold)Buffer(ansi reset)"
    print $"  Files:          ($stats.files)"
    print $"  Total size:     ($stats.total_bytes)"
    print $"  Spans:          ($stats.span_count)"

    if $stats.files > 0 {
        print $"  Date range:     ($stats.oldest) to ($stats.newest)"
    }
}

# Upload buffered telemetry data to the configured OTLP endpoint.
# Sends two streams: traces (/v1/traces) and DB shape profiles (/v1/profiles).
@category "genq-common"
export def send [] {
    let endpoint = ($env.GENQ_CONFIG?.telemetry?.endpoint_url? | default "")
    if ($endpoint | is-empty) {
        print $"(ansi red)Error:(ansi reset) No endpoint URL configured."
        print "Set telemetry.endpoint_url in config/default.toml"
        return
    }
    send-otlp $endpoint
    send-profiles $endpoint
}

# Delete all local telemetry buffer files without uploading.
@category "genq-common"
export def clear [] {
    clear-buffer
    print "Local telemetry buffer cleared."
}

# Print buffered telemetry events in a readable format.
@category "genq-common"
export def view [] {
    let spans = (read-buffer)

    if ($spans | is-empty) {
        print "No buffered telemetry data."
        return
    }

    let sessions = ($spans | where name == "genq.session")
    let session_ends = ($spans | where name == "genq.session.end")
    let commands = ($spans | where name != "genq.session" and name != "genq.session.end")

    print $"(ansi cyan_bold)Buffered Telemetry — ($sessions | length) session\(s), ($commands | length) command\(s)(ansi reset)"
    print ""

    for session in $sessions {
        let attrs = ($session.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })

        # Find the latest session-end span for this trace, if any
        let latest_end = ($session_ends | where traceId == $session.traceId | last)
        let end_attrs = if ($latest_end | is-empty) {
            {}
        } else {
            $latest_end.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value }
        }

        let commands_run = ($end_attrs | get --optional 'genq.session.commands_run' | get --optional intValue
            | default ($attrs | get --optional 'genq.session.commands_run' | get --optional intValue | default '0'))
        let error_count = ($end_attrs | get --optional 'genq.session.error_count' | get --optional intValue
            | default ($attrs | get --optional 'genq.session.error_count' | get --optional intValue | default '0'))
        let duration = ($end_attrs | get --optional 'genq.session.duration_ms' | get --optional intValue | default '—')

        print $"  Session: ($session.traceId | str substring 0..8)..."
        print $"    DB:           ($attrs | get --optional 'genq.db.name' | get --optional stringValue | default '?')"
        print $"    Cold start:   ($attrs | get --optional 'genq.session.cold_start_ms' | get --optional intValue | default '?') ms"
        print $"    Duration:     ($duration) ms"
        print $"    Commands:     ($commands_run)"
        print $"    Errors:       ($error_count)"
        print ""
    }

    if ($commands | is-not-empty) {
        print "  Commands:"
        for cmd in $commands {
            let attrs = ($cmd.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })
            let duration = ($attrs | get --optional 'genq.duration_ms' | get --optional intValue | default '?')
            let status_icon = if ($cmd.status.code == 1) { $"(ansi green)ok(ansi reset)" } else { $"(ansi red)err(ansi reset)" }
            print $"    ($cmd.name) — ($duration) ms [($status_icon)]"
        }
    }
}

# Show the upload transmission log: when, mode, KB, span count, status.
@category "genq-common"
export def history [] {
    let entries = (read-history)

    if ($entries | is-empty) {
        print "No upload history yet."
        return
    }

    $entries
    | sort-by timestamp --reverse
    | each {|e|
        let kb = (($e.bytes | default 0) / 1024 | math round --precision 1)
        {
            When: $e.timestamp
            KB: $kb
            Spans: $e.span_count
            Status: $e.status
        }
    }
}

# Show pending DB shape profile snapshots and the cache state.
@category "genq-common"
export def profile [] {
    let profiles = (list-profiles)
    let db_path = ($env.rmdb? | default "")

    print $"(ansi cyan_bold)DB Shape Profile(ansi reset)"
    print ""

    if ($db_path | is-empty) or (not ($db_path | path exists)) {
        print "  Active DB:      (none)"
    } else {
        print $"  Active DB:      ($db_path)"
        try {
            let fp = (compute-fingerprint $db_path)
            print $"  Fingerprint:    ($fp.rm_unique_id) @ ($fp.latest_utcmoddate)"
        } catch { }
        let pending = (try { should-profile $db_path } catch { true })
        let label = if $pending { $"(ansi yellow)pending(ansi reset)" } else { $"(ansi green)current(ansi reset)" }
        print $"  Status:         ($label)"
    }

    print ""
    print $"(ansi cyan_bold)Local snapshots(ansi reset)"
    if ($profiles | is-empty) {
        print "  (none)"
        return
    }
    $profiles | each {|p|
        {
            file: $p.file
            size_bytes: $p.size_bytes
            modified: $p.modified
        }
    }
}

# Hook handler — called from pre_prompt to record a single completed command.
# 
# Parses the commandline, records a command span (if it's a genq command),
# updates session counters, and emits a fresh session.end summary.
# Silent on any error; telemetry must never break genq.
export def --env "record-from-hook" [start_time: datetime, end_time: datetime, cmdline: string] {
    try {
        let session = ($env.GENQ_TELEMETRY_SESSION? | default null)
        if $session == null { return }

        let parsed = (parse-genq-subcommand $cmdline)
        if $parsed == null { return }

        record-command $session $parsed.command $parsed.subcommand $start_time $end_time

        # Increment session counters and re-emit session.end
        let updated = ($session
            | upsert commands_run (($session | get --optional commands_run | default 0) + 1))
        $env.GENQ_TELEMETRY_SESSION = $updated
        record-session-end $updated
    } catch { }
}

# Extract a privacy-safe { command, subcommand } from a commandline.
# 
# Rules:
#   - Must start with "genq"
#   - Only alphabetic, lowercase tokens after "genq" are kept (max 3)
#   - Stops at first non-alphabetic token (flags, args, RINs, paths, pipes)
#   - Returns null for non-genq commands
export def parse-genq-subcommand [cmdline: string] {
    let head = ($cmdline | str trim)
    let head_part = if ($head | str contains '|') {
        $head | split row '|' | first | str trim
    } else {
        $head
    }

    let raw_parts = ($head_part
        | split row ' '
        | each {|p| $p | str trim }
        | where {|p| ($p | str length) > 0 })

    if ($raw_parts | is-empty) { return null }
    if ($raw_parts | first) != "genq" { return null }

    mut command_parts = []
    for p in ($raw_parts | skip 1) {
        if (($command_parts | length) >= 3) { break }
        let lower = ($p | str downcase)
        if not ($lower =~ '^[a-z][a-z-]*$') { break }
        $command_parts = ($command_parts | append $lower)
    }

    if ($command_parts | is-empty) { return null }

    {
        command: ($command_parts | first)
        subcommand: ($command_parts | str join ' ')
    }
}
