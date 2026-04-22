# List sources.
@category "genq-common"
@search-terms "Evidence Explained, First Reference Note, Subsequent Note, Source List Entry"
@example 'List free-form source names, footnotes, short footnotes and bibliographies' {'genq list sources'}
@example 'List all sources (free-form and template-based) with rendered citation text' {'genq list sources --all'}
export def "main" [
    --freeform (-f) # Show only free-form sources (default when no flag given)
    --all (-a)      # Show all sources including template-based ones, with rendered citation text
] {
    use rm-template *

    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    let show_freeform = ($freeform or not $all)

    if $show_freeform {
        print "List of free-form sources."
        let sqlquery = "SELECT SourceID as SrcID, Name as SourceName, TemplateID as TempID, cast(Fields AS TEXT) as Fields,
            COALESCE(STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM SourceTable WHERE TemplateID = 0"
        open $env.rmdb | query db $sqlquery
        | insert AbbrevSourceName {|row| limit $row.SourceName ((term size).columns - 55)}
        | insert Footnote      {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten
        | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten
        | insert Bibliography  {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject SourceName Fields LastUpdateUTC | startat1
    } else {
        print "List of all sources (free-form and template-based)."
        let sqlquery = "SELECT
            s.SourceID as SrcID,
            s.Name COLLATE NOCASE as SourceName,
            s.TemplateID as TempID,
            CASE WHEN s.TemplateID = 0 THEN 'Free-form' ELSE COALESCE(t.Name, 'Unknown Template') END COLLATE NOCASE as TemplateName,
            cast(s.Fields AS TEXT) as Fields,
            COALESCE(t.Footnote,      '') AS TmplFootnote,
            COALESCE(t.ShortFootnote, '') AS TmplShortFootnote,
            COALESCE(t.Bibliography,  '') AS TmplBibliography,
            COALESCE(STRFTIME(DATETIME(s.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM SourceTable s
        LEFT JOIN SourceTemplateTable t ON s.TemplateID = t.TemplateID
        ORDER BY s.TemplateID = 0, t.Name COLLATE NOCASE, s.Name COLLATE NOCASE"
        open $env.rmdb | query db $sqlquery
        | insert AbbrevSourceName {|row| limit $row.SourceName ((term size).columns - 45)}
        | insert Footnote {|row|
            if $row.TempID == 0 {
                extract-freeform-field $row.Fields "Footnote"
            } else {
                render-template $row.TmplFootnote $row.Fields --plain-text
            }
          }
        | insert ShortFootnote {|row|
            if $row.TempID == 0 {
                extract-freeform-field $row.Fields "ShortFootnote"
            } else {
                render-template $row.TmplShortFootnote $row.Fields --plain-text
            }
          }
        | insert Bibliography {|row|
            if $row.TempID == 0 {
                extract-freeform-field $row.Fields "Bibliography"
            } else {
                render-template $row.TmplBibliography $row.Fields --plain-text
            }
          }
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject SourceName Fields TmplFootnote TmplShortFootnote TmplBibliography LastUpdateUTC
        | startat1
    }
}

