# Life Timeline Anomaly Detector

## Product Pitch

Every serious genealogy database accumulates errors. A date is mistyped. A death is attached to the wrong person. A burial ends up before the death. A parent is eight years old when the child is born.

The Life Timeline Anomaly Detector catches those errors at scale. It reconstructs the chronological story of each person and flags patterns that are biologically impossible, socially unlikely, or internally inconsistent.

This analytic is valuable because it protects trust in the tree. It is not just “data cleanup.” It is risk control. A family line with one wrong generation can contaminate hundreds of descendants. By surfacing anomalies early, you prevent bad inferences, bad merges, and bad publishing.

RootsMagic already stores the right ingredients for this in `EventTable`, `PersonTable`, `FamilyTable`, `ChildTable`, and the encoded date fields. Polars turns those rows into timeline validation rules that can run over the whole database in seconds.

## Making It Real

### Prep Work

You need parsed event dates with sortable values. `genq list events` already exposes `SortDate` and can parse event dates. For parent-child checks, you also need `genq list children` and `genq list people`.

### Commands

Load people and events:

```nu
let people = (genq list people | polars into-df)
let events = (genq list events --place-name | polars into-df)
let children = (genq list children | polars into-df)
```

Create birth and death baselines:

```nu
let births = (
  $events
  | polars filter ((polars col Event) == "Birth")
  | polars select [RIN Given Surname EventDate SortDate Place]
  | polars rename {EventDate: BirthDate, SortDate: BirthSort, Place: BirthPlace}
)

let deaths = (
  $events
  | polars filter ((polars col Event) == "Death")
  | polars select [RIN EventDate SortDate Place]
  | polars rename {EventDate: DeathDate, SortDate: DeathSort, Place: DeathPlace}
)
```

Flag death-before-birth cases:

```nu
$births
| polars join $deaths --left-on RIN --right-on RIN --how inner
| polars filter ((polars col DeathSort) < (polars col BirthSort))
| polars collect
```

Build a per-person event sequence and look for reversals:

```nu
$events
| polars sort-by [RIN SortDate]
| polars group-by [RIN Given Surname]
| polars agg [
    (polars col Event | polars implode | polars as EventSequence)
    (polars col EventDate | polars implode | polars as DateSequence)
    (polars col Place | polars implode | polars as PlaceSequence)
  ]
| polars collect
```

Flag improbable parent ages at childbirth:

```nu
let birth_sql = "
  SELECT
    child.PersonID AS ChildRIN,
    cn.Given AS ChildGiven,
    cn.Surname AS ChildSurname,
    cb.SortDate AS ChildBirthSort,
    parent.PersonID AS ParentRIN,
    pn.Given AS ParentGiven,
    pn.Surname AS ParentSurname,
    pb.SortDate AS ParentBirthSort,
    parent.Sex
  FROM ChildTable ct
  JOIN FamilyTable f ON ct.FamilyID = f.FamilyID
  JOIN PersonTable child ON child.PersonID = ct.ChildID
  JOIN NameTable cn ON cn.OwnerID = child.PersonID AND cn.IsPrimary = 1
  JOIN PersonTable parent ON parent.PersonID = f.FatherID OR parent.PersonID = f.MotherID
  JOIN NameTable pn ON pn.OwnerID = parent.PersonID AND pn.IsPrimary = 1
  LEFT JOIN EventTable cb ON cb.OwnerType = 0 AND cb.OwnerID = child.PersonID AND cb.EventType = 1
  LEFT JOIN EventTable pb ON pb.OwnerType = 0 AND pb.OwnerID = parent.PersonID AND pb.EventType = 1
"

open $env.rmdb | query db $birth_sql
| polars into-df
| polars with-column ((((polars col ChildBirthSort) - (polars col ParentBirthSort)) / 1000000000000) | polars as ApproxParentAgeYears)
| polars filter (((polars col ApproxParentAgeYears) < 12) or ((polars col ApproxParentAgeYears) > 65))
| polars collect
```

### Output You Want

Produce three reports:

- hard contradictions
- soft anomalies
- a prioritized correction queue

The hard contradictions are where this analytic earns its keep. Those are the records most likely to represent outright mistakes in the tree.
