# Integration tests against pres2025.rmtree (US Presidents demo database)
# Always runs in CI — this database is committed to the repo.
# Label: [db-read] — reads live DB, never writes
#
# Uses a per-test temp copy to avoid writing into the committed .rmtree file.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *
use "../src/lib/ext/pres2025/mod.nu" *
use "./helpers.nu" *

const PROJ = path self | path dirname | path join ".."

@before-each
def setup [] {
    let src = ($PROJ | path join "data" "pres2025.rmtree" | path expand)
    let tmp = (mktemp -t "genq-pres-XXXXXX")
    cp $src $tmp
    {
        db:  $tmp
        sql: ($PROJ | path join "sql" | path expand)
    }
}

@after-each
def teardown [] {
    let ctx = $in
    rm -f $ctx.db
    rm -f $"($ctx.db)-wal"
    rm -f $"($ctx.db)-shm"
}

# Build the with-env record for a test context
def e [ctx: record] {
    { rmdb: $ctx.db, genq_sql: $ctx.sql, RDMF: 1 }
}

# =============================================================================
# genq list people
# =============================================================================

@test
def "db-pres2025 list people pres2025 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list people } | columns)
    for col in [RIN Given Surname Sex BirthDate DeathDate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-pres2025 list people pres2025 - omits sort dates and year columns by default" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list people } | columns)
    for col in [BirthSortDate DeathSortDate BirthYear DeathYear] {
        assert not ($cols | any { |c| $c == $col })
    }
}

@test
def "db-pres2025 list people pres2025 - formats birth and death dates" [] {
    let ctx = $in
    let washington = (with-env (e $ctx) { genq list people | where RIN == 394 | first })

    assert equal $washington.BirthDate "11 Feb 1732"
    assert equal $washington.DeathDate "14 Dec 1799"
}

@test
def "db-pres2025 list people pres2025 - returns records" [] {
    let ctx = $in
    let result = (timed-test "db-pres2025 list people pres2025 - returns records" {
        with-env (e $ctx) { genq list people }
    })
    assert (($result | length) > 0)
}

@test
def "db-pres2025 list people pres2025 - contains Washington" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert (($result | where Surname == "Washington" | length) > 0)
}

@test
def "db-pres2025 list people pres2025 - Sex values are M or F only" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    let invalid = ($result | where { |r| $r.Sex != "M" and $r.Sex != "F" })
    assert equal ($invalid | length) 0
}

@test
def "db-pres2025 list people pres2025 - RIN values are positive" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert equal ($result | where RIN <= 0 | length) 0
}

@test
def "db-pres2025 list people pres2025 - --with adds nested fact column" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people --with [occupation] })
    let cols = ($result | columns)
    assert ($cols | any { |c| $c == "Occupation" })
    let with_jobs = ($result | where ($it.Occupation | length) > 0)
    assert (($with_jobs | length) > 0)
}

@test
def "db-pres2025 list people pres2025 - --with nested cells are list<record> with expected fields" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people --with [occupation] | where ($it.Occupation | length) > 0 | first })
    let first_fact = ($result.Occupation | first)
    for f in [Date Description Place SortDate] {
        assert (($first_fact | columns) | any { |c| $c == $f })
    }
}

@test
def "db-pres2025 list people pres2025 - --with drops people with no matching facts" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people --with [occupation] })
    let empty_rows = ($result | where ($it.Occupation | length) == 0)
    assert equal ($empty_rows | length) 0
}

@test
def "db-pres2025 list people pres2025 - --with multiple types keeps rows with at least one match" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people --with [occupation residence] })
    # Every row must have at least one non-empty fact column.
    let bad = ($result | where { |r| ($r.Occupation | length) == 0 and ($r.Residence | length) == 0 })
    assert equal ($bad | length) 0
    # And we expect rows where only one of the two is populated (the union, not intersection).
    let only_one = ($result | where { |r| (($r.Occupation | length) == 0 and ($r.Residence | length) > 0) or (($r.Occupation | length) > 0 and ($r.Residence | length) == 0) })
    assert (($only_one | length) > 0)
}

