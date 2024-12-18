# Source this script to add the commands
let rmdb = "pres2020.rmtree"
let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]

def rmgc_action_completer [] { ["updated", "list", "quality", "help" ] }
def census_action_completer [] { ["year", "RIN", "quality", "help" ] }

def rmgc [action: string@rmgc_action_completer, ...objects: string] { 
 match $action {
    "updated" => {
        if ($objects | is-empty) {
            print $'(ansi red_bold)List of recently updated records.(ansi reset)'
            print 'citations, events, find-a-grave, obits, people, sources'
            print $"(ansi yellow_bold)NO FUNCTIONALITY YET(ansi reset)\n"
        } else {
        }
    },

    "list" => {
        if ($objects | is-empty) { 
            print $'(ansi red_bold)List table of all records(ansi reset)' 
            print "citations, events, find-a-grave, obits, people, sources\n"            
         } else { 
            match $objects.0 {
                'find-a-grave' => {
                    # Objective: List a Webtags with Find a Grave enties.
                    # Notes:  
                    # It's possible to weblinks in a variety of contexts, which is stored as OwnerType in the database. For the Person context, I personally only used it for Find a Grave.

                    # Values available for OwnerType
                    # 0 = Person,
                    # 3 = Source,
                    # 4 = Citation,
                    # 5 = Place,
                    # 6 = Task,
                    # 14 = Place Details
                    # More info:  https://docs.google.com/spreadsheets/d/1VenU0idUAmkbA9kffazvj5RX_dZn6Ncn/edit?usp=sharing&ouid=104459570713722063434&rtpof=true&sd=true
                   open $rmdb | query db "select OwnerID as RIN, Name, URL, Note AS Latest_Retrival from URLTable where OwnerType=0"
                },

                'people' => {
                    # Create temp Table of people consisting of only Primary Names.
                    open $rmdb | query db "DROP TABLE IF EXISTS tmpNames"
                    open $rmdb | query db "CREATE TABLE tmpNames AS SELECT OwnerID, Given COLLATE NOCASE, Surname COLLATE NOCASE, BirthYear, DeathYear FROM NameTable WHERE IsPrimary=1"
                    # Create another temp Table of people joining with personTable
                    open $rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
                    open $rmdb | query db "CREATE TABLE tmpFullNames AS SELECT DISTINCT OwnerID as RIN, Given COLLATE NOCASE, Surname COLLATE NOCASE, CASE WHEN Sex = 1 THEN 'F' ELSE 'M' END as Sex, BirthYear, DeathYear, ParentID, SpouseID, Note as PersonNote FROM tmpNames INNER JOIN PersonTable ON tmpNames.OwnerID=PersonTable.PersonID"

                    open $rmdb | query db "SELECT * FROM tmpFullNames" | select RIN Given Surname Sex BirthYear DeathYear
                },

                'citations' => {
                    # Combine CitationTable and CitationLinkTable
                    open $rmdb | query db "DROP TABLE IF EXISTS tmpCitations"
                    open $rmdb | query db "CREATE TABLE tmpCitations AS SELECT clt.OwnerID AS PersonID, ct.CITATIONID AS CitID, ct.sourceid AS SrcID, 
                        ct.refnumber AS CitREFN, QUOTE(ct.actualtext) AS CitTxt, 
                        clt.ownertype AS OwnerType FROM citationtable ct 
                        LEFT OUTER JOIN citationlinktable clt ON ct.citationid=clt.citationid WHERE clt.ownertype=2"
                    open $rmdb | query db "SELECT * from tmpCitations" | sort-by CitREFN
                },

                'events' => {
                    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
                    let sqlquery = "SELECT EventID, OwnerID, EventTable.OwnerType, Name, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS mydate FROM EventTable INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType;"
                    let my_dataframe = open $rmdb | query db $sqlquery | 
                       insert date {|row| $row.mydate | date to-timezone local } | 
                       reject mydate | 
                       insert day {|row| $row.date | 
                       format date "%Y-%m-%d" }
                    $my_dataframe
                },

                'obits' => {
                    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
                    let sqlquery = "SELECT EventID, OwnerID, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdate 
                    FROM EventTable 
                    JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
                    WHERE EventTable.EventType = 1000 
                    AND Obituary LIKE '%Newspapers.com%' ORDER BY Newspaper ASC"

                    let my_dataframe = open $rmdb | query db $sqlquery | insert NewObit {|row|   

                    # Replace tags <b>, <i>, and <u> with actual ANSI escape codes
                    let ansi_text = $row.Obituary 
                     | str replace --all --regex '<b>(.*?)</b>' $"(ansi light_green_bold)$1(ansi reset)"          # Bold
                     | str replace --all --regex '<i>(.*?)</i>' $"(ansi light_green_italic)$1(ansi reset)"        # Italic
                     | str replace --regex '<u>(.*?)</u>' $"(ansi blue_underline)$1(ansi reset)";                 # Underline
                     $ansi_text      
                     }
                     | reject Obituary Newspaper EventID LastUpdate
                    $my_dataframe
                },

                'sources' => {
                    let sqlquery = "SELECT SourceID, Name, TemplateID,  cast(Fields AS TEXT) as Fields, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
                    FROM SourceTable"
                    let my_dataframe = open $rmdb | query db $sqlquery
                    $my_dataframe 
                },

                'sources newspapers state' => {
                    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name 
                    | insert state_comma {|row| $row.Name | str index-of ',' | $in - 1} 
                    | insert state {|row| $row.Name | str substring 12..$row.state_comma} | reject Name 
                    | reject state_comma | uniq --count | flatten | sort-by count
                },

                'sources newspapers state histogram' => {
                    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name 
                    | insert state_comma {|row| $row.Name | str index-of ',' | $in - 1} 
                    | insert state {|row| $row.Name | str substring 12..$row.state_comma} | histogram state
                }
            }
            }
        },
    'quality' => {
        print 'Perform variety of quality checks'
        print 'findagrave'
    },
    'help' => {
        print 'This is RMGC help'},
    _ => {print 'I think you need RMGC help.'}
    }
    }

