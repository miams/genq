# GenQuery Discoverer Edition — 20 Innovative Use Cases

**Date**: 2026-03-26
**Context**: Commercial edition built on genq + http-nu + Datastar + xs + FamilySearch API

---

## Stack Summary (What Makes These Possible)

| Layer | Role |
|-------|------|
| **genq** | Local RootsMagic SQLite query engine — the authoritative local truth |
| **FamilySearch API** | 1.8B tree persons, 22.7B historical records, hints, memories, places, change history |
| **http-nu** | Nushell HTTP server — routes, SSE streaming, Datastar SDK, xs store integration |
| **Datastar** | ~11.4KB reactive browser frontend — signals + SSE-driven DOM morphing, no build step |
| **xs** | Append-only local event log — actors, services, TTL, Nushell-native; the connective tissue |

---

## The 20 Use Cases

---

### 1. Live Record Hint Processor

**What it does**: A xs background service continuously polls FamilySearch hint ETags for every person in your local tree. When new hints appear, a xs actor scores them (confidence × data completeness × source quality), and the top candidates surface in real time in a Datastar dashboard — before you even open FamilySearch.

**Tech combination**:
- xs service: polls `GET /platform/tree/persons/{pid}/matches` on a schedule per person
- xs actor: scores each hint, appends `hint.ready` frames with priority rank
- http-nu + Datastar: live hint queue streams to browser via SSE; `datastar-patch-elements` inserts ranked cards

**Why it's innovative**: Genealogy research currently requires manually opening each person on FamilySearch to check for hints. This inverts the model — hints come to you, pre-scored, across your entire tree simultaneously.

**Commercial value**: The single feature most likely to convert active researchers. Eliminates the most tedious part of the workflow.

---

### 2. Tree Divergence Live Audit

**What it does**: Side-by-side live comparison of your local RootsMagic data against the FamilySearch Family Tree for any person or family group. Conflicts (differing birth dates, name spellings, missing parents, contradictory death locations) appear as colored diff cards streamed via SSE. Each conflict links directly to the FS `sourceLinker` page for resolution.

**Tech combination**:
- genq queries local RootsMagic for person facts
- FamilySearch API `GET /platform/tree/persons/{pid}` fetches FS version
- Nushell diffing logic compares GEDCOM X facts against local SQL fields
- Datastar signals: `$current_rin` drives the comparison; morphing updates conflict list in place
- xs: captures every accepted/rejected resolution as an append-only audit trail

**Why it's innovative**: Today researchers manually toggle between RootsMagic and FamilySearch. This delivers a structured, auditable diff — and because xs stores every resolution decision, you can replay and review your own reasoning months later.

---

### 3. Research Session Capture & Replay

**What it does**: Every research action — person viewed, hint accepted, source attached, note added, FamilySearch page visited — is appended as an xs frame with metadata. Sessions are replayable: scrub through a timeline to see exactly what you did and why. Export sessions as a structured research log narrative.

**Tech combination**:
- xs: append-only log with `research.person.viewed`, `research.hint.accepted`, `research.source.attached` topics
- xs `last:1` TTL for "current focus" state
- http-nu + Datastar: live activity sidebar streams via SSE into browser during active research
- Nushell pipeline: `.cat --topic "research.*"` → formatted session report

**Why it's innovative**: Genealogical proof standards require documenting your research process, not just your conclusions. This generates that documentation automatically. The xs replay model means you can demonstrate your reasoning to other researchers or reviewers.

---

### 4. Multi-Researcher Awareness Room

**What it does**: Multiple researchers working on the same family line (e.g., cousins collaborating) share a live xs stream. When researcher A starts working on an ancestor, researcher B's browser immediately shows "Alice is researching John Iiams (1842)" — preventing duplicate work and enabling hand-offs. Includes a live research map showing who is focused where in the pedigree.

**Tech combination**:
- xs: shared store exposed via TCP (`xs serve --expose :3021`) or iroh P2P (no port forwarding needed)
- xs `ephemeral` TTL: "currently researching" presence frames that vanish when researcher disconnects
- http-nu + Datastar: each researcher's browser subscribes to the shared stream via SSE
- Datastar signals: `$focus_rin` per researcher, rendered as avatars on a pedigree graph

