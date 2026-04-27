# GenQuery — Database Shape Profile: Metric Catalog

**Date:** 2026-04-25
**Source of truth:** `src/lib/common/genq telemetry/profile-catalog.nu`
**Runner:** `src/lib/common/genq telemetry/profile.nu`
**Transport:** `POST /v1/profiles` (gzipped JSON) — see `docs/telemetry-design.md`
**Goal:** Catalog every candidate metric for a standard RootsMagic database "shape" report. Each row captures the specific query, whether it is currently in the live catalog, whether Claude Code recommends keeping/adding it, and the reasoning.

> **Note:** This document was originally drafted alongside a JS prototype
> (`scripts/db-shape-profile-metrics.js`) and a draft `sql/db-shape-profile.sql`.
> Both have been retired. The metric catalog now lives in Nushell at
> `profile-catalog.nu` and runs as a single mega-query at GenQuery startup.

> **Collation note.** Every metric below that performs DISTINCT, GROUP BY,
> ORDER BY, or string-equality on a RootsMagic name/place/source column uses
> `COLLATE NOCASE` to override the column's declared `RMNOCASE` collation —
> Nushell's SQLite layer cannot load the RootsMagic `RMNOCASE` extension, and
> any unqualified comparison against an `RMNOCASE` column would otherwise
> error with `no such collation sequence: RMNOCASE`. The trade-off is that
> `NOCASE` folds case but not diacritics, so distinct counts on diacritic-rich
> data (surnames, place names) can be marginally higher than RootsMagic's
> own UI reports. See the project README's *Known Limitations* section.

---

## How to read this catalog

| Column | Meaning |
|---|---|
| **Metric** | Output column or row of interest |
| **Specific Query** | SQL fragment that produces the metric (full queries live in `profile-catalog.nu`) |
| **Impl** | Y if the metric is in the live `profile-catalog.nu`; N if it is a candidate not yet included |
| **Rec** | Claude Code's recommendation for the final query — Y = keep/add, N = drop/skip |
| **Reasoning** | Why it earns (or fails) the recommendation |

Recommendation philosophy:
- **Tier A — keep:** High-signal scalar that captures size, structure, completeness, or data quality and varies meaningfully across customer DBs.
- **Tier B — discretionary:** Low-cost extras that round out coverage but rarely move the needle. Mostly Y when already present, N when adding more rows just to add them.
- **Tier C — drop:** Cosmetic flags, RM-internal admin tables, or fields with near-zero variance in real customer data.

---

## 1. Version & database metadata — `version_metadata`

Single-row record identifying RM version, DB identity, and SQLite physical layout.

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `sqlite_user_version` | `SELECT user_version FROM pragma_user_version` | Y | Y | Free; RM does not set this (always 0) but its presence/absence is a forensic check that the file is genuinely RM. |
| `sqlite_page_count` | `SELECT page_count FROM pragma_page_count` | Y | N | Useful only as a multiplicand for `db_size_kb` — keep the product, drop the operand. |
| `sqlite_page_size` | `SELECT page_size FROM pragma_page_size` | Y | N | Same as above — collapse into `db_size_kb`. |
| `db_size_kb` | `page_count * page_size / 1024` | Y | Y | Single most predictive scalar for query duration. |
| `rm_version` | `SUBSTR(ConfigTable.DataRec, …)` between `<Version>…</Version>` | Y | Y | Distinguishes RM7/8/9/10/11 — schema differences track this. |
| `rm_st_version` | `<STVersion>…</STVersion>` extract | Y | Y | Source-template definition version; matters for template interpretation. |
| `rm_unique_id` | `<UniqueID>…</UniqueID>` extract | Y | Y | Stable database GUID; lets multiple uploads from the same DB be correlated without other PII. |
| `rm_default_language` | `<DefLang>…</DefLang>` extract | Y | Y | Drives sentence rendering; cheap and revealing of locale. |
| `rm_date_format` | `<DateFormat>…</DateFormat>` extract | Y | Y | User's preferred date format setting. |
| `latest_utcmoddate_julian` | `MAX(UTCModDate)` across major tables | Y | Y | Activity recency signal — distinguishes a maintained DB from a dormant one. |
| `sqlite_version()` | `SELECT sqlite_version()` | N | Y | Cheap one-call; tells us which SQLite the host shipped (rusqlite version varies by Nushell build). |
| `pragma_journal_mode` | `PRAGMA journal_mode` | N | N | Read-only sessions don't care; reading it can switch modes on some builds. |
| `pragma_encoding` | `PRAGMA encoding` | N | N | Always UTF-8 in RM; zero variance. |
| `pragma_application_id` | `PRAGMA application_id` | N | N | RM doesn't set it — always 0. |
| `config_record_count` | `SELECT COUNT(*) FROM ConfigTable` | N | N | RM has only one ConfigTable row of interest; trivial. |
| `earliest_utcmoddate_julian` | `MIN(UTCModDate)` across tables | N | N | Approximates DB creation date but fragile (imports reset mod dates). |
| `record_count_total` | sum of `COUNT(*)` across all user tables | N | N | Derivable from the per-table sections; redundant. |

