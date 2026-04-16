# FAN Network Centrality Map

## Product Pitch

Genealogists solve hard problems by leaving the direct line and studying the cluster around it: friends, associates, and neighbors.

The FAN Network Centrality Map turns that method into a repeatable analytic. It combines RootsMagic associations, witnesses, shared places, and shared sources to identify the people who sit at the center of a family’s social network. These are often the key to breaking brick walls.

This matters because the most useful person in a problem set is not always the target ancestor. It may be the recurring witness at marriages, the neighbor in two censuses, the executor in a probate trail, or the cemetery owner tied to several burials.

RootsMagic’s `FANTable`, `WitnessTable`, and event/source structures provide enough relational signal to build a lightweight network model. Polars is well suited for edge-table generation, weighting, and centrality pre-processing.

## Making It Real

### Prep Work

You need:

- `genq list associations`
- `genq list witnesses`
- person identity tables
- optionally shared-place or shared-source edges

The network metric can start simple with weighted degree centrality before moving to full graph tooling.

### Commands

Load direct association edges:

```nu
let assoc = (genq list associations | polars into-df)
let witnesses = (genq list witnesses | polars into-df)
let people = (genq list people | polars into-df)
```

Build witness-based edges:

```nu
let witness_edges = (
  $witnesses
  | polars select [EventID PersonID Role]
  | polars rename {PersonID: RIN2}
)
```

Build association edge weights:

```nu
let assoc_edges = (
  $assoc
  | polars with-column (
      when ((polars col AssocType) == "Neighbors") { 3 }
      else when ((polars col AssocType) == "Friends") { 2 }
      else { 1 }
      | polars as EdgeWeight
    )
)
```

Compute degree-style centrality:

```nu
$assoc_edges
| polars group-by [RIN]
| polars agg [
    (polars col ID2 | polars nunique | polars as UniqueConnections)
    (polars col EdgeWeight | polars sum | polars as WeightedDegree)
  ]
| polars sort-by WeightedDegree --reverse
| polars collect
```

Augment with shared-event participation:

```nu
$witnesses
| polars group-by [PersonID]
| polars agg [(polars col EventID | polars nunique | polars as SharedEventCount)]
| polars sort-by SharedEventCount --reverse
| polars collect
```

### Output You Want

The product output should show:

- top network hubs around a selected line
- repeated associates appearing across multiple event types
- bridge people who connect one family cluster to another

That gives the genealogist a concrete FAN research target list instead of a vague reminder to “look at neighbors.”
