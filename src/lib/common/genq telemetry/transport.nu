# Telemetry transport — HTTP upload to OTLP endpoint
#
# Reads buffered NDJSON spans and transmits them in batch via OTLP/HTTP JSON.
# Every send attempt — success, deferred (offline), or failed — is logged
# via history.nu so `genq telemetry history` can report a transmission log.

use buffer.nu [read-buffer, clear-buffer]
use history.nu [record-upload, classify-error]

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
