# GenQuery Deep Dive: Iiams.rmtree × 30 Producers × Nushell Idiom Audit

**Date:** 2026-04-25
**Database:** `Iiams.rmtree` (RootsMagic 11; 32 tables)
**Scope:** Producer-coverage gaps · command-tree organization · Nushell idiom leverage

---

## 0. TL;DR — The Three Findings

1. **Coverage**: ~22 of 32 RM tables are reachable today. The biggest *direct* gaps are `FactTypeTable` (114 rows — the customization spine of every event), `RoleTable` (199), `AddressTable` (42), `AddressLinkTable` (515), and `ExclusionTable` (138). The biggest *indirect* gaps are reverse-lookups (e.g., "every event citing source X", "every fact attached to media Y") and genealogist power-features (ancestors / descendants / timeline / relationship-distance / lifespans / `today`).

2. **Organization**: The `genq <verb> <noun> [modifiers]…` shape is mostly OK, but it has drifted: 18 different prefixes under `list` (good); naming is inconsistent (`groups` vs `web-tags`, `ancestry-links` vs `findagrave`, `list census` vs `census`); URL coverage is fragmented across four commands; extension namespaces pollute the global root verbs; the planned `tabulate`/`assess`/`audit` namespaces are mostly empty. A small refactor — `genq <noun> [filter]` (entities), `genq stats <noun>` (frequency), `genq audit <issue>` (quality), `genq find <query>` (search), `genq report <type>` (composed) — would absorb ~90% of the existing surface and make extensions additive instead of namespace-polluting.

3. **Nushell**: We use the *fundamentals* well — pipelines, closures, structured data, `select`/`reject`/`upsert`, `from xml`, `query db -p`, `@category`/`@example`/`@search-terms`. We **underuse** `par-each`, `error make`, custom completers, `polars`, `stor` (in-memory SQLite), the `format pattern`/`describe`/`metadata`/`inspect` family, overlays, `def --env`, `compact`, and we have a project-wide DRY opportunity around the LastUpdate insert / db-existence check / "List of X." print pollution.

The rest of this document substantiates and prioritizes each of these.

---

## Part 1 · Producer Call Site Gaps

### 1.1 Coverage Matrix — 32 RM Tables → 30 Producers

| Table | Rows (Iiams) | Direct producer? | Indirect coverage | Notes |
|---|---:|---|---|---|
| **PersonTable** | 11,700 | ✓ `genq list people` | many | core |
| **NameTable** | 12,249 | ✓ via people join | — | alternate names not surfaced separately |
| **EventTable** | 39,484 | ✓ `genq list events` | census/obits/etc. | core |
| **FactTypeTable** | 114 | ✗ **gap** | name shown in events | 86 standard + 28 custom — invisible to users |
| **FamilyTable** | ~? | ✓ `genq list families` | children/witnesses | OK |
| **ChildTable** | — | ✓ `genq list children` | — | OK |
| **SourceTable** | 5,455 | ✓ `genq list sources` (+ newspapers, sum all, labels) | — | well-covered |
| **CitationTable** | — | ✓ `genq list citations` | — | OK |
| **CitationLinkTable** | — | ✗ **gap** (no reverse-lookup) | implicit via citations | "Every event citing source X" requires hand SQL |
| **PlaceTable** | 5,133 | ✓ `genq list places` | — | OK |
| **MediaTable** | — | ✓ `genq list media` | — | OK |
| **MediaLinkTable** | — | ✗ **gap** (reverse) | implicit | "Every fact attached to media Y" |
| **GroupTable** | — | ✓ `genq list groups` | — | OK |
| **GroupMemberTable** | — | ✓ via groups | — | OK |
| **TagTable** | — | ✓ `genq list web-tags` | — | naming inconsistent (see §2) |
| **TagMemberTable** | — | ✓ via web-tags | — | OK |
| **URLTable** | 5,469 | ◐ partial | findagrave/ancestry-links/familysearch-links | fragmented — see §2 |
| **AncestryTable** | — | ✓ `genq list ancestry-links` | — | naming asymmetry |
| **FamilySearchTable** | — | ✓ `genq list familysearch-links` | — | OK |
| **WitnessTable** | — | ✓ `genq list witnesses` | — | OK |
| **DNATable** | — | ✓ `genq list dna` | — | OK |
| **TaskTable** | — | ✓ `genq list tasks` | — | OK |
| **AddressTable** | 42 | ✗ **gap** | — | repositories/libraries — invisible |
| **AddressLinkTable** | 515 | ✗ **gap** | — | every linked address — invisible |
| **FANTable** | 3 | ✓ `genq list associations` | — | OK |
| **FANTypeTable** | 16 | ✗ **gap** | name shown in associations | reverse mirror of FactType problem |
| **RoleTable** | 199 | ✗ **gap** | partial via witness role text | "Who plays role 'Bride' or 'Officiator'?" |
| **RoleNameTable** | — | ✗ **gap** | implicit | role-name overrides per fact-type |
| **HealthTable** | 0 | n/a | — | RM 11 reserved; empty in this tree |
| **ExclusionTable** | 138 | ✗ **gap** | — | "Who's excluded from reports/web?" |
| **MultimediaTable** | — | (legacy) | — | — |
| **VersionTable** / **MetaDataTable** / RM-internal | small | n/a | — | engine bookkeeping |