**Why it's innovative**: No genealogy software currently provides real-time collaborative awareness without a cloud backend. xs's iroh P2P mode means two researchers can connect directly, no server required.

---

### 5. Change History Guardian

**What it does**: FamilySearch is a shared, collaborative tree — anyone can modify your ancestors. The Guardian polls change history ETags for your key ancestors (configurable list), detects unauthorized or conflicting edits via xs, and pushes an alert to your browser in real time with a diff showing exactly what changed and who made the change.

**Tech combination**:
- xs service: polls `GET /platform/tree/persons/{pid}/changes` per watched person, compares ETags
- xs actor: when ETag changes, fetches change detail, appends `tree.change.detected` frame
- http-nu + Datastar: `datastar-patch-signals` pushes `{alert_count: N}` to browser badge counter; SSE streams alert cards
- Nushell: `to datastar-patch-elements` renders diff HTML — "Birth year changed from 1842 to 1844 by contributor X"

**Why it's innovative**: FamilySearch provides no push notifications for changes to your watchlist. This fills that gap entirely. For researchers with significant contributions to the shared tree, this is critical protective tooling.

---

### 6. Brick Wall Busting Pipeline

**What it does**: For any person with no parents ("brick walls"), the pipeline automatically fans out: queries FamilySearch tree search, fetches record hints, queries the FS Genealogies API for potential matching persons, and runs a local probability model scoring each candidate parent group. Results are ranked and streamed to a Datastar "candidate families" board, with one-click navigation to FS source linker for each.

**Tech combination**:
- genq: identifies brick wall persons (`WHERE FatherID IS NULL AND MotherID IS NULL`)
- xs service: processes brick walls in a background queue, appends `brickwall.candidates` frames
- FamilySearch API: `GET /platform/tree/search` (by name + birth facts), `GET /platform/tree/persons/{pid}/matches`
- xs actor: scores candidate families (name similarity × date proximity × location match)
- Datastar: candidate cards stream in ranked order as each result arrives

**Why it's innovative**: Brick wall research is the most time-consuming part of genealogy. This transforms it from manual searching to an automated candidate pipeline where the researcher makes the final call rather than doing the grunt work.

---

### 7. Geographic Migration Visualizer

**What it does**: Pulls all event locations (birth, marriage, death, census) for a family line, resolves them through the FamilySearch Places API (6M+ locations with historical name variants and administrative hierarchies), and renders an animated generational migration map. Clicking any event location streams a panel of all family members present at that place and time.

**Tech combination**:
- genq: queries EventTable with places across multiple generations
- FamilySearch Places API: `GET /platform/places/search` resolves historical place names to modern coordinates + hierarchy
- http-nu: serves a lightweight HTML page with a mapping library (Leaflet.js via CDN)
- Datastar: `$generation_filter` and `$year_range` signals drive SSE queries; morphing updates the map overlay
- xs: caches resolved place data (place name → coordinates) to avoid re-querying the API

**Why it's innovative**: Migration patterns are invisible in tabular genealogy data. Visualizing them across generations reveals family strategies (chain migration, return migration, clustering) that text reports cannot capture.

---

### 8. Living Memory Preservation Engine

**What it does**: xs generates structured interview prompts for living relatives based on gaps in the local tree (e.g., "Your grandmother has no photos and no stories — we have 3 questions for her"). Responses and uploaded photos are automatically organized and uploaded to FamilySearch Memories API with proper personas linking the media to tree persons.

**Tech combination**:
- genq: identifies living persons and persons within 2 generations with no memories attached
- FamilySearch Memories API: `POST /platform/memories/artifacts` (upload photo/story), persona linking
- xs: tracks which prompts have been sent, which answered (`last:1` per person per prompt type)
- http-nu + Datastar: interview prompt UI streamed to browser; media upload handled via multipart POST

