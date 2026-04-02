# List all individuals.
@category "genq-common"
@search-terms "people persons individuals names RIN"
@example "list the first 10 people" {'genq list people | first 10'}
@example "list people with alternate name spellings" {'genq list people --all-names | where AlternateNames != ""'}
export def "main" [
    --all-names (-a)  # Include alternate names as an additional column
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
            SELECT OwnerID, Given COLLATE NOCASE as Given, Surname COLLATE NOCASE as Surname, BirthYear, DeathYear
            FROM NameTable WHERE IsPrimary = 1
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
            n.BirthYear,
            n.DeathYear,
            COALESCE(a.AlternateNames, '') as AlternateNames
        FROM primary_names n
        INNER JOIN PersonTable p ON n.OwnerID = p.PersonID
        LEFT JOIN alt_names a ON p.PersonID = a.OwnerID"
        open $env.rmdb | query db $sqlquery | startat1
    } else {
        print "List of individuals."
        # COLLATE NOCASE inside CTE overrides any RMNOCASE collation stored in the DB schema
        let sqlquery = "WITH primary_names AS (
            SELECT OwnerID, Given COLLATE NOCASE as Given, Surname COLLATE NOCASE as Surname, BirthYear, DeathYear
            FROM NameTable WHERE IsPrimary = 1
        )
        SELECT
            p.PersonID as RIN,
            n.Given as Given,
            n.Surname as Surname,
            CASE WHEN p.Sex = 1 THEN 'F' ELSE 'M' END as Sex,
            n.BirthYear,
            n.DeathYear
        FROM primary_names n
        INNER JOIN PersonTable p ON n.OwnerID = p.PersonID"
        open $env.rmdb | query db $sqlquery | startat1
    }
}
