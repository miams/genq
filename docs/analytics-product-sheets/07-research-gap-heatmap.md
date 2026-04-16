# Research Gap Heatmap

## Product Pitch

A genealogy database is never simply “complete” or “incomplete.” It is uneven.

The Research Gap Heatmap shows exactly where the unevenness is: which decades are under-sourced, which counties are full of unsourced events, which surname lines have thin documentation, and which person clusters need work first.

This is valuable because most researchers manage their backlog by memory and intuition. That works poorly once the database gets large. The heatmap turns the backlog into a visible map of opportunity, organized by time, place, family, and fact type.

RootsMagic already contains the needed signals: dates, places, citations, source counts, names, and event types. Polars is ideal for binning those dimensions and producing dense summary tables that can feed terminal reports or lightweight visualizations.

## Making It Real

### Prep Work

You need:

- person events with dates and places
- citation links to those events
- a way to bin years into decades and places into state/county

This analytic works well with event-level SQL plus Polars aggregation.

### Commands

Extract event coverage:

```nu
let coverage = (
  open $env.rmdb | query db "
    SELECT
      e.EventID,
      e.OwnerID AS RIN,
      ft.Name AS EventType,
      e.SortDate,
      COALESCE(pl.Name, '') AS Place,
      cl.CitationID
    FROM EventTable e
    JOIN FactTypeTable ft ON ft.FactTypeID = e.EventType
    LEFT JOIN PlaceTable pl ON pl.PlaceID = e.PlaceID
    LEFT JOIN CitationLinkTable cl ON cl.OwnerType = 2 AND cl.OwnerID = e.EventID
    WHERE e.OwnerType = 0
  " | polars into-df
)
```

Bin by decade:

```nu
$coverage
| polars with-column ((((polars col SortDate) / 1000000000000000) | floor / 10 | floor * 10) | polars as Decade)
| polars group-by [Decade EventType]
| polars agg [
    (polars col EventID | polars nunique | polars as EventCount)
    (polars col CitationID | polars nunique | polars as CitationCount)
  ]
| polars with-column (((polars col CitationCount) / (polars col EventCount)) | polars as CitationPerEvent)
| polars sort-by [Decade EventType]
| polars collect
```

Bin by geography:

```nu
$coverage
| polars with-column ((polars col Place | polars str split ", ") | polars as Parts)
| polars with-column ((polars col Parts | polars list get 1) | polars as County)
| polars with-column ((polars col Parts | polars list get 2) | polars as State)
| polars group-by [State County]
| polars agg [
    (polars col EventID | polars nunique | polars as EventCount)
    (polars col CitationID | polars nunique | polars as CitationCount)
  ]
| polars with-column ((((polars col EventCount) - (polars col CitationCount)) / (polars col EventCount)) | polars as GapScore)
| polars sort-by GapScore --reverse
| polars collect
```

### Output You Want

Useful outputs:

- decade-by-fact-type coverage table
- state/county gap rankings
- per-surname gap profiles

The strongest product experience is a prioritized “where to work next” board driven by objective coverage gaps.