**Why it's innovative**: Most genealogical memory is lost because no one asks before it's too late. This systematically identifies the highest-priority living sources and delivers actionable prompts. The FamilySearch upload ensures memories are preserved beyond any single software installation.

---

### 9. Historical Context Enricher

**What it does**: For any person in your tree, generates a rich "world they lived in" context panel. Combines local event data with FamilySearch Places API (what county/state/country this location was in *at that time*), and surfaces historical context — border changes, war years, famine periods, emigration waves — as a narrative alongside the person's timeline.

**Tech combination**:
- genq: fetches person facts + event dates + locations
- FamilySearch Places API: temporal hierarchy queries (what was this place called in 1847? what country/state?)
- xs: caches place context data; `last:1` TTL for per-place-per-year results
- http-nu + Datastar: `@get('/context/:rin')` triggers SSE stream; `datastar-patch-elements` inserts context cards into the person view
- Nushell: `rmdate` parsing + timeline construction

**Why it's innovative**: RootsMagic stores facts but not context. A researcher looking at an 1847 birth in Galway needs to know about the Famine without leaving the tool. This brings that context in automatically.

---

### 10. Evidence Chain Visualizer

**What it does**: For any conclusion in your tree (e.g., "birth year: 1842"), builds an interactive evidence chain: local RootsMagic citation → FamilySearch source description → FS record hint status → original record type → corroborating vs. contradicting evidence. Renders as a hypermedia graph where each node links to the actual source.

**Tech combination**:
- genq: queries CitationTable + CitationLinkTable + SourceTable for a conclusion
- FamilySearch API: `GET /platform/tree/persons/{pid}/sources` fetches attached FS sources; hint status from matches endpoint
- http-nu + Datastar: graph rendered as HTML `<div>` nodes with `id=` attributes; SSE morphs nodes as evidence is fetched asynchronously
- xs: caches evidence chain per conclusion; detects when local citations diverge from FS sources

**Why it's innovative**: Genealogical proof standard requires tracking contradictory as well as supporting evidence. No current tool visualizes the complete evidence chain across both local and cloud sources in a single view.

---

### 11. Research Priority Queue

**What it does**: A continuously updated, scored queue of the most valuable research tasks across your entire tree. Scoring factors: number of pending FS hints, number of unsourced conclusions, recency of FS changes to the person, number of missing key facts (no birth, no parents), and relationship closeness to your direct line. Researchers work the queue top-down; xs tracks completion.

**Tech combination**:
- genq: identifies unsourced conclusions, missing events, persons without parents
- FamilySearch API: pending hint counts per person, change history recency
- xs actor: recomputes scores when new hints arrive or local data changes; appends `queue.updated` frames
- Datastar: live queue sorted by score; `$filter_type` signal (hints / unsourced / missing / direct-line); SSE streams re-ranked items

**Why it's innovative**: Researchers waste time on low-value work while high-value opportunities sit unnoticed. A scored, live queue transforms ad-hoc research into systematic, measurable progress — essential for a commercial product.

---

### 12. Automated Source Attachment Workflow

**What it does**: When a FS record hint exceeds a confidence threshold (configurable, e.g., 90%), xs queues it in a "ready to attach" batch. A Datastar review UI presents each match as a card — local facts vs. record facts side by side — and the researcher approves or rejects with a single keystroke. Approvals trigger `POST /platform/tree/persons/{pid}/source-references` via the FamilySearch API.

**Tech combination**:
- xs: `hint.ready` frames from Use Case 1; `source.attach.queue` topic for approved batches
- FamilySearch API: `GET /platform/tree/persons/{pid}/matches` + `POST` source reference attachment
- http-nu + Datastar: keyboard-driven review UI (j/k to navigate, enter to approve, x to reject)
- xs audit log: every attachment decision stored permanently for compliance with genealogical proof standards

**Why it's innovative**: Attaching sources one at a time on FamilySearch is the slowest part of the workflow. A keyboard-driven batch review UI with pre-fetched comparisons cuts the time per attachment from minutes to seconds.

---

### 13. Multi-Tree Staging Manager

