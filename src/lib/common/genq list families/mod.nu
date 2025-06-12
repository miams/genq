# List families.
@category "genq-common"
@search-terms "married spouse spouses couples"
@example "list top 20 men with the most spouses." {'genq list families | where WifeOrder != 0 | sort-by FatherID WifeOrder | uniq-by FatherID --count | sort-by count --reverse | flatten | move count --before FamilyID | first 20'}
export def "main" [
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
        HusbOrder, WifeOrder, STRFTIME(DATETIME(FamilyTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC 
        FROM FamilyTable 
        JOIN NameTable as Father ON FamilyTable.FatherID = Father.OwnerID  
        JOIN NameTable as Mother ON FamilyTable.MotherID = Mother.OwnerID 
        WHERE FatherIsPrimary AND MotherIsPrimary"
    
        # FamilyTable.UTCModDate can be NULL
    let family_dataframe = open $env.rmdb | query db $sqlquery | 
    insert LastUpdate {|row| if ($row.LastUpdateUTC | is-not-empty) { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"} }
    | reject LastUpdateUTC FatherIsPrimary MotherIsPrimary | startat1

    $family_dataframe 
}