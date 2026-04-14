# List all individuals.
use rmdate *

@category "genq-common"
@search-terms "people persons individuals names RIN"
@example "list the first 10 people" {'genq list people | first 10'}
@example "list people with alternate name spellings" {'genq list people --all-names | where AlternateNames != ""'}
export def "main" [
    --all-names (-a)  # Include alternate names as an additional column
    --mod-date (-d)   # Include LastUpdate column (PersonTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

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
        if $mod_date {
            $result | select RIN Given Surname Sex BirthDate DeathDate AlternateNames LastUpdate | startat1
        } else {
            $result | select RIN Given Surname Sex BirthDate DeathDate AlternateNames | startat1
        }
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
        if $mod_date {
            $result | select RIN Given Surname Sex BirthDate DeathDate LastUpdate | startat1
        } else {
            $result | select RIN Given Surname Sex BirthDate DeathDate | startat1
        }
    }
}