**What it does**: Uses the FamilySearch Genealogies API (private trees, up to 100-person bulk operations) as a staging area. Changes to your local RootsMagic tree are staged in a private FS tree first, reviewed against the shared Family Tree diff, then promoted to the public shared tree only after verification. Rollback is one click — restore the prior Genealogies state.

**Tech combination**:
- FamilySearch Genealogies API: private tree CRUD with bulk 100-person POST
- genq: source of local truth; Nushell pipeline transforms RootsMagic data → GEDCOM X JSON
- xs: tracks staging state per person — `staged`, `verified`, `promoted`, `rolled-back`
- Datastar: staging dashboard with per-person status badges; SSE streams promotion progress

**Why it's innovative**: The shared Family Tree has no undo for bulk changes. A private staging tree with a structured promotion workflow gives researchers confidence to make significant changes without risking corrupting the shared record.

---

### 14. Citation Quality Auditor

**What it does**: Analyzes every source and citation in your local tree against a quality rubric (Evidence Explained citation standards). Scores each source: Does it have an author? Repository? Access date? Is it a primary or secondary source? Does it have a corresponding FamilySearch source description? Surfaces a prioritized list of citation upgrades, with direct links to FS source descriptions for already-attached sources.

**Tech combination**:
- genq: queries SourceTable + CitationTable; parses XML fields for Evidence Explained template data
- FamilySearch API: `GET /platform/tree/persons/{pid}/sources` to correlate local citations to FS descriptions
- xs actor: recomputes quality scores when sources change; appends `audit.source.degraded` frames
- Datastar: quality score bars per source; `$min_score` filter signal; SSE streams audit results

**Why it's innovative**: Citation quality is a known weakness in amateur genealogy. Automated scoring against professional standards, with actionable upgrade paths, is something no current consumer software provides.

---

### 15. Family Portrait Gallery

**What it does**: For every person in your tree who has a FamilySearch match, fetches their portrait and memory photos from the FamilySearch Memories API. Displays as a browseable photo gallery organized by family group and generation, with faces of previously unknown relatives appearing automatically as you navigate deeper into the tree.

**Tech combination**:
- FamilySearch API: `GET /platform/tree/persons/{pid}/portrait` + Memories API for associated photos
- xs: caches memory artifact metadata (`last:N` TTL per person) — avoids re-fetching portraits
- http-nu + Datastar: gallery rendered with CSS Grid; `data-on-intersect` (Intersection Observer) lazy-loads photos as user scrolls
- Datastar signals: `$selected_family` drives SSE query; morphing inserts photo cards by family group ID

**Why it's innovative**: Most genealogy databases are text. Seeing the faces of ancestors — especially ones you've never seen photos of — is a deeply compelling experience. This creates it automatically from the Memories API without manual curation.

---

### 16. Surname Migration Pattern Analyzer

**What it does**: Combines local census event data (genq census commands) with FamilySearch tree search across the 1.8B-person shared tree to build migration patterns for specific surnames. Shows where a surname cluster was in 1800, 1850, 1900, and 1950 — revealing immigration ports, internal migration routes, and geographic clustering across the broader family network beyond your own tree.

**Tech combination**:
- genq `census year` commands: local census event data with location fields
- FamilySearch tree search: `GET /platform/tree/search` with surname + birth year range for each decade
- xs: caches decade-by-decade search results (expensive API calls); `time:86400000` (24-hour TTL)
- Datastar: animated decade slider (`$decade` signal 1800–1950); SSE streams location points per decade

**Why it's innovative**: Individual tree analysis only shows your direct ancestors. Querying the FS shared tree for surname patterns reveals the broader clan — and migration routes your direct ancestors likely also took but for which you lack specific records.

---

### 17. "This Week in Your Family History" Digest

**What it does**: Every week, a xs service queries your local tree for people born, married, or who died in the current calendar week across all years. Enriches each entry with any FS memories attached to that person, constructs a curated digest, and delivers it as a live Datastar page — shareable with family members as a URL. Optionally uploads a weekly story to FamilySearch Memories.

