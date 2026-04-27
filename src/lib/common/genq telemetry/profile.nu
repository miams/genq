# GenQuery DB shape profile runner
#
# Executes the `profile-catalog.nu` metric set against a target SQLite database
# (typically the user's active RootsMagic .rmtree), assembles a profile record,
# and persists it as gzipped JSON for later upload to /v1/profiles.
#
# Design highlights:
#   • Scalar metrics are consolidated into a single mega-query so the database
#     is opened/closed once for the bulk of the work. SQLite's optimizer can
#     plan all the subqueries together; on Iiams (~12k people) this completes
#     in well under a second.
#   • Multi-row metrics (histograms, usage tables) run individually after the
#     mega-query. They're per-table aggregations that can't be inlined as a
#     scalar column without losing rows.
#   • Fingerprint cache (rm_unique_id + latest_utcmoddate) skips redundant
#     runs — RM stamps UTCModDate on every write, so a stable fingerprint
#     means nothing has changed.
#   • 7-day TTL fallback ensures we eventually re-emit even if the DB hasn't
#     been touched (catches schema/version drift, fact-type rename, etc.).
#   • All operations are best-effort. The runner is invoked from a background
#     `job spawn { … }`, so unhandled errors silently terminate the worker
#     rather than disrupting the user.

use profile-catalog.nu [
    metrics-catalog
    runnable-scalars
    runnable-multirow
]

use paths.nu [telemetry-data-dir, telemetry-cache-dir]

# Storage layout (see paths.nu for the platform-specific roots):
#
#   <data-dir>/profiles/
#     <rm_unique_id>-<UTC-stamp>.json.gz    pending uploads ("data, not cache":
#                                           losing them loses real signal)
#
#   <cache-dir>/profiles/
#     fingerprint-cache.json                fingerprint → latest-capture index
#                                           (purgeable; rebuilt next session)
#     sent/<rm_unique_id>-<UTC-stamp>.json.gz   post-upload archive (purgeable)
export def profiles-dir [] {
    let base = (telemetry-data-dir | path join "profiles")
    if not ($base | path exists) { mkdir $base }
    $base
}

export def profiles-cache-dir [] {
    let base = (telemetry-cache-dir | path join "profiles")
    if not ($base | path exists) { mkdir $base }
    $base
}

export def sent-profiles-dir [] {
    let base = (profiles-cache-dir | path join "sent")
    if not ($base | path exists) { mkdir $base }
    $base
}

export def cache-file [] {
    profiles-cache-dir | path join "fingerprint-cache.json"
}

# ─── Mega-query construction ────────────────────────────────────────────────
#
# Each scalar metric in the catalog ships its own complete `SELECT … AS v
# FROM …` statement that yields exactly one row, one column. To run them all
# in a single round-trip we wrap each as a *scalar subquery* on the columns
# of an outer SELECT against `(SELECT 1)`:
#
#   SELECT
#     (SELECT v FROM (<metric_query_1>)) AS m_0001,
#     (SELECT v FROM (<metric_query_2>)) AS m_0002,
#     ...
#   FROM (SELECT 1)
#
# Why m_NNNN aliases (instead of the metric's own name)?
#   1. Metric names like "people.total" are not legal SQL identifiers without
#      quoting; quoted names round-trip oddly through Nushell record keys.
#   2. A positional alias makes the result-row → metric-name mapping a pure
#      function of catalog order, which is deterministic.
#
# Why `SELECT v FROM (...)` instead of just `(...)`?
#   Some catalog queries use CTEs (`WITH cfg AS (...) SELECT ... FROM cfg`).
#   SQLite forbids a top-level CTE inside a scalar-subquery position unless
#   it's wrapped as a derived table. Wrapping in `SELECT v FROM (...)` makes
#   every catalog query — CTE or plain — usable as a scalar subquery.
export def build-mega-query [scalars: list] {
    mut parts = []
    for entry in ($scalars | enumerate) {
        let alias = $"m_(($entry.index + 1) | into string | fill --alignment right --character '0' --width 4)"
        # `($entry.item.query)` is the catalog SELECT producing column `v`.
        # Wrap as derived-table; SQLite will reduce a single-row source.
        let frag = $"  \(SELECT v FROM \(($entry.item.query)\)\) AS ($alias)"
        $parts = ($parts | append $frag)
    }

    let body = ($parts | str join ",\n")
    let header = "-- ════════════════════════════════════════════════════════════════
-- GenQuery DB shape profile — scalar mega-query
-- Auto-generated from profile-catalog.nu (do not edit by hand).
-- One row, one column per scalar metric. Aliases are positional
-- (m_NNNN); profile.nu maps them back to metric names.
-- ════════════════════════════════════════════════════════════════
SELECT
"
    $header + $body + "\nFROM (SELECT 1)"
}

