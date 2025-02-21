# Source this script to add the commands

let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]
$env.SurnameGroup = [Iams, Iames, Iiams, Iiames, Ijams, Ijames, Imes, Eimes]

def rmgc_action_completer [] { ["review-updates", "list", "tabulate", "assess", "help" ] }
def list_action_completer [] { ["find-a-grave", "people", "citations", "events", "obit"]}
def census_action_completer [] { ["year", "RIN", "quality", "help" ] }
# RMGC generates tabular reports from the RootsMagic database.
export def rmgc [
    action: string@rmgc_action_completer,  # action command [updates, list, quality, help]
    ...objects: string  # additional directives, options vary based on action command
  #
  #Examples:
  #
  #  List all 1880 census events
  #  > rmgc list census year 1880
  #
  #  List all citations
  #  > rmgc list citations
  #
  #  List obituaries
  #  > rmgc list obits
  #
  #  Generate a histogram or obituary events created, by month
  #  > rmgc list obit_sum | insert yyyy_mm {|row| $row.LastUpdate | str substring 0..6} | histogram yyyy_mm | sort-by yyyy_mm

    ] {
 match $action {
    "review-updates" => {
        if ($objects | is-empty) {
            print $'(ansi red_bold)List of recently updated records.(ansi reset)'
            print 'citations, events, find-a-grave, obits, people, sources'
            print $"(ansi yellow_bold)NO FUNCTIONALITY YET(ansi reset)\n"
        } else {
        }
    },
    "list" => {
        let mylist = "find-a-grave people citations events obit"
        list ($mylist)
        },
    'assess' => {
        print $'(ansi red_bold)Perform variety of data quality checks for consistency and completeness.(ansi reset)'
        print 'rmgc assess consistency findagrave'
        print 'rmgc assess consistency sources'
        print 'rmgc assess citation-breadth'
        print 'rmgc assess citation-coverage'
        print $"(ansi yellow_bold)NOT FUNCTIONAL YET - EVALUATION PHASE(ansi reset)\n"
    },
    'tabulate' => {
        print $'(ansi red_bold)Generate tabulated reports summarizing data. (ansi reset)'
        print 'rmgc assess consistency findagrave'
        print 'rmgc assess consistency sources'
        print 'rmgc assess citation-breadth'
        print 'rmgc assess citation-coverage'
        print $"(ansi yellow_bold)NOT FUNCTIONAL YET - EVALUATION PHASE(ansi reset)\n"
    },
    'help' => {
       print "DESCRIPTION" 
       let printstr = "RMGC is an open-source, third-party RootsMagic reporting engine for use in the terminal. RMGC is designed to let you quickly and easily pull data from your RootsMagic database. RMGC is built on top of Nushell, a new kind of shell for OS X, Linux, and Windows. Unlike traditional shells such as bash, zsh or Powershell, Nushell uses structured data allowing for powerful but simple pipelines. It enables users to easily analyze and process data using easier more readable commands.\n"
       wrap-text $printstr (term size).columns
       print "At its core, RMGC uses SQL (Structured Queried Language) to query RootsMagics SQLite database. In most cases, RMGC removes the need to deal with SQL complexity.  RMGC leverages its library of internal and third-party SQL queries to extract data. From there, you are able to access a rich set of Nushell commands to personalize your data analysis and reports to your individual needs." 
       },
    _ => {print 'I think you need RMGC help.'}
    }
}  

# List a variety of RootsMagic records.
def "rmgc list" [] {
    print "List a variety of RootsMagic record types."
}

# Generate tabulated reports summarizing data. 
def "rmgc tabulate" [] {
    print "Generate tabulated reports summarizing data. "
}

