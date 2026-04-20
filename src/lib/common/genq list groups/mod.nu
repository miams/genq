# List named groups (colour-coded sets) with member counts.
@category "genq-common"
@search-terms "group tag colour color set members flagged"
@example "List all groups with member counts." {'genq list groups'}
@example "List the top 5 groups by size." {'genq list groups | sort-by Members --reverse | first 5'}
@example "Find groups whose name contains 'census'." {'genq list groups | where GroupName =~ "(?i)census"'}
@example "List every person in the War_Veterans group." {'genq list groups --members | where GroupName == "War_Veterans"'}
export def "main" [
    --members (-m)           # Expand to one row per member (adds RIN, Given, Surname columns)
    --group-id (-g): int     # Filter to a single group by its numeric ID
    --mod-date (-d)          # Include LastUpdate column
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    let gid_filter = if ($group_id | is-empty) { "" } else { $" AND t.TagValue = ($group_id)" }

    if $members {
        print "List of group members."
        # Expand StartID..EndID ranges by joining PersonTable ON PersonID BETWEEN StartID AND EndID.
        # This uses the PersonID primary key index and avoids slow recursive CTEs.
        let sqlquery = ($"
            SELECT
                t.TagValue  AS GroupID,
                t.TagName   AS GroupName,
                COALESCE\(t.Description, ''\) AS Description,
                p.PersonID  AS RIN,
                n.Given  COLLATE NOCASE AS Given,
                n.Surname COLLATE NOCASE AS Surname,
                COALESCE\(STRFTIME\(DATETIME\(t.UTCModDate + 2415018.5\)\) || ' +0000', ''\) AS LastUpdateUTC
            FROM TagTable t
            JOIN GroupTable g  ON g.GroupID = t.TagValue
            JOIN PersonTable p ON p.PersonID >= g.StartID AND p.PersonID <= g.EndID
            JOIN NameTable n   ON n.OwnerID = p.PersonID AND n.IsPrimary = 1
            WHERE t.TagType = 0($gid_filter)
            ORDER BY t.TagName COLLATE NOCASE, n.Surname COLLATE NOCASE, n.Given COLLATE NOCASE")

        let result = open $env.rmdb | query db $sqlquery
            | insert LastUpdate {|row|
                if ($row.LastUpdateUTC | is-empty) { "" } else {
                    $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
                }
            }
            | reject LastUpdateUTC

        if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }

    } else {
        print "List of groups."
        let sqlquery = ($"
            SELECT
                t.TagValue AS GroupID,
                t.TagName  AS GroupName,
                COALESCE\(t.Description, ''\) AS Description,
                COALESCE\(SUM\(g.EndID - g.StartID + 1\), 0\) AS Members,
                COALESCE\(STRFTIME\(DATETIME\(t.UTCModDate + 2415018.5\)\) || ' +0000', ''\) AS LastUpdateUTC
            FROM TagTable t
            LEFT JOIN GroupTable g ON g.GroupID = t.TagValue
            WHERE t.TagType = 0($gid_filter)
            GROUP BY t.TagValue
            ORDER BY Members DESC")

        let result = open $env.rmdb | query db $sqlquery
            | insert LastUpdate {|row|
                if ($row.LastUpdateUTC | is-empty) { "" } else {
                    $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
                }
            }
            | reject LastUpdateUTC

        if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
    }
}