**Score**: 22 tables directly reachable, 7 missing direct producers, 3 RM-internal. `FactTypeTable` and `RoleTable` aren't usually browsed *as tables*, but they're the customization spine of the tree and we have no surface for them.

### 1.2 Missing Direct Producers — Top 5

#### a) `genq list fact-types` (or `genq tabulate fact-types`)
- **Why it matters**: 114 fact types in this tree (86 stock + 28 custom) and the user can't see which are user-defined or which are *unused* anywhere in events. RootsMagic itself buries this two dialogs deep.
- **What it would show**: `FactTypeID, Name, Abbrev, Sentence, OwnerType (P/F), Class, Used (event count)`.
- **Power**: combined with a `where Used == 0` clause it becomes a "kill orphan fact types" cleanup; combined with `histogram Class` it reveals the shape of the tree's evidence.
- **Sketch**: `SELECT FactTypeID, Name, OwnerType, Class, (SELECT COUNT(*) FROM EventTable e WHERE e.EventType = ft.FactTypeID) AS Used FROM FactTypeTable ft`

#### b) `genq list addresses` + `genq list address-links`
- **Why**: 42 addresses, 515 links. These are the repositories/libraries that anchor citations. Right now they're write-only — RM dialogs let you add them, but no read path exists in genq.
- **What**: `Name, Street1, City, State, Zip, Country, Email, Phone` plus link counts. With a join to `SourceTable`, "all citations whose source has an address in MD" becomes a one-liner.
- **Adjacent power**: feed `genq distance-from "Annapolis, MD"` (the existing geo helper) over the address list to rank repositories by drive time.

#### c) `genq list exclusions`
- **Why**: 138 rows. ExclusionTable controls who is hidden from reports, websites, and exports. If you've ever had a "missing person" in a published report, this table is the first place to look. Currently invisible.
- **What**: `RIN, Name (joined), ExcludedFromReports, ExcludedFromWeb, Reason`.

#### d) `genq list roles` and `genq list role-names`
- **Why**: 199 role rows. Roles are how RM expresses "Sarah was the Bride at Marriage event 4321", "Robert was the Officiator at Burial 9876". The witness producer surfaces *named witnesses* but not the structured role mapping itself. Power-users absolutely need this for narrative report writing.
- **What**: `RoleID, RoleName, ForFactType, Sentence`. Reverse query: "Show all events where role 'Officiator' is filled".

#### e) `genq list fan-types`
- **Why**: 16 rows. The taxonomy of associations (Friend, Neighbor, Adversary, Business Partner, …). Mirror of the FactType gap, smaller scale.
- **What**: `FANTypeID, Name, Sentence, Used (count)`.

### 1.3 Indirect & Reverse-Lookup Gaps