# List person Webtags named of "Find a Grave."
def "rmgc list find-a-grave" [] {
    print "List of Find a Grave entries."

    # List of Find-a-Grave entries.

    # print "List of Find-a-Grave entries."
    # Objective: List Webtags with Find a Grave entries.
    # Notes:  
    # It's possible to use Webtags in a variety of contexts, which is stored as OwnerType in the database. For the Person context, I personally only used it for Find a Grave.

    # Values available for OwnerType
    # 0 = Person,
    # 3 = Source,
    # 4 = Citation,
    # 5 = Place,
    # 6 = Task,
    # 14 = Place Details
    # More info:  https://docs.google.com/spreadsheets/d/1VenU0idUAmkbA9kffazvj5RX_dZn6Ncn/edit?usp=sharing&ouid=104459570713722063434&rtpof=true&sd=true 
    
    let sqlquery = "select OwnerID as RIN, Name, URL, Note AS Retrieved, STRFTIME(DATETIME(UTCModDate + 2415018.5)) AS LastUpdate from URLTable where OwnerType=0"
    print $sqlquery
    open $env.rmdb | query db $sqlquery | startat1
}

# List events/facts.
@category "rmgc-common"
@search-terms "MRIN"
@example "list the 10 most recent facts/events added to the database" {
    rmgc list events | sort-by LastUpdate | last 10
} 
@example "another list the 10 most recent facts/events added to the database" {
    rmgc list events | sort-by LastUpdate | last 10
} 
def "rmgc list events" [] {
    # Note: Marriage events show here, but they are reporting MRIx, not RIN.
    print "List of events/facts."
    print "Marriages list MRIN in RIN column"

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "SELECT EventID, OwnerID AS RIN, Name as Event, Details as Description, 
      Substr(Date,4,4) COLLATE NOCASE AS EventDate, 
      STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC 
    FROM EventTable 
    INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
    JOIN NameTable ON NameTable.OwnerID = EventTable.OwnerID
    WHERE EventTable.EventType=18 ORDER BY PersonID ASC, CensusDate ASC;"

    let my_dataframe = open $env.rmdb | query db $sqlquery | 
    insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"}
    | reject LastUpdateUTC | startat1

    $my_dataframe 
}