---

## 2. People — `people_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM PersonTable` | Y | Y | The headline scalar — every report and Enhanced Properties screen leads with it. |
| `male` | `SUM(CASE WHEN Sex = 0 …)` | Y | Y | Sex distribution drives RM lineage queries; useful proxy for completeness. |
| `female` | `SUM(CASE WHEN Sex = 1 …)` | Y | Y | Same as above. |
| `unknown_sex` | `SUM(CASE WHEN Sex NOT IN (0,1) …)` | Y | Y | Data quality flag — high counts indicate skeleton imports from GEDCOM. |
| `living` | `SUM(CASE WHEN Living = 1 …)` | Y | Y | Privacy-relevant; influences default report scope. |
| `private` | `SUM(CASE WHEN IsPrivate = 1 …)` | Y | N | RM10/11 stores the field but most users never set it; near-zero variance. Keep only if a customer reports its use. |
| `bookmarked` | `SUM(CASE WHEN Bookmark = 1 …)` | Y | N | Cosmetic; UI-only flag, no analytical value. |
| `with_note` | `COUNT(*) FROM PersonTable WHERE Note IS NOT NULL AND Note <> ''` | N | Y | Reveals depth of research notes; distinguishes a bare imported tree from a curated one. |
| `with_color` | `SUM(CASE WHEN Color1+…+Color9 > 0 …)` | N | N | Color tagging is heavily used by some RM power users but expressed across 10 columns; adds rows for niche payoff. |
| `with_proof` | `SUM(CASE WHEN Proof > 0 …)` | N | N | RM10 deprecated person-level Proof; the flag now lives on events. |
| `relate1_max` | `MAX(Relate1)` | N | N | Internal RM cache; unstable. |

---

## 3. Names — `name_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM NameTable` | Y | Y | Includes alternates; ≥ person count always. |
| `primary_names` | `SUM(CASE WHEN IsPrimary = 1 …)` | Y | Y | Should match person count exactly — divergence is a data-quality red flag. |
| `alternate_names` | `SUM(CASE WHEN IsPrimary = 0 …)` | Y | Y | AKA / married / nickname density; meaningful research depth signal. |
| `with_birth_year` | `SUM(CASE WHEN BirthYear > 0 …)` | Y | Y | RM auto-populates BirthYear from primary Birth event; coverage proxy. |
| `with_death_year` | `SUM(CASE WHEN DeathYear > 0 …)` | Y | Y | Same as above for deaths. |
| `distinct_surnames` | `COUNT(DISTINCT Surname COLLATE NOCASE) WHERE IsPrimary = 1` | N | Y | Surname diversity — a one-family tree has 1, a community tree has thousands. |
| `distinct_given_names` | `COUNT(DISTINCT Given …)` | N | N | High-cardinality and noisy (initials, compound names); little signal beyond surname diversity. |
| `with_prefix` | `SUM(CASE WHEN Prefix <> '' …)` | N | N | Niche; mostly clergy/military trees. |
| `with_suffix` | `SUM(CASE WHEN Suffix <> '' …)` | N | N | Niche; very low variance. |
| `with_nickname` | `SUM(CASE WHEN Nickname <> '' …)` | N | N | Niche; low variance. |
| `name_type_distribution` | `SELECT NameType, COUNT(*) GROUP BY NameType` | N | Y *(if added)* | Multi-row output; only worth it if `alternate_names > 0`. Defer until customers ask. |

---