These are reachable in principle by chaining existing producers, but the reverse direction is missing or tortuous:

- **"Every event citing source X"** → today needs hand SQL through CitationLinkTable. A `genq list events --source-id 1234` flag (or `genq cite-uses <SourceID>`) would close this.
- **"Every fact attached to media Y"** → MediaLinkTable reverse-lookup. `genq media-uses <MediaID>`.
- **"Every person tagged <tag>"** → web-tags producer is tag-centric, not person-centric. A `genq list people --web-tag findagrave` flag (or filter helper) would invert the cardinality cheaply.
- **"Every place where event type = Census 1850"** → places producer doesn't filter by event usage.

The pattern: **producers today list one entity; users frequently ask about *intersections***. Five of the next ten power features are intersection queries, which suggests a more compositional approach than adding ten more producers (see §2.6).

### 1.4 Genealogist Power Features Worth Building

Ranked by genealogist value, with rough effort:

| Feature | What it does | Effort | Why high-value |
|---|---|---|---|
| `genq ancestors <RIN> [--gen N]` | Walk ChildTable up; return RIN, name, birth, death | S | Most-asked question in any tree |
| `genq descendants <RIN> [--gen N]` | Walk down | S | Same |
| `genq timeline <RIN>` | Single-person events sorted by date with computed age-at-event | S | "Tell me this person's life in one column" |
| `genq pedigree <RIN> [--gen 4]` | Ancestry-style boxed pedigree (text) | M | High-density visualization |
| `genq relationship <RIN-A> <RIN-B>` | Common ancestor + relationship name (e.g., "1st cousin 2x removed") | M | Killer-app for tree merging |
| `genq distance <RIN-A> <RIN-B>` | Generation distance only | XS | Subset of relationship |
| `genq today` | All events whose month-day is today (births, deaths, anniversaries) | XS | Daily-driver feature; many tools have it |
| `genq find <query>` | Free-text search across names, places, notes | S | Replaces 5 specific filters |
| `genq lifespan <RIN>` | Years between birth and death events with anomaly flags | XS | First-class wrapper around existing date math |
| `genq endogamy [--threshold]` | Count of common ancestors within N generations | M | High signal for colonial-era trees |
| `genq migration <RIN>` | Place-changes over time → corridors | M | Maps onto existing `distance-from` | 

The first six (ancestors, descendants, timeline, pedigree, relationship, today) are the genealogist baseline that any RM-aware tool is expected to provide. Building them on the rmdate three-layer API is straightforward and reuses existing infrastructure.

### 1.5 Tabulation Gaps — `tabulate` Namespace Is Almost Empty

CLAUDE.md lists `genq tabulate` as a planned summary-reports namespace, and only one command exists: `genq tabulate sources labels`. Strong candidates:

- `genq tabulate fact-types` — frequency of EventType across EventTable (Iiams: Birth 10666, Death 8089, Marriage 4986, Census 4001, Obituary 2236…)
- `genq tabulate decades` — events grouped by decade (`SortDate / 365.25 / 10` ⇒ century-bucket)
- `genq tabulate surnames` — surname frequency from NameTable
- `genq tabulate ages-at-death` — life-span histogram
- `genq tabulate places` — place frequency, with `--by city|county|state|country` flag
- `genq tabulate citation-coverage` — % of facts with at least one citation
- `genq tabulate sources templates` — sibling to "labels"; group by `TemplateID`
- `genq tabulate gender` — male/female/unknown
- `genq tabulate role-usage` — how often each role is filled
- `genq tabulate fan-types` — FAN type frequency

These are *cheap*: each is a 5-15 line wrapper over the existing producers + `histogram` or `group-by` + `compact`. They turn the tree into a research dashboard.

### 1.6 Audit / Quality Gaps — `assess` / `audit` Namespace Is Missing

The most-requested *actionable* reports in genealogy software are quality audits. Iiams.rmtree's row counts suggest this tree has plenty of low-hanging fruit:

