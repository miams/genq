# Narrative Completeness Score

## Product Pitch

A person can look “done” in a tree and still be missing the story.

The Narrative Completeness Score measures whether a person has enough structured evidence to support a credible biography. It checks for the building blocks of a usable narrative: primary identity, vital events, dated chronology, geographic context, citations, notes, witnesses, and media.

This is valuable because genealogists often decide what to research next by browsing. The completeness score replaces browsing with prioritization. It tells you which ancestors are ready for publication, which need one more source pass, and which are still just skeletal records.

For GenQuery specifically, this analytic is a strong product fit because it matches the tool’s strengths: extracting many RootsMagic entities and turning them into practical research reports. It also aligns with future markdown or AI-generated biography features.

## Making It Real

### Prep Work

You need:

- primary person identity
- birth and death events
- place-bearing events
- citations
- media links
- notes or witnesses if available

This analytic works as a weighted checklist over joined tables.

### Commands

Build person-level feature tables:

```nu
let people = (genq list people | polars into-df)
let events = (genq list events --place-name | polars into-df)
let media = (genq list media | polars into-df)
let witnesses = (genq list witnesses | polars into-df)
```

Get person citation counts:

```nu
let citation_counts = (
  open $env.rmdb | query db "
    SELECT
      e.OwnerID AS RIN,
      COUNT(DISTINCT cl.CitationID) AS CitationCount
    FROM EventTable e
    LEFT JOIN CitationLinkTable cl ON cl.OwnerType = 2 AND cl.OwnerID = e.EventID
    WHERE e.OwnerType = 0
    GROUP BY e.OwnerID
  " | polars into-df
)
```

Aggregate event completeness signals:

```nu
let event_features = (
  $events
  | polars group-by [RIN Given Surname]
  | polars agg [
      (((polars col Event) == "Birth") | polars sum | polars as HasBirth)
      (((polars col Event) == "Death") | polars sum | polars as HasDeath)
      (((polars col Place) != "") | polars sum | polars as EventsWithPlace)
      (((polars col EventDate) != "") | polars sum | polars as EventsWithDate)
      (polars col Event | polars nunique | polars as DistinctEventTypes)
    ]
)
```

Score the narrative:

```nu
$people
| polars join $event_features --left-on RIN --right-on RIN --how left
| polars join $citation_counts --left-on RIN --right-on RIN --how left
| polars with-column (
    (
      (when ((polars col BirthDate) != "") { 15 } else { 0 })
      + (when ((polars col DeathDate) != "") { 15 } else { 0 })
      + (when ((polars col EventsWithPlace) > 0) { 15 } else { 0 })
      + (when ((polars col CitationCount) >= 3) { 25 } else when ((polars col CitationCount) > 0) { 10 } else { 0 })
      + (when ((polars col DistinctEventTypes) >= 5) { 20 } else { 5 })
    ) | polars as NarrativeScore
  )
| polars sort-by NarrativeScore
| polars collect
```

Create the publication-ready list:

```nu
$people
| polars join $event_features --left-on RIN --right-on RIN --how left
| polars join $citation_counts --left-on RIN --right-on RIN --how left
| polars filter (((polars col CitationCount) >= 5) and ((polars col DistinctEventTypes) >= 5))
| polars collect
```

### Output You Want

This analytic should produce:

- a ranked person list by narrative readiness
- a thin-record queue for research
- a publication-ready shortlist for markdown profiles or AI narration

That makes it one of the most productizable analytics in the set.
