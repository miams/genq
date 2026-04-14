# List all places from PlaceTable (gazetteer).
@category "genq-common"
@search-terms "gazetteer location geography coordinates lat lon"
@example "list all places" {'genq list places'}
@example "find places that have been geocoded" {'genq list places --coordinates | where Latitude != 0'}
export def "main" [
    --coordinates (-c)  # Include Latitude and Longitude columns (stored as integer × 1e7)
    --all               # Include place details (sub-places) in addition to top-level places
    --mod-date (-d)     # Include LastUpdate column (PlaceTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of places."

    let type_filter = if $all { "" } else { " WHERE PlaceType = 0" }

    let mod_date_sql = ", COALESCE(STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC"

    let sqlquery = if $coordinates {
        ["SELECT PlaceID,
            Name COLLATE NOCASE as Name,
            Normalized COLLATE NOCASE as Normalized,
            ROUND(CAST(Latitude AS REAL) / 10000000.0, 7) as Latitude,
            ROUND(CAST(Longitude AS REAL) / 10000000.0, 7) as Longitude,
            CASE PlaceType WHEN 0 THEN 'Place' WHEN 1 THEN 'Temple' WHEN 2 THEN 'Detail' ELSE 'Unknown' END as PlaceType"
            $mod_date_sql "
        FROM PlaceTable" $type_filter " ORDER BY Name COLLATE NOCASE"] | str join
    } else {
        ["SELECT PlaceID,
            Name COLLATE NOCASE as Name,
            Normalized COLLATE NOCASE as Normalized,
            CASE PlaceType WHEN 0 THEN 'Place' WHEN 1 THEN 'Temple' WHEN 2 THEN 'Detail' ELSE 'Unknown' END as PlaceType"
            $mod_date_sql "
        FROM PlaceTable" $type_filter " ORDER BY Name COLLATE NOCASE"] | str join
    }

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
