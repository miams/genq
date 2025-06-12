# List sources.
@category "genq-common"
@search-terms "Evidence Explained, First Reference Note, Subsequent Note, Source List Entry"
@example 'List Source Names, Footnotes, Short Footnotes and Bibliographies' {'genq list sources'}
export def "main" [
    --freeform (-f) # Filter to show only free form-based sources. (default)
    --all (-a) # Show all sources.
] {

let freeform = if ($freeform or not $all) { true } else { false }

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
} else { 

print "The ability to print all sources is pending."

# output an empty table to avoid an error if result is piped into subsequent commands
let emptytable = [
    [SrcID TempID SourceDate AbbrevSourceName Footnote ShortFootnote Bibliography]; # No records, just headers
]

$emptytable | flatten

}
}