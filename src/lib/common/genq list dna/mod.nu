# List DNA matches.
@category "genq-common"
@search-terms "DNA match cM centimorgans ancestry genetics"
@example "List all DNA matches." {'genq list dna'}
@example "Show only Ancestry DNA matches." {'genq list dna | where Provider == "Ancestry"'}
@example "Find matches with more than 200 cM shared." {'genq list dna | where SharedCM > 200'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (DNATable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of DNA matches."

    let sqlquery = "
        SELECT
            d.RecID,
            d.ID1,
            COALESCE(n1.Given, '') || ' ' || COALESCE(n1.Surname, '') AS Person1,
            d.ID2,
            COALESCE(n2.Given, '') || ' ' || COALESCE(n2.Surname, '') AS Person2,
            CASE d.DNAProvider
                WHEN 1 THEN '23andMe'
                WHEN 2 THEN 'Ancestry'
                WHEN 3 THEN 'FTDNA'
                WHEN 4 THEN 'LivingDNA'
                WHEN 5 THEN 'MyHeritage'
                WHEN 6 THEN 'GEDmatch'
                ELSE 'Unknown'
            END AS Provider,
            ROUND(d.SharedCM, 1)      AS SharedCM,
            ROUND(d.SharedPercent, 2) AS SharedPct,
            d.SharedSegs,
            ROUND(d.LargeSeg, 1)      AS LargestSeg,
            d.Date,
            d.Note,
            COALESCE(STRFTIME(DATETIME(d.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM DNATable d
        LEFT JOIN NameTable n1 ON n1.OwnerID = d.ID1 AND n1.IsPrimary = 1
        LEFT JOIN NameTable n2 ON n2.OwnerID = d.ID2 AND n2.IsPrimary = 1
        ORDER BY d.SharedCM DESC"

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.LastUpdateUTC | is-empty) { "" } else {
                $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
            }
        }
        | reject LastUpdateUTC

    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
