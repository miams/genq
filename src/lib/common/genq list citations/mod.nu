# List citations. [wide]
@category "genq-common"
export def "main" [
    --flag1 # Info 1
    --flag2 # Info 2
   ] {
    print "List of citations."

    let sql_script = [$env.genq_sql, "all-citations.sql"] | str join 
    let sqlquery = (open $sql_script)
    open $env.rmdb | query db $sqlquery | startat1
}