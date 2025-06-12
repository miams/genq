# List citations. [wide]
@category "genq-common"
@example "List all citations in database." {'genq list citations'} 
export def "main" [
   ] {
    print "List of citations."

    let sql_script = [$env.genq_sql, "all-citations.sql"] | str join 
    let sqlquery = (open $sql_script)
    open $env.rmdb | query db $sqlquery | startat1
}