# List families.
@category "genq-common"
@search-terms "married spouse spouses couples"
@example "list top 20 men with the most spouses." {'genq list families | where WifeOrder != 0 | sort-by FatherID WifeOrder | uniq-by FatherID --count | sort-by count --reverse | flatten | move count --before FamilyID | first 20'}
@example "list families where the relationship proof is not established." {'genq list families --proof | where Proof == ""'}
@example "list families using non-standard spouse labels (Partner, custom)." {'genq list families --labels | where FatherRole != "Husband" or MotherRole != "Wife"'}
export def "main" [
    --proof   # Include Proof column (Proven / Disproven / Disputed / blank)
    --labels  # Include FatherRole and MotherRole columns (decoded from FatherLabel/MotherLabel)
    --note    # Include Note column (family-level note text)
] {
    print "List of spouses in families"
    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "Select FamilyID, FatherID,
        Father.Given COLLATE NOCASE as FatherGiven,
        Father.Surname COLLATE NOCASE as FatherSurname,
        Father.IsPrimary as FatherIsPrimary,
        MotherID,
        Mother.Given COLLATE NOCASE as MotherGiven,
        Mother.Surname COLLATE NOCASE as MotherSurname,
        Mother.IsPrimary as MotherIsPrimary,
        HusbOrder, WifeOrder,
        CASE FamilyTable.Proof WHEN 1 THEN 'Proven' WHEN 2 THEN 'Disproven' WHEN 3 THEN 'Disputed' ELSE '' END AS Proof,
        CASE FamilyTable.FatherLabel WHEN 0 THEN 'Father' WHEN 1 THEN 'Husband' WHEN 2 THEN 'Partner' WHEN 3 THEN COALESCE(FamilyTable.FatherLabelStr, 'Other') ELSE '' END AS FatherRole,
        CASE FamilyTable.MotherLabel WHEN 0 THEN 'Mother' WHEN 1 THEN 'Wife' WHEN 2 THEN 'Partner' WHEN 3 THEN COALESCE(FamilyTable.MotherLabelStr, 'Other') ELSE '' END AS MotherRole,
        COALESCE(FamilyTable.Note, '') AS Note,
        STRFTIME(DATETIME(FamilyTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC
        FROM FamilyTable
        JOIN NameTable as Father ON FamilyTable.FatherID = Father.OwnerID
        JOIN NameTable as Mother ON FamilyTable.MotherID = Mother.OwnerID
        WHERE FatherIsPrimary AND MotherIsPrimary"

    # FamilyTable.UTCModDate can be NULL
    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-not-empty) { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"} }
        | reject LastUpdateUTC FatherIsPrimary MotherIsPrimary
    let with_proof = if $proof { $result } else { $result | reject Proof }
    let with_labels = if $labels { $with_proof } else { $with_proof | reject FatherRole MotherRole }
    let final = if $note { $with_labels } else { $with_labels | reject Note }
    $final
}