**Tech combination**:
- genq: queries NameTable BirthYear + DeathYear; EventTable for marriage events — filtered to current week's month/day
- FamilySearch Memories API: fetches attached photos/stories for matched persons
- xs service: triggered weekly (`time:604800000` TTL marker); appends `digest.ready` frame
- http-nu + Datastar: digest page served at `/this-week`; shareable link; SSE-updated as person details load
- FamilySearch Memories API: optional auto-upload of digest as a story artifact

**Why it's innovative**: Genealogy is often a solitary pursuit. A curated weekly digest turns it into a family-shared experience, increasing perceived value. The FamilySearch Memories upload ensures the digest is preserved for future generations.

---

### 18. Person Completeness Scorecard

**What it does**: For every person in your tree, computes a "genealogical completeness" score across 12 dimensions: primary name, birth date, birth place, death date, death place, both parents known, spouse known, at least one citation, FamilySearch match found, FS source attached, memory/photo available, change history monitored. Renders a per-generation heatmap showing where the research gaps are concentrated.

**Tech combination**:
- genq: queries all relevant tables in a single pass; Nushell computes per-dimension scores
- FamilySearch API: checks for FS match (`/matches`), attached sources, memories per person
- xs actor: recomputes scores on `hint.accepted` or `source.attached` events; live score updates
- Datastar: heatmap by generation (`$generation` signal); cell click streams person detail; `datastar-patch-signals` updates aggregate stats in real time

**Why it's innovative**: Researchers often don't know what they don't know. A visual heatmap of completeness across generations makes research gaps immediately obvious and prioritizable — and the live update when you attach a source provides instant positive reinforcement.

---

### 19. Collaborative Source Review Room

**What it does**: Multiple family researchers join a shared xs stream to collectively review a contested conclusion — e.g., the birth year of a common ancestor where multiple records conflict. Each researcher sees the same evidence cards in real time, can annotate them, vote on confidence levels, and the consensus resolution is recorded to xs with full attribution. The final decision is then pushed to the local tree and optionally to FamilySearch.

**Tech combination**:
- xs: shared stream (iroh P2P) with `review.session.*` topics; researcher presence via `ephemeral` TTL
- FamilySearch API: fetches all attached sources + hints for the contested person
- http-nu + Datastar: shared session UI where each annotation `datastar-patch-elements` updates all connected browsers simultaneously via the same SSE stream
- xs: final consensus recorded as `review.resolution` frame with all participant IDs and votes

**Why it's innovative**: Genealogical disputes between family branches are common — especially for immigrant ancestors with conflicting records. A structured real-time review room with immutable audit trail provides a professional resolution process that no current consumer tool offers.

---

### 20. Research Gap Intelligence Feed

**What it does**: An always-on intelligence layer that monitors the FamilySearch ecosystem for changes relevant to your tree: new record collections added to FS that match your ancestors' locations and time periods, changes to the shared tree by other contributors, newly available digital archives for your research counties, and batch hint processing for newly indexed records. All delivered as a ranked feed to your Datastar dashboard the moment they become available.

**Tech combination**:
- xs service: polls `GET /platform/collections` for new collection additions; compares against local tree's geographic and temporal profile
- xs actor: cross-references new collections against genq's EventTable locations/dates — only surfaces collections that match your actual research geography
- FamilySearch change history: ETag polling (per Use Case 5) extended to detect when others add sources to your matched persons
- xs `last:50` TTL: rolling feed of the 50 most recent intelligence items
- Datastar: live feed with category badges (new collection / tree change / new hints / new memories); `$filter_category` signal; SSE streams new items to top of feed

**Why it's innovative**: FamilySearch indexes new records constantly — but researchers only discover them by accident. This systematically matches new collections against your research profile and pushes them to you. Combined with the change history monitoring, it creates a comprehensive research intelligence system that works even when you're not actively researching.

---

## Summary Matrix

