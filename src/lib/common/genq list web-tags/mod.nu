# List web tags across all owner types.
@category "genq-common"
@search-terms "URL webtag web tag link website findagrave ancestry"
@example "List all web tags in the database." {'genq list web-tags'}
@example "List only person web tags." {'genq list web-tags --type person'}
@example "List only source web tags." {'genq list web-tags --type source'}
@example "Find all Find a Grave links." {'genq list web-tags --type person | where URL =~ "findagrave"'}
@example "Find all web tags for a specific person." {'genq list web-tags --type person | where OwnerID == 1234'}
export def "main" [
    --type (-t): string  # Filter by owner type: person, source, citation, place, task, placedetail
    --mod-date (-d)      # Include LastUpdate column (URLTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of web tags."

    let type_where = match ($type | default "") {
        "person"      => " AND u.OwnerType = 0"
        "source"      => " AND u.OwnerType = 3"
        "citation"    => " AND u.OwnerType = 4"
        "place"       => " AND u.OwnerType = 5"
        "task"        => " AND u.OwnerType = 6"
        "placedetail" => " AND u.OwnerType = 14"
        _             => ""
    }

    let sqlquery = ($"
        SELECT
            u.LinkID,
            u.OwnerID,
            CASE u.OwnerType
                WHEN 0  THEN 'Person'
                WHEN 3  THEN 'Source'
                WHEN 4  THEN 'Citation'
                WHEN 5  THEN 'Place'
                WHEN 6  THEN 'Task'
                WHEN 14 THEN 'PlaceDetail'
                ELSE 'Unknown'
            END AS OwnerType,
            CASE u.OwnerType
                WHEN 0  THEN COALESCE\(n.Given, ''\) || ' ' || COALESCE\(n.Surname, ''\)
                WHEN 3  THEN COALESCE\(s.Name, ''\)
                WHEN 4  THEN COALESCE\(c.CitationName, ''\)
                WHEN 5  THEN COALESCE\(p.Name, ''\)
                WHEN 6  THEN COALESCE\(t.Name, ''\)
                WHEN 14 THEN COALESCE\(pd.Name, ''\)
                ELSE ''
            END AS OwnerName,
            COALESCE\(u.Name, ''\) AS TagName,
            u.URL,
            COALESCE\(u.Note, ''\) AS Note,
            COALESCE\(STRFTIME\(DATETIME\(u.UTCModDate + 2415018.5\)\) || ' +0000', ''\) AS LastUpdateUTC
        FROM URLTable u
        LEFT JOIN NameTable n    ON u.OwnerType = 0  AND n.OwnerID   = u.OwnerID AND n.IsPrimary = 1
        LEFT JOIN SourceTable s  ON u.OwnerType = 3  AND s.SourceID  = u.OwnerID
        LEFT JOIN CitationTable c ON u.OwnerType = 4 AND c.CitationID = u.OwnerID
        LEFT JOIN PlaceTable p   ON u.OwnerType = 5  AND p.PlaceID   = u.OwnerID
        LEFT JOIN TaskTable t    ON u.OwnerType = 6  AND t.TaskID    = u.OwnerID
        LEFT JOIN PlaceTable pd  ON u.OwnerType = 14 AND pd.PlaceID  = u.OwnerID
        WHERE 1=1($type_where)
        ORDER BY u.OwnerType, u.OwnerID")

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.LastUpdateUTC | is-empty) { "" } else {
                $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
            }
        }
        | reject LastUpdateUTC

    if $mod_date { $result } else { $result | reject LastUpdate }
}
