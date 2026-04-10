# Add a Distance column to a table that has Latitude and Longitude columns.
# The reference point can be a PlaceID, place name, or raw coordinates.
# Rows with no GPS data (Latitude = 0 and Longitude = 0) receive null for Distance.
@category "genq-common"
@search-terms "distance haversine gps coordinates near location geography"
@example "distances in km from a PlaceID" { 'genq list places --coordinates | genq distance-from --place-id 1' }
@example "distances in miles from a named place" { 'genq list places --coordinates | genq distance-from --place-name "Washington, District of Columbia, USA" --unit mi' }
@example "distances from raw coordinates, custom column name" { 'genq list places --coordinates | genq distance-from --lat 38.8951 --lon -77.0364 --column DistKm' }
export def "main" [
    --place-id(-i): int       # Reference point: PlaceID from PlaceTable
    --place-name(-n): string  # Reference point: place name (case-insensitive, exact match)
    --lat: float              # Reference latitude  (requires --lon)
    --lon: float              # Reference longitude (requires --lat)
    --unit(-u): string = "km" # Distance unit: km or mi
    --column(-c): string = "Distance"  # Output column name
] {
    let rows = $in

    # Validate unit
    if $unit != "km" and $unit != "mi" {
        print $"(ansi red)Error:(ansi reset) --unit must be 'km' or 'mi', got: ($unit)"
        return
    }

    # Validate reference point — exactly one source
    let has_pid    = ($place_id   | is-not-empty)
    let has_pname  = ($place_name | is-not-empty)
    let has_lat    = ($lat | is-not-empty)
    let has_lon    = ($lon | is-not-empty)

    if $has_lat != $has_lon {
        print $"(ansi red)Error:(ansi reset) --lat and --lon must be used together"
        return
    }
    let has_coords = $has_lat

    let source_count = ([$has_pid $has_pname $has_coords] | where $it | length)
    if $source_count == 0 {
        print $"(ansi red)Error:(ansi reset) Provide one of: --place-id, --place-name, or --lat/--lon"
        return
    }
    if $source_count > 1 {
        print $"(ansi red)Error:(ansi reset) Provide only one of: --place-id, --place-name, or --lat/--lon"
        return
    }

    # Resolve reference lat/lon
    let ref = if $has_coords {
        { Latitude: $lat, Longitude: $lon }
    } else {
        if not ($env.rmdb? | default "" | path exists) {
            print $"(ansi red)Error:(ansi reset) Database not found. Configure with 'genq config'."
            return
        }
        let result = if $has_pid {
            let q = $"SELECT ROUND\(CAST\(Latitude AS REAL\) / 10000000.0, 7\) AS Latitude, ROUND\(CAST\(Longitude AS REAL\) / 10000000.0, 7\) AS Longitude FROM PlaceTable WHERE PlaceID = ($place_id) LIMIT 1"
            open $env.rmdb | query db $q
        } else {
            let safe = ($place_name | str replace --all "'" "''")
            let q = $"SELECT ROUND\(CAST\(Latitude AS REAL\) / 10000000.0, 7\) AS Latitude, ROUND\(CAST\(Longitude AS REAL\) / 10000000.0, 7\) AS Longitude FROM PlaceTable WHERE Name = '($safe)' COLLATE NOCASE LIMIT 1"
            open $env.rmdb | query db $q
        }
        if ($result | is-empty) {
            let desc = if $has_pid { $"PlaceID ($place_id)" } else { $"'($place_name)'" }
            print $"(ansi red)Error:(ansi reset) Place not found: ($desc)"
            return
        }
        $result | first
    }

    # Warn if reference place has no GPS data
    if $ref.Latitude == 0.0 and $ref.Longitude == 0.0 {
        let desc = if $has_pid {
            $"PlaceID ($place_id)"
        } else if $has_pname {
            $"'($place_name)'"
        } else {
            "provided coordinates"
        }
        print $"(ansi yellow)Warning:(ansi reset) Reference place has no GPS coordinates: ($desc)"
    }

    let r = if $unit == "km" { 6371.0088 } else { 3958.7613 }
    let ref_lat = $ref.Latitude
    let ref_lon = $ref.Longitude

    $rows | each {|row|
        let row_lat = ($row | get --optional Latitude | default 0.0)
        let row_lon = ($row | get --optional Longitude | default 0.0)

        let dist = if $row_lat == 0.0 and $row_lon == 0.0 {
            null
        } else {
            haversine $ref_lat $ref_lon $row_lat $row_lon $r
        }

        $row | insert $column $dist
    }
}

# Haversine great-circle distance. Returns distance in the same units as r.
def haversine [
    lat1: float  lon1: float
    lat2: float  lon2: float
    r: float     # Earth radius in desired units
] {
    let to_rad = 3.141592653589793 / 180.0
    let φ1 = $lat1 * $to_rad
    let φ2 = $lat2 * $to_rad
    let sin_dφ = (($lat2 - $lat1) * $to_rad / 2.0 | math sin)
    let sin_dλ = (($lon2 - $lon1) * $to_rad / 2.0 | math sin)
    let a = ($sin_dφ * $sin_dφ) + (($φ1 | math cos) * ($φ2 | math cos) * ($sin_dλ * $sin_dλ))
    let a_c = if $a < 0.0 { 0.0 } else if $a > 1.0 { 1.0 } else { $a }
    2.0 * $r * ($a_c | math sqrt | math arcsin)
}
