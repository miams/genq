# List citations. [wide]
@category "genq-common"
@example "List all citations in database." {'genq list citations'}
@example "List citations with modification dates." {'genq list citations --mod-date'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (CitationTable.UTCModDate)
] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }
    
    print "List of citations."

    let sql_script = [$env.genq_sql, "all-citations.sql"] | path join 
    
    # Validate SQL file exists
    if not ($sql_script | path exists) {
        print $"(ansi red)Error:(ansi reset) SQL file not found: ($sql_script)"
        print "This usually indicates a GenQuery installation problem."
        return
    }
    
    let sqlquery = (open $sql_script)
    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.CitUTCModDate | is-empty) { "" } else { $row.CitUTCModDate | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" }
        }
        | reject CitUTCModDate
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}