@test
def "db-pres2025 list people pres2025 - --with multiple types adds a column per type" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list people --with [occupation residence] } | columns)
    assert ($cols | any { |c| $c == "Occupation" })
    assert ($cols | any { |c| $c == "Residence" })
}

@test
def "db-pres2025 list people pres2025 - --with is case insensitive" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list people --with [OcCuPaTiOn] } | columns)
    assert ($cols | any { |c| $c == "Occupation" })
}

@test
def "db-pres2025 list people pres2025 - --with rejects unknown fact type" [] {
    let ctx = $in
    let failed = try {
        with-env (e $ctx) { genq list people --with [definitely-not-a-fact] }
        false
    } catch { true }
    assert $failed
}

@test
def "db-pres2025 list people pres2025 - --with rejects family-level fact type" [] {
    let ctx = $in
    let failed = try {
        with-env (e $ctx) { genq list people --with [marriage] }
        false
    } catch { true }
    assert $failed
}

@test
def "db-pres2025 list people pres2025 - --with chronologically sorts nested facts" [] {
    let ctx = $in
    let multi = (with-env (e $ctx) {
        genq list people --with [occupation]
        | where ($it.Occupation | length) > 1
    })
    if ($multi | is-empty) { return }
    let row = ($multi | first)
    let sortdates = ($row.Occupation | get SortDate)
    assert equal $sortdates ($sortdates | sort)
}

# =============================================================================
# genq list events
# =============================================================================

@test
def "db-pres2025 list events pres2025 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list events } | columns)
    for col in [EventID RIN Given Surname Event Description EventDate SortDate LastUpdate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-pres2025 list events pres2025 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    assert (($result | length) > 0)
}

@test
def "db-pres2025 list events pres2025 - has Occupation events" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    assert (($result | where Event == "Occupation" | length) > 0)
}

@test
def "db-pres2025 list events pres2025 - SortDate is YYYY-MM-DD or empty" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    let invalid = ($result | where { |r|
        let d = $r.SortDate
        not (($d | is-empty) or ($d =~ '^\d{4}-\d{2}-\d{2}$'))
    })
    assert equal ($invalid | length) 0
}

@test
def "db-pres2025 list events pres2025 - sort-date-by orders SortDate ascending" [] {
    let ctx = $in
    let sorted = (with-env (e $ctx) { genq list events | sort-date-by EventDate | get SortDate | where $it != "" })
    assert equal $sorted ($sorted | sort)
}

# =============================================================================
# genq list families
# =============================================================================

@test
def "db-pres2025 list families pres2025 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list families } | columns)
    for col in [FamilyID FatherID FatherGiven FatherSurname MotherID MotherGiven MotherSurname HusbOrder WifeOrder] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-pres2025 list families pres2025 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list families })
    assert (($result | length) > 0)
}

@test
def "db-pres2025 list families pres2025 - FatherID and MotherID are positive" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list families })
    assert equal ($result | where FatherID <= 0 | length) 0
    assert equal ($result | where MotherID <= 0 | length) 0
}

# =============================================================================
# genq list sources
# =============================================================================

@test
def "db-pres2025 list sources pres2025 - runs without error" [] {
    let ctx = $in
    # pres2025 may have no freeform sources (TemplateID=0); just verify no crash
    let result = (with-env (e $ctx) { genq list sources })
    assert (($result | length) >= 0)
}

# =============================================================================
# genq list media
# =============================================================================

@test
def "db-pres2025 list media pres2025 - runs without error" [] {
    let ctx = $in
    with-env (e $ctx) { genq list media } | ignore
}

# =============================================================================
# genq list presidents  (pres2025 extension)
# =============================================================================

@test
def "db-pres2025 list presidents pres2025 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list presidents } | columns)
    for col in [RIN Given Surname Event Description EventDate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "db-pres2025 list presidents pres2025 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    assert (($result | length) > 0)
}

@test
def "db-pres2025 list presidents pres2025 - all descriptions contain US President" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    let non_pres = ($result | where { |r| not ($r.Description | str contains "US President") })
    assert equal ($non_pres | length) 0
}

@test
def "db-pres2025 list presidents pres2025 - Washington is included" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    assert (($result | where Surname == "Washington" | length) > 0)
}
