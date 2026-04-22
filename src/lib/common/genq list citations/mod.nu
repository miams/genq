# List citations. [wide]
@category "genq-common"
@example "List all citations in database." {'genq list citations'}
@example "List citations with modification dates." {'genq list citations --mod-date'}
@example "List citations with GPS citation quality fields (Source, Information, Evidence)." {'genq list citations --quality'}
@example "List citations with EventID for event-level filtering." {'genq list citations --event-id | where EventID == 5432'}
@example "List citations showing citation-level research notes and verbatim transcripts." {'genq list citations --research-notes | where ActualText != ""'}
@example "List citations with rendered footnote text." {'genq list citations --footnote'}
@example "List citations with rendered short footnote text." {'genq list citations --short-footnote'}
@example "List citations with rendered bibliography text." {'genq list citations --bibliography'}
@example "List citations with all three rendered citation formats." {'genq list citations --footnote --short-footnote --bibliography'}
export def "main" [
    --mod-date (-d)          # Include LastUpdate column (CitationTable.UTCModDate)
    --quality (-q)           # Decode citation quality into Source, Information, and Evidence columns (renames Source column to SourceName)
    --event-id (-e)          # Include EventID column (non-null only for individual and couple-event fact citations)
    --research-notes (-n)    # Include ActualText (verbatim transcript) and Comments (research annotation) columns
    --footnote (-f)          # Render Footnote column for each citation (merges source and citation fields)
    --short-footnote (-s)    # Render ShortFootnote column for each citation
    --bibliography (-b)      # Render Bibliography column for each citation
] {
    use rm-template *
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

    let want_rendered = ($footnote or $short_footnote or $bibliography)

    let with_footnotes = if $want_rendered {
        # One query gets citation Fields + source Fields + template format strings for all citations.
        # Citation-level fields (page, volume, specific entry) are merged over source-level fields
        # (author, title, publisher) so the template sees the full set of values.
        let tpl_sql = "
            SELECT
                c.CitationID as CitID,
                COALESCE(cast(c.Fields as TEXT), '') as CitFields,
                COALESCE(cast(s.Fields as TEXT), '') as SrcFields,
                COALESCE(s.TemplateID, 0) as TemplateID,
                COALESCE(t.Footnote, '') as TmplFootnote,
                COALESCE(t.ShortFootnote, '') as TmplShortFootnote,
                COALESCE(t.Bibliography, '') as TmplBibliography
            FROM CitationTable c
            LEFT JOIN SourceTable s ON c.SourceID = s.SourceID
            LEFT JOIN SourceTemplateTable t ON s.TemplateID = t.TemplateID
        "
        let tpl_data = open $env.rmdb | query db $tpl_sql

        $final
        | join --left $tpl_data CitID
        | each {|row|
            let is_freeform = ($row.TemplateID? | default 0) == 0
            let src_xml = ($row.SrcFields? | default "")
            let merged = if $is_freeform { {} } else {
                (parse-rm-fields $src_xml) | merge (parse-rm-fields ($row.CitFields? | default ""))
            }
            mut r = $row
            if $footnote {
                $r = ($r | insert Footnote (if $is_freeform {
                    extract-freeform-field $src_xml "Footnote"
                } else {
                    render-template-fields ($row.TmplFootnote? | default "") $merged --plain-text
                }))
            }
            if $short_footnote {
                $r = ($r | insert ShortFootnote (if $is_freeform {
                    extract-freeform-field $src_xml "ShortFootnote"
                } else {
                    render-template-fields ($row.TmplShortFootnote? | default "") $merged --plain-text
                }))
            }
            if $bibliography {
                $r = ($r | insert Bibliography (if $is_freeform {
                    extract-freeform-field $src_xml "Bibliography"
                } else {
                    render-template-fields ($row.TmplBibliography? | default "") $merged --plain-text
                }))
            }
            $r | reject CitFields SrcFields TemplateID TmplFootnote TmplShortFootnote TmplBibliography
        }
    } else {
        $final
    }

    if $mod_date { $with_footnotes | startat1 } else { $with_footnotes | reject LastUpdate | startat1 }
}