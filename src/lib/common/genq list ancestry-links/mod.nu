# List Ancestry TreeShare links.
@category "genq-common"
@search-terms "Ancestry TreeShare sync link ID person citation media"
@example "List all Ancestry-linked records." {'genq list ancestry-links'}
@example "List only person links." {'genq list ancestry-links | where LinkType == "Person"'}
@example "List only citation links." {'genq list ancestry-links | where LinkType == "Citation"'}
@example "List records with a change flag." {'genq list ancestry-links | where Modified == "Y"'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (AncestryTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of Ancestry TreeShare linkage records."

    let sqlquery = "
        SELECT
            a.rmID,
            CASE a.LinkType
                WHEN 0  THEN 'Person'
                WHEN 4  THEN 'Citation'
                WHEN 11 THEN 'Media'
                ELSE 'Unknown'
            END AS LinkType,
            CASE a.LinkType
                WHEN 0  THEN COALESCE(n.Given, '') || ' ' || COALESCE(n.Surname, '')
                WHEN 4  THEN COALESCE(c.CitationName, '')
                WHEN 11 THEN COALESCE(m.Caption, m.MediaFile, '')
                ELSE ''
            END AS Name,
            a.anID AS AncestryID,
            CASE WHEN a.Modified = 1 THEN 'Y' ELSE 'N' END AS Modified,
            a.Status,
            COALESCE(STRFTIME(DATETIME(a.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM AncestryTable a
        LEFT JOIN NameTable n       ON a.LinkType = 0  AND n.OwnerID    = a.rmID AND n.IsPrimary = 1
        LEFT JOIN CitationTable c   ON a.LinkType = 4  AND c.CitationID = a.rmID
        LEFT JOIN MultimediaTable m ON a.LinkType = 11 AND m.MediaID    = a.rmID
        ORDER BY a.LinkType, a.rmID"

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.LastUpdateUTC | is-empty) { "" } else {
                $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
            }
        }
        | reject LastUpdateUTC

    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