- `genq audit unsourced` — events with zero CitationLinkTable rows (likely thousands)
- `genq audit dates` — events with malformed `Date`, future birthdates, deaths-before-birth, marriages-after-death
- `genq audit places` — place strings not normalized (commas, capitalization, country missing)
- `genq audit duplicates` — same name + same DOB + DDB ≈ duplicate person
- `genq audit lifespans` — > 110 years or < 0
- `genq audit primary-name` — people with no name marked primary
- `genq audit orphans` — people with no parent and no children (true islands vs. legitimate root ancestors)
- `genq audit gender` — events whose role-set conflicts with person's gender
- `genq audit broken-media` — MediaTable rows with missing files on disk
- `genq audit empty-fact-types` — FactTypes with zero events (cleanup)

This is where a *power genealogist* will spend most of their time once the reporting basics work. It is also the strongest argument for a structured `genq report <type>` composer (§2.6) that bundles "all audits → markdown".

---

## Part 2 · Organizational Structure

### 2.1 Current Shape — A Snapshot

```
genq                                        ← root dispatcher
├─ config / config list / config --help     ← setup wizard (no get/set, by design)
├─ list (~24 subcommands)
│   ├─ associations · citations · children · dna · events · families
│   ├─ groups · media · people · places · sources · tasks · web-tags · witnesses
│   ├─ ancestry-links · familysearch-links
│   ├─ census                               ← top-level (in main.nu, ≠ genq census)
│   ├─ polars events                        ← in-progress, commented-out
│   └─ (extension)
│       ├─ miams: findagrave · obits · obits sum all · newspaper obits summary
│       │         · sources newspapers
│       └─ pres2025: presidents
├─ tabulate
│   └─ sources labels                       ← only 1 entry
├─ distance-from                            ← geo transformer
├─ rmdate <subcommands>                     ← date library
├─ census  (miams ext)                      ← name-clash with `list census`
└─ (no audit / assess / report / find / today / ancestors / etc.)
```

### 2.2 Inconsistencies and Friction

**A. Naming asymmetries.** `genq list groups` vs `genq list web-tags` — both are user-defined groupings; one is "groups", one is "tags". OK at the RM level, jarring as a CLI surface. `genq list ancestry-links` vs `genq list findagrave` — both are external-link producers; one is structured (`AncestryTable`), one is a single-purpose URL filter. A user would not guess this from the names.

**B. Verb-noun shape drifts at extensions.** `miams` adds `genq census`, `genq list findagrave`, `genq list obits`, `genq list obits sum all`, `genq list newspaper obits summary`, `genq tabulate sources labels`, `genq list sources newspapers`. Five of those seven sit *under* the global verbs (`list` / `tabulate`) and pollute the global namespace; `genq census` is alone at root and *also* coexists with `genq list census` (in `src/main.nu`). A separate `genq miams …` namespace would make the extensions strictly additive instead of competing for global verbs.

**C. URL coverage is fragmented.** Today: `genq list ancestry-links`, `genq list familysearch-links`, `genq list findagrave`, `genq list web-tags`. All four hit overlapping URL data. A unified `genq list links [--source ancestry|fs|findagrave|all] [--owner P|S|F]` would consolidate four producers into one with flags, and `findagrave` becomes `genq list links --type findagrave` rather than its own miams extension.

**D. Naming verbosity.** `genq list newspaper obits summary` is five words. `genq list obits sum all` is five words. These are filter expressions wearing command-name clothes. The natural Nushell shape is `genq list obits` (the producer) `| where Newspaper =~ 'X'` or `| histogram` — the extensions have *already* hand-rolled the producer logic each time, with cut-and-paste SQL. Compare:
- `src/lib/ext/miams/genq list obits/mod.nu:8` and
- `src/lib/ext/miams/genq list newspaper obits summary/mod.nu:8` and
- `src/lib/ext/miams/genq list obits sum all/mod.nu:8`

Three near-identical SQL queries, three commands, all because there's no `genq list events --type 1000` to filter on. The right shape is *one* producer + filters + downstream.