# ─── Profile execution ──────────────────────────────────────────────────────
#
# Runs all scalar metrics in one shot, then iterates the multi-row catalog
# entries. Returns a record with the raw outputs plus per-phase timing.
export def run-profile [db_path: string] {
    let scalars = (runnable-scalars)
    let multirows = (runnable-multirow)

    let started = (date now)

    # ── Phase 1: scalars (mega-query, single round-trip) ─────────────────
    let mega = (build-mega-query $scalars)
    let scalar_started = (date now)
    let scalar_row = (try {
        open $db_path | query db $mega | first
    } catch {
        # If the mega-query fails (e.g. a single bad subquery aborts the
        # entire SELECT), fall back to per-metric execution so a single bad
        # entry doesn't blank the entire profile. Slower path but resilient.
        run-scalars-individually $db_path $scalars
    })
    let scalar_ms = (((date now) - $scalar_started) / 1ms | into int)

    # Re-key m_NNNN → metric name.
    mut scalars_out = {}
    for entry in ($scalars | enumerate) {
        let alias = $"m_(($entry.index + 1) | into string | fill --alignment right --character '0' --width 4)"
        let value = ($scalar_row | get --optional $alias)
        $scalars_out = ($scalars_out | upsert $entry.item.name $value)
    }

    # ── Phase 2: multi-row metrics (one query each) ──────────────────────
    let multi_started = (date now)
    mut multi_out = {}
    for m in $multirows {
        let rows = (try { open $db_path | query db $m.query } catch { [] })
        $multi_out = ($multi_out | upsert $m.name $rows)
    }
    let multi_ms = (((date now) - $multi_started) / 1ms | into int)

    let total_ms = (((date now) - $started) / 1ms | into int)

    {
        scalars: $scalars_out
        multi_rows: $multi_out
        timing: {
            total_ms: $total_ms
            scalars_ms: $scalar_ms
            multirows_ms: $multi_ms
            scalar_count: ($scalars | length)
            multirow_count: ($multirows | length)
        }
    }
}

# Resilient fallback: run scalar metrics one-by-one and assemble a
# m_NNNN-keyed record. Used only when the consolidated mega-query fails;
# significantly slower because it opens the DB once per metric.
export def run-scalars-individually [db_path: string, scalars: list] {
    mut row = {}
    for entry in ($scalars | enumerate) {
        let alias = $"m_(($entry.index + 1) | into string | fill --alignment right --character '0' --width 4)"
        let value = (try {
            open $db_path | query db $entry.item.query | get 0.v
        } catch { null })
        $row = ($row | upsert $alias $value)
    }
    $row
}

# ─── Fingerprint & cache logic ──────────────────────────────────────────────
#
# A profile is "current" if (rm_unique_id, latest_utcmoddate) matches what
# we already captured. Both inputs are read directly from the catalog so the
# fingerprint stays consistent with what the full profile would produce.
export def compute-fingerprint [db_path: string] {
    let catalog = (metrics-catalog)
    let uid_q = ($catalog | where name == "rm_unique_id" | first | get query)
    let mod_q = ($catalog | where name == "latest_utcmoddate_julian" | first | get query)

    let rm_unique_id = (try { open $db_path | query db $uid_q | get 0.v } catch { "" })
    let latest_mod  = (try { open $db_path | query db $mod_q | get 0.v } catch { "" })

    {
        rm_unique_id: ($rm_unique_id | default "")
        latest_utcmoddate: ($latest_mod | default "")
    }
}

# Returns true when a fresh profile run is warranted. Skips when:
#   • a cache exists for this rm_unique_id, AND
#   • the cached latest_utcmoddate matches the current value, AND
#   • the captured_at timestamp is younger than 7 days.
export def should-profile [db_path: string] {
    let cache_path = (cache-file)
    if not ($cache_path | path exists) { return true }

    let cache = (try { open $cache_path } catch { return true })
    let fp = (compute-fingerprint $db_path)

    if ($fp.rm_unique_id | is-empty) { return true }

    let match = ($cache | get --optional $fp.rm_unique_id)
    if $match == null { return true }

    if (($match.latest_utcmoddate? | default "") != $fp.latest_utcmoddate) { return true }

    # 7-day TTL fallback. Stored as Unix nanoseconds for cheap arithmetic.
    let captured_nano = ($match.captured_at_unix_nano? | default 0)
    if $captured_nano == 0 { return true }
    let age_nano = ((date now) | into int) - $captured_nano
    let seven_days_nano = ((7 * 24 * 60 * 60) * 1_000_000_000)
    if $age_nano > $seven_days_nano { return true }

    false
}