## 4. Families — `family_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM FamilyTable` | Y | Y | Couple-units count; a fundamental structural number. |
| `one_parent` | `SUM(CASE WHEN (FatherID=0) <> (MotherID=0) …)` | Y | Y | Single-parent family count; reflects how exhaustively the user has built lineage. |
| `no_parents` | `SUM(CASE WHEN FatherID=0 AND MotherID=0 …)` | Y | Y | "Adoption-only" or skeleton families; data quality signal. |
| `child_links` | `COUNT(*) FROM ChildTable` | Y | Y | Total parent-child links across the tree. |
| `with_children` | `COUNT(DISTINCT FamilyID) FROM ChildTable` | Y | Y | Families with at least one child link. |
| `with_marriage_event` | `COUNT(DISTINCT OwnerID) FROM EventTable WHERE OwnerType=1 AND EventType=marriage_id` | N | N | Already implicit in `event_counts.family_events`; redundant. |
| `child_count_distribution` | `SELECT cnt, COUNT(*) FROM (SELECT FamilyID, COUNT(*) cnt FROM ChildTable GROUP BY FamilyID)` | N | N | Multi-row histogram; adds bulk for marginal insight. |
| `relationship_type_distribution` | `SELECT RelationType, COUNT(*) FROM ChildTable GROUP BY RelationType` | N | Y | Adoption / step / foster mix; small table, high-signal for tree complexity. |

---

## 5. Fact types — `fact_type_counts` & `fact_type_usage`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM FactTypeTable` | Y | Y | RM ships ~70 standard types; > 70 indicates customizations. |
| `person_scoped` | `SUM(CASE WHEN OwnerType = 0 …)` | Y | Y | Splits person vs family fact types — confirms catalog integrity. |
| `family_scoped` | `SUM(CASE WHEN OwnerType = 1 …)` | Y | Y | Same. |
| `likely_custom` | `SUM(CASE WHEN COALESCE(GedcomTag,'') = '' …)` | Y | Y | Best heuristic — standard fact types always carry a GEDCOM tag. |
| `used` | `COUNT(DISTINCT EventType) FROM EventTable` | Y | Y | How many fact types are actually exercised in this DB. |
| **`fact_type_usage` (table)** | per-row `(FactTypeID, Name, OwnerType, GedcomTag, COUNT)` | Y | Y | The interpretive payload — names included so custom types are readable. |
| `unused_fact_types` | `COUNT(*) FROM FactTypeTable WHERE FactTypeID NOT IN (SELECT EventType …)` | N | N | Derivable from `total - used` plus the usage table. |
| `sentence_overrides` | `COUNT(*) FROM FactTypeTable WHERE Sentence <> ''` | N | N | Cosmetic; doesn't affect data. |

---

## 6. Events — `event_counts`, `event_citation_coverage`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM EventTable` | Y | Y | Headline event count. |
| `person_events` | `SUM(CASE WHEN OwnerType = 0 …)` | Y | Y | Person/family split is a basic shape attribute. |
| `family_events` | `SUM(CASE WHEN OwnerType = 1 …)` | Y | Y | Same. |
| `with_date` | `SUM(CASE WHEN Date IS NOT NULL AND Date <> '' AND Date <> '.' …)` | Y | Y | Completeness ratio — undated events suggest GEDCOM debris. |
| `with_place` | `SUM(CASE WHEN PlaceID > 0 …)` | Y | Y | Same as above for places. |
| `proven` | `SUM(CASE WHEN Proof = 1 …)` | Y | Y | Quality flag — meaningful for genealogists who use it. |
| `disproven` | `SUM(CASE WHEN Proof = 2 …)` | Y | Y | Same. |
| `disputed` | `SUM(CASE WHEN Proof = 3 …)` | Y | Y | Same. |
| `private` | `SUM(CASE WHEN IsPrivate = 1 …)` | Y | Y | Privacy/scope signal. |
| `events_with_citations` | `COUNT(DISTINCT OwnerID) FROM CitationLinkTable WHERE OwnerType = 2` | Y | Y | Source-coverage proxy. |
| `witnesses_total` | `COUNT(*) FROM WitnessTable` | Y | Y | Witness/role usage indicates advanced RM customers. |
| `with_note` | `SUM(CASE WHEN Note <> '' …)` | N | Y | Note density per event distinguishes annotated from skeletal trees. |
| `with_sentence_override` | `SUM(CASE WHEN SentenceOverride <> '' …)` | N | N | Cosmetic narrative customization; rarely used. |
| `date_modifier_distribution` | `SUBSTR(Date, 2, 1)` histogram (about/before/after/between) | N | N | Niche; date-parser noise. |
| `date_type_distribution` | `SUBSTR(Date, 1, 1)` histogram (D/Q/R/T) | N | N | Almost always D in real data; near-zero variance. |
| `events_per_person` | `COUNT(*) / COUNT(DISTINCT OwnerID)` for OwnerType=0 | N | Y | One synthetic ratio that captures research depth at a glance. |

