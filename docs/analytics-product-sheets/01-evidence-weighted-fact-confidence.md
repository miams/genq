# Evidence-Weighted Fact Confidence Score

## Product Pitch

Most genealogy software can tell you whether a fact is sourced. That is not the same thing as telling you whether the fact is trustworthy.

The Evidence-Weighted Fact Confidence Score ranks facts, events, and people by research strength. It combines citation count, source diversity, citation quality, and source richness into a single score that immediately answers three questions:

- Which conclusions are rock solid?
- Which conclusions are weakly supported?
- Where should the next hour of research go?

For a genealogist, this turns a database from a static archive into an evidence map. Instead of manually opening one person at a time, you can identify weak birth facts, over-relied-on sources, or people whose narratives look complete but are actually resting on one derivative citation.

This is especially valuable in RootsMagic because the evidence model is spread across `EventTable`, `CitationLinkTable`, `CitationTable`, and `SourceTable`, with quality encoded in `CitationLinkTable.Quality`. That means the signal exists, but it is hard to see without analytics.

## Making It Real

### Prep Work

You need:

- a synced copy of the RootsMagic database via `syncdb`
- Polars available in Nushell
- event-level citations exposed from RootsMagic tables

Because the current `genq list citations` command does not yet provide the full event-oriented link picture, use direct SQL for this analytic.

### Commands

Extract fact-level evidence:

```nu
let fact_evidence = (
  open $env.rmdb | query db "
    SELECT
      e.EventID,
      e.OwnerID AS RIN,
      ft.Name AS Event,
      e.Date AS FullDate,
      e.SortDate,
      COALESCE(pl.Name, '') AS Place,
      cl.CitationID,
      cl.Quality,
      c.SourceID,
      COALESCE(c.CitationName, '') AS CitationName,
      COALESCE(s.Name, '') AS SourceName,
      s.TemplateID
    FROM EventTable e
    JOIN FactTypeTable ft ON e.EventType = ft.FactTypeID
    LEFT JOIN PlaceTable pl ON e.PlaceID = pl.PlaceID
    LEFT JOIN CitationLinkTable cl ON cl.OwnerType = 2 AND cl.OwnerID = e.EventID
    LEFT JOIN CitationTable c ON c.CitationID = cl.CitationID
    LEFT JOIN SourceTable s ON s.SourceID = c.SourceID
    WHERE e.OwnerType = 0
  " | polars into-df
)
```

Score the evidence:

```nu
let scored = (
  $fact_evidence
  | polars group-by [EventID RIN Event FullDate SortDate Place]
  | polars agg [
      (polars col CitationID | polars nunique | polars as CitationCount)
      (polars col SourceID | polars nunique | polars as SourceDiversity)
      (polars col Quality | polars drop-nulls | polars first | polars as SampleQuality)
    ]
  | polars with-column (
      (
        (polars col CitationCount) * 20
        + (polars col SourceDiversity) * 25
        + (
            when ((polars col SampleQuality) == "PDO") { 30 }
            else when ((polars col SampleQuality) == "SDX") { 18 }
            else when ((polars col SampleQuality) == "~~~") { 8 }
            else { 12 }
          )
      ) | polars as ConfidenceScore
    )
  | polars sort-by ConfidenceScore --reverse
)

$scored | polars collect
```

Research queue for weakly supported facts:

```nu
$scored
| polars filter ((polars col ConfidenceScore) < 35)
| polars sort-by ConfidenceScore
| polars collect
```

### Output You Want

The main deliverables are:

- a fact-level confidence table
- a per-person average confidence score
- a filtered worklist of low-confidence vital events

That final worklist is the product: a targeted research backlog generated from evidence, not guesswork.
