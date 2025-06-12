# List sources for newspapers.
@category "genq-ext-miams"
@search-terms "Evidence Explained, First Reference Note, Subsequent Note, Source List Entry"
@example 'Filtering for only newspapers, list Source Names, Footnotes, Short Footnotes and Bibliographies' {'genq list sources newspapers | sort-by AbbrevSourceName | explore'}
export def "main" [] {
    print "List of sources of newspapers."
    let sqlquery = "SELECT SourceID as SrcID, Name as SourceName, TemplateID as TempID,  cast(Fields AS TEXT) as Fields, STRFTIME(DATETIME(UTCModDate + 2415018.5)) AS SourceDate  
    FROM SourceTable WHERE TemplateID = 0;"
    open $env.rmdb | query db $sqlquery | where SourceName =~ 'Newspapers:'  
    | insert AbbrevSourceName {|row| limit $row.SourceName ((term size).columns - 55)} 
    | insert Footnote      {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
    | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten
    | insert Bibliography  {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    | reject SourceName Fields | startat1
}