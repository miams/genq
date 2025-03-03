# Census
@category "rmgc-ext-miams"
export def "main" [action: string@census_action_completer, ...objects: string] {
    match $action {
        "RIN" => {
            let RIN = $objects.0 | into int 
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

            # Objective: List Persons in Census Events other than the Head person.   The goal will be to combine this table with a similar table of Census Events that include the Head person.
            let year = $objects.0
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
            ORDER BY Reverse ASC" | where Census == $year and Role == "Head" | reject Reverse Role
            },

        'help' => {
            print 'This is Census help'},
        _ => {print 'I think you need Census help.'}
        }
    }