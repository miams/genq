# GenQuery Analytics Product Sheets

These product sheets describe ten genealogy analytics that become practical once GenQuery can hand RootsMagic data to Nushell Polars dataframes.

Each sheet is split into two parts:

- **Product Pitch**: what the analytic does and why a genealogist would care
- **Making It Real**: the prep work and command patterns needed to produce it in a Polars-enabled `genq` workflow

## Assumptions

These sheets assume:

- `genq` is sourced from [`src/main.nu`](/Users/miams/Code/genq/src/main.nu)
- `$env.rmdb` points at a synced copy of a RootsMagic database
- the Nushell Polars plugin is installed and registered in the user's Nushell environment
- RootsMagic data is queried read-only through `open $env.rmdb | query db ...`

## Shared Prep

In a fresh Nushell session, the common setup looks like this:

```nu
cd /Users/miams/Code/genq
source src/main.nu
syncdb
```

If you want a reusable dataframe-first workflow, the practical pattern is:

```nu
let people = (genq list people | polars into-df)
let events = (genq list events --place-name | polars into-df)
let names = (genq list names | polars into-df)
let families = (genq list families | polars into-df)
let children = (genq list children | polars into-df)
let citations = (genq list citations | polars into-df)
let sources = (genq list sources --all | polars into-df)
let places = (genq list places --coordinates | polars into-df)
let witnesses = (genq list witnesses | polars into-df)
let associations = (genq list associations | polars into-df)
```

Where current `genq` commands do not yet expose all needed columns, the sheets also show direct SQL extraction patterns using `query db`.

## Sheets

1. [Evidence-Weighted Fact Confidence Score](./01-evidence-weighted-fact-confidence.md)
2. [Life Timeline Anomaly Detector](./02-life-timeline-anomaly-detector.md)
3. [Migration Corridor Mapper](./03-migration-corridor-mapper.md)
4. [Surname and Identity Drift Analyzer](./04-surname-and-identity-drift-analyzer.md)
5. [FAN Network Centrality Map](./05-fan-network-centrality-map.md)
6. [Source Template Effectiveness Dashboard](./06-source-template-effectiveness-dashboard.md)
7. [Research Gap Heatmap](./07-research-gap-heatmap.md)
8. [Household Reconstruction Engine](./08-household-reconstruction-engine.md)
9. [Blended Family Complexity Profiler](./09-blended-family-complexity-profiler.md)
10. [Narrative Completeness Score](./10-narrative-completeness-score.md)
