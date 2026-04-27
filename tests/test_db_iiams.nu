# Integration tests against Iiams.rmtree (full personal genealogy database)
# Requires the GENQ_TEST_DB environment variable pointing to the database file.
# In CI this is set after the S3 download step; locally set it manually.
# Label: [db-read] — reads live DB, never writes
#
# All tests skip gracefully (return without assertion) when GENQ_TEST_DB is
# not set or the file does not exist — safe for forks and contributors.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *
use "../src/lib/ext/miams/mod.nu" *
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
# genq list people
# =============================================================================

@test
def "db-iiams list people iiams - returns records" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams list people iiams - returns records" {
        with-env (ie) { genq list people }
    })
    assert (($result | length) > 0)
}

@test
def "db-iiams list people iiams - substantially larger than pres2025" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    assert (($result | length) > 100)
}

@test
def "db-iiams list people iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list people } | columns)
    for col in [RIN Given Surname Sex BirthDate DeathDate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list people iiams - omits sort dates and year columns by default" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list people } | columns)
    for col in [BirthSortDate DeathSortDate BirthYear DeathYear] {
        assert not ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list people iiams - contains Iiams surname" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people })
    assert (($result | where Surname == "Iiams" | length) > 0)
}

# =============================================================================
# genq list events
# =============================================================================

@test
def "db-iiams list events iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    assert (($result | length) > 0)
}

@test
def "db-iiams list events iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list events } | columns)
    for col in [EventID RIN Given Surname Event Description EventDate SortDate LastUpdate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list events iiams - has multiple event types" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    let type_count = ($result | get Event | uniq | length)
    assert ($type_count > 3)
}

@test
def "db-iiams list events iiams - SortDate is YYYY-MM-DD or empty" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list events })
    let invalid = ($result | where { |r|
        let d = $r.SortDate
        not (($d | is-empty) or ($d =~ '^\d{4}-\d{2}-\d{2}$'))
    })
    assert equal ($invalid | length) 0
}

@test
def "db-iiams list events iiams - sort-date-by orders SortDate ascending" [] {
    if (no-db) { return }
    let sorted = (with-env (ie) { genq list events | sort-date-by EventDate | get SortDate | where $it != "" })
    assert equal $sorted ($sorted | sort)
}

# =============================================================================
# genq list families
# =============================================================================

@test
def "db-iiams list families iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list families })
    assert (($result | length) > 0)
}

@test
def "db-iiams list families iiams - HusbOrder and WifeOrder are non-negative" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list families })
    assert equal ($result | where HusbOrder < 0 | length) 0
    assert equal ($result | where WifeOrder < 0 | length) 0
}

# =============================================================================
# genq list sources
# =============================================================================

@test
def "db-iiams list sources iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    # Iiams database has freeform sources
    assert (($result | length) > 0)
}

@test
def "db-iiams list sources iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [SrcID TempID AbbrevSourceName Footnote ShortFootnote Bibliography] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list sources iiams - SrcID values are positive" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources })
    if ($result | length) == 0 { return }
    assert equal ($result | where SrcID <= 0 | length) 0
}

# =============================================================================
# genq list citations
# =============================================================================

@test
def "db-iiams list citations iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    assert (($result | length) > 0)
}

@test
def "db-iiams list citations iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [RIN Surname Givens Source] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list citations iiams - RIN values are positive" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list citations })
    if ($result | length) == 0 { return }
    assert equal ($result | where RIN <= 0 | length) 0
}

# =============================================================================
# genq list findagrave  (miams extension)
# =============================================================================

@test
def "db-iiams list findagrave iiams - runs without error" [] {
    if (no-db) { return }
    with-env (ie) { genq list findagrave } | ignore
}

@test
def "db-iiams list findagrave iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list findagrave })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [RIN Name URL] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list findagrave iiams - URLs contain findagrave.com" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list findagrave })
    if ($result | length) == 0 { return }
    let non_fg = ($result | where { |r| not ($r.URL | str contains "findagrave.com") })
    assert equal ($non_fg | length) 0
}

# =============================================================================
# genq list obits  (miams extension)
# =============================================================================

@test
def "db-iiams list obits iiams - runs without error" [] {
    if (no-db) { return }
    with-env (ie) { genq list obits } | ignore
}

@test
def "db-iiams list obits iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list obits })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [RIN NewObit] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq list newspaper obits summary  (miams extension)
# =============================================================================

@test
def "db-iiams list newspaper obits summary iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list newspaper obits summary })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [RIN Newspaper EventID] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq census year  (miams extension)
# =============================================================================

@test
def "db-iiams census year 1910 iiams - returns records" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams census year 1910 iiams - returns records" {
        with-env (ie) { genq census year "1910" }
    })
    assert (($result | length) > 0)
}

@test
def "db-iiams census year 1910 iiams - Census column is 1910" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    if ($result | length) == 0 { return }
    assert equal ($result | where Census != "1910" | length) 0
}

@test
def "db-iiams census year 1910 iiams - has expected columns" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [Census RIN Surname Given Place] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams census year 1910 iiams - contains Iiams family" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq census year "1910" })
    # The database is the Iiams family — should have Iiams in 1910 census
    assert (($result | where { |r| $r.Surname == "Iiams" or $r.Surname == "Iams" or $r.Surname == "Ijams" } | length) > 0)
}

