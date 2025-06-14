# Tabulate sources for newspapers by state.
@category "genq-ext-miams"
@example 'Display a frequency of the newspaper sources by state.' {'genq tabulate sources newspaper state'}
export def "main" [] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }
    
    print "Tabulation of source newspapers by state of publication."
    
    # Query sources directly with correct schema (based on genq list sources implementation)
    let sqlquery = "SELECT SourceID, Name as SourceName, TemplateID FROM SourceTable WHERE TemplateID = 0"
    
    let all_sources = try {
        open $env.rmdb | query db $sqlquery
    } catch { |error|
        print $"(ansi red)Error:(ansi reset) Database query failed: ($error.msg)"
        print "This might indicate database corruption or SQL compatibility issues."
        return
    }
    
    # Process sources to match original genq list sources behavior
    let newspaper_sources = ($all_sources 
        | insert AbbrevSourceName {|row| $row.SourceName}  # Use full name for now, could truncate later if needed
        | where AbbrevSourceName =~ 'Newspapers:'
        | select AbbrevSourceName 
        | sort-by AbbrevSourceName)
    
    $newspaper_sources 
    | insert state_comma {|row| $row.AbbrevSourceName | str index-of ',' | $in - 1} 
    | insert state {|row| $row.AbbrevSourceName | str substring 12..$row.state_comma} | reject AbbrevSourceName
    | reject state_comma | flatten 
    | histogram state
}