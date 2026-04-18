# List FamilySearch person ID links.
@category "genq-common"
@search-terms "FamilySearch family tree FS sync link ID"
@example "List all FamilySearch-linked persons." {'genq list familysearch-links'}
@example "List persons with a mismatch flag set." {'genq list familysearch-links | where Modified == "Y"'}
@example "List persons imported from FamilySearch." {'genq list familysearch-links | where Status == "Imported"'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (FamilySearchTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of FamilySearch linkage records."

    let sqlquery = "
        SELECT
            f.rmID AS RIN,
            COALESCE(n.Given, '') || ' ' || COALESCE(n.Surname, '') AS Name,
            f.fsID AS FamilySearchID,
            CASE WHEN f.Modified = 1 THEN 'Y' ELSE 'N' END AS Modified,
            CASE f.Status WHEN 4 THEN 'Imported' ELSE 'Linked' END AS Status,
            COALESCE(STRFTIME(DATETIME(f.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM FamilySearchTable f
        LEFT JOIN NameTable n ON n.OwnerID = f.rmID AND n.IsPrimary = 1
        ORDER BY f.rmID"

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.LastUpdateUTC | is-empty) { "" } else {
                $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
            }
        }
        | reject LastUpdateUTC

    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
