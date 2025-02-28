# List events/facts.  Note: Marriage show here, but are actually reporting MRIN, not RIN.
# Purpose is completely parse the date field and also present sort-date field.

# It will also test using new documentation attributes
# It will also test loading of external modules from main code.


# Document Here
def "rmgc list event_dates" [] {

    # pos is for position in the 13 character date string
    # Date Type
    const pos1 = [
        { DateType: "Empty Date",    Code: "." }
        { DateType: "Standard Date", Code: "D" }
        { DateType: "Quarter Date",  Code: "R" } # seen with Julian/Gregorian Double Dates
        { DateType: "Quaker Date",   Code: "Q" }
        { DateType: "Text Date",     Code: "T" }
        { DateType: "Precise Date"   Code: ""  } # Not defined my RM, but seems useful type to add.
    ]
    # Single word date qualifiers 
    const pos2a = [
        { Qualifier: "Empty",  Code: ""  }   # Not defined in RM, adding this prevents empty sets where no date provided
        { Qualifier: "On",    Code: "." }    # Normal date, but "On" is implied, not printed
        { Qualifier: "Bef",   Code: "B" }
        { Qualifier: "By",    Code: "Y" }
        { Qualifier: "To",    Code: "T" }
        { Qualifier: "Until", Code: "U" }
        { Qualifier: "From",  Code: "F" }
        { Qualifier: "Since", Code: "I" }
        { Qualifier: "After", Code: "A" }
    ]

    # More complex date range qualifiers
    const pos2b = [
        {RangeLabel: "Bet/And", Code: "R"}
        {RangeLabel: "From/To", Code: "S"}
        {RangeLabel: "–",       Code: "-"}
        {RangeLabel: "Or",      Code: "O"}
    ]

    #combine both pos2 tables.
    let pos2 = $pos2a | append $pos2b | rename --column {RangeLabel: Qualifier}


    # would like to see the primary sources for people with BC dates.
    const pos3 = [
        { Era: "Empty",  Code: ""  }   # Not defined in RM, adding this prevents empty sets where no date provided
        { Era: "BC",     Code: "-"}
        { Era: "AD",     Code: "+"} 
    ]

    # pos 4-7 are YYYY

    # pos 8-9 usually month (if pos1=D) or quarters (if pos1=R)
    # including ShortName and LongName for convenience.
    const pos89 = [
        {Type: "D", Code: "DD", Number: "", ShortName: "Empty", LongName: "Empty"} # Not defined in RM, adding this prevents empty sets where no date provided
        {Type: "D", Code: "DD", Number: "00", ShortName: "NoMonth", LongName: "NoMonth"}
        {Type: "D", Code: "DD", Number: "01", ShortName: "Jan", LongName: "January"}
        {Type: "D", Code: "DD", Number: "02", ShortName: "Feb", LongName: "February"}
        {Type: "D", Code: "DD", Number: "03", ShortName: "Mar", LongName: "March"}
        {Type: "D", Code: "DD", Number: "04", ShortName: "Apr", LongName: "April"}
        {Type: "D", Code: "DD", Number: "05", ShortName: "May", LongName: "May"}
        {Type: "D", Code: "DD", Number: "06", ShortName: "Jun", LongName: "June"}
        {Type: "D", Code: "DD", Number: "07", ShortName: "Jul", LongName: "July"}
        {Type: "D", Code: "DD", Number: "08", ShortName: "Aug", LongName: "August"}
        {Type: "D", Code: "DD", Number: "09", ShortName: "Sep", LongName: "September"}
        {Type: "D", Code: "DD", Number: "10", ShortName: "Oct", LongName: "October"}
        {Type: "D", Code: "DD", Number: "11", ShortName: "Nov", LongName: "November"}
        {Type: "D", Code: "DD", Number: "12", ShortName: "Dec", LongName: "December"}
        {Type: "R", Code: "DD", Number: "01", ShortName: "Q1", LongName: "Quarter1"}
        {Type: "R", Code: "DD", Number: "02", ShortName: "Q2", LongName: "Quarter2"}
        {Type: "R", Code: "DD", Number: "03", ShortName: "Q3", LongName: "Quarter3"}
        {Type: "R", Code: "DD", Number: "04", ShortName: "Q4", LongName: "Quarter4"}
    ]

    # pos 10-11
    # Day of Month
    #  if pos1=D, then 2-digit day of month. 00 is used if day not specified.
    #  if pos1=R, then always use 00.

    # pos 12
    const pos12 = [
        {"DateType": "Empty", "Code": ""}            # Not defined in RM, adding this prevents empty sets where no date provided
        {"DateType": "Conventional", "Code": "."}   
        {"DateType": "JG Double Date", "Code": "/"}  # Julian/Gregorian Double Date 
        ]

    # pos 13
    # Date accuracy descriptors
    # wonder if this have formal definitions of when to use one versus another.
    const pos13  = [
        { Descriptor: "Empty", Code: ""  } # Not defined in RM, adding this prevents empty sets where no date provided
        { Descriptor: "",      Code: "." } # default if none of these are used.
        { Descriptor: "Maybe", Code: "?" }
        { Descriptor: "Prhps", Code: "1" }
        { Descriptor: "Appar", Code: "2" }
        { Descriptor: "Lkly",  Code: "3" }
        { Descriptor: "Poss",  Code: "4" }
        { Descriptor: "Prob",  Code: "5" }
        { Descriptor: "Cert",  Code: "6" }
        { Descriptor: "Abt",   Code: "A" }
        { Descriptor: "Ca",    Code: "C" }
        { Descriptor: "Est",   Code: "E" }
        { Descriptor: "Calc",  Code: "L" }
        { Descriptor: "Say",   Code: "S" }
    ]
    
    # Date Formats
    # 1. 10 Jan 2020
    # 2. Jan 10, 2020
    # 3. 10 January 2020
    # 4. January 10, 2020
    # 5. 10 JAN 2020
    # 6. JAN 10, 2020
    # 7. 10 JANUARY 2020
    # 8. JANUARY 10, 2020

    print "List of events/facts."
    print "Marriages list MRIN in RIN column"

  
    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "SELECT EventID, OwnerID AS RIN, Name as Event, Details as Description, Substr(Date,4,4) COLLATE NOCASE AS EventDate, Date AS FullDate, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC FROM EventTable INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType;"

    let my_dataframe = open $env.rmdb | query db $sqlquery 
    | insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"}   #LastUpdate
    | insert DateType {|row| let key = $row.FullDate | str substring 0..0                                  #DateType
        $pos1 | where Code == $key | get DateType | first}
    | insert DateQualifier {|row| let key = $row.FullDate | str substring 1..1                             #DateQualifier
        $pos2 | where Code == $key | get Qualifier.0 }
    | insert DateERA {|row| let key = $row.FullDate | str substring 2..2 
        $pos3 | where Code == $key | get Era | first }
    | insert MonthShortName {|row| let key = $row.FullDate | str substring 0..0
    if $key == "D" {let akey = $row.FullDate | str substring 7..8 
        $pos89 | where Number == $akey | get ShortName | first } else { "" }}
    | insert MonthLongName {|row| let key = $row.FullDate | str substring 0..0
    if $key == "D" {let akey = $row.FullDate | str substring 7..8 
        $pos89 | where Number == $akey | get LongName | first } else { "" }}
    | insert DayofMonth {|row| $row.FullDate | str substring 9..10 }
    | insert CalendarDate {|row| let key = $row.FullDate | str substring 11..11
        $pos12 | where Code == $key | get DateType | first}
    | insert DateDescriptor {|row| let key = $row.FullDate | str substring 12..12
        $pos13 | where Code == $key | get Descriptor | first}  
    | reject Event LastUpdate LastUpdateUTC Description | startat1

    $my_dataframe
}




#  Timing the function
#  let TotalRecords = open $env.rmdb | query db $sqlquery | length
#  let RunTime = timeit {
#  let numRunTime = $RunTime | into int
#  let floatRunTime = $numRunTime / 1000000000 
#  print $"Total Records ($TotalRecords) in ($RunTime) seconds and ($floatRunTime), ($TotalRecords / $floatRunTime) records/sec."
# }