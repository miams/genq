# Nushell Upgrade Ideas for GenQuery

Based on analysis of Nushell release notes v0.108–v0.111 (Oct 2025 – Feb 2026).

> **Note:** These features require updating to the latest Nushell before implementation.

---

## Ideas Ranked by Impact

### 1. `try/catch/finally` — Simplify SQL Cleanup Everywhere (v0.111)
**Impact: High**

Every SQL module (e.g., `genq list people`) has duplicated `DROP TABLE IF EXISTS` cleanup in *both* the `try` block *and* the `catch` block. The new `finally` block runs unconditionally — collapsing this pattern into one cleanup block per command. Affects every module that creates temp tables.

### 2. Redesigned `input list` with Fuzzy Search + Table Rendering (v0.111)
**Impact: High**

The config wizard uses `input list` for menu selections. The v0.111 rewrite adds fuzzy search, multi-select, vim navigation, and aligned table column rendering. Would meaningfully upgrade `genq config` UX and could power interactive person/source pickers for queries.

### 3. Tab Completion with `@complete` Attribute (v0.108)
**Impact: High**

genq currently has near-zero tab completions for subcommands. The new simplified `@complete` attribute and static completion syntax could provide completions for `genq list <type>`, `genq tabulate <report>`, database connection names, and more — dramatically improving discoverability.

Example syntax: `def go [direction: string@[ left up right down ]]`

### 4. Pipeline `let` Statements (v0.110/v0.111)
**Impact: Medium-High**

genq's SQL chains use the old `let result = (open $env.rmdb | query db "...")` pattern. Pipeline `let` keeps the flow readable inline and avoids breaking long pipelines into separate assignments. Applies widely across all modules.

Before: `let result = (open $env.rmdb | query db $sql)`
After: `open $env.rmdb | query db $sql | let result`

### 6. `join --prefix` / `--suffix` for Overlapping Column Names (v0.111)
**Impact: Medium**

When joining SQL result tables (people + events, people + citations), column name collisions (e.g., duplicate `OwnerID`, `Note`) require manual renaming. The new flags to prefix/suffix right-table columns would eliminate that boilerplate.

### 7. `compact` on Records to Drop Nulls (v0.108)
**Impact: Medium**

RootsMagic records are sparse — BirthYear, DeathYear, ParentID, SpouseID are frequently null. `compact` now works on records to remove null fields, enabling cleaner display and downstream processing without manual `reject` pipelines.

### 8. `str replace` with Closures (v0.109)
**Impact: Medium**

The `colorize` command (`src/main.nu`) uses chained `str replace` calls to map RTF markup to ANSI codes. Closure-based replacements would allow a single-pass transformation over all markup types, and could enable dynamic formatting based on matched content or capture groups.

### 9. `error_style = short` Config Option (v0.110)
**Impact: Medium**

genq is a data tool run interactively. The default Nushell error display with full context spans many lines. Setting `error_style = short` in genq's environment setup would give users tighter, single-line error messages that don't bury query output in noise.

### 10. `each --flatten` for Streaming Large Datasets (v0.108)
**Impact: Medium-Low**

Some users have RootsMagic databases with tens of thousands of records. The `--flatten` flag on `each` allows stream-of-streams to pass through without intermediate collection, reducing memory pressure in pipelines that transform rows (e.g., date formatting, RTF parsing, conditional field enrichment).

---

## Source Release Notes

- [v0.111.0](https://www.nushell.sh/blog/2026-02-28-nushell_v0_111_0.html) — Feb 28, 2026
- [v0.110.0](https://www.nushell.sh/blog/2026-01-17-nushell_v0_110_0.html) — Jan 17, 2026
- [v0.109.0](https://www.nushell.sh/blog/2025-11-29-nushell_v0_109_0.html) — Nov 29, 2025
- [v0.108.0](https://www.nushell.sh/blog/2025-10-15-nushell_v0_108_0.html) — Oct 15, 2025