---

## 7. Places — `place_counts`, `place_usage`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `places` | `SUM(CASE WHEN PlaceType = 0 …)` FROM PlaceTable | Y | Y | Distinct places. |
| `temples` | `SUM(CASE WHEN PlaceType = 1 …)` | Y | N | LDS-specific; vast majority of trees report 0. Keep only if a customer skews LDS. |
| `place_details` | `SUM(CASE WHEN PlaceType = 2 …)` | Y | Y | Sub-place granularity is a marker of advanced usage. |
| `geocoded` | `SUM(CASE WHEN Latitude<>0 OR Longitude<>0 …)` | Y | Y | Geocoded ratio is a great quality indicator. |
| `not_geocoded` | `SUM(CASE WHEN Latitude=0 AND Longitude=0 …)` | Y | Y | Same. |
| `places_total` | `COUNT(*) FROM PlaceTable` | Y | Y | All-types row; sanity check vs the type breakdown. |
| `places_used` | `COUNT(DISTINCT PlaceID) FROM EventTable WHERE PlaceID > 0` | Y | Y | Reveals "ghost" places left over from imports. |
| `with_note` | `SUM(CASE WHEN Note <> '' …)` | N | N | Niche. |
| `country_count` | parse comma-tail of `Name` | N | N | RM stores place name as a single comma-joined string; expensive heuristic, low payoff. |
| `master_places` | `COUNT(*) FROM PlaceTable WHERE MasterID = 0` (PlaceTable hierarchy) | N | N | RM10's hierarchy is uneven; deferring. |

---

## 8. Sources, citations, templates — `source_counts`, `citation_*`, `source_template_*`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `sources.total` | `COUNT(*) FROM SourceTable` | Y | Y | Source count is a primary quality indicator. |
| `sources.freeform` | `SUM(CASE WHEN TemplateID = 0 …)` | Y | Y | Free-form vs templated split tells us the user's research style. |
| `sources.template_based` | `SUM(CASE WHEN TemplateID > 0 …)` | Y | Y | Same. |
| `citations.citations_total` | `COUNT(*) FROM CitationTable` | Y | Y | How many citations have been authored. |
| `citations.citations_no_source` | `SUM(CASE WHEN SourceID = 0 OR IS NULL …)` | Y | Y | Orphan citations — major data-quality flag. |
| `citation_links.citation_links_total` | `COUNT(*) FROM CitationLinkTable` | Y | Y | Total citation→record attachments. |
| `citation_links.citations_used` | `COUNT(DISTINCT CitationID) FROM CitationLinkTable` | Y | Y | "Live" citations vs orphans. |
| `source_citation_coverage.sources_with_citations` | `COUNT(DISTINCT SourceID) FROM CitationTable WHERE SourceID > 0` | Y | Y | How many sources are actually cited. |
| `source_template_counts.total` | `COUNT(*) FROM SourceTemplateTable` | Y | Y | Often 200-260 in stock RM. |
| `source_template_counts.likely_custom` | `SUM(CASE WHEN TemplateID >= 200 …)` | Y | Y | Heuristic — verify threshold once on more DBs. |
| **`source_template_usage` (table)** | per-row `(TemplateID, Name, Category, COUNT)` | Y | Y | Names + categories make custom templates interpretable. |
| `citation_links_by_owner_type` | `SELECT OwnerType, COUNT(*) GROUP BY OwnerType` | N | Y | Reveals whether citations are attached to people, events, families, etc. — a one-row distribution worth the ink. |
| `citations_with_quality` | `SUM(CASE WHEN Quality1+Quality2+Quality3 > 0 …)` | N | N | Quality fields rarely populated; near-zero variance. |
| `citations_with_note` | `SUM(CASE WHEN CitationName <> '' …)` | N | N | Niche. |
| `template_categories` | `SELECT Category, COUNT(*) GROUP BY Category` | N | N | Already covered in `source_template_usage` table. |

---

## 9. Repositories & addresses — `repository_and_address_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `repositories` | `SUM(CASE WHEN AddressType = 1 …)` | Y | Y | Real-archive count — separates serious researchers from hobbyists. |
| `general_addresses` | `SUM(CASE WHEN AddressType <> 1 …)` | Y | Y | Most RM trees keep this near zero; large values indicate deliberate use. |
| `repositories_used` | `COUNT(DISTINCT RepositoryID) FROM SourceTable WHERE RepositoryID > 0` | N | N | RM10 dropped explicit repository linking from the source UI; hard to interpret. |

