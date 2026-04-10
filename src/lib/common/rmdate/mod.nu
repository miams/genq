# Parses RootsMagic's genealogy date fields.

# Used with Fact/Event records (possibly others).

# Parses RootsMagic's genealogy date field.
@category "genq-platform"
@search-terms "convert date Julian Gregorian"
@example "convert date that has xxx" {
    rmdate (eventdate, -f 3 ) 
} 
@example "convert date that has xxx output format " {
    rmdate (eventdate, --format 2 )
} 
export def main [
    eventdate: string       # event date read from RootsMagic
    --format(-f): int     # desired date output format, default to env.RDMF
    --verbose(-v):        # print all columns, default to false    
] {
    let empty_result = [{
        FormattedDate: ""
        SortableDate: ""
        DateType: "Empty Date"
        DateQualifier: "Empty"
        DateERA: "Empty"
        DateYear: ""
        MonthShortName: ""
        MonthLongName: ""
        DayofMonth: ""
        CalendarDate: "Empty"
        DateDescriptor: "Empty"
    }]

    let passthrough_result = {|text|
        [{
            FormattedDate: $text
            SortableDate: ""
            DateType: "Text Date"
            DateQualifier: ""
            DateERA: ""
            DateYear: ""
            MonthShortName: ""
            MonthLongName: ""
            DayofMonth: ""
            CalendarDate: ""
            DateDescriptor: ""
        }]
    }

    if ($eventdate | is-empty) or $eventdate == "." {
        return $empty_result
    }

    let rm_prefixes = [D R Q T .]
    let first_char = ($eventdate | str substring 0..0)
    if (($eventdate | str length) < 13) or not ($rm_prefixes | any {|p| $p == $first_char }) {
        return (do $passthrough_result $eventdate)
    }

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

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
#    let sqlquery = "SELECT EventID, OwnerID AS RIN, Name as Event, Details as Description, Substr(Date,4,4) COLLATE NOCASE AS EventDate, Date AS FullDate, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC FROM EventTable INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType;"

#    let eventdate = "D.+17910213..+00000000.."
#    print $eventdate
    
    let key = $eventdate | str substring 0..0 
    let $DateType = $pos1 | where Code == $key | get DateType | first
    
    let key = $eventdate | str substring 1..1 
    let $DateQualifier = $pos2 | where Code == $key | get Qualifier.0

    let key = $eventdate| str substring 2..2 
    let $DateERA = $pos3 | where Code == $key | get Era | first 

    let DateYear = $eventdate| str substring 3..6 

    let key = $eventdate | str substring 0..0
    let MonthShortName = if $key == "D" {let akey = $eventdate | str substring 7..8 
       $pos89 | where Number == $akey | get ShortName | first } else { "" }

    let key = $eventdate | str substring 0..0
    let MonthLongName = if $key == "D" {let akey = $eventdate | str substring 7..8 
       $pos89 | where Number == $akey | get LongName | first } else { "" }

    let DayofMonth = $eventdate | str substring 9..10 

    let key = $eventdate | str substring 11..11
    let CalendarDate = $pos12 | where Code == $key | get DateType | first 

    let key = $eventdate | str substring 12..12
    let DateDescriptor = $pos13 | where Code == $key | get Descriptor | first

    # if date format not specified in parameter, default to $env.RDMF
    # $env.RDMF = random int 1..8
    mut format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }
    
    # Compute fully formatted date.   
    let printDateQualifier = if $DateQualifier != "On" {$"($DateQualifier) "} else {""}  # On is assumed by default, only print if not On
    let printDayofMonth = if $DayofMonth != "00" {$"($DayofMonth)"} else {""}  #only print if not 00
    mut printMonth = match $format {
        1 => {$"($MonthShortName)" }
        2 => {$"($MonthShortName)" }
        3 => {$"($MonthLongName)" }
        4 => {$"($MonthLongName)" }
        5 => {$"($MonthShortName)" | str upcase}
        6 => {$"($MonthShortName)" | str upcase}
        7 => {$"($MonthLongName)" | str upcase}
        8 => {$"($MonthLongName)" | str upcase}}
    
    mut printDayMonthOrder = if $format mod 2 == 0 { $"($printMonth) ($printDayofMonth), "} else  { $"($printDayofMonth) ($printMonth) "}
    mut printDayMonthOrder = if $MonthShortName == "NoMonth" {""} else {$printDayMonthOrder} # if no month, don't print it.
    mut printDayMonthOrder = if $MonthShortName != "NoMonth" and $DayofMonth == "00" {$"($printMonth) "} else {$printDayMonthOrder} # if no day, print just month.

    let printDateERA = if $DateERA != "AD" {" BC"} else {""}  # AD is assumed by default, only print if BC
    let printDateDescriptor = if $DateDescriptor != "" {$"($DateDescriptor) "} else {""}  # only print (and pad with space) if not empty
    let FormattedDate = if $DateType != "Empty Date" { [$printDateDescriptor, $printDateQualifier, $printDayMonthOrder, $DateYear, $printDateERA] | str join  } else {''}
  
     let SortableDate = if $DateType != "Empty Date" { 
        if $MonthShortName == "NoMonth" and $DayofMonth == "00" {$"01 Jan ($DateYear)" | into datetime | format date '%F'} else {
        if $MonthShortName != "NoMonth" and $DayofMonth == "00" {$"01 ($MonthShortName) ($DateYear)" | into datetime | format date '%F'} else {
        $"($printDayMonthOrder) ($DateYear)" | into datetime | format date '%F'}}} else {''}
    
    mut my_dataframe = [{'FormattedDate': $"($FormattedDate)" }]
    $my_dataframe | insert "SortableDate" $SortableDate | insert "DateType" $DateType | insert "DateQualifier" $DateQualifier | insert "DateERA" $DateERA | insert "DateYear" $DateYear | insert "MonthShortName" $MonthShortName | insert "MonthLongName" $MonthLongName | insert "DayofMonth" $DayofMonth  | insert "CalendarDate" $CalendarDate | insert "DateDescriptor" $DateDescriptor
   # $my_dataframe | insert "DateType" $DateType | insert "DateQualifier" $DateQualifier | insert "DateERA" $DateERA | insert "DateYear" $DateYear | insert "MonthShortName" $MonthShortName | insert "MonthLongName" $MonthLongName | insert "DayofMonth" $DayofMonth  | insert "CalendarDate" $CalendarDate | insert "DateDescriptor" $DateDescriptor
}

