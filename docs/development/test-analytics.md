# GenQuery Test Analytics

Test results from every run (local dev and CI) are shipped to a hosted Turso (LibSQL) database for historical tracking, flaky test detection, and performance regression monitoring.

## Architecture

```
Run tests → test-report.xml (JUnit)
         → test-timing.json (wall-clock)
         → test-timing-sidecar.ndjson (per-test timings)
              ↓
         nu tests/ingest-results.nu
              ↓
         Turso (hosted SQLite) via Hrana v2 HTTP API
```

No Lambda, no extra infrastructure — Turso's free tier covers this workload indefinitely.

---

## Setup (One-Time)

### 1. Create the Turso database

```zsh
turso db create gengtestanalytics
turso db show gengtestanalytics   # get the HTTPS URL
turso db tokens create gengtestanalytics
```

### 2. Set environment variables

```zsh
export TURSO_DB_URL="https://gengtestanalytics-miams.aws-us-east-1.turso.io"
export TURSO_AUTH_TOKEN="<token from step 1>"
```

### 3. Apply the schema

```zsh
nu tests/analytics/setup-db.nu
```

Expected output:
```
Applying 5 schema statements to https://...
Schema applied successfully.
Tables created:
  test_runs   — one row per test run
  test_results — one row per test in a run
Views created:
  recent_failures — latest failing tests
  flaky_tests     — tests with any failures
  run_summary     — runs with totals
```

### 4. Add secrets to GitHub

In the repository Settings → Secrets and variables → Actions:
- `TURSO_DB_URL` — the HTTPS URL from step 1
- `TURSO_AUTH_TOKEN` — a read-write token from step 1

CI will then ingest results automatically after every `db` job run.

---

## Database Schema

Two tables:

### `test_runs`

One row per test run (local or CI):

| Column | Type | Description |
|--------|------|-------------|
| `run_id` | TEXT PK | `"{sha8}_{epoch_ms}_{source_slug}"` |
| `git_sha` | TEXT | Full commit SHA |
| `git_branch` | TEXT | Branch name |
| `nu_version` | TEXT | Nushell version |
| `genq_version` | TEXT | Short SHA (used as version) |
| `source` | TEXT | `"local"` \| `"ci-ubuntu-latest"` \| `"ci-macos-latest"` \| `"ci-windows-latest"` |
| `label_filter` | TEXT | `"fast"` \| `"db-pres2025"` \| `"db-iiams"` \| `"db-all"` \| `"all"` (CI) |
| `run_at` | INTEGER | Unix epoch ms (start of run) |
| `duration_ms` | INTEGER | Wall-clock ms for the full run |
| `total` / `passed` / `failed` / `skipped` | INTEGER | Counts |

### `test_results`

One row per test in a run:

| Column | Type | Description |
|--------|------|-------------|
| `run_id` | TEXT FK | References `test_runs.run_id` |
| `suite` | TEXT | File stem: `test_db_iiams`, `test_config`, etc. |
| `test_name` | TEXT | Full def name: `"db-iiams list people iiams - returns records"` |
| `label` | TEXT | `"fast"` \| `"db-pres2025"` \| `"db-iiams"` \| null |
| `status` | TEXT | `"pass"` \| `"fail"` \| `"skip"` |
| `duration_ms` | INTEGER | null unless wrapped with `timed-test` |

### Views

- `recent_failures` — latest failing tests across all runs
- `flaky_tests` — tests with any failure, ranked by fail rate
- `run_summary` — runs with totals, ordered by most recent

---

## Running the Ingest Locally

After running tests with `--ci` or `--db`:

```zsh
# After a full CI-style run:
GENQ_TEST_DB=/Users/miams/Code/genq/data/Iiams.rmtree \
  nu tests/run-tests.nu --ci

GENQ_SOURCE=local-macos nu tests/ingest-results.nu

# After a single-DB run:
nu tests/run-tests.nu --db pres2025
GENQ_SOURCE=local-macos nu tests/ingest-results.nu
```

The script skips gracefully if `TURSO_DB_URL` / `TURSO_AUTH_TOKEN` are not set.

---

## Turso CLI Quick Reference

```zsh
# Connect to the DB interactively
turso db shell gengtestanalytics

# Run a one-off query
turso db shell gengtestanalytics "SELECT * FROM run_summary LIMIT 10"

# Show DB info (URL, regions, size)
turso db show gengtestanalytics

# List all databases
turso db list

# Create a new read-only token (for CI)
turso db tokens create gengtestanalytics --expiration none

# Destroy and recreate if schema needs a full reset
turso db destroy gengtestanalytics
turso db create gengtestanalytics
nu tests/analytics/setup-db.nu
```

---

## Useful Queries

```sql
-- Most recent run per platform
SELECT source, git_branch, run_at_utc, passed, failed, total
FROM run_summary
GROUP BY source HAVING run_at = MAX(run_at);

-- Tests failing on any platform right now
SELECT t.test_name, r.source, t.status
FROM test_results t JOIN test_runs r ON t.run_id = r.run_id
WHERE t.status = 'fail' AND r.source LIKE 'ci-%'
ORDER BY r.run_at DESC LIMIT 50;

-- Performance trend for tabulate trees
SELECT datetime(r.run_at/1000,'unixepoch') AS run_at, r.source, t.duration_ms
FROM test_results t JOIN test_runs r ON t.run_id = r.run_id
WHERE t.test_name = 'db-iiams tabulate trees - returns records'
  AND t.duration_ms IS NOT NULL
ORDER BY r.run_at DESC LIMIT 30;

-- All tests by label
SELECT label, COUNT(*) as count, SUM(CASE WHEN status='fail' THEN 1 ELSE 0 END) as failures
FROM test_results
GROUP BY label;
```

---

## Per-Test Timing

Per-test wall-clock timing is captured for selected slow tests using the `timed-test` helper:

```nushell
use "./helpers.nu" *

@test
def "db-iiams tabulate trees - returns records" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams tabulate trees - returns records" {
        with-env (ie) { genq tabulate trees }
    })
    assert (($result | length) > 0)
}
```

`timed-test` measures elapsed time, prints `  timed <name>: 900ms`, and appends an entry to `test-timing-sidecar.ndjson` (set automatically by `run-tests.nu --ci` and `--db`). The ingest script reads this sidecar and populates `duration_ms` in `test_results`.

### Tests Currently Timed

| Test | Why |
|------|-----|
| `db-iiams list people iiams - returns records` | 11k-person table scan |
| `db-iiams census year 1910 iiams - returns records` | CTE join across multiple tables |
| `db-iiams tabulate sources labels iiams - returns records` | Aggregation across sources |
| `db-iiams tabulate trees - returns records` | Union-find label propagation (~900ms) |
| `db-iiams tabulate trees --rin 1 - returns 10570 rows` | BFS/degree walk over full tree |
| `db-pres2025 list people pres2025 - returns records` | Baseline pres2025 DB timing |

To add timing to a new slow test, wrap the command call with `timed-test "exact test def name" { ... }`.
