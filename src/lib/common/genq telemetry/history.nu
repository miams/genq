# Telemetry upload history — local NDJSON log of every send attempt
#
# Each upload (success or failure) appends one record under
# ~/.local/share/genq/telemetry/uploads/YYYY-MM-DD.ndjson. Schema:
#   { timestamp, endpoint_url, span_count, bytes, status, error_msg }
# status is one of: "success" | "deferred" | "failed"
#   deferred → host appears offline (network unreachable / DNS failure / timeout)
#   failed   → endpoint reachable but rejected the payload (HTTP error, malformed)

# Return the upload-history directory path, creating it if missing.
export def history-dir [] {
    let base = if ($env.APPDATA? | default "" | is-not-empty) {
        # Windows
        $env.APPDATA | path join "genq" "telemetry" "uploads"
    } else {
        # macOS / Linux (XDG)
        let data_home = ($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share"))
        $data_home | path join "genq" "telemetry" "uploads"
    }

    if not ($base | path exists) {
        mkdir $base
    }

    $base
}

# Heuristic: classify a transport error message as "deferred" (likely offline)
# or "failed" (other error). Used by transport.nu to label upload entries.
export def classify-error [msg: string] {
    let lower = ($msg | str downcase)
    let offline_signals = [
        "could not resolve"
        "name or service not known"
        "connection refused"
        "network is unreachable"
        "no route to host"
        "operation timed out"
        "timed out"
        "request timeout"
        "connection reset"
        "no such host"
    ]

    let is_offline = ($offline_signals | any {|sig| $lower | str contains $sig })
    if $is_offline { "deferred" } else { "failed" }
}

# Append a single upload-attempt record to today's history file.
export def record-upload [
    endpoint_url: string
    span_count: int
    bytes: int
    status: string
    error_msg: string = ""
] {
    let dir = (history-dir)
    let today = (date now | format date "%Y-%m-%d")
    let file = ($dir | path join $"($today).ndjson")
    let entry = {
        timestamp: ((date now) | format date "%Y-%m-%dT%H:%M:%S%:z")
        endpoint_url: $endpoint_url
        span_count: $span_count
        bytes: $bytes
        status: $status
        error_msg: $error_msg
    }

    $entry | to json --raw | $in + "\n" | save --append --raw $file
}

# Read all upload-history records across all NDJSON files. Returns a list of records.
export def read-history [] {
    let dir = (history-dir)
    let files = (glob ($dir | path join "*.ndjson"))

    if ($files | is-empty) {
        return []
    }

    $files
    | sort
    | each {|f|
        open $f --raw
        | lines
        | where {|l| not ($l | str trim | is-empty) }
        | each {|l| $l | from json }
    }
    | flatten
}

# Delete history files older than retention_days.
export def rotate-history [retention_days: int = 30] {
    let dir = (history-dir)
    let files = (glob ($dir | path join "*.ndjson"))

    if ($files | is-empty) {
        return
    }

    let cutoff = (date now) - ($retention_days | into duration --unit day)

    $files | each {|f|
        let basename = ($f | path basename | str replace ".ndjson" "")
        try {
            let file_date = ($basename | into datetime)
            if $file_date < $cutoff {
                rm $f
            }
        } catch {
            # Skip files with unparseable names
        }
    }
}