**E. The "List of X." print pollution.** Every producer starts with:
```nu
print "List of X."
```
This fires *even when piped* — `genq list people | first 5` prints "List of people." then 5 records. It pollutes test capture, breaks composition, and serves no purpose at the REPL where the table itself is self-evidently the list. See `src/lib/ext/miams/genq list obits/mod.nu:5`, `src/lib/ext/miams/genq list obits sum all/mod.nu:5`, `src/lib/ext/miams/genq list newspaper obits summary/mod.nu:6`. **Recommendation**: drop these prints, or guard with `if (term size).columns > 0 and (input-is-tty)` (Nushell exposes terminal mode via `$env`).

**F. `display_output` hook collides with explicit pipelines.** The 1-based `index` column is great for REPL ergonomics but it surprises any pipeline that does `| where index < 5`. Fine as a default; needs a switch.

**G. `genq list polars events` is checked in with all logic commented out.** Either ship it or remove it. It clutters the surface and a `--help` user can't tell the difference between aspirational and working.

**H. `genq list census` lives in `src/main.nu`, not `src/lib/`.** Architecturally it should live alongside its peers. Right now `main.nu` is the dispatcher *and* a producer host, which makes it harder to read.

### 2.3 If We Started From Scratch — A "From-Scratch" Model

The verb-as-namespace plan that fits today's commands and the 30+ aspirational ones:

```
genq <noun>                  ← entity producer (default: list-all)
genq <noun> --filter ...     ← inline filtering, no separate command
genq stats <noun>            ← histograms / frequencies (replaces tabulate)
genq audit <issue>           ← quality reports (replaces list checks)
genq find <query>            ← free-text search across nouns
genq report <type>           ← composed multi-producer outputs
genq export <noun> --fmt md  ← format converters
genq <verb-of-art>           ← genealogy verbs: ancestors, descendants,
                               timeline, pedigree, relationship, today, lifespan
genq config / rmdate / distance-from   ← tools (unchanged)
genq <ext>:<command>         ← namespaced extensions, e.g. miams:obits
```

**Mapping today → tomorrow** (no command goes extinct, all are cheaper):

| Today | Tomorrow |
|---|---|
| `genq list people` | `genq people` |
| `genq list events` | `genq events` |
| `genq list census` (in main.nu) | `genq events --type census` |
| `genq census` (miams) | `genq miams:census` |
| `genq list obits` | `genq events --type obituary --notes` |
| `genq list newspaper obits summary` | `genq events --type obituary --filter "newspaper =~ 'X'" --no-notes` |
| `genq list obits sum all` | `genq events --type obituary --no-notes` |
| `genq tabulate sources labels` | `genq stats sources --by tag` |
| `genq list findagrave` | `genq links --type findagrave` |
| `genq list ancestry-links` | `genq links --type ancestry` |
| `genq list familysearch-links` | `genq links --type fs` |
| `genq list web-tags` | `genq links --by tag` |
| (new) | `genq audit unsourced`, `genq today`, `genq ancestors 191`, … |

Wins: extensions become additive; `tabulate` doesn't sit empty; the four URL commands collapse to one; the obits triplet collapses to one; `audit`/`today`/`ancestors` arrive in a coherent place; the `print "List of X."` problem disappears at the same time because we'd remove the prints when porting.

### 2.4 Migration Path (Non-Breaking)

If the from-scratch shape is accepted, the migration is:

1. Add the new shape (`genq people`, `genq events`, etc.) as **aliases** to the existing `list` commands. No removal.
2. Move `tabulate` to `stats` with an alias.
3. Add `audit`, `today`, `ancestors`, `descendants`, `timeline`, `relationship` as new commands. Zero impact on existing.
4. Build the unified `genq links` and start aliasing the four old commands.
5. Mark the old `list X` and `tabulate` shapes deprecated in `--help` (`@category` is your friend) over one minor release.
6. Drop deprecated commands at the next major.

This is a 2–3 week project at most, broken into PRs that are each independently shippable.

---

## Part 3 · Are We Fully Leveraging Nushell?

