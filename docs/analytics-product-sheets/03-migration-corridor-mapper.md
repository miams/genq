# Migration Corridor Mapper

## Product Pitch

Genealogy is not just about names and dates. It is also about movement.

The Migration Corridor Mapper reconstructs how families moved across counties, states, and countries over time. It turns disconnected place entries into recognizable migration lanes: Virginia to Kentucky, Ohio to Indiana, rural county to industrial city, cemetery back to ancestral hometown.

This is valuable because migration patterns reveal research strategy. If you know a line moved through the Pennsylvania-to-Ohio corridor in the 1830s, you know where to hunt for land, probate, tax, and church records next. It also helps distinguish same-name individuals by showing which person followed which geographic path.

RootsMagic’s `PlaceTable` is unusually useful here because it stores hierarchical place names and reverse-place fields, while `EventTable` links those places to life facts. Polars makes it easy to split the place hierarchy, sort movements by time, and aggregate route patterns across a surname, family, or region.

## Making It Real

### Prep Work

You need:

- events with resolved place names
- parsed place hierarchy into city, county, state, country
- enough dated events to build movement sequences

The current `genq list events --place-name` command is enough to start.

### Commands

Load event geography:

```nu
let events = (
  genq list events --place-name
  | where Place != ""
  | polars into-df
)
```

Split place hierarchy:

```nu
let geo = (
  $events
  | polars with-column ((polars col Place | polars str split ", ") | polars as PlaceParts)
  | polars with-column ((polars col PlaceParts | polars list get 0) | polars as City)
  | polars with-column ((polars col PlaceParts | polars list get 1) | polars as County)
  | polars with-column ((polars col PlaceParts | polars list get 2) | polars as State)
  | polars with-column ((polars col PlaceParts | polars list get 3) | polars as Country)
)
```

Build person movement sequences:

```nu
$geo
| polars sort-by [RIN SortDate]
| polars group-by [RIN Given Surname]
| polars agg [
    (polars col Event | polars implode | polars as EventPath)
    (polars col EventDate | polars implode | polars as DatePath)
    (polars col Place | polars implode | polars as PlacePath)
    (polars col State | polars implode | polars as StatePath)
  ]
| polars collect
```

Find common state-to-state corridors:

```nu
let corridor_sql = "
  SELECT
    e.OwnerID AS RIN,
    n.Given,
    n.Surname,
    e.SortDate,
    pl.Name AS Place
  FROM EventTable e
  JOIN NameTable n ON n.OwnerID = e.OwnerID AND n.IsPrimary = 1
  JOIN PlaceTable pl ON pl.PlaceID = e.PlaceID
  WHERE e.OwnerType = 0
    AND e.PlaceID != 0
    AND e.SortDate IS NOT NULL
    AND e.SortDate != 9223372036854775807
"

open $env.rmdb | query db $corridor_sql
| polars into-df
| polars with-column ((polars col Place | polars str split ", ") | polars as Parts)
| polars with-column ((polars col Parts | polars list get 2) | polars as State)
| polars sort-by [RIN SortDate]
| polars group-by [RIN Given Surname]
| polars agg [(polars col State | polars implode | polars as States)]
| polars collect
```

### Output You Want

The best product outputs are:

- per-person movement timelines
- surname-level migration corridor summaries
- decade-by-decade state inflow and outflow tables

That gives both a visual story and a research-planning tool.
