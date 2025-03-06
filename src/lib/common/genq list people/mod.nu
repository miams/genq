# List all individuals, as well as their aliases.
@category "genq-common"
export def "main" [
] {
    print "List of individuals, as well as their aliases."
    help modules --find rmdate | get commands | flatten | flatten
    
    # Create temp Table of people consisting of only Primary Names.
    open $env.rmdb | query db "DROP TABLE IF EXISTS tmpNames"
    open $env.rmdb | query db "CREATE TABLE tmpNames AS SELECT OwnerID, Given COLLATE NOCASE, Surname COLLATE NOCASE, BirthYear, DeathYear FROM NameTable WHERE IsPrimary=1"
    # Create another temp Table of people joining with personTable
    open $env.rmdb | query db "DROP TABLE IF EXISTS tmpFullNames"
    open $env.rmdb | query db "CREATE TABLE tmpFullNames AS SELECT DISTINCT OwnerID as RIN, Given COLLATE NOCASE, Surname COLLATE NOCASE, CASE WHEN Sex = 1 THEN 'F' ELSE 'M' END as Sex, BirthYear, DeathYear, ParentID, SpouseID, Note as PersonNote FROM tmpNames INNER JOIN PersonTable ON tmpNames.OwnerID=PersonTable.PersonID"

    open $env.rmdb | query db "SELECT * FROM tmpFullNames" | select RIN Given Surname Sex BirthYear DeathYear | startat1
}

# @example "list all people" {
#     genq list people
# } 