Reference baseline: nushell.sh/commands, /lang-guide, /cookbook, and especially "Thinking in Nu" — Nu is a *structured* shell; pipes carry tables, not lines.

### 3.1 What We Use Well

- **Pipelines & structured data.** Producers return tables; downstream `where`/`select`/`reject`/`sort-by`/`first` compose cleanly. This is the core idiom and we honor it.
- **Closures + `insert {|row| ...}`.** Used extensively in `genq list obits/mod.nu` to pre-render ANSI from `<b>`/`<i>`/`<u>` tags, and in `genq list sources newspapers/mod.nu` to extract source-template fields from XML. Idiomatic.
- **`from xml` for source templates.** `src/lib/ext/miams/genq list sources newspapers/mod.nu:11-13` parses the `Fields` BLOB as XML and pulls `Footnote/ShortFootnote/Bibliography` via path indexing. Excellent leverage.
- **`query db -p` for parameterized SQL.** Used in producers that take RIN/ID arguments — avoids string-concat injection.
- **Annotation metadata.** `@category`, `@example`, `@search-terms` (e.g., `genq list sources newspapers/mod.nu:3-4`) is exactly what `--help` and `tldr`-style discovery want. Strong.
- **Three-layer date API in `rmdate/`.** The atomic accessor / parse-full / composite predicate split is textbook Nushell module design — small typed building blocks composed at the call site.
- **`display_output` hook** for table indexing — uses Nushell's hook system instead of wrapping each producer.
- **`use ext/miams *` / `use ext/pres2025 *`** in `main.nu` — module-as-namespace.

### 3.2 What We Underuse — Each With a Concrete Hook

#### a) `par-each` for I/O-heavy fanout
The textbook `par-each` case is any per-row I/O fanout — file existence checks, hash computations, network probes. Example for a future `genq audit broken-media`:
```nu
$media | par-each {|m| { ...$m, exists: ($m.fullpath | path exists) } }
```
**Where it fits**: `genq audit broken-media` (file-existence checks), the planned `genq export` (per-person markdown writes), any future `genq audit links` that probes URLs.

#### b) `error make` instead of `print "Error:" + ansi red`
`genq tabulate sources labels/mod.nu:8-10` uses `print` + `return`:
```nu
print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
print "Make sure your database is configured correctly with 'genq config'."
return
```
The Nushell idiom is `error make`:
```nu
error make {
    msg: "Database not found or not accessible"
    label: { text: "expected at $env.rmdb", span: (metadata $env.rmdb).span }
    help: "Run 'genq config' to set the database path."
}
```
This gets a real exit code, structured error, line span — and *test scripts can `try/catch` on it*.

#### c) Custom completers
None today. `genq list census --year <TAB>` should complete to `[1790 1800 ...]`; `genq list events --type <TAB>` to fact-type names; `genq ancestors <TAB>` to RIN+Name from PersonTable. Nushell's `external_completer` / `command-completion` config is exactly the right fit for SQL-backed completion. Even a 50-row most-recent person prefetch would be transformative for daily use.

#### d) `polars` plugin
Started in `src/lib/common/genq list polars events/mod.nu` and **all logic commented out**. For 39k-row event scans with date-math joins, polars dataframes are 10-100× faster than the equivalent Nushell tabular operators. A real win for `audit`/`stats` commands that scan the full event table. Either finish it (one producer is a great proof point) or remove the file — the half-state is worse than either.

#### e) `stor` (in-memory SQLite)
Nushell ships a built-in in-memory SQLite via `stor open`/`stor create`. For tests, intermediate joins, and the planned `audit duplicates` (which needs a self-join over names + DOBs), `stor` is faster than re-roundtripping through `query db`. Currently unused.

#### f) `format pattern`
For any future `'{Surname}, {Given} (RIN {RIN})'`-style filename or display generation (e.g., a `genq export` command), `format pattern` is the typed alternative to string interpolation — and it works directly on table rows. Minor, but it's the idiomatic Nu way.

