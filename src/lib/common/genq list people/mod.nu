# List all individuals, as well as their aliases.
@category "genq-common"
export def "main" [
] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }
    
    print "List of individuals, as well as their aliases."
    
    # Create and manage temporary tables with proper cleanup
    try {
        # Create temp Table of people consisting of only Primary Names.
        open $env.rmdb | query db "DROP TABLE IF EXISTS tmpNames"
        open $env.rmdb | query db "CREATE TABLE tmpNames AS SELECT OwnerID, Given COLLATE NOCASE, Surname COLLATE NOCASE, BirthYear, DeathYear FROM NameTable WHERE IsPrimary=1"
        
        # Create another temp Table of people joining with personTable
        open $env.rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
        open $env.rmdb | query db "CREATE TABLE tmpFullNames AS SELECT DISTINCT OwnerID as RIN, Given COLLATE NOCASE, Surname COLLATE NOCASE, CASE WHEN Sex = 1 THEN 'F' ELSE 'M' END as Sex, BirthYear, DeathYear, ParentID, SpouseID, Note as PersonNote FROM tmpNames INNER JOIN PersonTable ON tmpNames.OwnerID=PersonTable.PersonID"

        # Execute query and return results
        let result = (open $env.rmdb | query db "SELECT * FROM tmpFullNames" | select RIN Given Surname Sex BirthYear DeathYear | startat1)
        
        # Clean up temporary tables after successful execution
        try {
            open $env.rmdb | query db "DROP TABLE IF EXISTS tmpNames"
            open $env.rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
        } catch {
            # Ignore cleanup errors - tables may not exist
        }
        
        $result
    } catch { |error|
        # Clean up temporary tables even if query failed
        try {
            open $env.rmdb | query db "DROP TABLE IF EXISTS tmpNames"
            open $env.rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
        } catch {
            # Ignore cleanup errors - tables may not exist
        }
        
        print $"(ansi red)Error:(ansi reset) Database query failed: ($error.msg)"
        print "This might indicate database corruption or insufficient permissions."
    }
}

# @example "list all people" {
#     genq list people
# } 