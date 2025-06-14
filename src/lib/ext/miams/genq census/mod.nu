# List Census Records by RIN or Year.
@category "genq-ext-miams"
@example "List Census records for individual with RIN of 2." {genq census RIN 2} 
@example "List all Census records for 1850." {genq census year 1850} 
export def "main" [action?: string, ...objects: string] {
    match ($action | default "" | str downcase) {
        "rin" => {
            # Validate RIN parameter
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
            let person = open $env.rmdb | query db $"SELECT Given, Surname, BirthYear, DeathYear from NameTable WHERE OwnerID = ($RIN)"
            print $"Census records for: (ansi gb)($person.Given.0) ($person.Surname.0) \(($person.BirthYear.0) - ($person.DeathYear.0)\)(ansi reset)"
            # Objective: List Persons in Census Events other than the Head person.   The goal will be to combine this table with a similar table of Census Events that include the Head person.
            # -- Get People attached to Census Records
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_attached_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_attached_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventTable.EventID COLLATE NOCASE AS EventID, 
            EventTable.OwnerID AS RIN, 
            RoleName COLLATE NOCASE AS Role, 
            PersonID COLLATE NOCASE
            FROM WitnessTable 
            JOIN EventTable ON WitnessTable.EventID=EventTable.EventID
            JOIN RoleTable ON WitnessTable.Role = RoleTable.RoleID
            WHERE EventTable.EventType=18 and PersonID>0 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Get primary Census Records
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_prime_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_prime_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventID COLLATE NOCASE, 
            EventTable.OwnerID COLLATE NOCASE AS RIN, 
            'Head' AS Role, 
            EventTable.OwnerID COLLATE NOCASE AS PersonID
            FROM EventTable
            WHERE EventType=18 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Consolidate Census Records albeit with minimal supporting data
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_minimal AS select * from tmp_census_prime_minimal
            UNION ALL
            SELECT * FROM tmp_census_attached_minimal ORDER BY PersonID ASC, CensusDate ASC;"


            open $env.rmdb | query db "SELECT CensusDate, SUBSTR(PlaceTable.Name, 1, Length(PlaceTable.Name) -  15) AS Place, RIN, Role, PersonID FROM tmp_census_minimal 
            JOIN EventTable ON tmp_census_minimal.EventID=EventTable.EventID
            JOIN PlaceTable ON EventTable.PlaceID=PlaceTable.PlaceID" | where PersonID == $RIN | sort-by CensusDate
            },

        "year" => {
            # Validate year parameter
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

            # Objective: List Persons in Census Events other than the Head person.   The goal will be to combine this table with a similar table of Census Events that include the Head person.
            print $"Census records for the year: (ansi gb)($year)(ansi gb)"

            # -- Get People attached to Census Records
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_attached_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_attached_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventTable.EventID COLLATE NOCASE AS EventID, 
            EventTable.OwnerID AS RIN, 
            RoleName COLLATE NOCASE AS Role, 
            PersonID COLLATE NOCASE
            FROM WitnessTable 
            JOIN EventTable ON WitnessTable.EventID=EventTable.EventID
            JOIN RoleTable ON WitnessTable.Role = RoleTable.RoleID
            WHERE EventTable.EventType=18 and PersonID>0 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Get primary Census Records
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_prime_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_prime_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventID COLLATE NOCASE, 
            EventTable.OwnerID COLLATE NOCASE AS RIN, 
            'Head' AS Role, 
            EventTable.OwnerID COLLATE NOCASE AS PersonID
            FROM EventTable
            WHERE EventType=18 ORDER BY PersonID ASC, CensusDate ASC;"

            # -- Consolidate Census Records albeit with minimal supporting data
            open $env.rmdb | query db "DROP VIEW IF EXISTS tmp_census_minimal"
            open $env.rmdb | query db "CREATE VIEW tmp_census_minimal AS select * from tmp_census_prime_minimal
            UNION ALL
            SELECT * FROM tmp_census_attached_minimal ORDER BY PersonID ASC, CensusDate ASC;"

            open $env.rmdb | query db "SELECT CensusDate as Census, RIN, NameTable.Surname COLLATE NOCASE AS Surname, 
               NameTable.Given COLLATE NOCASE AS Given, Reverse COLLATE NOCASE AS Reverse, 
               SUBSTR(PlaceTable.Name, 1, Length(PlaceTable.Name) -  15) AS Place, Role 
            FROM tmp_census_minimal 
            JOIN EventTable ON tmp_census_minimal.EventID=EventTable.EventID
            JOIN PlaceTable ON EventTable.PlaceID=PlaceTable.PlaceID
            JOIN NameTable ON NameTable.OwnerID=RIN 
            ORDER BY Reverse ASC" | where Census == ($year | into string) and Role == "Head" | reject Reverse Role
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
            print '   genq census year 1850'},

        _ => {print "To use GenQuery Census, you must specify subcommand: RIN or year\n"
              print "Examples:\n"
              print '   genq census RIN 2'
              print '   genq census year 1850'}
        }
    }
