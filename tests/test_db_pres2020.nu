# Integration tests against pres2020.rmtree (US Presidents demo database)
# Always runs in CI — this database is committed to the repo.
#
# Uses a per-test temp copy to avoid writing into the committed .rmtree file.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *
use "../src/lib/ext/pres2020/mod.nu" *

const PROJ = path self | path dirname | path join ".."

@before-each
def setup [] {
    let src = ($PROJ | path join "data" "pres2020.rmtree" | path expand)
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
def "list people pres2020 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list people } | columns)
    for col in [index RIN Given Surname Sex BirthYear DeathYear] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list people pres2020 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert (($result | length) > 0)
}

@test
def "list people pres2020 - contains Washington" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert (($result | where Surname == "Washington" | length) > 0)
}

@test
def "list people pres2020 - Sex values are M or F only" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    let invalid = ($result | where { |r| $r.Sex != "M" and $r.Sex != "F" })
    assert equal ($invalid | length) 0
}

@test
def "list people pres2020 - index starts at 1" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert equal ($result | first | get index) 1
}

@test
def "list people pres2020 - RIN values are positive" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list people })
    assert equal ($result | where RIN <= 0 | length) 0
}

# =============================================================================
# genq list events
# =============================================================================

@test
def "list events pres2020 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list events } | columns)
    for col in [index EventID RIN Given Surname Event Description EventDate LastUpdate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list events pres2020 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    assert (($result | length) > 0)
}

@test
def "list events pres2020 - has Occupation events" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    assert (($result | where Event == "Occupation" | length) > 0)
}

@test
def "list events pres2020 - EventDate is 4-digit year or empty" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    let invalid = ($result | where { |r|
        let d = $r.EventDate
        not (($d | is-empty) or (($d | str length) == 4))
    })
    assert equal ($invalid | length) 0
}

@test
def "list events pres2020 - index starts at 1" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list events })
    assert equal ($result | first | get index) 1
}

# =============================================================================
# genq list families
# =============================================================================

@test
def "list families pres2020 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list families } | columns)
    for col in [index FamilyID FatherID FatherGiven FatherSurname MotherID MotherGiven MotherSurname HusbOrder WifeOrder] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list families pres2020 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list families })
    assert (($result | length) > 0)
}

@test
def "list families pres2020 - FatherID and MotherID are positive" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list families })
    assert equal ($result | where FatherID <= 0 | length) 0
    assert equal ($result | where MotherID <= 0 | length) 0
}

# =============================================================================
# genq list sources
# =============================================================================

@test
def "list sources pres2020 - runs without error" [] {
    let ctx = $in
    # pres2020 may have no freeform sources (TemplateID=0); just verify no crash
    let result = (with-env (e $ctx) { genq list sources })
    assert (($result | length) >= 0)
}

# =============================================================================
# genq list media
# =============================================================================

@test
def "list media pres2020 - runs without error" [] {
    let ctx = $in
    with-env (e $ctx) { genq list media } | ignore
}

# =============================================================================
# genq list presidents  (pres2020 extension)
# =============================================================================

@test
def "list presidents pres2020 - has expected columns" [] {
    let ctx = $in
    let cols = (with-env (e $ctx) { genq list presidents } | columns)
    for col in [index RIN Given Surname Event Description EventDate] {
        assert ($cols | any { |c| $c == $col })
    }
}

@test
def "list presidents pres2020 - returns records" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    assert (($result | length) > 0)
}

@test
def "list presidents pres2020 - all descriptions contain US President" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    let non_pres = ($result | where { |r| not ($r.Description | str contains "US President") })
    assert equal ($non_pres | length) 0
}

@test
def "list presidents pres2020 - Washington is included" [] {
    let ctx = $in
    let result = (with-env (e $ctx) { genq list presidents })
    assert (($result | where Surname == "Washington" | length) > 0)
}