# Parse a RootsMagic date string and return the single parsed date record.
export def "parse-rm-date" [
    eventdate: string       # RootsMagic date string
    --format(-f): int       # desired date output format, defaults to $env.RDMF or 1
] {
    if ($format | is-empty) {
        main $eventdate | first
    } else {
        main $eventdate --format $format | first
    }
}

# Format a RootsMagic date string for display.
def "fast-format-rm-date" [
    eventdate: string       # RootsMagic date string
    date_format: int        # desired date output format
] {
    if ($eventdate | is-empty) or $eventdate == "." {
        return { FormattedDate: "", SortableDate: "", IsFast: true }
    }

    let is_standard_date = (
        (($eventdate | str length) >= 13)
        and (($eventdate | str substring 0..0) == "D")
        and (($eventdate | str substring 2..2) == "+")
    )

    if not $is_standard_date {
        return { FormattedDate: "", SortableDate: "", IsFast: false }
    }

    let qualifier_code = ($eventdate | str substring 1..1)
    let descriptor_code = ($eventdate | str substring 12..12)
    let qualifier = match $qualifier_code {
        "." => ""
        "B" => "Bef "
        "Y" => "By "
        "T" => "To "
        "U" => "Until "
        "F" => "From "
        "I" => "Since "
        "A" => "After "
        "R" => "Bet/And "
        "S" => "From/To "
        "-" => "– "
        "O" => "Or "
        _ => null
    }
    let descriptor = match $descriptor_code {
        "." => ""
        "?" => "Maybe "
        "1" => "Prhps "
        "2" => "Appar "
        "3" => "Lkly "
        "4" => "Poss "
        "5" => "Prob "
        "6" => "Cert "
        "A" => "Abt "
        "C" => "Ca "
        "E" => "Est "
        "L" => "Calc "
        "S" => "Say "
        _ => null
    }

    if ($qualifier == null) or ($descriptor == null) {
        return { FormattedDate: "", SortableDate: "", IsFast: false }
    }

    let year = ($eventdate | str substring 3..6)
    let month_num = ($eventdate | str substring 7..8)
    let day = ($eventdate | str substring 9..10)

    if $month_num == "00" {
        return {
            FormattedDate: $"($descriptor)($qualifier)($year)"
            SortableDate: $"($year)-01-01"
            IsFast: true
        }
    }

    let month_int = ($month_num | into int)
    if ($month_int < 1) or ($month_int > 12) {
        return { FormattedDate: "", SortableDate: "", IsFast: false }
    }

    let month_index = ($month_int - 1)
    let month_short = ([Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec] | get $month_index)
    let month_long = ([January February March April May June July August September October November December] | get $month_index)
    let month = match $date_format {
        1 | 2 => $month_short
        3 | 4 => $month_long
        5 | 6 => ($month_short | str upcase)
        7 | 8 => ($month_long | str upcase)
        _ => $month_short
    }

    if $day == "00" {
        return {
            FormattedDate: $"($descriptor)($qualifier)($month) ($year)"
            SortableDate: $"($year)-($month_num)-01"
            IsFast: true
        }
    }

    let day_month_year = if ($date_format mod 2) == 0 {
        $"($month) ($day), ($year)"
    } else {
        $"($day) ($month) ($year)"
    }

    {
        FormattedDate: $"($descriptor)($qualifier)($day_month_year)"
        SortableDate: $"($year)-($month_num)-($day)"
        IsFast: true
    }
}