# Atomically replace the cache file with an updated entry for `fingerprint`.
# Cache shape: { <rm_unique_id>: { latest_utcmoddate, captured_at_*, profile_path, db_path } }
export def update-cache [
    db_path: string
    fingerprint: record
    captured_at: datetime
    profile_path: string
] {
    let cache_path = (cache-file)
    let prev = (if ($cache_path | path exists) {
        try { open $cache_path } catch { {} }
    } else { {} })

    let entry = {
        latest_utcmoddate: $fingerprint.latest_utcmoddate
        captured_at_iso: ($captured_at | format date "%Y-%m-%dT%H:%M:%S%:z")
        captured_at_unix_nano: ($captured_at | into int)
        profile_path: $profile_path
        db_path: $db_path
    }
    let updated = ($prev | upsert $fingerprint.rm_unique_id $entry)
    $updated | to json | save --raw --force $cache_path
}

# ─── Profile record assembly + persistence ──────────────────────────────────
#
# The on-disk record mirrors the OTLP resource-attribute shape we use for
# traces (so the backend can index by service.name / service.version) but
# uses a custom envelope rather than reusing OTLP profiles — those are still
# in-flux upstream and we want full control over the schema for now.
export def build-profile-record [
    db_path: string
    profile: record
    fingerprint: record
] {
    let now = (date now)
    let now_iso = ($now | format date "%Y-%m-%dT%H:%M:%S%:z")
    let now_nano = ($now | into int | into string)

    {
        schemaVersion: "1"
        capturedAt: $now_iso
        capturedAtUnixNano: $now_nano
        resource: {
            attributes: [
                { key: "service.name",          value: { stringValue: "genq" } }
                { key: "service.version",       value: { stringValue: ($env.GENQ_CONFIG?.metadata?.version? | default "unknown") } }
                { key: "telemetry.sdk.language", value: { stringValue: "nushell" } }
                { key: "genq.db.name",          value: { stringValue: ($env.GENQ_CONFIG?.database?.active? | default "unknown") } }
                { key: "genq.db.filename",      value: { stringValue: ($db_path | path basename) } }
                { key: "genq.db.unique_id",     value: { stringValue: $fingerprint.rm_unique_id } }
            ]
        }
        fingerprint: $fingerprint
        timing: $profile.timing
        scalars: $profile.scalars
        multiRows: $profile.multi_rows
    }
}

# Gzip the record to disk. Uses the system `gzip` binary (always present on
# macOS / Linux; on Windows we'd need a fallback — TODO when we ship for it).
# Returns the absolute path of the written file.
export def persist-profile [record: record] {
    let dir = (profiles-dir)
    let ts = (date now | format date "%Y%m%dT%H%M%SZ")
    let raw_uid = ($record.fingerprint.rm_unique_id? | default "")
    let safe_uid = (if ($raw_uid | is-empty) { "unknown" } else { $raw_uid })
    let out = ($dir | path join $"($safe_uid)-($ts).json.gz")
    let json = ($record | to json --raw)
    let gz = ($json | ^gzip -9c)
    $gz | save --raw --force $out
    $out
}

# ─── Top-level entry — fire-and-forget ──────────────────────────────────────
#
# Designed for `job spawn { genq telemetry profile-init }`. The wrapping
# try/catch guarantees no error escapes into the parent shell.
export def profile-init [] {
    try {
        let db_path = ($env.rmdb? | default "")
        if ($db_path | is-empty) or (not ($db_path | path exists)) { return }

        if not (should-profile $db_path) { return }

        let fingerprint = (compute-fingerprint $db_path)
        let raw = (run-profile $db_path)
        let record = (build-profile-record $db_path $raw $fingerprint)
        let out_path = (persist-profile $record)
        update-cache $db_path $fingerprint (date now) $out_path
    } catch { }
}

# ─── Inspection helpers (user-facing diagnostics) ───────────────────────────
#
# Returns a list of locally-buffered profile files, newest first. Reads each
# manifest header (first ~256 bytes) to surface metadata without unzipping
# the entire payload.
export def list-profiles [] {
    let dir = (profiles-dir)
    let files = (glob ($dir | path join "*.json.gz"))
    if ($files | is-empty) { return [] }
    $files | each {|f|
        let stat = (ls $f | first)
        {
            path: $f
            file: ($f | path basename)
            size_bytes: $stat.size
            modified: $stat.modified
        }
    } | sort-by modified --reverse
}

# Read & decompress a profile by path. Returns the parsed record.
export def read-profile [path: string] {
    let raw = (^gzip -dc $path)
    $raw | from json
}
