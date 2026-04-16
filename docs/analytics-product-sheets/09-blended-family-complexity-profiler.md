# Blended Family Complexity Profiler

## Product Pitch

Modern family structure analytics are not only for modern families.

The Blended Family Complexity Profiler identifies adoptive, step, foster, guardianship, remarriage, and multi-spouse patterns across the database. It shows where family structure is straightforward, where it is layered, and where recorded relationships deserve closer interpretation.

This is valuable because those complexity patterns are often where genealogists make wrong assumptions. A child in a household is not always a biological child. A repeated spouse sequence may indicate remarriage after death, divorce, or duplicate families. A recorded parent may be adoptive, foster, or step.

RootsMagic preserves key relationship signals in `FamilyTable`, `ChildTable.RelFather`, `ChildTable.RelMother`, spouse ordering, and family facts. Polars lets you roll these into a family complexity score and expose clusters that need narrative care.

## Making It Real

### Prep Work

You need:

- family records
- child relationship codes
- spouse ordering
- marriage and divorce family events where present

The first version can be built mostly from `genq list families` and `genq list children`.

### Commands

Load family structure:

```nu
let families = (genq list families | polars into-df)
let children = (genq list children | polars into-df)
```

Find non-birth parent-child links:

```nu
$children
| polars filter (((polars col RelToFather) != "Birth") or ((polars col RelToMother) != "Birth"))
| polars collect
```

Measure multi-spouse complexity:

```nu
$families
| polars group-by [FatherID]
| polars agg [(polars col FamilyID | polars count | polars as FamilyCount)]
| polars filter ((polars col FamilyCount) > 1)
| polars sort-by FamilyCount --reverse
| polars collect
```

Build a family complexity score:

```nu
let adopted = (
  $children
  | polars group-by [MRIN]
  | polars agg [
      (
        (
          ((polars col RelToFather) != "Birth")
          or ((polars col RelToMother) != "Birth")
        ) | polars sum
      ) | polars as NonBirthLinks
    ]
)

$families
| polars join $adopted --left-on FamilyID --right-on MRIN --how left
| polars with-column (
    (
      (when ((polars col WifeOrder) > 0) { 2 } else { 0 })
      + (when ((polars col HusbOrder) > 0) { 2 } else { 0 })
      + (polars col NonBirthLinks | polars fill-null 0)
    ) | polars as ComplexityScore
  )
| polars sort-by ComplexityScore --reverse
| polars collect
```

### Output You Want

Best outputs:

- a ranked list of complex families
- explanation columns showing why the family scored high
- a narrative caution list for downstream reporting and AI summaries

This is a high-value interpretive safeguard, especially when generating prose or automated biographies.