# Format a RootsMagic date string for display.
export def "format-rm-date" [
    eventdate: string       # RootsMagic date string
    --format(-f): int       # desired date output format, defaults to $env.RDMF or 1
] {
    mut date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }

    let fast_date = (fast-format-rm-date $eventdate $date_format)
    if $fast_date.IsFast {
        return $fast_date.FormattedDate
    }

    let parsed = if ($format | is-empty) {
        parse-rm-date $eventdate
    } else {
        parse-rm-date $eventdate --format $format
    }

    $parsed.FormattedDate
}

# Format a RootsMagic date string and return display + sortable dates.
export def "format-sort-rm-date" [
    eventdate: string       # RootsMagic date string
    --format(-f): int       # desired date output format, defaults to $env.RDMF or 1
] {
    mut date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }

    let fast_date = (fast-format-rm-date $eventdate $date_format)
    if $fast_date.IsFast {
        return {
            FormattedDate: $fast_date.FormattedDate
            SortableDate: $fast_date.SortableDate
        }
    }

    let parsed = if ($format | is-empty) {
        parse-rm-date $eventdate
    } else {
        parse-rm-date $eventdate --format $format
    }

    {
        FormattedDate: $parsed.FormattedDate
        SortableDate: $parsed.SortableDate
    }
}

# Upsert formatted display and optional sort columns from a raw RootsMagic date column.
export def "upsert-rm-date" [
    raw_column: string      # input column containing the raw RootsMagic date string
    display_column: string  # output column for the formatted date
    sort_column?: string    # optional output column for SortableDate
    --format(-f): int       # desired date output format, defaults to $env.RDMF or 1
] {
    $in | each {|row|
        let eventdate = ($row | get --optional $raw_column | default "")
        if ($sort_column | is-empty) {
            let display_date = if ($format | is-empty) {
                format-rm-date $eventdate
            } else {
                format-rm-date $eventdate --format $format
            }
            $row | upsert $display_column $display_date
        } else {
            let formatted = if ($format | is-empty) {
                format-sort-rm-date $eventdate
            } else {
                format-sort-rm-date $eventdate --format $format
            }
            $row | upsert $display_column $formatted.FormattedDate | upsert $sort_column $formatted.SortableDate
        }
    }
}
