# Tabulate sources by label/tag
@category "genq-ext-miams"
export def "main" [] {
    print "Tabulation of sources by their label/tag (part before :)."
    let sqlquery = "SELECT SourceID, Name, TemplateID, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
    FROM SourceTable"
    open $env.rmdb | query db $sqlquery 
    | insert source_tag_pos {|row| $row.Name | str index-of ':' | $in - 1}
    | insert SourceTag {|row| $row.Name | if $row.source_tag_pos < 0 { '*No Tag*' } else { str substring 0..$row.source_tag_pos }}
    | insert NameTruncated {|row| $row.Name | str substring 0..30}
    | reject Name source_tag_pos
    | move SourceTag --after SourceID
    | move NameTruncated --after SourceTag 
    | startat1
    | histogram SourceTag
}