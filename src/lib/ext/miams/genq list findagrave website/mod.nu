# List persons with their Find a Grave website URLs, including basic person data.
@category "genq-ext-miams"
@example "List all persons who have a Find a Grave URL." {'genq list findagrave website'}
export def "main" [] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        return
    }

    print "List of persons with Find a Grave URLs."

    let sqlquery = "
        SELECT
            n.OwnerID   AS RIN,
            wt.URL,
            n.Given,
            n.Surname,
            p.BirthYear,
            p.DeathYear
        FROM URLTable wt
        JOIN PersonTable p  ON wt.OwnerID = p.PersonID
        JOIN NameTable n    ON p.PersonID = n.OwnerID AND n.IsPrimary = 1
        WHERE wt.OwnerType = 0
          AND wt.URL LIKE '%findagrave%'
        ORDER BY n.Surname COLLATE NOCASE, n.Given COLLATE NOCASE
    "
    open $env.rmdb | query db $sqlquery | startat1
}
