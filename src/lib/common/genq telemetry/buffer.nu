# Telemetry NDJSON buffer — local file I/O
#
# Spans are appended to daily NDJSON files under ~/.local/share/genq/telemetry/.
# No network I/O happens here; transmission is handled by transport.nu.

# Return the buffer directory path, creating it if it does not exist.
export def buffer-dir [] {
    let dir = if ($env.APPDATA? | default "" | is-not-empty) {
        # Windows
        $env.APPDATA | path join "genq" "telemetry"
    } else {
        # macOS / Linux (XDG)
        let data_home = ($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share"))
        $data_home | path join "genq" "telemetry"
    }

    if not ($dir | path exists) {
        mkdir $dir
    }

    $dir
}

# Append a single span record as one JSON line to today's buffer file.
export def append-span [span: record] {
    let dir = (buffer-dir)
    let today = (date now | format date "%Y-%m-%d")
    let file = ($dir | path join $"($today).ndjson")

    $span | to json --raw | $in + "\n" | save --append --raw $file
}

# Read all buffered spans across all NDJSON files. Returns a list of records.
export def read-buffer [] {
    let dir = (buffer-dir)
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

# Delete buffer files older than the configured retention period.
export def rotate-buffer [retention_days: int = 30] {
    let dir = (buffer-dir)
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

# Delete all NDJSON buffer files.
export def clear-buffer [] {
    let dir = (buffer-dir)
    let files = (glob ($dir | path join "*.ndjson"))

    $files | each {|f| rm $f }
}

# Return summary statistics about the current buffer.
export def buffer-stats [] {
    let dir = (buffer-dir)
    let files = (glob ($dir | path join "*.ndjson"))

    if ($files | is-empty) {
        return {
            files: 0
            total_bytes: 0
            oldest: null
            newest: null
            span_count: 0
        }
    }

    let sorted = ($files | sort)
    let total_bytes = ($sorted | each {|f| ls $f | get 0.size } | math sum)
    let span_count = ($sorted | each {|f|
        open $f --raw | lines | where {|l| not ($l | str trim | is-empty) } | length
    } | math sum)

    {
        files: ($sorted | length)
        total_bytes: $total_bytes
        oldest: ($sorted | first | path basename | str replace ".ndjson" "")
        newest: ($sorted | last | path basename | str replace ".ndjson" "")
        span_count: $span_count
    }
}
