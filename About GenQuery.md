# GenQuery

## Principles, Philosophy and Implementation Approach

### What GenQuery Is

GenQuery is a genealogy reporting engine use with RootsMagic databases. It sits between the genealogist and the underlying SQLite file, exposing family tree data as structured, composable pipelines instead of complex SQL queries or canned reports.

It is built for casual researchers who want to *explore* their data — ask questions, find inconsistencies, improve quality — without writing brittle SQL or wrestling with the limits of RootsMagic's built-in reporting. It is built with the understanding that we think iteratively as we learn and explore

### Philosophy

**Data is the interface.** Genealogy is a data problem: people, events, relationships, sources, and the tangled web between them. GenQuery treats every output as structured data first — tables you can filter, sort, join, and pipe — and presentation second.

**Pipelines beat scripts.** A chain of small, well-named operations is easier to read, modify, and trust than a dense SQL statement. SQL is powerful but unforgiving; one missing JOIN reshapes the whole result. Nushell's structured pipelines deliver the same expressive power with a fraction of the cognitive load — and they reward curiosity. Genealogy is supposed to be fun.

**Exploration is the goal, not reporting.** Most genealogy tools treat output as the end state: a printed family group sheet, a PDF. GenQuery treats output as raw material for the next question. Every command is a starting point.

**Quality over completeness.** A small tree with clean, well-sourced data is more valuable than a sprawling one full of conflicts and unsourced claims. GenQuery exists to surface the inconsistencies that pull data quality upward.

### Principles

1. **Read-only by construction.** GenQuery never modifies the user's `.rmtree` file. Reports cannot corrupt data they cannot write to.
2. **Domain language, not schema.** Users ask for `people`, `events`, `citations` — never `PersonTable` or `EventTable`. The schema is an implementation detail.
3. **Composability over feature count.** A small set of primitives that compose beats a hundred specialized reports. `genq list people | where ...` beats `genq report-people-without-birthdates-in-iowa`.
4. **Extensibility belongs to the user.** Personal research questions are personal. `src/lib/ext/` is a first-class home for idiosyncratic, "just for me" extensions — not a hack around the core.
5. **Configuration is data, not API.** Settings live in TOML. No `config get` / `config set` surface to maintain. Edit the file or run the wizard.
6. **Tests scale with cost.** Fast tests gate every change; database tests run serially when needed. The label is the contract.

### What GenQuery Is Not

- **Not a replacement for RootsMagic.** Editing, GEDCOM, and tree management stay in RootsMagic. GenQuery is the analytical companion.
- **Not a GUI.** The terminal is the interface; the pipeline is the language.
- **Not a traditional reporting engine.** No layouts, print formatting, or PDF templates — those are downstream concerns.
- **Not a write tool.** Even when writes would be convenient, they are out of scope.
- **Not a general-purpose database tool.** GenQuery knows about *genealogy*. That domain knowledge is the value.
- **Not bit-for-bit identical to RootsMagic's UI for name comparisons.** GenQuery uses SQLite's `NOCASE` collation (ASCII-only case folding) in lieu of RootsMagic's proprietary `RMNOCASE`, which folds diacritics as well. Sorts and distinct-counts on names containing diacritics can differ slightly from RootsMagic. See the README's *Known Limitations* section.

### Implementation Approach

- **Built on Nushell** for structured pipelines and a syntax that rewards exploration.
- **SQLite via CTEs.** All intermediate query logic lives in `WITH ... AS (...)` clauses inside read-only queries — no views or temp tables touch the user's database.
- **Layered architecture.** `common/` holds shared primitives; `ext/` holds personal and project-specific extensions. New domains slot in without touching the core.
- **Tested by cost class.** `fast`, `db-pres2025`, `db-iiams` labels let the developer run the slice that matches the change.
