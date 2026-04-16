# Source Template Effectiveness Dashboard

## Product Pitch

Not all source habits create equal research value.

The Source Template Effectiveness Dashboard tells you which source types, templates, and repositories are actually helping your tree. It measures which templates produce rich citation detail, broad linkage across people and events, and stronger evidence reuse.

This matters because genealogy databases often contain thousands of citations but uneven documentation quality. One researcher may be careful with books and careless with websites. Another may overuse one derivative database. The dashboard reveals those patterns and helps standardize better sourcing behavior.

RootsMagic is especially well suited for this analytic because source metadata and citation detail are split cleanly between `SourceTable.Fields`, `CitationTable.Fields`, and `SourceTemplateTable.FieldDefs`. Once those XML blobs are flattened, Polars can score template performance at scale.

## Making It Real

### Prep Work

You need:

- source rows
- citation rows
- citation links
- source templates
- XML flattening for source and citation fields

Current `genq list sources --all` is a useful starting point, but this analytic works best from direct SQL plus XML parsing.

### Commands

Extract source, citation, and template data:

```nu
let raw_sources = (
  open $env.rmdb | query db "
    SELECT SourceID, Name, TemplateID, CAST(Fields AS TEXT) AS SourceFields
    FROM SourceTable
  " | polars into-df
)

let raw_citations = (
  open $env.rmdb | query db "
    SELECT CitationID, SourceID, CAST(Fields AS TEXT) AS CitationFields, CitationName
    FROM CitationTable
  " | polars into-df
)

let templates = (
  open $env.rmdb | query db "
    SELECT TemplateID, Name AS TemplateName, CAST(FieldDefs AS TEXT) AS FieldDefs
    FROM SourceTemplateTable
  " | polars into-df
)

let links = (
  open $env.rmdb | query db "
    SELECT CitationID, OwnerType, OwnerID, Quality
    FROM CitationLinkTable
  " | polars into-df
)
```

Flatten basic performance metrics:

```nu
$raw_citations
| polars join $raw_sources --left-on SourceID --right-on SourceID --how left
| polars join $templates --left-on TemplateID --right-on TemplateID --how left
| polars join $links --left-on CitationID --right-on CitationID --how left
| polars group-by [TemplateID TemplateName]
| polars agg [
    (polars col CitationID | polars nunique | polars as CitationCount)
    (polars col SourceID | polars nunique | polars as SourceCount)
    (polars col OwnerID | polars nunique | polars as LinkedClaims)
    (polars col Quality | polars drop-nulls | polars implode | polars as QualityValues)
  ]
| polars sort-by CitationCount --reverse
| polars collect
```

Find thin templates with low citation richness:

```nu
$raw_citations
| polars with-column ((polars col CitationFields | polars str len-chars) | polars as CitationFieldChars)
| polars group-by [SourceID]
| polars agg [
    (polars col CitationID | polars count | polars as CitationCount)
    (polars col CitationFieldChars | polars mean | polars as AvgFieldLength)
  ]
| polars sort-by AvgFieldLength
| polars collect
```

### Output You Want

Produce:

- a ranked template scorecard
- a repository/source-type comparison
- a “low-value sourcing habit” report

This helps shape future data-entry behavior, not just analyze past work.
