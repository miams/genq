# Integration tests for genq tabulate trees
# Requires the GENQ_TEST_DB environment variable pointing to the Iiams database file.
# Tests skip gracefully when GENQ_TEST_DB is not set or the file does not exist.
# Label: [db-read] — reads live DB (via private temp SQLite file), never writes to user's DB

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *
use "./helpers.nu" *

const PROJ = path self | path dirname | path join ".."

# Return the Iiams DB path, or empty string if unavailable
def iiams-db [] {
    $env.GENQ_TEST_DB? | default ""
}

# Return true when this test should be skipped
def no-db [] {
    let db = (iiams-db)
    ($db | is-empty) or (not ($db | path exists))
}

# Build with-env record for Iiams tests
def ie [] {
    {
        rmdb:     (iiams-db)
        genq_sql: ($PROJ | path join "sql" | path expand)
        RDMF:     1
    }
}

# =============================================================================
# genq tabulate trees (summary mode)
# =============================================================================

@test
def "db-iiams tabulate trees - returns records" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams tabulate trees - returns records" {
        with-env (ie) { genq tabulate trees }
    })
    assert (($result | length) > 0)
}

@test
def "db-iiams tabulate trees - has correct columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq tabulate trees } | columns)
    for col in [index RIN Given Surname Count] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams tabulate trees - returns exactly 68 trees" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees })
    assert equal ($result | length) 68
}

@test
def "db-iiams tabulate trees - sorted by Count descending" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees })
    let counts = ($result | get Count)
    let sorted = ($counts | sort --reverse)
    assert equal $counts $sorted
}

@test
def "db-iiams tabulate trees - main tree is RIN 1 with 10570 members" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees })
    let top = ($result | first)
    assert equal $top.RIN 1
    assert equal $top.Count 10570
    assert equal $top.Given "Michael Dorsey"
    assert equal $top.Surname "Iams"
}

@test
def "db-iiams tabulate trees - tree 5 is RIN 14 Crawford with 54 members" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees })
    let tree5 = ($result | where RIN == 14 | first)
    assert equal $tree5.Count 54
    assert equal $tree5.Surname "Crawford"
}

@test
def "db-iiams tabulate trees - all counts are positive integers" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees })
    let invalid = ($result | where Count <= 0)
    assert equal ($invalid | length) 0
}

# =============================================================================
# genq tabulate trees --rin (member list mode)
# =============================================================================

@test
def "db-iiams tabulate trees --rin 1 - returns 10570 rows" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams tabulate trees --rin 1 - returns 10570 rows" {
        with-env (ie) { genq tabulate trees --rin 1 }
    })
    assert equal ($result | length) 10570
}

@test
def "db-iiams tabulate trees --rin 2471 - returns 54 rows" [] {
    if (no-db) { return }
    # RIN 2471 (Eli Iams) is in Catherine Crawford's tree (RIN 14, 54 members)
    let result = (with-env (ie) { genq tabulate trees --rin 2471 })
    assert equal ($result | length) 54
}

@test
def "db-iiams tabulate trees --rin - has correct columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq tabulate trees --rin 1 } | columns)
    for col in [index RIN Given Surname Sex BirthYear DeathYear Ga Gb Degree] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams tabulate trees --rin - anchor has Ga=0 Gb=0 Degree=0" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees --rin 1 })
    let anchor = ($result | where RIN == 1 | first)
    assert equal $anchor.Ga 0
    assert equal $anchor.Gb 0
    assert equal $anchor.Degree 0
}

@test
def "db-iiams tabulate trees --rin - blood relatives have positive Degree" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees --rin 1 })
    # Exclude self (Degree=0); all other blood relatives must have Degree > 0
    let blood_non_self = ($result | where { |r| (not ($r.Ga | is-empty)) and $r.Degree > 0 })
    let invalid = ($blood_non_self | where { |r| $r.Degree <= 0 })
    assert equal ($invalid | length) 0
}

@test
def "db-iiams tabulate trees --rin - spouses have null Ga Gb and null Degree" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees --rin 1 })
    let spouses = ($result | where ($it.Ga | is-empty))
    assert (($spouses | length) > 0)
    let non_null = ($spouses | where (not ($it.Degree | is-empty)))
    assert equal ($non_null | length) 0
}

@test
def "db-iiams tabulate trees --rin - Degree equals Ga plus Gb for blood relatives" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees --rin 1 })
    let blood = ($result | where (not ($it.Ga | is-empty)))
    let invalid = ($blood | where { |r| $r.Degree != ($r.Ga + $r.Gb) })
    assert equal ($invalid | length) 0
}

@test
def "db-iiams tabulate trees --rin - Ga and Gb are non-negative for blood relatives" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate trees --rin 1 })
    let blood = ($result | where (not ($it.Ga | is-empty)))
    let invalid = ($blood | where { |r| $r.Ga < 0 or $r.Gb < 0 })
    assert equal ($invalid | length) 0
}
