# List FAN (Friends, Associates, Neighbors) associations between persons.
@category "genq-common"
@search-terms "FAN friends associates neighbors employer godparent DNA"
@example "list all associations" {'genq list associations'}
@example "list associations for a person" {'genq list associations --rin 42'}
@example "list neighbor associations" {'genq list associations | where AssocType == "Neighbors"'}
export def "main" [
    --rin (-r): int      # Filter: show associations where this RIN is either person
    --type (-t): string  # Filter by association type name (case-insensitive substring match)
    --mod-date (-d)      # Include LastUpdate column (FANTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of person associations (FAN club)."

    let sqlquery = "SELECT
        f.FanID,
        f.ID1 as RIN1,
        n1.Given COLLATE NOCASE as Given1,
        n1.Surname COLLATE NOCASE as Surname1,
        ft.Role1 COLLATE NOCASE as Role1,
        f.ID2 as RIN2,
        n2.Given COLLATE NOCASE as Given2,
        n2.Surname COLLATE NOCASE as Surname2,
        ft.Role2 COLLATE NOCASE as Role2,
        ft.Name COLLATE NOCASE as AssocType,
        f.Date COLLATE NOCASE as Date,
        f.Description COLLATE NOCASE as Description,
        COALESCE(STRFTIME(DATETIME(f.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
    FROM FANTable f
    JOIN FANTypeTable ft ON f.FanTypeID = ft.FANTypeID
    LEFT JOIN NameTable n1 ON f.ID1 = n1.OwnerID AND n1.IsPrimary = 1
    LEFT JOIN NameTable n2 ON f.ID2 = n2.OwnerID AND n2.IsPrimary = 1
    ORDER BY ft.Name COLLATE NOCASE, n1.Surname COLLATE NOCASE, n1.Given COLLATE NOCASE"

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC

    # Apply post-query filters in Nu (simpler than injecting into SQL)
    let result = if not ($rin | is-empty) {
        $result | where {|r| $r.RIN1 == $rin or $r.RIN2 == $rin}
    } else { $result }

    let result = if not ($type | is-empty) {
        let t = $type | str downcase
        $result | where {|r| ($r.AssocType | str downcase) | str contains $t}
    } else { $result }

    if $mod_date { $result } else { $result | reject LastUpdate }
}
