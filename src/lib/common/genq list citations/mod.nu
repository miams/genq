# List citations. [wide]
@category "genq-common"
@example "List all citations in database." {'genq list citations'}
@example "List citations with modification dates." {'genq list citations --mod-date'}
@example "List citations with GPS citation quality fields (Source, Information, Evidence)." {'genq list citations --quality'}
@example "List citations with EventID for event-level filtering." {'genq list citations --event-id | where EventID == 5432'}
@example "List citations showing citation-level research notes and verbatim transcripts." {'genq list citations --research-notes | where ActualText != ""'}
export def "main" [
    --mod-date (-d)       # Include LastUpdate column (CitationTable.UTCModDate)
    --quality (-q)        # Decode citation quality into Source, Information, and Evidence columns (renames Source column to SourceName)
    --event-id (-e)       # Include EventID column (non-null only for individual and couple-event fact citations)
    --research-notes (-n) # Include ActualText (verbatim transcript) and Comments (research annotation) columns
] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }
    
    print "List of citations."

    let sql_script = [$env.genq_sql, "all-citations.sql"] | path join 
    
    # Validate SQL file exists
    if not ($sql_script | path exists) {
        print $"(ansi red)Error:(ansi reset) SQL file not found: ($sql_script)"
        print "This usually indicates a GenQuery installation problem."
        return
    }
    
    let sqlquery = (open $sql_script)
    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.CitUTCModDate | is-empty) { "" } else { $row.CitUTCModDate | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" }
        }
        | reject CitUTCModDate
        | rename --column {CitTxt: ActualText CitComment: Comments}

    let decoded = if $quality {
        $result
        | rename --column {Source: SourceName}
        | insert Source {|row|
            if ($row.Quality | is-empty) { "" } else {
                match ($row.Quality | split chars | get 0) {
                    "P" => "Primary"
                    "S" => "Secondary"
                    _ => ""
                }
            }
        }
        | insert Information {|row|
            if ($row.Quality | is-empty) { "" } else {
                match ($row.Quality | split chars | get 1) {
                    "D" => "Direct"
                    "I" => "Indirect"
                    "N" => "Negative"
                    _ => ""
                }
            }
        }
        | insert Evidence {|row|
            if ($row.Quality | is-empty) { "" } else {
                match ($row.Quality | split chars | get 2) {
                    "O" => "Original"
                    "X" => "Derivative"
                    _ => ""
                }
            }
        }
        | reject Quality
    } else {
        $result | reject Quality
    }

    let with_event = if $event_id { $decoded } else { $decoded | reject EventID }
    let final = if $research_notes { $with_event } else { $with_event | reject ActualText Comments }
    if $mod_date { $final | startat1 } else { $final | reject LastUpdate | startat1 }
}