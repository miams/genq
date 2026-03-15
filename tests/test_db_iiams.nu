# Integration tests against Iiams.rmtree (full personal genealogy database)
# Requires the GENQ_TEST_DB environment variable pointing to the database file.
# In CI this is set after the S3 download step; locally set it manually.
#
# All tests skip gracefully (return without assertion) when GENQ_TEST_DB is
# not set or the file does not exist — safe for forks and contributors.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *
use "../src/lib/ext/miams/mod.nu" *

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
# genq list people
# =============================================================================

@test
def "list people iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    assert (($result | length) > 0)
}

@test
def "list people iiams - substantially larger than pres2020" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    assert (($result | length) > 100)
}

@test
def "list people iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list people } | columns)
    for col in [index RIN Given Surname Sex BirthYear DeathYear] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list people iiams - contains Iiams surname" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    assert (($result | where Surname == "Iiams" | length) > 0)
}

@test
def "list people iiams - BirthYear is historical or zero" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    # 0 = unknown; known years must be in a plausible historical range
    let invalid = ($result | where { |r|
        $r.BirthYear != 0 and ($r.BirthYear < 1600 or $r.BirthYear > 2030)
    })
    assert equal ($invalid | length) 0
}

# =============================================================================
# genq list events
# =============================================================================

@test
def "list events iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    assert (($result | length) > 0)
}

@test
def "list events iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list events } | columns)
    for col in [index EventID RIN Given Surname Event Description EventDate LastUpdate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list events iiams - has multiple event types" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    let type_count = ($result | get Event | uniq | length)
    assert ($type_count > 3)
}

@test
def "list events iiams - EventDate is 4-digit year or empty" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    let invalid = ($result | where { |r|
        let d = $r.EventDate
        not (($d | is-empty) or (($d | str length) == 4))
    })
    assert equal ($invalid | length) 0
}

# =============================================================================
# genq list families
# =============================================================================

@test
def "list families iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list families })
    assert (($result | length) > 0)
}

@test
def "list families iiams - HusbOrder and WifeOrder are non-negative" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list families })
    assert equal ($result | where HusbOrder < 0 | length) 0
    assert equal ($result | where WifeOrder < 0 | length) 0
}

# =============================================================================
# genq list sources
# =============================================================================

@test
def "list sources iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    # Iiams database has freeform sources
    assert (($result | length) > 0)
}

@test
def "list sources iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index SrcID TempID AbbrevSourceName Footnote ShortFootnote Bibliography] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list sources iiams - SrcID values are positive" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    if ($result | length) == 0 { return }
    assert equal ($result | where SrcID <= 0 | length) 0
}

# =============================================================================
# genq list citations
# =============================================================================

@test
def "list citations iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    assert (($result | length) > 0)
}

@test
def "list citations iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index RIN Surname Given Source] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list citations iiams - RIN values are positive" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    if ($result | length) == 0 { return }
    assert equal ($result | where RIN <= 0 | length) 0
}

# =============================================================================
# genq list findagrave  (miams extension)
# =============================================================================

@test
def "list findagrave iiams - runs without error" [] {
    if (no-db) { return }
    with-env (ie) { genq list findagrave } | ignore
}

@test
def "list findagrave iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list findagrave })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index RIN Name URL] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list findagrave iiams - URLs contain findagrave.com" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list findagrave })
    if ($result | length) == 0 { return }
    let non_fg = ($result | where { |r| not ($r.URL | str contains "findagrave.com") })
    assert equal ($non_fg | length) 0
}

# =============================================================================
# genq list findagrave website  (miams extension)
# =============================================================================

@test
def "list findagrave website iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list findagrave website })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index RIN URL Given Surname BirthYear DeathYear] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq list obits  (miams extension)
# =============================================================================

@test
def "list obits iiams - runs without error" [] {
    if (no-db) { return }
    with-env (ie) { genq list obits } | ignore
}

@test
def "list obits iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list obits })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index RIN NewObit] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq list newspaper obits summary  (miams extension)
# =============================================================================

@test
def "list newspaper obits summary iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list newspaper obits summary })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [index RIN Newspaper EventID] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq census year  (miams extension)
# =============================================================================

@test
def "census year 1910 iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    assert (($result | length) > 0)
}

@test
def "census year 1910 iiams - Census column is 1910" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    if ($result | length) == 0 { return }
    assert equal ($result | where Census != "1910" | length) 0
}

@test
def "census year 1910 iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [Census RIN Surname Given Place] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "census year 1910 iiams - contains Iiams family" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    # The database is the Iiams family — should have Iiams in 1910 census
    assert (($result | where { |r| $r.Surname == "Iiams" or $r.Surname == "Iams" or $r.Surname == "Ijams" } | length) > 0)
}

# =============================================================================
# genq tabulate sources labels  (miams extension)
# =============================================================================

@test
def "tabulate sources labels iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq tabulate sources labels })
    assert (($result | length) > 0)
}