| # | Use Case | genq | FS API | http-nu | Datastar | xs |
|---|----------|:----:|:------:|:-------:|:--------:|:--:|
| 1 | Live Record Hint Processor | ✓ | hints | ✓ | ✓ | ✓ |
| 2 | Tree Divergence Live Audit | ✓ | persons | ✓ | ✓ | ✓ |
| 3 | Research Session Capture | ✓ | multi | ✓ | ✓ | ✓ |
| 4 | Multi-Researcher Awareness | ✓ | — | ✓ | ✓ | ✓ |
| 5 | Change History Guardian | ✓ | changes | ✓ | ✓ | ✓ |
| 6 | Brick Wall Busting Pipeline | ✓ | search+hints | ✓ | ✓ | ✓ |
| 7 | Geographic Migration Visualizer | ✓ | places | ✓ | ✓ | ✓ |
| 8 | Living Memory Preservation | ✓ | memories | ✓ | ✓ | ✓ |
| 9 | Historical Context Enricher | ✓ | places | ✓ | ✓ | ✓ |
| 10 | Evidence Chain Visualizer | ✓ | sources+hints | ✓ | ✓ | ✓ |
| 11 | Research Priority Queue | ✓ | hints+changes | ✓ | ✓ | ✓ |
| 12 | Automated Source Attachment | ✓ | sources | ✓ | ✓ | ✓ |
| 13 | Multi-Tree Staging Manager | ✓ | genealogies | ✓ | ✓ | ✓ |
| 14 | Citation Quality Auditor | ✓ | sources | ✓ | ✓ | ✓ |
| 15 | Family Portrait Gallery | ✓ | memories | ✓ | ✓ | ✓ |
| 16 | Surname Migration Analyzer | ✓ | tree search | ✓ | ✓ | ✓ |
| 17 | This Week in Family History | ✓ | memories | ✓ | ✓ | ✓ |
| 18 | Person Completeness Scorecard | ✓ | multi | ✓ | ✓ | ✓ |
| 19 | Collaborative Source Review | ✓ | sources+hints | ✓ | ✓ | ✓ |
| 20 | Research Gap Intelligence Feed | ✓ | collections+changes | ✓ | ✓ | ✓ |

---

## Commercial Tier Considerations

**Highest immediate value** (likely to drive initial sales):
- **#1 Live Record Hint Processor** — solves the most common daily frustration
- **#5 Change History Guardian** — protective; anxiety-reducing
- **#11 Research Priority Queue** — productivity multiplier
- **#18 Completeness Scorecard** — visual progress, shareable

**Highest differentiation** (no competitor does this):
- **#4 Multi-Researcher Awareness** (xs iroh P2P — no server required)
- **#3 Research Session Capture & Replay** (audit trail for proof standards)
- **#13 Multi-Tree Staging Manager** (safe publish workflow)
- **#19 Collaborative Source Review** (structured dispute resolution)

**FamilySearch API certification required before shipping**:
- Uses #1, 2, 5, 6, 8, 10, 12, 13, 14, 15, 16: Tree Write Compatible + Sources Write Compatible
- Use #8 (Memories upload): Memories Write Compatible
- All uses: Read Compatible + Authentication Compatible (baseline)

---

## FamilySearch API Notes for Development

- **No DNA endpoints exist** — FS does not offer DNA testing; integrate Ancestry or 23andMe APIs separately for DNA use cases
- **Record display restriction**: Full historical record content cannot be displayed in third-party apps (legal/licensing). Use cases involving records must redirect to FS via Tree-Page-Links service
- **Rate limits**: Per-user (not per-app-key); ~18s processing time per 1-minute window. xs caching is essential to avoid throttling
- **Batch writes**: Family Tree is one-person-at-a-time. Genealogies API allows up to 100 persons/POST — use for staging (#13)
- **Living persons**: FS suppresses data for living individuals — all 20 use cases above apply only to deceased persons
- **Start in Integration sandbox**, promote to Production after Compatible Solution Program review

---

## References

- FamilySearch Developer Portal: https://developers.familysearch.org/
- FamilySearch API Reference: https://developers.familysearch.org/main/reference/api-reference-guide
- Compatible Solution Program: https://www.familysearch.org/innovate/api-compatibility-benefits
- Tech stack analysis: `docs/tech-analysis-datastar-http-nu-xs.md`
