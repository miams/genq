# Tabulate sources for newspapers by state.
@category "genq-ext-miams"
@example 'Display a frequency of the newspaper sources by state.' {'genq tabulate sources newspaper state'}
export def "main" [] {
    print "Tabulation of source newspapers by state of publication." 
    genq list sources | where AbbrevSourceName =~ 'Newspapers:' | select AbbrevSourceName | sort-by AbbrevSourceName 
    | insert state_comma {|row| $row.AbbrevSourceName | str index-of ',' | $in - 1} 
    | insert state {|row| $row.AbbrevSourceName | str substring 12..$row.state_comma} | reject AbbrevSourceName
    | reject state_comma | flatten 
    | histogram state
}