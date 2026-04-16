#!/usr/bin/env nu
# GenQuery Test Analytics Ingest Script
# Reads test artifacts from the last run and ships results to Turso.
#
# Reads (from working directory):
#   test-report.xml     — JUnit report (test names + pass/fail per test)
#   test-timing.json    — run wall-clock timing { run_at, duration_ms, label_filter }
#                         (written by run-tests.nu --db-serial or --fast)
#
# Required env vars:
#   TURSO_DB_URL        — https://<db>-<org>.turso.io
#   TURSO_AUTH_TOKEN    — API token from 'turso db tokens create <db>'
#
# Optional env vars:
#   GENQ_SOURCE         — "local" | "ci-ubuntu-latest" | etc.  (default: "local")
#
# Usage:
#   nu tests/ingest-results.nu
#   GENQ_SOURCE=ci-ubuntu-latest nu tests/ingest-results.nu

def main [] {
    let url   = ($env.TURSO_DB_URL?    | default "" | str replace --regex '^libsql://' 'https://')
    let token = $env.TURSO_AUTH_TOKEN? | default ""

    if ($url | is-empty) or ($token | is-empty) {
        print $"(ansi yellow)Notice:(ansi reset) TURSO_DB_URL / TURSO_AUTH_TOKEN not set — skipping analytics ingest."
        return
    }

    # --- Collect artifacts ---

    if not ("test-report.xml" | path exists) {
        print $"(ansi yellow)Notice:(ansi reset) test-report.xml not found — skipping ingest."
        print "  Run: nu tests/run-tests.nu --ci"
        return
    }

    # --- Git + environment metadata ---

    let git_sha    = (^git rev-parse HEAD | str trim)
    let git_sha8   = ($git_sha | str substring 0..8)
    let git_branch = (^git rev-parse --abbrev-ref HEAD | str trim | default "detached")
    let nu_ver     = (version | get version)
    let source     = ($env.GENQ_SOURCE? | default "local")

    # --- Timing metadata (written by run-tests.nu) ---

    let timing = if ("test-timing.json" | path exists) {
        open "test-timing.json"
    } else {
        { run_at: ((date now | into int) / 1_000_000), duration_ms: null, label_filter: null }
    }

    # --- Build run_id ---
    let run_id = $"($git_sha8)_($timing.run_at)_($source | str replace -a ' ' '-')"

    print $"Ingesting run ($run_id)..."
    print $"  source:      ($source)"
    print $"  git SHA:     ($git_sha8)"
    print $"  branch:      ($git_branch)"
    print $"  nu version:  ($nu_ver)"

    # --- Parse per-test timing sidecar (written by timed-test helper) ---

    let sidecar_timings = if ("test-timing-sidecar.ndjson" | path exists) {
        open "test-timing-sidecar.ndjson"
            | lines
            | where { |l| not ($l | str trim | is-empty) }
            | each { |l| $l | from json }
            | where type == "test_timing"
            | reduce --fold {} { |entry, acc|
                $acc | insert $entry.test $entry.duration_ms
            }
    } else {
        {}
    }

    # --- Parse JUnit XML ---
    let xml = (open "test-report.xml")
    # testsuites → list of testsuite → list of testcase

    let test_results = ($xml.content | each { |suite|
        let suite_name = $suite.attributes.name
        $suite.content | each { |tc|
            let has_failure = ($tc.content | any { |c| $c.tag == "failure" })
            let has_skipped = ($tc.content | any { |c| $c.tag == "skipped" })
            let status = if $has_failure { "fail" } else if $has_skipped { "skip" } else { "pass" }
            let name = $tc.attributes.name
            # Extract label from first word of test name
            let label = ($name | str replace -r " .*" "")
            let label_clean = if ($label | str ends-with ":") {
                null  # old colon format — ignore
            } else if ($label == "fast" or $label == "db-pres2025" or $label == "db-iiams" or $label == "db-write") {
                $label
            } else {
                null
            }
            let duration = ($sidecar_timings | get --optional $name)
            {
                suite:       $suite_name
                name:        $name
                label:       $label_clean
                status:      $status
                duration_ms: $duration
            }
        }
    } | flatten)

    let total   = ($test_results | length)
    let passed  = ($test_results | where status == "pass" | length)
    let failed  = ($test_results | where status == "fail" | length)
    let skipped = ($test_results | where status == "skip" | length)

    print $"  tests:       ($total) total / ($passed) passed / ($failed) failed / ($skipped) skipped"
    if ($timing.duration_ms != null) {
        let d = $timing.duration_ms
        let display = if $d < 1000 { $"($d)ms" } else { $"($d / 1000.0 | math round --precision 1)s" }
        print $"  duration:    ($display)"
    }

    # --- Build Turso pipeline requests ---

    # INSERT test_runs
    let run_req = {
        type: "execute"
        stmt: {
            sql: "INSERT OR REPLACE INTO test_runs (run_id, git_sha, git_branch, nu_version, genq_version, source, label_filter, run_at, duration_ms, total, passed, failed, skipped) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            args: [
                (ta-text $run_id)
                (ta-text $git_sha)
                (ta-text $git_branch)
                (ta-text $nu_ver)
                (ta-text $git_sha8)
                (ta-text $source)
                (ta-nullable-text $timing.label_filter)
                (ta-int ($timing.run_at | into int))
                (ta-nullable-int $timing.duration_ms)
                (ta-int $total)
                (ta-int $passed)
                (ta-int $failed)
                (ta-int $skipped)
            ]
        }
    }

    # INSERT test_results (one request per test)
    let result_reqs = ($test_results | each { |t|
        {
            type: "execute"
            stmt: {
                sql: "INSERT OR REPLACE INTO test_results (run_id, suite, test_name, label, status, duration_ms) VALUES (?, ?, ?, ?, ?, ?)"
                args: [
                    (ta-text $run_id)
                    (ta-text $t.suite)
                    (ta-text $t.name)
                    (ta-nullable-text $t.label)
                    (ta-text $t.status)
                    (ta-nullable-int $t.duration_ms)
                ]
            }
        }
    })

    let pipeline = {
        requests: ([$run_req] | append $result_reqs | append [{ type: "close" }])
    }

    # --- POST to Turso ---
    let response = ($pipeline | to json | http post
        --content-type "application/json"
        --headers { Authorization: $"Bearer ($token)" }
        $"($url)/v2/pipeline")

    # Check for errors in the response
    let errors = ($response.results? | default [] | where { |r| $r.type? == "error" })
    if ($errors | length) > 0 {
        print $"(ansi red)Turso error:(ansi reset)"
        for e in $errors {
            print $"  ($e.error?.message? | default 'unknown error')"
        }
        exit 1
    }

    print $"(ansi green)✓ Ingested ($total) test results to Turso.(ansi reset)"
}

# --- Turso Hrana argument helpers ---

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
