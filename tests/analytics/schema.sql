-- GenQuery Test Analytics Schema
-- Hosted on Turso (LibSQL / hosted SQLite)
-- Run setup-db.nu to create these tables once.

-- One row per test run (local dev or CI job)
CREATE TABLE IF NOT EXISTS test_runs (
    run_id       TEXT PRIMARY KEY,  -- "{git_sha8}_{epoch_ms}_{source_slug}"
    git_sha      TEXT NOT NULL,     -- full SHA
    git_branch   TEXT,
    nu_version   TEXT,
    genq_version TEXT,              -- HEAD commit short SHA used as version
    source       TEXT NOT NULL,     -- "local" | "ci-ubuntu-latest" | "ci-macos-latest" | "ci-windows-latest"
    label_filter TEXT,              -- "fast" | "db-read" | null (all tests)
    run_at       INTEGER NOT NULL,  -- unix epoch ms (start of run)
    duration_ms  INTEGER,           -- wall-clock ms for the full run
    total        INTEGER,
    passed       INTEGER,
    failed       INTEGER,
    skipped      INTEGER
);

-- One row per test in a run
CREATE TABLE IF NOT EXISTS test_results (
    run_id      TEXT NOT NULL REFERENCES test_runs(run_id),
    suite       TEXT NOT NULL,  -- file stem: "test_db_iiams", "test_db_pres2025", etc.
    test_name   TEXT NOT NULL,  -- full def name: "db-read list people iiams - returns records"
    label       TEXT,           -- "fast" | "db-read" | null (unlabeled)
    status      TEXT NOT NULL,  -- "pass" | "fail" | "skip"
    duration_ms INTEGER,        -- null unless explicitly measured with timed-test
    PRIMARY KEY (run_id, suite, test_name)
);

-- Useful views for common queries
CREATE VIEW IF NOT EXISTS recent_failures AS
SELECT
    r.run_at,
    r.source,
    r.git_sha,
    t.suite,
    t.test_name,
    t.status
FROM test_results t
JOIN test_runs r ON t.run_id = r.run_id
WHERE t.status = 'fail'
ORDER BY r.run_at DESC;

CREATE VIEW IF NOT EXISTS flaky_tests AS
SELECT
    t.suite,
    t.test_name,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN t.status = 'fail' THEN 1 ELSE 0 END) AS failures,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'fail' THEN 1 ELSE 0 END) / COUNT(*), 1) AS fail_pct
FROM test_results t
JOIN test_runs r ON t.run_id = r.run_id
GROUP BY t.suite, t.test_name
HAVING failures > 0
ORDER BY fail_pct DESC, failures DESC;

CREATE VIEW IF NOT EXISTS run_summary AS
SELECT
    run_id,
    source,
    git_sha,
    datetime(run_at / 1000, 'unixepoch') AS run_at_utc,
    label_filter,
    total,
    passed,
    failed,
    skipped,
    duration_ms
FROM test_runs
ORDER BY run_at DESC;
