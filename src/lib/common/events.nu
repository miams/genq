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
    ]
    # Single word date qualifiers 
    let pos2a = [
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

    # would like to see the primary sources for people with BC dates.
    const pos3 = [
        { Era: "BC", Code: "-"}
        { Era: "AD", Code: "+"} 
    ]

    # pos 4-7 are YYYY

    # pos 8-9 usually month (if pos1=D) or quarters (if pos1=R)
    # including ShortName and FullName for convenience.
    const pos89 = [
        {Type: "D", Code: "DD", Number: "00", ShortName: "NoMonth", FullName: "NoMonth"}
        {Type: "D", Code: "DD", Number: "01", ShortName: "Jan", FullName: "January"}
        {Type: "D", Code: "DD", Number: "02", ShortName: "Feb", FullName: "February"}
        {Type: "D", Code: "DD", Number: "03", ShortName: "Mar", FullName: "March"}
        {Type: "D", Code: "DD", Number: "04", ShortName: "Apr", FullName: "April"}
        {Type: "D", Code: "DD", Number: "05", ShortName: "May", FullName: "May"}
        {Type: "D", Code: "DD", Number: "06", ShortName: "Jun", FullName: "June"}
        {Type: "D", Code: "DD", Number: "07", ShortName: "Jul", FullName: "July"}
        {Type: "D", Code: "DD", Number: "08", ShortName: "Aug", FullName: "August"}
        {Type: "D", Code: "DD", Number: "09", ShortName: "Sep", FullName: "September"}
        {Type: "D", Code: "DD", Number: "10", ShortName: "Oct", FullName: "October"}
        {Type: "D", Code: "DD", Number: "11", ShortName: "Nov", FullName: "November"}
        {Type: "D", Code: "DD", Number: "12", ShortName: "Dec", FullName: "December"}
        {Type: "R", Code: "DD", Number: "01", ShortName: "Q1", FullName: "Quarter1"}
        {Type: "R", Code: "DD", Number: "02", ShortName: "Q2", FullName: "Quarter2"}
        {Type: "R", Code: "DD", Number: "03", ShortName: "Q3", FullName: "Quarter3"}
        {Type: "R", Code: "DD", Number: "04", ShortName: "Q4", FullName: "Quarter4"}
    ]

    # pos 10-11
    # Day of Month
    #  if pos1=D, then 2-digit day of month. 00 is used if day not specified.
    #  if pos1=R, then always use 00.

    # pos 12
    const pos12 = [
        {"Date Type": "Normal", "Code": "."}   
        {"Date Type": "Julian/Gregorian Double Date", "Code": "/"}
        ]

    # pos 13
    # Date accuracy descriptors
    # wonder if this have formal definitions of when to use one versus another.
    const pos13  = [
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
    
    print "List of events/facts."
    print "Marriages list MRIN in RIN column"

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "SELECT EventID, OwnerID AS RIN, Name as Event, Details as Description, Substr(Date,4,4) COLLATE NOCASE AS EventDate, Date AS FullDate, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC FROM EventTable INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType;"

    let my_dataframe = open $env.rmdb | query db $sqlquery 
    | insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"}
    | insert DateType {|row| let key = $row.FullDate | str substring 0..0 
        $pos1 | where Code == $key | get DateType | first}
    | insert DateQualifier {|row| let key = $row.FullDate | str substring 1..1 | default "0"
        $pos2a | where Code == $key | get Qualifier | default ["Range or None"] }
    | reject LastUpdateUTC Description | startat1

 # | insert DateType {|row| $row.FullDate | str substring 0..1 | into string | do {$pos1 | get $in} }

    #$pos1 | where Position1 == ($row.FullDate | str substring 0..1) | get Function | default "Unknown Date Type"

    $my_dataframe 


}

 #  | insert DateType {|row| $row.FullDate | str substring 0..0  | do {$pos1 | where Code == "." | get DateType} $in }