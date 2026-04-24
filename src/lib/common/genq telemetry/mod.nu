# GenQuery Telemetry Module
#
# Collects anonymous diagnostic data to answer four questions:
#   1. Which commands are actually used?
#   2. Which platform/Nu version combinations produce errors?
#   3. Which commands are slow enough to optimize?
#   4. After a release, did error rates or latency change?
#
# Privacy: opt-in only, no PII, no cross-session identity.
# See docs/telemetry-design.md for full specification.

use consent.nu [is-enabled, set-enabled, first-run-check]
use collector.nu [new-session, record-session-start, record-command, build-resource]
use buffer.nu [read-buffer, clear-buffer, rotate-buffer, buffer-stats, append-span]
use transport.nu [send-otlp, send-turso]

# Telemetry management for GenQuery.
@category "genq-common"
export def main [] {
    print $"(ansi cyan_bold)GenQuery Telemetry(ansi reset)"
    print ""
    print "Commands:"
    print "  genq telemetry status   — Show current telemetry state"
    print "  genq telemetry enable   — Opt in to telemetry"
    print "  genq telemetry disable  — Opt out and delete buffered data"
    print "  genq telemetry send     — Upload buffered data to backend"
    print "  genq telemetry clear    — Delete local buffer without uploading"
    print "  genq telemetry view     — Print buffered events"
    print ""
    print "See docs/telemetry-design.md for privacy details."
}

# Show current telemetry opt-in state and buffer statistics.
@category "genq-common"
export def status [] {
    let enabled = (is-enabled)
    let stats = (buffer-stats)
    let mode = ($env.GENQ_CONFIG?.telemetry?.endpoint_mode? | default "otlp")
    let endpoint = ($env.GENQ_CONFIG?.telemetry?.endpoint_url? | default "(not set)")
    let retention = ($env.GENQ_CONFIG?.telemetry?.retention_days? | default 30)

    print $"(ansi cyan_bold)Telemetry Status(ansi reset)"
    print ""
    print $"  Enabled:        (if $enabled { $'(ansi green)yes(ansi reset)' } else { $'(ansi yellow)no(ansi reset)' })"
    print $"  Endpoint mode:  ($mode)"
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

# Enable telemetry data collection.
@category "genq-common"
export def enable [] {
    set-enabled true
    print $"(ansi green)Telemetry enabled.(ansi reset)"
    print "Anonymous diagnostic data will be collected locally."
    print "Use 'genq telemetry send' to upload, or 'genq telemetry status' to review."
}

# Disable telemetry and delete all buffered data.
@category "genq-common"
export def disable [] {
    set-enabled false
    clear-buffer
    print $"Telemetry disabled. All buffered data has been deleted."
}

# Upload buffered telemetry data to the configured backend.
@category "genq-common"
export def send [] {
    if not (is-enabled) {
        print $"(ansi yellow)Notice:(ansi reset) Telemetry is disabled. Enable it first with: genq telemetry enable"
        return
    }

    let mode = ($env.GENQ_CONFIG?.telemetry?.endpoint_mode? | default "otlp")

    match $mode {
        "otlp" => {
            let endpoint = ($env.GENQ_CONFIG?.telemetry?.endpoint_url? | default "")
            if ($endpoint | is-empty) {
                print $"(ansi red)Error:(ansi reset) No endpoint URL configured."
                print "Set telemetry.endpoint_url in config/default.toml"
                return
            }
            send-otlp $endpoint
        }
        "turso" => {
            send-turso
        }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown endpoint_mode: ($mode)"
            print "Valid modes: otlp, turso"
        }
    }
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
    let commands = ($spans | where name != "genq.session")

    print $"(ansi cyan_bold)Buffered Telemetry — ($sessions | length) session\(s), ($commands | length) command\(s)(ansi reset)"
    print ""

    for session in $sessions {
        let attrs = ($session.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })
        print $"  Session: ($session.traceId | str substring 0..8)..."
        print $"    DB:         ($attrs | get --optional 'genq.db.name' | get --optional stringValue | default '?')"
        print $"    Cold start: ($attrs | get --optional 'genq.session.cold_start_ms' | get --optional intValue | default '?') ms"
        print $"    Commands:   ($attrs | get --optional 'genq.session.commands_run' | get --optional intValue | default '?')"
        print $"    Errors:     ($attrs | get --optional 'genq.session.error_count' | get --optional intValue | default '?')"
        print ""
    }

    if ($commands | is-not-empty) {
        print "  Commands:"
        for cmd in $commands {
            let attrs = ($cmd.attributes | reduce --fold {} {|a, acc| $acc | insert $a.key $a.value })
            let duration = ($attrs | get --optional 'genq.duration_ms' | get --optional intValue | default '?')
            let status_icon = if ($cmd.status.code == 1) { $"(ansi green)ok(ansi reset)" } else { $"(ansi red)err(ansi reset)" }
            print $"    ($cmd.name) — ($duration) ms [$status_icon]"
        }
    }
}
