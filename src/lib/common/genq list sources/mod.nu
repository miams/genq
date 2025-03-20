# List sources.
@category "genq-common"
export def "main" [
    --freeform (-f) # Filter to show only free form-based sources. (default)
] {

if $freeform {
    print "List of sources."
    let sqlquery = "SELECT SourceID as SrcID, Name as SourceName, TemplateID as TempID,  cast(Fields AS TEXT) as Fields, STRFTIME(DATETIME(UTCModDate + 2415018.5)) AS SourceDate  
    FROM SourceTable WHERE TemplateID = 0;"
    open $env.rmdb | query db $sqlquery 
    | insert AbbrevSourceName {|row| limit $row.SourceName ((term size).columns - 55)} 
    | insert Footnote      {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
    | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten
    | insert Bibliography  {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    | reject SourceName Fields | startat1
}
}
# | move AbbrevSourceName --after SrcID