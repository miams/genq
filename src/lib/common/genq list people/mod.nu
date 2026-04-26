# List all individuals.
@category "genq-common"
@search-terms "people persons individuals names RIN"
@example "list the first 10 people" {'genq list people | first 10'}
@example "list people with alternate name spellings" {'genq list people --all-names | where AlternateNames != ""'}
@example "list only living people" {'genq list people --living | where Living == "Y"'}
@example "attach occupations as a nested column" {'genq list people --with [occupation] | where ($it.Occupation | length) > 0'}
@example "attach multiple fact types and flatten one of them" {'genq list people --with [occupation residence] | flatten --all Occupation'}
export def "main" [
    --all-names (-a)        # Include alternate names as an additional column
    --full-name (-f)        # Add FullName column (Given + Surname combined)
    --full-date             # Include BirthFullDate and DeathFullDate columns (raw 24-char RM date strings)
    --mod-date (-d)         # Include LastUpdate column (PersonTable.UTCModDate)
    --living (-l)           # Include Living column (Y=Living, N=Deceased; from PersonTable.Living)
    --note (-n)             # Include Note column (PersonTable.Note)
    --with: list<string> = []  # Attach person-level facts as nested columns, e.g. --with [occupation residence]
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    let resolved_facts = resolve-fact-types $with

    if $all_names {
        print "List of individuals with alternate names."
        # COLLATE NOCASE inside CTEs overrides any RMNOCASE collation stored in the DB schema
        let sqlquery = "WITH primary_names AS (
            SELECT OwnerID, Given COLLATE NOCASE as Given, Surname COLLATE NOCASE as Surname
            FROM NameTable WHERE IsPrimary = 1
        ),
        birth_events AS (
            SELECT OwnerID, COALESCE(Date, '') COLLATE NOCASE as BirthFullDate
            FROM (
                SELECT OwnerID, Date, ROW_NUMBER() OVER (
                    PARTITION BY OwnerID
                    ORDER BY CASE WHEN SortDate IS NULL OR SortDate = 0 THEN 1 ELSE 0 END, SortDate, EventID
                ) as rn
                FROM EventTable
                WHERE OwnerType = 0 AND EventType = 1
            )
            WHERE rn = 1
        ),
        death_events AS (
            SELECT OwnerID, COALESCE(Date, '') COLLATE NOCASE as DeathFullDate
            FROM (
                SELECT OwnerID, Date, ROW_NUMBER() OVER (
                    PARTITION BY OwnerID
                    ORDER BY CASE WHEN SortDate IS NULL OR SortDate = 0 THEN 1 ELSE 0 END, SortDate, EventID
                ) as rn
                FROM EventTable
                WHERE OwnerType = 0 AND EventType = 2
            )
            WHERE rn = 1
        ),
        alt_names AS (
            SELECT OwnerID,
                GROUP_CONCAT(
                    Given COLLATE NOCASE || ' ' || Surname COLLATE NOCASE || ' (' ||
                    CASE NameType
                        WHEN 0 THEN 'AKA'
                        WHEN 1 THEN 'Birth'
                        WHEN 2 THEN 'Immigrant'
                        WHEN 3 THEN 'Maiden'
                        WHEN 4 THEN 'Married'
                        WHEN 5 THEN 'Nickname'
                        WHEN 6 THEN 'Other'
                        ELSE 'Unknown'
                    END || ')',
                    '; '
                ) as AlternateNames
            FROM NameTable WHERE IsPrimary = 0
            GROUP BY OwnerID
        )
        SELECT
            p.PersonID as RIN,
            n.Given as Given,
            n.Surname as Surname,
            CASE WHEN p.Sex = 1 THEN 'F' ELSE 'M' END as Sex,
            COALESCE(b.BirthFullDate, '') as BirthFullDate,
            COALESCE(d.DeathFullDate, '') as DeathFullDate,
            COALESCE(a.AlternateNames, '') as AlternateNames,
            CASE WHEN p.Living = 1 THEN 'Y' ELSE 'N' END AS Living,
            COALESCE(p.Note, '') AS Note,
            COALESCE(STRFTIME(DATETIME(p.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM primary_names n
        INNER JOIN PersonTable p ON n.OwnerID = p.PersonID
        LEFT JOIN birth_events b ON p.PersonID = b.OwnerID
        LEFT JOIN death_events d ON p.PersonID = d.OwnerID
        LEFT JOIN alt_names a ON p.PersonID = a.OwnerID"
        let result = open $env.rmdb | query db $sqlquery
        | upsert-rm-date BirthFullDate BirthDate
        | upsert-rm-date DeathFullDate DeathDate
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC
        let with_facts = attach-facts $result $resolved_facts
        let fact_cols = ($resolved_facts | get label)
        let cols = ([RIN Given Surname]
            | if $full_name { append FullName } else { $in }
            | append [Sex BirthDate DeathDate]
            | if $full_date { append [BirthFullDate DeathFullDate] } else { $in }
            | append AlternateNames
            | if $living { append Living } else { $in }
            | if $note { append Note } else { $in }
            | if $mod_date { append LastUpdate } else { $in }
            | append $fact_cols)
        let prepped = if $full_name {
            $with_facts | insert FullName { |row| [$row.Given, $row.Surname] | str join " " }
        } else { $with_facts }
        $prepped | select ...$cols
    } else {
        print "List of individuals."
        # COLLATE NOCASE inside CTE overrides any RMNOCASE collation stored in the DB schema
        let sqlquery = "WITH primary_names AS (
            SELECT OwnerID, Given COLLATE NOCASE as Given, Surname COLLATE NOCASE as Surname
            FROM NameTable WHERE IsPrimary = 1
        ),
        birth_events AS (
            SELECT OwnerID, COALESCE(Date, '') COLLATE NOCASE as BirthFullDate
            FROM (
                SELECT OwnerID, Date, ROW_NUMBER() OVER (
                    PARTITION BY OwnerID
                    ORDER BY CASE WHEN SortDate IS NULL OR SortDate = 0 THEN 1 ELSE 0 END, SortDate, EventID
                ) as rn
                FROM EventTable
                WHERE OwnerType = 0 AND EventType = 1
            )
            WHERE rn = 1
        ),
        death_events AS (
            SELECT OwnerID, COALESCE(Date, '') COLLATE NOCASE as DeathFullDate
            FROM (
                SELECT OwnerID, Date, ROW_NUMBER() OVER (
                    PARTITION BY OwnerID
                    ORDER BY CASE WHEN SortDate IS NULL OR SortDate = 0 THEN 1 ELSE 0 END, SortDate, EventID
                ) as rn
                FROM EventTable
                WHERE OwnerType = 0 AND EventType = 2
            )
            WHERE rn = 1
        )
        SELECT
            p.PersonID as RIN,
            n.Given as Given,
            n.Surname as Surname,
            CASE WHEN p.Sex = 1 THEN 'F' ELSE 'M' END as Sex,
            COALESCE(b.BirthFullDate, '') as BirthFullDate,
            COALESCE(d.DeathFullDate, '') as DeathFullDate,
            CASE WHEN p.Living = 1 THEN 'Y' ELSE 'N' END AS Living,
            COALESCE(p.Note, '') AS Note,
            COALESCE(STRFTIME(DATETIME(p.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM primary_names n
        INNER JOIN PersonTable p ON n.OwnerID = p.PersonID
        LEFT JOIN birth_events b ON p.PersonID = b.OwnerID
        LEFT JOIN death_events d ON p.PersonID = d.OwnerID"
        let result = open $env.rmdb | query db $sqlquery
        | upsert-rm-date BirthFullDate BirthDate
        | upsert-rm-date DeathFullDate DeathDate
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC
        let with_facts = attach-facts $result $resolved_facts
        let fact_cols = ($resolved_facts | get label)
        let cols = ([RIN Given Surname]
            | if $full_name { append FullName } else { $in }
            | append [Sex BirthDate DeathDate]
            | if $full_date { append [BirthFullDate DeathFullDate] } else { $in }
            | if $living { append Living } else { $in }
            | if $note { append Note } else { $in }
            | if $mod_date { append LastUpdate } else { $in }
            | append $fact_cols)
        let prepped = if $full_name {
            $with_facts | insert FullName { |row| [$row.Given, $row.Surname] | str join " " }
        } else { $with_facts }
        $prepped | select ...$cols
    }
}

# Validate `--with` names against FactTypeTable; reject unknown or family-level types.
# Returns a list of {id: int, label: string} ordered to match user input.
def resolve-fact-types [requested: list<string>] {
    if ($requested | is-empty) { return [] }

    let fact_meta = open $env.rmdb | query db "SELECT FactTypeID, Name COLLATE NOCASE as Name, OwnerType FROM FactTypeTable"

    $requested | each { |name|
        let needle = ($name | str downcase | str trim)
        if ($needle | is-empty) {
            error make { msg: "--with received an empty fact type name" }
        }
        let match = ($fact_meta | where { |r| ($r.Name | str downcase) == $needle })
        if ($match | is-empty) {
            error make { msg: $"Unknown fact type: '($name)'. Run `genq list events | get Event | uniq` to see available types." }
        }
        let row = ($match | first)
        if $row.OwnerType != 0 {
            error make { msg: $"'($row.Name)' is a family-level fact and is not supported by `genq list people --with`. Use `genq list events` for family-level facts." }
        }
        { id: $row.FactTypeID, label: $row.Name }
    }
}

# Attach a nested column per requested fact type to the people table.
# Each cell is a list of {Date, Description, Place, SortDate} sorted chronologically.
# People with no matching events get an empty list (keeps the schema rectangular).
def attach-facts [people: table, resolved: list<any>] {
    if ($resolved | is-empty) { return $people }

    use rmdate *

    let id_csv = ($resolved | get id | each { |i| $i | into string } | str join ",")
    let labels = ($resolved | get label)

    let sql = "SELECT
            EventTable.OwnerID as RIN,
            FactTypeTable.Name COLLATE NOCASE as FactType,
            COALESCE(EventTable.Date, '') COLLATE NOCASE as FullDate,
            COALESCE(EventTable.Details, '') COLLATE NOCASE as Description,
            COALESCE(PlaceTable.Name, '') COLLATE NOCASE as Place,
            COALESCE(EventTable.SortDate, 0) as SortDate
        FROM EventTable
        INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
        LEFT JOIN PlaceTable ON EventTable.PlaceID = PlaceTable.PlaceID
        WHERE EventTable.OwnerType = 0
          AND EventTable.EventType IN (" + $id_csv + ")
        ORDER BY EventTable.OwnerID, EventTable.SortDate, EventTable.EventID"

    let events = (open $env.rmdb | query db $sql | each { |e|
        {
            RIN: $e.RIN
            FactType: $e.FactType
            Date: (format-rm-date $e.FullDate)
            Description: $e.Description
            Place: $e.Place
            SortDate: $e.SortDate
        }
    })

    let by_rin = if ($events | is-empty) { {} } else { $events | group-by { |r| $r.RIN | into string } }

    $people | each { |p|
        let rin_key = ($p.RIN | into string)
        let mine = ($by_rin | get --optional $rin_key | default [])
        $labels | reduce --fold $p { |label, acc|
            let facts = ($mine | where FactType == $label | each { |f|
                { Date: $f.Date, Description: $f.Description, Place: $f.Place, SortDate: $f.SortDate }
            })
            $acc | insert $label $facts
        }
    }
    | where { |row|
        # Drop people who have no matches for any of the requested fact types.
        $labels | any { |label| ($row | get $label | length) > 0 }
    }
}