---

## 10. Media — `media_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `media_items` | `COUNT(*) FROM MultimediaTable` | Y | Y | Stored media count. |
| `media_links` | `COUNT(*) FROM MediaLinkTable` | Y | Y | How many records reference media — the multiplier is meaningful. |
| `media_used` | `COUNT(DISTINCT MediaID) FROM MediaLinkTable` | Y | Y | Reveals orphan media files. |
| `media_by_type` | extract extension from `MediaPath` | N | N | RM doesn't store a clean type column; parsing path is brittle. |
| `media_with_caption` | `SUM(CASE WHEN Caption <> '' …)` | N | N | Cosmetic. |
| `media_links_by_owner_type` | `SELECT OwnerType, COUNT(*) GROUP BY OwnerType` | N | Y | Person vs event vs source attachment distribution; one extra small histogram. |

---

## 11. Tasks, groups, tags, roles — `task_*`, `group_tag_role_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `tasks.total` | `COUNT(*) FROM TaskTable` | Y | Y | To-do/research-task count; advanced-user marker. |
| `tasks.task_folders` | `COUNT(DISTINCT CASE WHEN TaskType > 0 …)` | Y | N | Field meaning is fuzzy across RM versions; rename or drop. |
| `task_links` | `COUNT(*) FROM TaskLinkTable` | Y | N | Implies tasks; usually small. Keep only if `tasks.total > 0`. |
| `groups` | `COUNT(DISTINCT GroupID) FROM GroupTable` | Y | Y | Named subset count. |
| `group_id_ranges` | `COUNT(*) FROM GroupTable` | Y | Y | Multiple ID-range rows per group; reveals structure. |
| `tags` | `COUNT(*) FROM TagTable` | Y | N | RM10 tag UI is minimal; many DBs report 0. Drop unless `> 0`. |
| `roles` | `COUNT(*) FROM RoleTable` | Y | Y | Custom witness roles — strong advanced-user marker. |

---

## 12. Associations — `association_counts`, `association_type_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `total` | `COUNT(*) FROM FANTable` | Y | Y | FAN-club / association count. |
| `missing_person` | `SUM(CASE WHEN ID1 = 0 OR ID2 = 0 …)` | Y | Y | Data-quality flag for orphan associations. |
| `association_types.total` | `COUNT(FANTypeID) FROM FANTypeTable` | Y | Y | RMNOCASE-safe count of declared association types. |
| `association_type_usage` | `SELECT t.FANTypeID, t.Name, (SELECT COUNT(*) FROM FANTable f WHERE f.FanTypeID = t.FANTypeID) FROM FANTypeTable t` | Y | Y | Per-type usage table; integer FK join (same shape as `fact_type_usage`). |

---

## 13. External links — `external_link_counts`

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `urls` | `COUNT(*) FROM URLTable` | Y | Y | Web-link count. |
| `ancestry_links` | `COUNT(*) FROM AncestryTable` | Y | Y | Ancestry.com integration usage. |
| `familysearch_links` | `COUNT(*) FROM FamilySearchTable` | Y | Y | FamilySearch tree-link usage. |
| `dna_records` | `COUNT(*) FROM DNATable` | Y | Y | DNA-research adoption signal. |
| `health_records` | `COUNT(*) FROM HealthTable` | Y | N | RM10's health table is rarely used; near-zero variance. |
| `urls_by_owner_type` | `SELECT OwnerType, COUNT(*) FROM URLTable GROUP BY OwnerType` | N | N | Niche. |

---

## 14. Time-bucketed histograms

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `events_by_decade` | `(yr/10)*10` from `SUBSTR(Date,4,4)` GROUP BY decade | Y | Y | Tree time-shape — does the data live in 1800s, 1900s, both? |
| `people_by_birth_decade` | `(BirthYear/10)*10` GROUP BY decade | Y | Y | Same shape via NameTable.BirthYear (auto-populated). |
| `deaths_by_decade` | `(DeathYear/10)*10` GROUP BY decade | N | Y | Mirror of births; small extra section, complete picture. |
| `marriages_by_decade` | events filtered to marriage `EventType` then bucketed | N | N | Adds complexity (need to resolve marriage FactTypeID first); deferring. |
| `events_by_year` | yearly granularity | N | N | Too noisy for a "shape" report; decades are right. |
| `events_by_century` | `(yr/100)*100` | N | N | Too coarse; decades dominate. |
| `events_by_decade_by_type` | decade × EventType cross-tab | N | N | Combinatorial blow-up; drop unless a specific use case appears. |