def census [action: string@census_action_completer, ...objects: string] {
    match $action {
        "RIN" => {
            let RIN = $objects.0 | into int 
            let person = open $rmdb | query db $"SELECT Given, Surname, BirthYear, DeathYear from NameTable WHERE OwnerID = ($RIN)"
            print $"Census records for: (ansi gb)($person.Given.0) ($person.Surname.0) \(($person.BirthYear.0) - ($person.DeathYear.0)\)(ansi reset)"
            # Objective: List Persons in Census Events other than the Head person.   The goal will be to combine this table with a similar table of Census Events that include the Head person.
            # -- Get People attached to Census Records
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_attached_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_attached_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventTable.EventID COLLATE NOCASE AS EventID, 
            EventTable.OwnerID AS RIN, 
            RoleName COLLATE NOCASE AS Role, 
            PersonID COLLATE NOCASE
            FROM WitnessTable 
            JOIN EventTable ON WitnessTable.EventID=EventTable.EventID
            JOIN RoleTable ON WitnessTable.Role = RoleTable.RoleID
            WHERE EventTable.EventType=18 and PersonID>0 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Get primary Census Records
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_prime_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_prime_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventID COLLATE NOCASE, 
            EventTable.OwnerID COLLATE NOCASE AS RIN, 
            'Head' AS Role, 
            EventTable.OwnerID COLLATE NOCASE AS PersonID
            FROM EventTable
            WHERE EventType=18 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Consolidate Census Records albeit with minimal supporting data
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_minimal AS select * from tmp_census_prime_minimal
            UNION ALL
            SELECT * FROM tmp_census_attached_minimal ORDER BY PersonID ASC, CensusDate ASC;"


            open $rmdb | query db "SELECT CensusDate, SUBSTR(PlaceTable.Name, 1, Length(PlaceTable.Name) -  15) AS Place, RIN, Role, PersonID FROM tmp_census_minimal 
            JOIN EventTable ON tmp_census_minimal.EventID=EventTable.EventID
            JOIN PlaceTable ON EventTable.PlaceID=PlaceTable.PlaceID" | where PersonID == $RIN | sort-by CensusDate
            },

        "year" => {

            # Objective: List Persons in Census Events other than the Head person.   The goal will be to combine this table with a similar table of Census Events that include the Head person.
            let year = $objects.0
            print $"Census records for the year: (ansi gb)($year)(ansi gb)"

            # -- Get People attached to Census Records
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_attached_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_attached_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventTable.EventID COLLATE NOCASE AS EventID, 
            EventTable.OwnerID AS RIN, 
            RoleName COLLATE NOCASE AS Role, 
            PersonID COLLATE NOCASE
            FROM WitnessTable 
            JOIN EventTable ON WitnessTable.EventID=EventTable.EventID
            JOIN RoleTable ON WitnessTable.Role = RoleTable.RoleID
            WHERE EventTable.EventType=18 and PersonID>0 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Get primary Census Records
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_prime_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_prime_minimal AS SELECT Substr(EventTable.Date,4,4) COLLATE NOCASE AS CensusDate, 
            EventID COLLATE NOCASE, 
            EventTable.OwnerID COLLATE NOCASE AS RIN, 
            'Head' AS Role, 
            EventTable.OwnerID COLLATE NOCASE AS PersonID
            FROM EventTable
            WHERE EventType=18 ORDER BY PersonID ASC, CensusDate ASC;"


            # -- Consolidate Census Records albeit with minimal supporting data
            open $rmdb | query db "DROP VIEW IF EXISTS tmp_census_minimal"
            open $rmdb | query db "CREATE VIEW tmp_census_minimal AS select * from tmp_census_prime_minimal
            UNION ALL
            SELECT * FROM tmp_census_attached_minimal ORDER BY PersonID ASC, CensusDate ASC;"


            open $rmdb | query db "SELECT CensusDate as Census, RIN, NameTable.Surname COLLATE NOCASE AS Surname, NameTable.Given COLLATE NOCASE AS Given, Reverse COLLATE NOCASE AS Reverse, SUBSTR(PlaceTable.Name, 1, Length(PlaceTable.Name) -  15) AS Place, Role FROM tmp_census_minimal 
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
