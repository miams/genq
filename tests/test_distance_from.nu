# Tests for genq distance-from
# Fast tests use --lat/--lon and require no database.
# db-pres2020 tests verify DB lookup paths.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *

const PROJ = path self | path dirname | path join ".."

# Known distance: New York City → London ≈ 5570 km
const NYC_LAT  = 40.7128
const NYC_LON  = -74.0060
const LON_LAT  = 51.5074
const LON_LON  = -0.1278

# =============================================================================
# Fast tests — no database required
# =============================================================================

@test
def "fast distance-from adds Distance column" [] {
    let rows = [{ Name: "London" Latitude: $LON_LAT Longitude: $LON_LON }]
    let result = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON)
    assert (($result | columns) | any { |c| $c == "Distance" })
}

@test
def "fast distance-from NYC to London is approximately 5570 km" [] {
    let rows = [{ Name: "London" Latitude: $LON_LAT Longitude: $LON_LON }]
    let dist = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON | first | get Distance)
    assert ($dist > 5500.0)
    assert ($dist < 5650.0)
}

@test
def "fast distance-from unit mi converts correctly" [] {
    let rows = [{ Name: "London" Latitude: $LON_LAT Longitude: $LON_LON }]
    let km  = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON --unit km | first | get Distance)
    let mi  = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON --unit mi | first | get Distance)
    # 1 km ≈ 0.621371 mi — ratio should be close
    let ratio = $mi / $km
    assert ($ratio > 0.619)
    assert ($ratio < 0.624)
}

@test
def "fast distance-from custom column name" [] {
    let rows = [{ Name: "London" Latitude: $LON_LAT Longitude: $LON_LON }]
    let result = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON --column DistKm | first)
    assert (($result | columns) | any { |c| $c == "DistKm" })
    assert not (($result | columns) | any { |c| $c == "Distance" })
}

@test
def "fast distance-from zero to self is zero" [] {
    let rows = [{ Name: "NYC" Latitude: $NYC_LAT Longitude: $NYC_LON }]
    let dist = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON | first | get Distance)
    assert ($dist < 0.001)
}

@test
def "fast distance-from ungeooded row gets null" [] {
    let rows = [{ Name: "Unknown" Latitude: 0.0 Longitude: 0.0 }]
    let dist = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON | first | get Distance)
    assert ($dist == null)
}

@test
def "fast distance-from preserves other columns" [] {
    let rows = [{ PlaceID: 42 Name: "London" Latitude: $LON_LAT Longitude: $LON_LON PlaceType: "Place" }]
    let result = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON | first)
    assert equal $result.PlaceID 42
    assert equal $result.Name "London"
    assert equal $result.PlaceType "Place"
}

@test
def "fast distance-from multiple rows all get Distance" [] {
    let rows = [
        { Name: "London"  Latitude: $LON_LAT Longitude: $LON_LON }
        { Name: "NYC"     Latitude: $NYC_LAT Longitude: $NYC_LON }
        { Name: "Unknown" Latitude: 0.0      Longitude: 0.0      }
    ]
    let result = ($rows | genq distance-from --lat $NYC_LAT --lon $NYC_LON)
    assert equal ($result | length) 3
    assert (($result | columns) | any { |c| $c == "Distance" })
    assert ($result.0.Distance > 5000.0)   # London
    assert ($result.1.Distance < 0.001)    # NYC to itself
    assert ($result.2.Distance == null)    # no coords
}

# =============================================================================
# db-pres2020 tests — verify DB lookup paths
# =============================================================================

@before-each
def setup [] {
    let src = ($PROJ | path join "data" "pres2020.rmtree" | path expand)
    let tmp = (mktemp -t "genq-dist-XXXXXX")
    cp $src $tmp
    { db: $tmp, sql: ($PROJ | path join "sql" | path expand) }
}

@after-each
def teardown [] {
    let ctx = $in
    rm -f $ctx.db
    rm -f $"($ctx.db)-wal"
    rm -f $"($ctx.db)-shm"
}

def e [ctx: record] {
    { rmdb: $ctx.db, genq_sql: $ctx.sql, RDMF: 1 }
}

@test
def "db-pres2020 distance-from place-id adds Distance column" [] {
    let ctx = $in
    let result = (with-env (e $ctx) {
        genq list places --coordinates
        | genq distance-from --place-id 1
    })
    assert (($result | columns) | any { |c| $c == "Distance" })
}

@test
def "db-pres2020 distance-from place-name adds Distance column" [] {
    let ctx = $in
    # Get the first place name to use as reference
    let first_place = (with-env (e $ctx) { genq list places | first | get Name })
    let result = (with-env (e $ctx) {
        genq list places --coordinates
        | genq distance-from --place-name $first_place
    })
    assert (($result | columns) | any { |c| $c == "Distance" })
}
