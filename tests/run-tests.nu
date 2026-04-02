#!/usr/bin/env nu
# GenQuery Test Runner — uses nutest framework
#
# Usage (from project root):
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fail
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fast
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db pres2020
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db iiams
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db all
#   nu tests/run-tests.nu --ci
#
# Test label conventions:
#   fast <name>        — no DB required; run in parallel
#   db-pres2020 <name> — pres2020 DB tests only; run serially
#   db-iiams <name>    — Iiams DB tests only; run serially
#
# Artifacts written to working directory:
#   test-report.xml              — JUnit report (--ci and --db modes)
#   test-summary.json            — summary counts (--ci mode)
#   test-timing.json             — wall-clock timing for analytics ingest
#   test-timing-sidecar.ndjson  — per-test timing NDJSON (--ci and --db modes)

use ../deps/nutest/mod.nu *

const TESTS_DIR = path self | path dirname

def main [
    --fail       # Exit with code 1 if any tests fail
    --ci         # CI mode: JUnit report + test-summary.json + --fail
    --fast       # Run only [fast] tests (no database required)
    --db: string # Run DB tests: pres2020 | iiams | all
] {
    if $ci {
        let sidecar = "test-timing-sidecar.ndjson"
        if ($sidecar | path exists) { rm $sidecar }
        if ("test-report.xml" | path exists) { rm "test-report.xml" }
        let t0 = (epoch-ms)
        let summary = (with-env { GENQ_TIMING_FILE: ($sidecar | path expand) } {
            (
                run-tests --path $TESTS_DIR
                    --display terminal
                    --report { type: "junit", path: "test-report.xml" }
                    --returns summary
            )
        })
        # Write timing before checking failures so it always runs
        write-timing $t0 "all"
        $summary | to json | save --force test-summary.json
        if ($summary.failed > 0) { exit 1 }

    } else if $fast {
        let t0 = (epoch-ms)
        run-tests --path $TESTS_DIR --match-tests "^fast " --strategy { threads: 0 }
        write-timing $t0 "fast"

    } else if ($db | is-not-empty) {
        let pattern = if $db == "pres2020" {
            "^db-pres2020 "
        } else if $db == "iiams" {
            "^db-iiams "
        } else if $db == "all" {
            "^db-"
        } else {
            error make { msg: $"Unknown --db value: ($db). Use pres2020, iiams, or all." }
        }
        let sidecar = "test-timing-sidecar.ndjson"
        if ($sidecar | path exists) { rm $sidecar }
        if ("test-report.xml" | path exists) { rm "test-report.xml" }
        let t0 = (epoch-ms)
        with-env { GENQ_TIMING_FILE: ($sidecar | path expand) } {
            (
                run-tests --path $TESTS_DIR
                    --match-tests $pattern
                    --strategy { threads: 1 }
                    --report { type: "junit", path: "test-report.xml" }
            )
        }
        write-timing $t0 $"db-($db)"

    } else if $fail {
        run-tests --path $TESTS_DIR --fail
    } else {
        run-tests --path $TESTS_DIR
    }
}

# Return current time as unix epoch milliseconds
def epoch-ms [] {
    (date now | into int) / 1_000_000 | into int
}

# Write test-timing.json for analytics ingest
def write-timing [started_at: int, label_filter: string] {
    let ended_at = (epoch-ms)
    {
        run_at:       $started_at
        duration_ms:  ($ended_at - $started_at)
        label_filter: $label_filter
    } | to json | save --force test-timing.json
}
