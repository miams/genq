# List Census Records by RIN or Year.
@category "genq-ext-miams"
@example "List Census records for individual with RIN of 2." {genq census RIN 2}
@example "List all Census records for 1850." {genq census year 1850}
export def "main" [action?: string, ...objects: string] {

    # Shared CTE — builds census_all from head (prime) + witness (attached) records.
    # Read-only: no CREATE VIEW / DROP VIEW, so no write lock on the user's database.
    let census_cte = "
WITH census_attached AS (
    SELECT SUBSTR(EventTable.Date, 4, 4) AS CensusDate,
        EventTable.EventID AS EventID,
        EventTable.OwnerID AS RIN,
        RoleName COLLATE NOCASE AS Role,
        WitnessTable.PersonID AS PersonID
    FROM WitnessTable
    JOIN EventTable ON WitnessTable.EventID = EventTable.EventID
    JOIN RoleTable ON WitnessTable.Role = RoleTable.RoleID
    WHERE EventTable.EventType = 18 AND WitnessTable.PersonID > 0
),
census_prime AS (
    SELECT SUBSTR(EventTable.Date, 4, 4) AS CensusDate,
        EventID,
        EventTable.OwnerID AS RIN,
        'Head' AS Role,
        EventTable.OwnerID AS PersonID
    FROM EventTable
    WHERE EventType = 18
),
census_all AS (
    SELECT * FROM census_prime
    UNION ALL
    SELECT * FROM census_attached
)"

    match ($action | default "" | str downcase) {
        "rin" => {
            if ($objects | length) == 0 {
                print $"(ansi red)Error:(ansi reset) RIN parameter required. Usage: genq census RIN <number>"
                return
            }

            let RIN = try {
                $objects.0 | into int
            } catch {
                print $"(ansi red)Error:(ansi reset) Invalid RIN '($objects.0)'. RIN must be a positive integer."
                return
            }

            if $RIN <= 0 {
                print $"(ansi red)Error:(ansi reset) Invalid RIN ($RIN). RIN must be a positive integer."
                return
            }

            let person = open $env.rmdb | query db $"SELECT Given COLLATE NOCASE AS Given, Surname COLLATE NOCASE AS Surname, BirthYear, DeathYear FROM NameTable WHERE OwnerID = ($RIN) AND IsPrimary = 1"
            print $"Census records for: (ansi gb)($person.Given.0) ($person.Surname.0) \(($person.BirthYear.0) - ($person.DeathYear.0)\)(ansi reset)"

            let sqlquery = [$census_cte, "
SELECT CensusDate,
    SUBSTR(PlaceTable.Name, 1, LENGTH(PlaceTable.Name) - 15) AS Place,
    census_all.RIN, Role, census_all.PersonID
FROM census_all
JOIN EventTable ON census_all.EventID = EventTable.EventID
JOIN PlaceTable ON EventTable.PlaceID = PlaceTable.PlaceID
WHERE census_all.PersonID = ", ($RIN | into string), "
ORDER BY CensusDate"] | str join

            open $env.rmdb | query db $sqlquery
        },

        "year" => {
            if ($objects | length) == 0 {
                print $"(ansi red)Error:(ansi reset) Year parameter required. Usage: genq census year <year>"
                return
            }

            let year = try {
                $objects.0 | into int
            } catch {
                print $"(ansi red)Error:(ansi reset) Invalid year '($objects.0)'. Year must be a 4-digit integer."
                return
            }

            if $year < 1790 or $year > 1950 {
                print $"(ansi red)Error:(ansi reset) Invalid census year ($year). U.S. Federal Census years are typically 1790-1950 taken every 10 years."
                return
            }

            print $"Census records for the year: (ansi gb)($year)(ansi reset)"

            let sqlquery = [$census_cte, "
SELECT CensusDate AS Census, census_all.RIN,
    NameTable.Surname COLLATE NOCASE AS Surname,
    NameTable.Given COLLATE NOCASE AS Given,
    SUBSTR(PlaceTable.Name, 1, LENGTH(PlaceTable.Name) - 15) AS Place
FROM census_all
JOIN EventTable ON census_all.EventID = EventTable.EventID
JOIN PlaceTable ON EventTable.PlaceID = PlaceTable.PlaceID
JOIN NameTable ON NameTable.OwnerID = census_all.RIN AND NameTable.IsPrimary = 1
WHERE CensusDate = '", ($year | into string), "' AND Role = 'Head'
ORDER BY NameTable.Surname COLLATE NOCASE, NameTable.Given COLLATE NOCASE"] | str join

            open $env.rmdb | query db $sqlquery
        },

        'help' => {
            print "GenQuery Census provides the following two capabilities:\n"
            print "1. List census records for a person by RIN. Unlike RootsMagic's event search, this"
            print "   query returns an individual's Census records both as a principle role, or any"
            print "   other role.\n"
            print '2. List all census records for a given year.  This works even if the census event date '
            print "   has a precise date recorded.\n"
            print "Examples:\n"
            print '   genq census RIN 2'
            print '   genq census year 1850'
        },

        _ => {
            print "To use GenQuery Census, you must specify subcommand: RIN or year\n"
            print "Examples:\n"
            print '   genq census RIN 2'
            print '   genq census year 1850'
        }
    }
}