#### g) `describe` / `inspect` / `metadata`
None used. Useful in `audit dates` (detect type drift in a column), in tests (assert column types), and in error messages (show the user "you piped me a list, not a table"). `metadata` is the way to retain spans for `error make`.

#### h) Overlays (`overlay use` / `overlay hide`)
The current module loading in `main.nu` is `use common *`, `use ext/miams *`, etc. — a single overlay. Overlays can be activated/deactivated dynamically, which is what an extension manager *should* be. Today, every extension is loaded at startup whether you want it or not. `overlay use ext/pres2025` would let users opt into extensions, and `overlay list` would tell them what's active. This is also how the planned "discoverer-edition" gating could work.

#### i) `def --env`
Producers that change `$env.config.datetime_format` (e.g., `genq list obits/mod.nu:7`) leak that change to the caller's session because the env mutation is happening inside a regular `def`. `def --env` makes it explicit; better still, format the date inside the closure and don't touch `$env.config` at all (the SQL already returns `STRFTIME(...)`).

#### j) `compact` / `default` / `is-empty` patterns
We do `| default ""` in a couple places and check `path exists`. Nushell's `compact` (drop nulls), `default` (fill nulls), and `is-empty`/`is-not-empty` are underused — many of the conditional column blocks in producers can be replaced with `| default "—"` over the whole table.

#### k) `histogram` and `group-by`
Used exactly once (`genq tabulate sources labels`). Any of the §1.5 tabulation gaps becomes a 3-line command with `group-by` + `length` or `histogram`. We're paying for a feature we don't use.

#### l) `inspect` for telemetry
The codebase has a telemetry scaffold (`docs/telemetry-design.md`). `inspect` is the natural Nushell hook for tap-the-stream telemetry — it passes through, prints to a sink, and doesn't break composition.

### 3.3 DRY / Pattern-Extraction Opportunities

Three patterns appear in 20+ files and each one is a one-function refactor.

**Pattern A — db-existence guard.** `genq tabulate sources labels/mod.nu:5-10` has the canonical version. Most producers don't have it (and silently produce empty tables when the rmdb is unset). Extract:
```nu
# common/ensure-db.nu
export def ensure-db [] {
    if not ($env.rmdb? | default "" | path exists) {
        error make { msg: "Database not configured", help: "Run: genq config" }
    }
}
```
Call once at the top of every producer. ~60 lines saved across the surface and behavior becomes uniform.

