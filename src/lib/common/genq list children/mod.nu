# List children with parent-child relationship types.
@category "genq-common"
@search-terms "children adopted step foster birth parents family"
@example "list all children" {'genq list children'}
@example "list adopted children" {'genq list children | where RelToFather == "Adopted" or RelToMother == "Adopted"'}
@example "list children for a specific family (MRIN)" {'genq list children | where MRIN == 5'}
export def "main" [
    --rin (-r): int   # Filter by child RIN
    --mrin (-m): int  # Filter by family MRIN
    --mod-date (-d)   # Include LastUpdate column (ChildTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of children with parent-child relationship types."

    let rin_where  = if not ($rin  | is-empty) { [$"c.ChildID = ($rin)"]    } else { [] }
    let mrin_where = if not ($mrin | is-empty) { [$"c.FamilyID = ($mrin)"]  } else { [] }

    let where_clause = (["1=1"] | append $rin_where | append $mrin_where | str join " AND ")

    let base_sql = "SELECT
        c.ChildID as RIN,
        cn.Given COLLATE NOCASE as Given,
        cn.Surname COLLATE NOCASE as Surname,
        CASE WHEN cp.Sex = 1 THEN 'F' ELSE 'M' END as Sex,
        c.FamilyID as MRIN,
        f.FatherID as FatherRIN,
        fn.Given COLLATE NOCASE as FatherGiven,
        fn.Surname COLLATE NOCASE as FatherSurname,
        f.MotherID as MotherRIN,
        mn.Given COLLATE NOCASE as MotherGiven,
        mn.Surname COLLATE NOCASE as MotherSurname,
        CASE c.RelFather
            WHEN 0 THEN 'Birth'
            WHEN 1 THEN 'Adopted'
            WHEN 2 THEN 'Step'
            WHEN 3 THEN 'Foster'
            WHEN 4 THEN 'Guardian'
            WHEN 5 THEN 'Sealed'
            WHEN 6 THEN 'Unknown'
            ELSE 'Unknown'
        END as RelToFather,
        CASE c.RelMother
            WHEN 0 THEN 'Birth'
            WHEN 1 THEN 'Adopted'
            WHEN 2 THEN 'Step'
            WHEN 3 THEN 'Foster'
            WHEN 4 THEN 'Guardian'
            WHEN 5 THEN 'Sealed'
            WHEN 6 THEN 'Unknown'
            ELSE 'Unknown'
        END as RelToMother,
        c.ChildOrder,
        COALESCE(STRFTIME(DATETIME(c.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
    FROM ChildTable c
    JOIN FamilyTable f ON c.FamilyID = f.FamilyID
    JOIN PersonTable cp ON c.ChildID = cp.PersonID
    JOIN NameTable cn ON c.ChildID = cn.OwnerID AND cn.IsPrimary = 1
    LEFT JOIN NameTable fn ON f.FatherID = fn.OwnerID AND fn.IsPrimary = 1
    LEFT JOIN NameTable mn ON f.MotherID = mn.OwnerID AND mn.IsPrimary = 1"

    let sqlquery = [$base_sql " WHERE " $where_clause " ORDER BY c.FamilyID, c.ChildOrder"] | str join

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
