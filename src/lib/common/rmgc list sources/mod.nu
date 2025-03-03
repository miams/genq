# List sources.
@category "rmgc-common"
export def "main" [
    --template (-t) # Filter to show only template-based sources.
    --free-form (-f) # Filter to show only free form-based sources.
    --all (-a) # No filtering - show all sources. (default)
] {
    print "List of sources."
    let sqlquery = "SELECT SourceID, Name, TemplateID,  cast(Fields AS TEXT) as Fields, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
    FROM SourceTable"
    open $env.rmdb | query db $sqlquery 
 #   | insert Footnote {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
 #   | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten 
 #   | insert Bibliography {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    | reject Fields | startat1
}