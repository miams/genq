# Telemetry filesystem layout — platform-aware data + cache root resolvers.
#
# Two roots, each with a meaningful guarantee:
#
#   data dir   — events that happened: pre-upload trace buffer, pre-upload
#                profile snapshots, upload history. Persists across reboots,
#                included in user backups (Time Machine on macOS). Losing
#                this means losing real diagnostic signal or audit trail.
#
#   cache dir  — pure cache: post-upload archive (`sent/`), fingerprint
#                index (`.cache.json`). The OS may purge this under disk
#                pressure; everything here is recreatable from the next
#                send/profile cycle.
#
# Per-platform mapping:
#
#   macOS    data → ~/Library/Application Support/genq/telemetry
#            cache → ~/Library/Caches/genq/telemetry
#
#   Linux    data → $XDG_DATA_HOME/genq/telemetry   (default ~/.local/share)
#            cache → $XDG_CACHE_HOME/genq/telemetry  (default ~/.cache)
#
#   Windows  data → %APPDATA%\genq\telemetry
#            cache → %LOCALAPPDATA%\genq\telemetry  (falls back to %APPDATA%)

def os-name [] { $nu.os-info.name }

export def telemetry-data-dir [] {
    let base = if (os-name) == "macos" {
        $nu.home-dir | path join "Library" "Application Support" "genq" "telemetry"
    } else if (os-name) == "windows" {
        ($env.APPDATA? | default ($nu.home-dir | path join "AppData" "Roaming")) | path join "genq" "telemetry"
    } else {
        let data_home = ($env.XDG_DATA_HOME? | default ($nu.home-dir | path join ".local" "share"))
        $data_home | path join "genq" "telemetry"
    }

    if not ($base | path exists) { mkdir $base }
    $base
}

export def telemetry-cache-dir [] {
    let base = if (os-name) == "macos" {
        $nu.home-dir | path join "Library" "Caches" "genq" "telemetry"
    } else if (os-name) == "windows" {
        ($env.LOCALAPPDATA? | default ($env.APPDATA? | default ($nu.home-dir | path join "AppData" "Local"))) | path join "genq" "telemetry"
    } else {
        let cache_home = ($env.XDG_CACHE_HOME? | default ($nu.home-dir | path join ".cache"))
        $cache_home | path join "genq" "telemetry"
    }

    if not ($base | path exists) { mkdir $base }
    $base
}
