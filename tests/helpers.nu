# GenQuery test helpers — shared utilities for nutest test files
# Not a test file — no @test annotations, so nutest will ignore it

# Return common test configuration scenarios as a record
export def get-test-scenarios [] {
    {
        demo_basic: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2020.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["pres2020"]
            }
            paths: {
                sql_dir: "sql"
                lib_dir: "src/lib"
                ext_dir: "src/lib/ext"
                output_dir: "vault"
            }
            display: {
                date_format: 1
                table_mode: "rounded"
            }
        }

        production_basic: {
            database: {
                active: "production"
                connections: {
                    demo: "./data/pres2020.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["miams", "pres2020"]
            }
            paths: {
                sql_dir: "sql"
                lib_dir: "src/lib"
                ext_dir: "src/lib/ext"
                output_dir: "vault"
            }
            display: {
                date_format: 1
                table_mode: "rounded"
            }
        }

        minimal: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2020.rmtree"
                }
            }
            extensions: {
                enabled: []
            }
        }
    }
}

# Create a temp directory with an isolated GenQuery config for testing.
# Returns the path to the temp config file.
# Caller is responsible for cleanup: rm -rf $temp_dir
export def create-test-config [scenario: record] {
    let temp_dir = (mktemp -d -t "genq-test-XXXXXX")
    let config_dir = ($temp_dir | path join "config")
    mkdir $config_dir
    let config_path = ($config_dir | path join "default.toml")
    $scenario | to toml | save $config_path
    { temp_dir: $temp_dir, config_path: $config_path }
}

# =============================================================================
# DB test-only utilities — not used in production code
# =============================================================================

# Verify that a database file is in WAL journal mode.
# Prints a warning if not; WAL mode prevents readers from blocking each other.
# Call once at the top of a @before-all or first test in a DB test file.
export def ensure-wal-mode [db: string] {
    let mode = (open $db | query db "PRAGMA journal_mode" | get journal_mode.0)
    if $mode != "wal" {
        print $"(ansi yellow)Warning:(ansi reset) ($db) journal_mode = ($mode) — expected wal. Concurrent DB tests may block."
    }
}

# Execute a SQL query against a database with exponential backoff on lock errors.
# Retries up to 6 times: 100 → 200 → 400 → 800 → 1600 → 3200 ms (TCP-style).
# Raises the last error if all retries are exhausted.
# For use in tests only — not for production commands.
export def query-db-safe [db: string, sql: string] {
    let delays_ms = [100, 200, 400, 800, 1600, 3200]
    mut last_err = null
    mut result = null
    mut succeeded = false

    for delay in $delays_ms {
        let outcome = try {
            { ok: (open $db | query db $sql), err: null }
        } catch { |e|
            { ok: null, err: $e }
        }

        if $outcome.err == null {
            $result = $outcome.ok
            $succeeded = true
            break
        }

        let msg = ($outcome.err | into string)
        if not ($msg | str contains "database is locked") {
            error make { msg: $msg }
        }

        $last_err = $outcome.err
        sleep ($delay | into duration --unit ms)
    }

    if not $succeeded {
        error make { msg: $"query-db-safe: database locked after all retries — ($last_err)" }
    }

    $result
}

# Time a DB test body closure and print elapsed time in human-readable format.
# Usage: timed-db-run { genq list people }
# Prints: "  elapsed: 245ms" or "  elapsed: 2.4s"
export def timed-db-run [body: closure] {
    let t0 = (date now | into int)
    let result = (do $body)
    let t1 = (date now | into int)
    # date now returns nanoseconds as int
    let elapsed_ns = ($t1 - $t0)
    let elapsed_ms = ($elapsed_ns / 1_000_000)

    let label = if $elapsed_ms < 1000 {
        $"($elapsed_ms)ms"
    } else {
        let secs = ($elapsed_ms / 1000.0 | math round --precision 1)
        $"($secs)s"
    }
    print $"  elapsed: ($label)"
    $result
}

# =============================================================================
# Per-test timing analytics — writes to GENQ_TIMING_FILE sidecar if set
# =============================================================================

# Append a NDJSON timing entry to $env.GENQ_TIMING_FILE (if set).
# Each line is a self-contained JSON object for easy streaming ingest.
export def timing-write [entry: record] {
    let file = ($env.GENQ_TIMING_FILE? | default "")
    if not ($file | is-empty) {
        $entry | to json --raw | $"($in)\n" | save --append $file
    }
}

# Run a named test body, measure wall-clock time, print it, and write to sidecar.
# Usage: timed-test "db-read list people iiams - returns records" { ... }
# Writes: { type: "test_timing", test: <name>, duration_ms: <int> }
export def timed-test [name: string, body: closure] {
    let t0 = (date now | into int)
    let result = (do $body)
    let t1 = (date now | into int)
    let elapsed_ms = (($t1 - $t0) / 1_000_000 | into int)

    let label = if $elapsed_ms < 1000 {
        $"($elapsed_ms)ms"
    } else {
        let secs = ($elapsed_ms / 1000.0 | math round --precision 1)
        $"($secs)s"
    }
    print $"  timed ($name): ($label)"

    timing-write { type: "test_timing", test: $name, duration_ms: $elapsed_ms }
    $result
}
