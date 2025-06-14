# List citations. [wide]
@category "genq-common"
@example "List all citations in database." {'genq list citations'} 
export def "main" [
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
    open $env.rmdb | query db $sqlquery | startat1
}