**Pattern B — UTCModDate format.** Every producer has the same SQL fragment:
```sql
STRFTIME(DATETIME(UTCModDate + 2415018.5)) AS LastUpdate
```
or with `' +0000'` appended (`genq list obits/mod.nu:8` has it; `genq list obits sum all/mod.nu:8` doesn't). Inconsistency aside, this is a SQL macro begging to be a Nushell helper:
```nu
def lastupdate-sql [col: string = "UTCModDate"] {
    $"STRFTIME(DATETIME(($col) + 2415018.5)) || ' +0000' AS LastUpdate"
}
```
Then producers do `let sql = $"SELECT ... ($lastupdate-sql) FROM ..."`. Single source of truth.

**Pattern C — `print "List of X."`.** Drop these or extract to one helper that respects `is-tty` / pipe state. Pollution gone.

**Pattern D — column conditional `select`/`reject`.** Many producers have a "show this column or not" branching. Push that into a `--columns` flag on a single helper that diffs against a default column-set. (This is the same shape as `git log --oneline` vs `git log --pretty=full`.)

### 3.4 "Thinking in Nu" Compliance

Per the *Thinking in Nu* essay, the tells of un-Nu-thinking are: text-stream reasoning, awk-style splitting, side-effect printing in the middle of pipelines, and command-as-script-file rather than command-as-data-transformer.

- ✓ **No awk-style splitting.** Producers stay tabular.
- ✓ **`from xml`, `query db`** instead of grep+regex against blobs.
- ✗ **Side-effect prints in producers.** "List of X." messages mid-pipeline.
- ✗ **Multiple near-identical scripts** for what should be filters (the obits triplet).
- ✗ **`$env.config.datetime_format = ...`** — env mutation inside a producer.
- ✓ **Module structure** is conventional Nushell.
- ◐ **Hooks used (display_output)** but not yet for telemetry/error reporting.

Net: **70% Nu-idiomatic**, with a clear path to 90% via the four DRY extractions and the print/env-mutation cleanup.

---

## Part 4 · Priority Matrix — Where to Spend Next

Sorted by user-visible value × engineering cost.

### Tier S — Ship This Sprint (each ≤ 1 day)

1. **`genq today`** — daily-driver feature, 30 lines. Filters `events` where `month-day = today()`.
2. **`genq ancestors <RIN>` + `genq descendants <RIN>`** — recursive ChildTable walk, ~50 lines each.
3. **`genq timeline <RIN>`** — events by date, age-at-event computed via rmdate. ~30 lines.
4. **DRY: `ensure-db` helper** — 5 lines + 25-call rollout. Eliminates silent empty tables.
5. **Drop or guard the "List of X." prints.** ~30 file edits, all trivial.

### Tier A — Next Two Sprints

6. **`genq audit` namespace** with `unsourced`, `dates`, `lifespans`, `duplicates`. Each 20-50 lines.
7. **`genq stats` rename** of `tabulate` + 8 new sub-stats (decades, surnames, ages, places, etc.).
8. **`genq list fact-types`, `roles`, `addresses`, `exclusions`, `fan-types`** — five 15-line producers.
9. **Unified `genq links`** with `--type` flag; deprecate the four splits.
10. **`genq relationship <A> <B>`** — common-ancestor walk + name table.
11. **`error make` rollout** — replace `print error + return` everywhere.

### Tier B — Sprint 3+ (Higher-effort, High-reward)

12. **Custom completers** for RIN, fact-type, year, place — turn the CLI into a Spotlight for the tree.
13. **`polars` for full-table audits** — finish what `genq list polars events` started.
14. **Extension namespacing migration** (`miams:obits`) with aliases preserving today's commands.
15. **`overlay use` for opt-in extensions** — reduce default surface area; better discoverability.
16. **`stor`-backed audit pipelines** — duplicate detection, date-anomaly detection, cross-source confirmation.

### Tier C — Strategic / Research

17. **`genq pedigree`** with text rendering — high-density visualization.
18. **`genq find <query>`** — full-text across names/notes/places.
19. **`genq export --md` as a generic format pipe** — Obsidian-flavored markdown writer with YAML frontmatter, plus `--csv`, `--json5` siblings.
20. **`genq report <kind>`** — composer that bundles "all audits" or "person dossier".
21. **`genq endogamy`, `genq migration`** — research-grade analytics tied to the analytics-product-sheets.

---

## Appendix A · Inventory of 30 Producer Call Sites

(Verified against `src/lib/{common,ext/miams,ext/pres2025}/`.)

**Common (17)**: people, events, families, children, witnesses, places, sources, citations, media, dna, tasks, groups, web-tags, ancestry-links, familysearch-links, associations, polars events (commented).

**Common — non-list (3)**: distance-from, rmdate (multi-sub), config (multi-sub).

**main.nu inline (1)**: list census.

**Extension miams (7)**: census, list findagrave, list obits, list obits sum all, list newspaper obits summary, list sources newspapers, tabulate sources labels.

**Extension pres2025 (1)**: list presidents.

(Three of these are derivative wrappers that should be filters — see §2.2-D and §2.3 mapping.)

## Appendix B · Reference Reads

- Nushell command index: https://www.nushell.sh/commands/
- Language guide: https://www.nushell.sh/lang-guide/
- Cookbook (esp. *Working with Tables*): https://www.nushell.sh/cookbook/
- Thinking in Nu: https://www.nushell.sh/book/thinking_in_nu.html
- Internal: `docs/db-coverage-matrix.md`, `docs/genq-improvement-ideas.md`, `docs/development/nushell-gotchas.md`, `docs/cookbook.md`, `docs/tao-of-genquery.md`.

— end —