# =============================================================================
# genq tabulate sources labels  (miams extension)
# =============================================================================

@test
def "db-iiams tabulate sources labels iiams - returns records" [] {
    if (no-db) { return }
    let result = (timed-test "db-iiams tabulate sources labels iiams - returns records" {
        with-env (ie) { genq tabulate sources labels }
    })
    assert (($result | length) > 0)
}

# =============================================================================
# genq list people --all-names  (Phase 1.1)
# =============================================================================

@test
def "db-iiams list people all-names iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people --all-names })
    assert (($result | length) > 0)
}

@test
def "db-iiams list people all-names iiams - has AlternateNames column" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list people --all-names } | columns)
    assert ($cols | any { |c| $c == "AlternateNames" })
}

@test
def "db-iiams list people all-names iiams - some records have alternate names" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list people --all-names })
    # Iiams DB has well-documented alternate spellings (Iams, Ijams, Iiames, etc.)
    assert (($result | where AlternateNames != "" | length) > 0)
}

# =============================================================================
# genq list names  (Phase 1.2)
# =============================================================================

@test
def "db-iiams list names iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list names })
    assert (($result | length) > 0)
}

@test
def "db-iiams list names iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list names } | columns)
    for col in [NameID RIN Surname Given NameType IsPrimary BirthYear DeathYear] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list names iiams - alternate flag returns only non-primary names" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list names --alternate })
    if ($result | length) == 0 { return }
    assert equal ($result | where IsPrimary != 0 | length) 0
}

@test
def "db-iiams list names iiams - NameType values are recognized labels" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list names })
    let valid = ["AKA", "Birth", "Immigrant", "Maiden", "Married", "Nickname", "Other", "Unknown"]
    let invalid = ($result | where { |r| not ($valid | any {|v| $v == $r.NameType}) })
    assert equal ($invalid | length) 0
}

# =============================================================================
# genq list places  (Phase 1.3)
# =============================================================================

@test
def "db-iiams list places iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list places })
    assert (($result | length) > 0)
}

@test
def "db-iiams list places iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list places } | columns)
    for col in [PlaceID Name Normalized PlaceType] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list places iiams - coordinates flag adds lat and lon" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list places --coordinates } | columns)
    assert ($cols | any { |c| $c == "Latitude" })
    assert ($cols | any { |c| $c == "Longitude" })
}

# =============================================================================
# genq list events --place-name  (Phase 1.4)
# =============================================================================

@test
def "db-iiams list events place-name iiams - has Place column" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list events --place-name } | columns)
    assert ($cols | any { |c| $c == "Place" })
}

# =============================================================================
# genq list children  (Phase 1.5)
# =============================================================================

@test
def "db-iiams list children iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list children })
    assert (($result | length) > 0)
}

@test
def "db-iiams list children iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list children } | columns)
    for col in [RIN Given Surname Sex MRIN FatherRIN MotherRIN RelToFather RelToMother] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list children iiams - RelToFather values are recognized" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list children })
    let valid = ["Birth", "Adopted", "Step", "Foster", "Guardian", "Sealed", "Unknown"]
    let invalid = ($result | where { |r| not ($valid | any {|v| $v == $r.RelToFather}) })
    assert equal ($invalid | length) 0
}

# =============================================================================
# genq list associations  (Phase 1.6)
# =============================================================================

@test
def "db-iiams list associations iiams - runs without error" [] {
    if (no-db) { return }
    with-env (ie) { genq list associations } | ignore
}

@test
def "db-iiams list associations iiams - has expected columns when records exist" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list associations })
    if ($result | length) == 0 { return }
    let cols = ($result | columns)
    for col in [FanID RIN1 Given1 Surname1 RIN2 Given2 Surname2 AssocType] {
        assert ($cols | any { |c| $c == $col })
    }
}

# =============================================================================
# genq list witnesses  (Phase 1.7)
# =============================================================================

@test
def "db-iiams list witnesses iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list witnesses })
    assert (($result | length) > 0)
}

@test
def "db-iiams list witnesses iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list witnesses } | columns)
    for col in [WitnessID EventID EventType EventOwnerRIN WitnessRIN Role] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list witnesses iiams - rin filter returns matching rows only" [] {
    if (no-db) { return }
    # RIN 1 is a real person in Iiams DB
    let result = (with-env (ie) { genq list witnesses --rin 1 })
    if ($result | length) == 0 { return }
    assert equal ($result | where WitnessRIN != 1 | length) 0
}

# =============================================================================
# genq list sources --all  (Phase 1.8)
# =============================================================================

@test
def "db-iiams list sources all iiams - returns records" [] {
    if (no-db) { return }
    let result = (with-env (ie) { genq list sources --all })
    assert (($result | length) > 0)
}

@test
def "db-iiams list sources all iiams - has expected columns" [] {
    if (no-db) { return }
    let cols = (with-env (ie) { genq list sources --all } | columns)
    for col in [SrcID TempID TemplateName AbbrevSourceName] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-iiams list sources all iiams - count >= freeform count" [] {
    if (no-db) { return }
    let all_count      = (with-env (ie) { genq list sources --all } | length)
    let freeform_count = (with-env (ie) { genq list sources } | length)
    assert ($all_count >= $freeform_count)
}
