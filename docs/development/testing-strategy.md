# GenQuery Testing Strategy

## Overview

GenQuery uses [nutest v1.1.0](https://github.com/vyadh/nutest) (vendored in `deps/nutest/`) as its test framework. Tests are auto-discovered from `tests/test_*.nu`.

The strategy has three pillars:
1. **Test labels** — classify every test so the runner can filter and schedule them
2. **Per-DB test isolation** — each database has its own label; run one DB at a time
3. **Read-only production commands** — eliminate write contention by using CTEs instead of views/temp tables

---

## Test Labels

Every test `def` name **must** begin with exactly one label word followed by a space:

> **Implementation note**: nutest generates the execute closure as `{ test_name }` (the literal command name in braces). Nushell resolves multi-word command names by longest-prefix match. A trailing `:` or leading `[` in the first word breaks this — they trigger record or list syntax. Use a plain word followed by a space.

### `fast`
- No database required
- Safe to run in parallel
- Examples: config structure, path utilities, input validation, syntax smoke tests
- Files: `test_config.nu`, `test_paths.nu`, `test_validation.nu`, `test_smoke.nu`
- `--match-tests` regex: `"^fast "`

### `db-pres2020`
- Tests against the pres2020 demo database (committed to repo — always available)
- Never writes to the database; uses per-test temp copies
- Run serially to avoid SQLite lock contention
- File: `test_db_pres2020.nu`
- `--match-tests` regex: `"^db-pres2020 "`

### `db-iiams`
- Tests against the Iiams personal genealogy database (11,692 people)
- Requires `GENQ_TEST_DB=/path/to/Iiams.rmtree`
- Tests skip gracefully (`if (no-db) { return }`) when DB is unavailable
- Includes `test_tabulate_trees.nu` (Iiams-specific tree algorithm tests)
- Run serially to avoid SQLite lock contention
- File: `test_db_iiams.nu`, `test_tabulate_trees.nu`
- `--match-tests` regex: `"^db-iiams "`

### `db-write` (reserved)
- Writes to a database during the test
- Reserved for future use (e.g., testing migration helpers)
- Avoid whenever possible — prefer temp-file patterns

### Adding a new database
1. Create `tests/test_db_<newdb>.nu`
2. Prefix all `@test` defs with `db-<newdb> `
3. Run with `nu tests/run-tests.nu --db <newdb>`
4. No changes to the runner needed

---

## Running Tests Locally

```bash
# All tests (no filter, default parallel):
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu

# Fast tests only (no DB, instant feedback):
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fast

# pres2020 DB tests only (always available):
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db pres2020

# Iiams DB tests only (requires GENQ_TEST_DB):
GENQ_TEST_DB=/Users/miams/Code/genq/data/Iiams.rmtree \
  nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db iiams

# All DB tests (both databases):
GENQ_TEST_DB=/Users/miams/Code/genq/data/Iiams.rmtree \
  nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --db all

# Full suite with CI artifacts (JUnit + timing):
GENQ_TEST_DB=/Users/miams/Code/genq/data/Iiams.rmtree \
  nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --ci

# Exit 1 on any failure:
nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fail
```

---

## CI Workflow (`.github/workflows/tests.yaml`)

Two jobs run in parallel:

### `fast` job
- Runs `--fast --fail` (labels: `fast` only)
- All platforms: ubuntu, macos, windows
- No secrets required — runs on every PR/push
- Provides quick pass/fail feedback

### `db` job
- Runs `--ci` (all tests, JUnit report)
- pres2020 DB always available (committed to repo)
- Iiams DB downloaded from S3 when `AWS_ACCESS_KEY_ID` + `GENQ_TEST_BUCKET` are configured
- Tests skip gracefully when Iiams DB is unavailable (safe for forks)
- JUnit results published via `EnricoMi/publish-unit-test-result-action`
- Test summary pushed to GitHub Gist on `main` branch (Linux only)
- Results ingested to Turso analytics DB (when `TURSO_DB_URL` + `TURSO_AUTH_TOKEN` set)

---

## SQLite Locking

### Root Cause

Nushell's `open $db | query db $sql` creates a new SQLite connection per call. When multiple nutest threads do this simultaneously, they can race for the write lock.

### Solution: Read-Only Production Commands

All production commands in `src/lib/` must be **read-only**. Use CTEs (`WITH ... AS (...)`) for intermediate query logic instead of views or temp tables:

```sql
-- Good: CTE — single read-only query
WITH census_all AS (
    SELECT * FROM census_prime
    UNION ALL
    SELECT * FROM census_attached
)
SELECT ... FROM census_all JOIN ...

-- Bad: views — acquires write lock on user's DB
CREATE VIEW tmp_census_minimal AS ...
```

### Safety Net: Serialized Test Execution

The `--db` flag uses `--strategy { threads: 1 }` — DB tests always run one at a time.

### Safety Net: Exponential Backoff (`query-db-safe`)

For cases where serialization isn't possible, `tests/helpers.nu` provides `query-db-safe`:

```nushell
# Retry with TCP-style backoff: 100 → 200 → 400 → 800 → 1600 → 3200 ms
let result = (query-db-safe $db "SELECT * FROM PersonTable")
```

This is **test-only** — never use it in production commands.

### WAL Mode Verification (`ensure-wal-mode`)

RootsMagic already enables WAL mode (`.rmtree-wal` / `.rmtree-shm` sidecar files). WAL allows concurrent readers without blocking. To verify:

```nushell
# Call once at the top of a DB test file (or @before-all)
ensure-wal-mode $db
```

---

## Timing DB Tests (`timed-test`)

`tests/helpers.nu` provides `timed-test` for measuring individual test wall-clock time and writing results to the analytics sidecar:

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

Output: `  timed db-iiams tabulate trees - returns records: 900ms`

The name passed to `timed-test` must exactly match the `def` name — this is how the analytics ingest script pairs timing data to test results in the JUnit XML.

Use `timed-test` on tests expected to be slow (large-table scans, tree computations) to catch performance regressions.

---

## Writing New Tests

1. Choose the correct label (`fast`, `db-pres2020`, `db-iiams`, or `db-<newdb>`)
2. Place the `@test` in the appropriate file
3. For Iiams tests, guard with `if (no-db) { return }`
4. For pres2020 tests, use the `@before-each`/`@after-each` temp-copy pattern
5. For slow DB tests, wrap the command call with `timed-test`
6. Verify the label appears first in the def name:
   ```nushell
   @test
   def "db-iiams my new feature - returns expected results" [] { ... }
   ```