# List families.
@category "rmgc-common"
def "rmgc list families" [] {
    print "List of spouses in families"

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "Select FamilyID, FatherID, 
        Father.Given COLLATE NOCASE as FatherGiven, 
        Father.Surname COLLATE NOCASE as FatherSurname, 
        Father.IsPrimary as FatherIsPrimary,
        MotherID, 
        Mother.Given COLLATE NOCASE as MotherGiven, 
        Mother.Surname COLLATE NOCASE as MotherSurname, 
        Mother.IsPrimary as MotherIsPrimary,
        HusbOrder, WifeOrder, STRFTIME(DATETIME(FamilyTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC 
        FROM FamilyTable 
        JOIN NameTable as Father ON FamilyTable.FatherID = Father.OwnerID  
        JOIN NameTable as Mother ON FamilyTable.MotherID = Mother.OwnerID 
        WHERE FatherIsPrimary AND MotherIsPrimary"
    
    let family_dataframe = open $env.rmdb | query db $sqlquery | 
    insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"}
    | reject LastUpdateUTC | startat1

    $family_dataframe 
}


# List citations. [wide]
#
# index:      Row Counter
# LinkiD:     Link identification number (CitationLinkTable)
# CitID:      Link to CitationTable.CitationID (CitationLinkTable)
# SrcID:      Source Identification Number (SourceTable)
# RIN:        Link to PersonTable.PersonID aka RIN (NameTable)
# Uniq:       IsPrimary - Primary Name (1) or Alternate Name (0) (NameTable)
# Surname:    Surname (NameTable)
# Sfx:        Suffix (NameTable)
# Pfx:        Prefix (NameTable)
# Givens:     Given Name (NameTable)
# Born:       Birth Year (NameTable)
# Died:       Death Year (NameTable)
# Citer:      Union of 'Personal', 'Spouse', 'Alternate Name' with Name (FactTypeTable)    
# Source:     Name (SourceTable)
# SrcREFN:    Source Ref. # (SourceTable)
# SrcTxt:     ActualText (SourceTable)
# SrcComment: Comments (SourceTable)
# CitREFN:    Reference Number (CitationTable)
# CitTxt:     ActualText (CitationTable)
# CitComment: Comments (CitationTable)

# List citations. [wide]
@category "rmgc-common"
def "rmgc list citations" [
    --flag1 # Info 1
    --flag2 # Info 2
   ] {
    print "List of citations."

    let sql_script = [$env.rmgc_sql, "all-citations.sql"] | str join 
    let sqlquery = (open $sql_script)
    open $env.rmdb | query db $sqlquery | startat1
}


# List of full obituaries from Newspapers.com
@category "rmgc-ext-miams"
def "rmgc list obits" [] {
    print "List of obituaries from Newspapers.com with transcriptions."

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
    let sqlquery = "SELECT EventID, OwnerID as RIN, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdate 
    FROM EventTable 
    JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
    WHERE EventTable.EventType = 1000 
    AND Obituary LIKE '%Newspapers.com%' ORDER BY Newspaper ASC"

    let my_dataframe = open $env.rmdb | query db $sqlquery | insert NewObit {|row|   

    # Replace tags <b>, <i>, and <u> with actual ANSI escape codes
    let ansi_text = $row.Obituary 
        | str replace --all --regex '<b>(.*?)</b>' $"(ansi light_green_bold)$1(ansi reset)"          # Bold
        | str replace --all --regex '<i>(.*?)</i>' $"(ansi light_green_italic)$1(ansi reset)"        # Italic
        | str replace --regex '<u>(.*?)</u>' $"(ansi blue_underline)$1(ansi reset)";                 # Underline
        $ansi_text      
        }
        | sort-by LastUpdate
        | reject Obituary Newspaper EventID LastUpdate
        | startat1

    $my_dataframe
}


# List summary of obituaries from Newspapers.com.
@category "rmgc-ext-miams"
def "rmgc list obits sum" [] {
  print "List summaries of obituaries."

  $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
  let sqlquery = "SELECT EventID, OwnerID as RIN, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) AS LastUpdate 
  FROM EventTable 
  JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
  WHERE EventTable.EventType = 1000 
  AND Obituary LIKE '%Newspapers.com%' ORDER BY Newspaper ASC"

  let my_dataframe = open $env.rmdb | query db $sqlquery 
      | sort-by LastUpdate
      | reject Obituary
      | startat1

  $my_dataframe

}


# List summary of all obituaries.
@category "rmgc-ext-miams"
def "rmgc list obits sum all" [] {
   print "List summaries of all obituaries."

   $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
   let sqlquery = "SELECT EventID, OwnerID as RIN, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) AS LastUpdate 
   FROM EventTable 
   JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
   WHERE EventTable.EventType = 1000" 
   let my_dataframe = open $env.rmdb | query db $sqlquery 
    | sort-by LastUpdate
    | reject Obituary
    | startat1

   $my_dataframe
}


# List all individuals, as well as their aliases.
@category "rmgc-common"
@example "list al people" {
    rmgc list people
} 
def "rmgc list people" [
] {
    print "List of individuals, as well as their aliases."
    # Create temp Table of people consisting of only Primary Names.
    open $env.rmdb | query db "DROP TABLE IF EXISTS tmpNames"
    open $env.rmdb | query db "CREATE TABLE tmpNames AS SELECT OwnerID, Given COLLATE NOCASE, Surname COLLATE NOCASE, BirthYear, DeathYear FROM NameTable WHERE IsPrimary=1"
    # Create another temp Table of people joining with personTable
    open $env.rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
    open $env.rmdb | query db "CREATE TABLE tmpFullNames AS SELECT DISTINCT OwnerID as RIN, Given COLLATE NOCASE, Surname COLLATE NOCASE, CASE WHEN Sex = 1 THEN 'F' ELSE 'M' END as Sex, BirthYear, DeathYear, ParentID, SpouseID, Note as PersonNote FROM tmpNames INNER JOIN PersonTable ON tmpNames.OwnerID=PersonTable.PersonID"

    open $env.rmdb | query db "SELECT * FROM tmpFullNames" | select RIN Given Surname Sex BirthYear DeathYear | startat1
 
}

# List sources.
@category "rmgc-common"
def "rmgc list sources" [
    --template (-t) # Filter to show only template-based sources.
    --free-form (-f) # Filter to show only free form-based sources.
    --all (-a) # No filtering - show all sources. (default)
] {
    print "List of sources."
    let sqlquery = "SELECT SourceID, Name, TemplateID,  cast(Fields AS TEXT) as Fields, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
    FROM SourceTable"
    open $env.rmdb | query db $sqlquery 
 #   | insert Footnote {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
 #   | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten 
 #   | insert Bibliography {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    | reject Fields | startat1
}


# List sources for Federal census records. [wide]
@category "rmgc-tbd"
def "rmgc list sources census" [] {
    print "List of sources for Federal census records (1790-1950)."
    # | insert Footnote {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
    # | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten 
    # | insert Bibliography {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    # | reject Fields | startat1
}


# List sources for newspapers.
@category "rmgc-ext-miams"
def "rmgc list sources newspapers" [] {
    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name | startat1
}


# Tabulate sources for newspapers by state.
@category "rmgc-ext-miams"
def "rmgc tabulate sources newspaper state" [] {
    print "Tabulation of source newspapers by state of publication." 
    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name 
    | insert state_comma {|row| $row.Name | str index-of ',' | $in - 1} 
    | insert state {|row| $row.Name | str substring 12..$row.state_comma} | reject Name 
    | reject state_comma | flatten 
    | histogram state

}

# Tabulate sources by label/tag
@category "rmgc-ext-miams"
def "rmgc tabulate sources labels" [] {
    print "Tabulation of sources by their label/tag (part before :)."
    let sqlquery = "SELECT SourceID, Name, TemplateID, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
    FROM SourceTable"
    open $env.rmdb | query db $sqlquery 
    | insert source_tag_pos {|row| $row.Name | str index-of ':' | $in - 1}
    | insert SourceTag {|row| $row.Name | if $row.source_tag_pos < 0 { '*No Tag*' } else { str substring 0..$row.source_tag_pos }}
    | insert NameTruncated {|row| $row.Name | str substring 0..30}
    | reject Name source_tag_pos
    | move SourceTag --after SourceID
    | move NameTruncated --after SourceTag 
    | startat1
    | histogram SourceTag
}

# Census
@category "rmgc-ext-miams"
def census [action: string@census_action_completer, ...objects: string] {
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

# Colorize RTF strings found in RM note files.
@category "rmgc-platform"    
def colorize [tag_string: string;] {
    echo $tag_string 
    | str replace --all --regex '<b>(.*?)</b>' $"(ansi light_green_bold)$1(ansi reset)"          # Bold
    | str replace --all --regex '<i>(.*?)</i>' $"(ansi light_yellow_italic)$1(ansi reset)"       # Italic
    | str replace --regex '<u>(.*?)</u>' $"(ansi blue_underline)$1(ansi reset)"                  # Underline
    | print $in 
}

# Start index at 1 instead of default 0.
@category "rmgc-platform"  
def startat1 [] {
   enumerate | flatten | each { |row| $row | upsert index ($row.index + 1) }
}

# Word wrap, improving readability of docs.
@category "rmgc-platform"  
def wrap-text [text: string, width: int] {
    let words = $text | split row ' '
    mut line = ''
    mut result = []


    for word in $words {
        if ($line | str length) + ($word | str length) + 2 <= $width {
            # Append word to current line
            $line = if ($line | is-empty) { $word } else { $"($line) ($word)" }
        } else {
            # Save the current line and start a new one
            $result = ($result | append $line)
            $line = $word
        }
    }

    # Append the last line if it's not empty
    if not ($line | is-empty) {
        $result = ($result | append $line)
    }

    # Print wrapped text
    $result | each { |row| print $row }
}