---

## 15. Activity & recency (candidates not yet implemented)

| Metric | Specific Query | Impl | Rec | Reasoning |
|---|---|---|---|---|
| `records_modified_30d` | `SUM(CASE WHEN UTCModDate > julianday('now') - 30 …)` per major table | N | Y | Distinguishes actively maintained DBs from archives — strong predictor of customer engagement. |
| `records_modified_365d` | same with 365d cutoff | N | Y | Annual activity bucket — pairs nicely with the 30d figure. |
| `oldest_record_age_days` | `julianday('now') - MIN(UTCModDate)` | N | N | Approximates DB age but unreliable (imports rewrite mod dates). |
| `record_count_total_user_tables` | summed `COUNT(*)` across listed user tables | N | N | Synthesizable downstream; redundant. |

---

## 16. Things deliberately excluded

These were considered and rejected for the standard report.

| Candidate | Why excluded |
|---|---|
| Free-text searches over Name / Note fields | Not a "shape" metric; risks ingesting PII. |
| `MaintTable`, `BackupRestoreTable`, `IndexTable` counts | RM internal admin; zero analytical value. |
| `SearchTable` contents | Ephemeral RM scratchpad. |
| Per-person event counts (top-N people) | Risk of de-identification; never include in any aggregate that could be uploaded. |
| Specific surnames or given names | PII; out of scope for telemetry-grade reporting. |
| Free-form Note text | PII risk. |
| GPS coordinates of geocoded places | PII-adjacent (residence locations). |

---

## Summary — what makes the cut

**Strongly recommended (core profile, ~45 metrics):**
- Version metadata (`rm_version`, `rm_st_version`, `rm_unique_id`, `rm_default_language`, `rm_date_format`, `latest_utcmoddate_julian`, `db_size_kb`, `sqlite_version()`)
- People scalars (`total`, `male`, `female`, `unknown_sex`, `living`, `with_note`)
- Names (`total`, `primary_names`, `alternate_names`, `with_birth_year`, `with_death_year`, `distinct_surnames`)
- Families (`total`, `one_parent`, `no_parents`, `child_links`, `with_children`, `relationship_type_distribution`)
- Fact types (`total`, `person_scoped`, `family_scoped`, `likely_custom`, `used`, plus the `fact_type_usage` table)
- Events (`total`, `person_events`, `family_events`, `with_date`, `with_place`, proof flags, `private`, `events_with_citations`, `witnesses_total`, `events_per_person`)
- Places (`places`, `place_details`, `geocoded`, `not_geocoded`, `places_used`)
- Sources/citations (`total`, `freeform`, `template_based`, `citations_total`, `citations_no_source`, `citation_links_total`, `citations_used`, `sources_with_citations`, `citation_links_by_owner_type`)
- Source templates (`total`, `likely_custom`, plus the `source_template_usage` table)
- Repositories (`repositories`, `general_addresses`)
- Media (`media_items`, `media_links`, `media_used`, `media_links_by_owner_type`)
- Tasks/groups/roles (`tasks.total`, `groups`, `group_id_ranges`, `roles`)
- Associations (`total`, `missing_person`, `association_types.total`)
- External links (`urls`, `ancestry_links`, `familysearch_links`, `dna_records`)
- Time histograms (`events_by_decade`, `people_by_birth_decade`, `deaths_by_decade`)
- Activity (`records_modified_30d`, `records_modified_365d`)

**Drop or defer:** `temples`, `bookmarked`, `private` (people), `tags`, `health_records`, `task_folders`, the various `with_note` / `with_caption` cosmetic flags, and any per-record histogram beyond decade granularity.

---

## Open questions for next iteration

1. **Verify `TemplateID >= 200` heuristic** for custom source templates against more customer DBs; the threshold may need to move to 1000 in newer RM versions.
2. **Verify `GedcomTag IS NULL OR ''` heuristic** for custom fact types — confirm there are no standard RM types with blank `GedcomTag`.
3. **Decide on a single canonical date-bucket** (decade chosen here) and apply it consistently to events, births, deaths, marriages.
4. **Resolve marriage FactTypeID dynamically** if the marriages-by-decade histogram is ever added — RM's standard marriage type is fact type ID 4 in stock DBs but customizers can change this.
5. **Consider a single derived "research density score"** — e.g., `(events + citations + media_links) / max(people, 1)` — as a one-number summary across the entire profile.
