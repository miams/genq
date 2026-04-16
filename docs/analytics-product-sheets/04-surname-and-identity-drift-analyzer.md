# Surname and Identity Drift Analyzer

## Product Pitch

Families do not hold still linguistically. Surnames drift. Clerks misspell. Immigrants translate or simplify. Married names replace maiden names. Nicknames become public identity.

The Surname and Identity Drift Analyzer tracks those shifts over time and across contexts. It identifies where a person’s identity footprint changes, where a surname line splits into variants, and where multiple records may represent the same person under different names.

This matters because many research failures are not really archival failures. They are identity-matching failures. The record exists, but the name changed just enough that the researcher did not see it.

RootsMagic stores the raw ingredients in `NameTable`, including primary names, alternates, `NameType`, dated alternate names, and metaphone-style columns. With Polars, you can turn those scattered alternates into a measurable identity history.

## Making It Real

### Prep Work

You need:

- all names, not just primary names
- `NameType`
- dated alternate names where available
- phonetic surname fields when populated

The existing `genq list people --all-names` is useful, but for full analysis go directly to `NameTable`.

### Commands

Extract all name variants:

```nu
let names = (
  open $env.rmdb | query db "
    SELECT
      n.NameID,
      n.OwnerID AS RIN,
      p.Sex,
      n.IsPrimary,
      n.NameType,
      n.Given,
      n.Surname,
      n.Nickname,
      n.Date AS FullDate,
      n.SortDate,
      n.SurnameMP,
      n.GivenMP
    FROM NameTable n
    JOIN PersonTable p ON p.PersonID = n.OwnerID
  " | polars into-df
)
```

Group by person to see drift:

```nu
$names
| polars sort-by [RIN IsPrimary SortDate]
| polars group-by [RIN]
| polars agg [
    (polars col Given | polars implode | polars as GivenHistory)
    (polars col Surname | polars implode | polars as SurnameHistory)
    (polars col NameType | polars implode | polars as NameTypeHistory)
    (polars col SurnameMP | polars implode | polars as SurnamePhonetics)
  ]
| polars collect
```

Find likely surname-drift clusters:

```nu
$names
| polars filter ((polars col Surname) != "")
| polars group-by [SurnameMP]
| polars agg [
    (polars col Surname | polars unique | polars implode | polars as VariantSurnames)
    (polars col RIN | polars nunique | polars as PersonCount)
  ]
| polars filter ((polars col PersonCount) > 1)
| polars sort-by PersonCount --reverse
| polars collect
```

Find married-name transitions:

```nu
$names
| polars filter (((polars col NameType) == 5) or ((polars col NameType) == 7))
| polars sort-by [RIN SortDate]
| polars collect
```

### Output You Want

Deliverables:

- per-person identity timelines
- surname-variant clusters
- probable same-line spelling families
- a research list of people whose alternates deserve search expansion

This analytic becomes especially powerful when paired with census, obituary, and immigration source work.
