# Telemetry transport — HTTP upload to OTLP endpoint
#
# Reads buffered NDJSON spans and transmits them in batch via OTLP/HTTP JSON.
# Every send attempt — success, deferred (offline), or failed — is logged
# via history.nu so `genq telemetry history` can report a transmission log.
#
# Two transports live here:
#   • send-otlp      → traces (NDJSON-buffered spans → /v1/traces)
#   • send-profiles  → DB shape profiles (gzipped JSON files → /v1/profiles)
# They share the upload-history log so `genq telemetry history` reports both.

use buffer.nu [read-buffer, clear-buffer]
use history.nu [record-upload, classify-error]
use profile.nu [profiles-dir, sent-profiles-dir]

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
    let body = ($payload | to json)
    let bytes = ($body | into binary | bytes length)
    let url = $"($endpoint_url | str replace --regex '/$' '')/v1/traces"
    let span_count = ($spans | length)

    print $"Sending ($span_count) spans to ($url)..."

    try {
        let response = ($body | http post
            --content-type "application/json"
            $url)

        record-upload $endpoint_url $span_count $bytes "success" ""
        print $"(ansi green)Success:(ansi reset) Telemetry data sent."
        clear-buffer
        print "Local buffer cleared."
    } catch {|e|
        let status = (classify-error $e.msg)
        record-upload $endpoint_url $span_count $bytes $status $e.msg
        let label = if $status == "deferred" { "Deferred" } else { "Error" }
        let color = if $status == "deferred" { (ansi yellow) } else { (ansi red) }
        print $"($color)($label):(ansi reset) Failed to send telemetry: ($e.msg)"
        print "Buffered data has been preserved for retry."
    }
}

# Upload all pending DB shape profile files to /v1/profiles.
#
# Each file under <profiles-dir>/*.json.gz is uploaded as a *separate* POST
# with the original gzip bytes in the body (so the server stores them as-is
# without re-encoding). On success the file is moved to <sent-profiles-dir>
# (under the OS cache root, not the data root — once shipped these are pure
# archive and the OS may safely reclaim them) so the next send is a no-op
# for already-uploaded snapshots.
#
# Failures are recorded in the upload-history log alongside trace failures;
# the file stays in place for the next retry.
export def send-profiles [endpoint_url: string] {
    let dir = (profiles-dir)
    let pending = (glob ($dir | path join "*.json.gz"))

    if ($pending | is-empty) {
        print "No pending profiles to send."
        return
    }

    let url = $"($endpoint_url | str replace --regex '/$' '')/v1/profiles"
    let sent_dir = (sent-profiles-dir)

    print $"Uploading ($pending | length) profile\(s) to ($url)..."

    for f in $pending {
        let basename = ($f | path basename)
        let body = (open $f --raw)
        let bytes = ($body | bytes length)

        try {
            # Body is gzipped JSON bytes. Wire content-type is octet-stream
            # because Nu's http post rejects binary input with the
            # application/json content-type; the Content-Encoding header
            # tells the server it's gzip, and the Lambda handler infers
            # JSON from the route (/v1/profiles always carries JSON).
            let _ = ($body | http post
                --content-type "application/octet-stream"
                --headers { "Content-Encoding": "gzip" }
                $url)

            record-upload $url 1 $bytes "success" ""
            mv $f ($sent_dir | path join $basename)
            print $"  (ansi green)✓(ansi reset) ($basename) — ($bytes) bytes"
        } catch {|e|
            let status = (classify-error $e.msg)
            record-upload $url 1 $bytes $status $e.msg
            let label = if $status == "deferred" { "deferred" } else { "failed" }
            let color = if $status == "deferred" { (ansi yellow) } else { (ansi red) }
            print $"  ($color)✗ ($label)(ansi reset) ($basename): ($e.msg)"
        }
    }
}
