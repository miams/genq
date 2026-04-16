# Household Reconstruction Engine

## Product Pitch

Family structure in historical records is often implied rather than explicitly declared.

The Household Reconstruction Engine infers likely household groupings from census events, witnesses, shared places, age proximity, and family links. It helps the genealogist answer questions like:

- Who was probably living together at a given time?
- Which children likely belong to this couple?
- Which apparent “extra” people are boarders, relatives, or remarried kin?

This is valuable because many genealogical breakthroughs happen at the household level, not the individual level. When a census page, burial cluster, and family network all point to the same household composition, the researcher can make better decisions about identity and kinship.

RootsMagic supports this with person events, census facts, family links, child records, witness roles, and place hierarchy. Polars can combine those signals into ranked household candidates.

## Making It Real

### Prep Work

You need:

- census or residence-like events
- family and child links
- names and birth years
- optional witness or association data for co-presence clues

For the first version, focus on census/residence events plus family links.

### Commands

Extract household candidates from census facts:

```nu
let census = (
  open $env.rmdb | query db "
    SELECT
      e.OwnerID AS RIN,
      n.Given,
      n.Surname,
      n.BirthYear,
      e.EventID,
      ft.Name AS EventType,
      e.SortDate,
      COALESCE(pl.Name, '') AS Place,
      COALESCE(e.Details, '') AS Details
    FROM EventTable e
    JOIN FactTypeTable ft ON ft.FactTypeID = e.EventType
    JOIN NameTable n ON n.OwnerID = e.OwnerID AND n.IsPrimary = 1
    LEFT JOIN PlaceTable pl ON pl.PlaceID = e.PlaceID
    WHERE e.OwnerType = 0
      AND ft.Name IN ('Census', 'Residence')
  " | polars into-df
)
```

Group likely co-residents by place and time:

```nu
$census
| polars with-column ((((polars col SortDate) / 1000000000000000) | floor) | polars as ApproxYear)
| polars group-by [Place ApproxYear]
| polars agg [
    (polars col RIN | polars implode | polars as HouseholdRINs)
    (polars col Given | polars implode | polars as GivenNames)
    (polars col Surname | polars implode | polars as Surnames)
    (polars col BirthYear | polars implode | polars as BirthYears)
  ]
| polars sort-by ApproxYear --reverse
| polars collect
```

Overlay recorded family structure:

```nu
let families = (genq list families | polars into-df)
let children = (genq list children | polars into-df)

$children
| polars group-by [MRIN]
| polars agg [
    (polars col ChildID | polars implode | polars as Children)
  ]
| polars collect
```

### Output You Want

The target outputs are:

- inferred household clusters by year and place
- a list of household members not already connected in RootsMagic
- possible missing-child or remarriage scenarios

This becomes a powerful “candidate relationships” product when used carefully and transparently.
