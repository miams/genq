# Tabulate sources by label/tag.
@category "genq-ext-miams"
@example 'Display a frequency of the source tags used' {'genq tabulate sources labels'}
export def "main" [] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }
    
    print "Tabulation of sources by their label/tag (part before :)."
    
    let sqlquery = "SELECT SourceID, Name, TemplateID, STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000' AS SourceDate  
    FROM SourceTable"
    
    let sources = try {
        open $env.rmdb | query db $sqlquery
    } catch { |error|
        print $"(ansi red)Error:(ansi reset) Database query failed: ($error.msg)"
        print "This might indicate database corruption or SQL compatibility issues."
        return
    }
    
    $sources 
    | insert source_tag_pos {|row| $row.Name | str index-of ':' | $in - 1}
    | insert SourceTag {|row| $row.Name | if $row.source_tag_pos < 0 { '*No Tag*' } else { str substring 0..$row.source_tag_pos }}
    | insert NameTruncated {|row| $row.Name | str substring 0..30}
    | reject Name source_tag_pos
    | move SourceTag --after SourceID
    | move NameTruncated --after SourceTag 
    | startat1
    | histogram SourceTag
}