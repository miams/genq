#!/usr/bin/env nu
# One-time Turso database setup script.
# Creates the test analytics schema.
#
# Prerequisites:
#   export TURSO_DB_URL=https://<db>-<org>.turso.io
#   export TURSO_AUTH_TOKEN=<token>
#
# Usage:
#   nu tests/analytics/setup-db.nu

const SCHEMA = path self | path dirname | path join "schema.sql"

def main [] {
    let url   = $env.TURSO_DB_URL?   | default ""
    let token = $env.TURSO_AUTH_TOKEN? | default ""

    if ($url | is-empty) or ($token | is-empty) {
        print $"(ansi red)Error:(ansi reset) TURSO_DB_URL and TURSO_AUTH_TOKEN must be set."
        print "  export TURSO_DB_URL=https://<db>-<org>.turso.io"
        print "  export TURSO_AUTH_TOKEN=<token from 'turso db tokens create <db>'>"
        exit 1
    }

    # Read schema and split into individual statements
    let stmts = (open $SCHEMA
        | lines
        | where { |l| not ($l | str trim | str starts-with "--") }
        | str join "\n"
        | split row ";"
        | each { str trim }
        | where { |s| not ($s | is-empty) }
    )

    print $"Applying ($stmts | length) schema statements to ($url)..."

    for stmt in $stmts {
        let response = (turso-execute $url $token $stmt)
        if $response.results?.0?.type? == "error" {
            print $"(ansi red)Error:(ansi reset) ($response.results.0.error.message)"
            exit 1
        }
    }

    print $"(ansi green)Schema applied successfully.(ansi reset)"
    print "\nTables created:"
    print "  test_runs   — one row per test run"
    print "  test_results — one row per test in a run"
    print "\nViews created:"
    print "  recent_failures — latest failing tests"
    print "  flaky_tests     — tests with any failures"
    print "  run_summary     — runs with totals"
}

def turso-execute [url: string, token: string, sql: string] {
    let payload = { requests: [
        { type: "execute", stmt: { sql: $sql } },
        { type: "close" }
    ]}
    (
        $payload | to json | http post
            --content-type "application/json"
            --headers { Authorization: $"Bearer ($token)" }
            $"($url)/v2/pipeline"
    )
}
