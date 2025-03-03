# Tabulate sources for newspapers by state.
@category "rmgc-ext-miams"
export def "main" [] {
    print "Tabulation of source newspapers by state of publication." 
    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name 
    | insert state_comma {|row| $row.Name | str index-of ',' | $in - 1} 
    | insert state {|row| $row.Name | str substring 12..$row.state_comma} | reject Name 
    | reject state_comma | flatten 
    | histogram state
}