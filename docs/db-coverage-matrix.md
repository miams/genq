# GenQuery — RM10 Database Coverage Matrix & Roadmap

**Date:** 2026-04-14
**Reference:** `RM10DataDef-V10_0_5-20250205.xlsx` (347 rows, 31 tables)
**Goal:** Every user-visible RM10 database field reachable via at least one `genq` command.

---

## Coverage Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Field is exposed in command output |
| 🟡 | Table is queried but this field is not exposed |
| ❌ | No genq command touches this table |
| ⚫ | Not Implemented in RM10 / internal RM admin table |

---

## Matrix

### PersonTable

Primary record for every individual. RIN = PersonID.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| PersonID (RIN) | PK | `genq list people` | ✅ | Shown as RIN |
| UniqueID | Text | — | ❌ | GUID; useful for dedup / FamilySearch linkage |
| Sex | Integer | `genq list people` | ✅ | |
| ParentID | FK→FamilyTable | — | 🟡 | Last-viewed family; not reliable for queries |
| SpouseID | FK→FamilyTable | — | 🟡 | Last-viewed spouse; not reliable for queries |
| Color … Color9 | Integer (0–27) | — | ❌ | 10 color-coding sets; useful for filtered views |
| Relate1 / Relate2 | Integer | — | ❌ | Relationship distance to focus person |
| Flags | Integer | — | ❌ | Half/spouse-of relationship qualifiers |
| Living | Integer | — | ❌ | 0=Deceased, 1=Living; important for privacy |
| IsPrivate | ⚫ | — | ⚫ | Not implemented in RM10 |
| Proof | ⚫ | — | ⚫ | Not implemented in RM10 |
| Bookmark | Integer | — | ❌ | RM bookmark flag |
| Note | Text | — | ❌ | Person-level note (not fact note) |
| UTCModDate | Float | `genq list people --mod-date` | 🟡 | Opt-in via `--mod-date`; shows as `LastUpdate` (local time) |

**Gap summary:** Living status, color-coding, person notes, and UniqueID are all unreachable.

---

### NameTable

One row per name fact per person. Primary + alternate names.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| NameID | PK | — | 🟡 | |
| OwnerID | FK→PersonTable | `genq list people` | ✅ | |
| Surname | Text | `genq list people` | ✅ | Primary name only |
| Given | Text | `genq list people` | ✅ | Primary name only |
| Prefix | Text | — | ❌ | Dr., Rev., Lord, etc. |
| Suffix | Text | — | ❌ | Jr., Sr., III, etc. |
| Nickname | Text | — | ❌ | |
| NameType | Integer | — | ❌ | AKA/Birth/Immigrant/Maiden/Married/Nickname/Other |
| Date | Text | — | ❌ | Date of alternate name fact |
| IsPrimary | Integer | `genq list people` | ✅ | Used to filter primary name |
| IsPrivate | Integer | — | 🟡 | |
| Proof | Integer | — | 🟡 | |
| Note | Text | — | ❌ | Name fact note |
| BirthYear | Integer | `genq list people` | ✅ | Denormalized from EventTable |
| DeathYear | Integer | `genq list people` | ✅ | Denormalized from EventTable |
| SurnameMP / GivenMP / NicknameMP | Text | — | 🟡 | Metaphone variants; search-only |
| UTCModDate | Float | `genq list names --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Alternate names fully covered by `genq list names`. Prefix/suffix/nickname columns not yet exposed.

---

### FamilyTable

One row per couple (husband + wife). Marriage and family facts live in EventTable with OwnerType=1.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| FamilyID (MRIN) | PK | `genq list families` | ✅ | |
| FatherID | FK→PersonTable | `genq list families` | ✅ | |
| MotherID | FK→PersonTable | `genq list families` | ✅ | |
| ChildID | FK→PersonTable | — | 🟡 | Last-active child in pedigree; unreliable |
| HusbOrder | Integer | `genq list families` | ✅ | Spouse ordering |
| WifeOrder | Integer | `genq list families` | ✅ | |
| IsPrivate | ⚫ | — | ⚫ | Not implemented |
| Proof | Integer | — | 🟡 | Blank/Proven/Disproven/Disputed |
| FatherLabel / MotherLabel | Integer | — | 🟡 | Father/Husband/Partner/Other |
| FatherLabelStr / MotherLabelStr | Text | — | 🟡 | Custom label when =Other |
| Note | Text | — | ❌ | Spouse-fact note |
| UTCModDate | Float | `genq list families` | ✅ | Always shown as `LastUpdate` (local time) |

**Gap summary:** Family proof status, spouse-role labels, and family notes are not exposed.

---

### ChildTable

Links children to families. One row per child-per-family.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| RecID | PK | — | — | |
| ChildID | FK→PersonTable | `genq list children` | ✅ | With name lookup |
| FamilyID | FK→FamilyTable | `genq list children` | ✅ | Shown as MRIN |
| RelFather | Integer | `genq list children` | ✅ | Decoded to Birth/Adopted/Step/Foster/Guardian/Sealed/Unknown |
| RelMother | Integer | `genq list children` | ✅ | Same |
| ChildOrder | Integer | `genq list children` | ✅ | |
| ProofFather / ProofMother | Integer | — | ❌ | Proven/Disproven/Disputed |
| Note | ⚫ | — | ⚫ | Not implemented |
| UTCModDate | Float | `genq list children --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Child relationship types fully covered by `genq list children`.

---

### EventTable

All facts/events for persons (OwnerType=0) and families (OwnerType=1).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| EventID | PK | `genq list events` | ✅ | |
| EventType | FK→FactTypeTable | `genq list events` | ✅ | Resolved to name |
| OwnerType | Integer | `genq list events` | 🟡 | Not shown (always 0 for person, 1 for family) |
| OwnerID | FK | `genq list events` | ✅ | Shown as RIN (or MRIN for family events) |
| FamilyID | FK→FamilyTable | — | 🟡 | For adoption/LDS seal events |
| PlaceID | FK→PlaceTable | `genq list events` | 🟡 | PlaceID visible but place name not always joined |
| SiteID | FK→PlaceTable | — | ❌ | Place details (sub-place) |
| Date | Text | `genq list events` | ✅ | Raw RM-encoded date |
| SortDate | BigInt | — | 🟡 | |
| IsPrimary | Integer | — | 🟡 | |
| IsPrivate | Integer | — | 🟡 | |
| Proof | Integer | — | 🟡 | Blank/Proven/Proven False/Disputed |
| Status | Integer | — | 🟡 | LDS ordinance status |
| Sentence | Text | — | ❌ | Custom sentence override |
| Details | Text | `genq list events` | ✅ | Description field |
| Note | Text | `genq list events` | 🟡 | Shown in raw output but not formatted |
| UTCModDate | Float | `genq list events` | ✅ | Always shown as `LastUpdate` (local time) |

**Gap summary:** Place details (SiteID), proof status, and privacy flag not exposed. Place name resolution available via `genq list events --place-name`.

---

### PlaceTable

Canonical place names. PlaceType: 0=Place, 1=LDS Temple, 2=Place Details.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| PlaceID | PK | `genq list events` | 🟡 | Referenced but no dedicated place command |
| PlaceType | Integer | — | ❌ | |
| Name | Text | `genq list events` | 🟡 | Joined in some contexts |
| Abbrev | Text | — | ❌ | |
| Normalized | Text | — | ❌ | Standardized/geocoded name |
| Latitude / Longitude | Integer | — | ❌ | ×1e7 encoding; geo-mapping potential |
| MasterID | FK→PlaceTable | — | ❌ | Parent place for place-details |
| Note | Text | — | ❌ | |
| UTCModDate | Float | `genq list places --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** `genq list places` covers Name, Normalized, PlaceType, and optionally coordinates. Abbrev and Note fields still missing.

---

### FactTypeTable

Lookup table for event/fact type names and configuration.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| FactTypeID | PK | `genq list events` | 🟡 | Used as FK, name resolved |
| OwnerType | Integer | — | 🟡 | Person vs. Family fact type |
| Name | Text | `genq list events` | ✅ | Fact type name shown |
| Abbrev | Text | — | ❌ | |
| GedcomTag | Text | — | ❌ | |
| UseValue / UseDate / UsePlace | Integer | — | ❌ | Field enablement flags |
| Sentence | Text | — | ❌ | Default sentence template |
| Flags | Integer | — | ❌ | Include settings |
| UTCModDate | Float | — | 🟡 | |

**Gap summary:** No `genq list fact-types` command yet. Useful for understanding what fact types are in use.

---

### WitnessTable

Shared events / witnesses. One row per person sharing a fact.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| WitnessID | PK | `genq list witnesses` | 🟡 | |
| EventID | FK→EventTable | `genq list witnesses` | ✅ | All event types |
| PersonID | FK→PersonTable | `genq list witnesses` | ✅ | |
| Role | FK→RoleTable | `genq list witnesses` | ✅ | RoleName resolved |
| Given / Surname | Text | `genq list witnesses` | ✅ | Both event owner and witness names shown |
| Note | Text | — | ❌ | Witness-specific note |
| Sentence | Text | — | ❌ | Custom sentence for this shared fact |
| UTCModDate | Float | `genq list witnesses --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** `genq list witnesses` covers all event types with roles. Witness notes and Sentence fields not yet exposed.

---

### RoleTable

Pre-defined and user-defined roles for shared events.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| RoleID | PK | `genq census` | 🟡 | |
| RoleName | Text | `genq census` | 🟡 | Not consistently surfaced |
| EventType | FK→FactTypeTable | — | ❌ | |
| Sentence | Text | — | ❌ | |
| UTCModDate | Float | — | 🟡 | |

**Gap summary:** Reference table; needs `genq list roles` for discoverability.

---

### CitationTable

One row per citation. Links sources to specific claims.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| CitationID | PK | `genq list citations` | ✅ | |
| SourceID | FK→SourceTable | `genq list citations` | ✅ | |
| Comments | Text | — | 🟡 | Detail Comment; not shown |
| ActualText | Text | — | 🟡 | Research Note; not shown |
| RefNumber | Text | — | 🟡 | Ref# field; not shown |
| Footnote | Text | `genq list citations` | ✅ | |
| ShortFootnote | Text | `genq list citations` | ✅ | |
| Bibliography | Text | `genq list citations` | ✅ | |
| Fields | Blob/XML | — | 🟡 | Template field values; not parsed |
| CitationName | Text | — | 🟡 | Auto-generated citation name |
| UTCModDate | Float | `genq list citations --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** `genq list citations` exposes the main citation fields. Template field values (XML blob) not parsed.

---

### CitationLinkTable

Maps citations to their owners (who cites what).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| CitationID | FK→CitationTable | — | ❌ | |
| OwnerType | Integer | — | ❌ | Person/Family/Event/Task/Name/Association |
| OwnerID | FK | — | ❌ | |
| Quality | Text | — | ❌ | 3-char: Primary/Secondary, Direct/Indirect, Original/Derivative |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** Entire table unreachable. Cannot answer "what events have citations?" or "what is the citation quality?". High research value.

---

### SourceTable

Master source records (free-form and template-based).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| SourceID | PK | `genq list sources` | ✅ | Free-form only |
| Name | Text | `genq list sources` | ✅ | |
| RefNumber | Text | — | 🟡 | |
| ActualText | Text | — | 🟡 | Source text/transcript |
| Comments | Text | — | 🟡 | Source comment |
| IsPrivate | ⚫ | — | ⚫ | Not implemented |
| TemplateID | FK→SourceTemplateTable | `genq list sources` | 🟡 | Shown; filter works but --all is stub |
| Fields | Blob/XML | `genq list citations` | 🟡 | Footnote/ShortFootnote/Bibliography extracted; other fields not |
| UTCModDate | Float | — | 🟡 | |

**Gap summary:** Template-based sources (`TemplateID > 0`) are unreachable — `genq list sources --all` is a stub. These represent the majority of sources in well-maintained databases.

---

### SourceTemplateTable

Defines the 439 built-in + user-defined citation templates.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| TemplateID | PK | — | ❌ | |
| Name | Text | — | ❌ | Template name (e.g., "Census, Federal — 1880") |
| Description | Text | — | ❌ | |
| Favorite | Integer | — | ❌ | Starred templates |
| Category | Text | — | ❌ | Template category |
| Footnote / ShortFootnote / Bibliography | Text | — | ❌ | Template format strings |
| FieldDefs | Blob/XML | — | ❌ | Field names, types, hints |
| UTCModDate | Float | — | 🟡 | |

**Gap summary:** No `genq list source-templates`. Needed for implementing `genq list sources --all`.

---

### MultimediaTable

Media items attached to the database.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| MediaID | PK | `genq list media` | ✅ | |
| MediaType | Integer | `genq list media` | ✅ | Image/File/Sound/Video |
| MediaPath | Text | `genq list media` | ✅ | Relative path |
| MediaFile | Text | `genq list media` | ✅ | Filename |
| URL | ⚫ | — | ⚫ | Not implemented in RM10 |
| Thumbnail | Blob | — | 🟡 | Binary; not useful in tabular output |
| Caption | Text | `genq list media` | ✅ | |
| RefNumber | Text | — | 🟡 | |
| Date | Text | — | 🟡 | Media date |
| Description | Text | `genq list media` | ✅ | |
| UTCModDate | Float | `genq list media --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Coverage is reasonable. RefNumber and Date missing. Known bug: fullpath wrapped in literal quotes.

---

### MediaLinkTable

Maps media items to owners (person/family/event/source/citation/place/name/association).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| MediaID | FK→MultimediaTable | — | ❌ | |
| OwnerType | Integer | — | ❌ | 9 owner types |
| OwnerID | FK | — | ❌ | |
| IsPrimary | Integer | — | ❌ | Primary photo flag |
| SortOrder | Integer | — | ❌ | |
| Comments | Text | — | ❌ | Tag comment |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** Cannot answer "what photos does person X have?" or "which media is tagged as primary?". High UX value.

---

### URLTable

Web tags attached to sources, citations, places, tasks, and place details.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | `genq list findagrave` | 🟡 | |
| OwnerType | Integer | `genq list findagrave` | 🟡 | Schema: 3=Source, 4=Citation, 5=Place, 6=Task, 14=PlaceDetail (NOT Person) |
| OwnerID | FK | `genq list findagrave` | 🟡 | Filtered by URL pattern only |
| LinkType | ⚫ | — | ⚫ | Not implemented |
| Name | Text | `genq list findagrave` | 🟡 | Web tag label |
| URL | Text | `genq list findagrave` | ✅ | |
| Note | Text | — | 🟡 | |
| UTCModDate | Float | — | 🟡 | |

**Gap summary:** `genq list findagrave` appears to have a schema discrepancy (code uses OwnerType=0 for person but schema says OwnerType doesn't include 0 for URLTable). Full web-tag browsing across all owner types is missing.

---

### FANTable (Friends, Associates, Neighbors)

Association facts between two persons.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| FanID | PK | `genq list associations` | 🟡 | |
| ID1 / ID2 | FK→PersonTable | `genq list associations` | ✅ | Both RINs with name lookup |
| FanTypeID | FK→FANTypeTable | `genq list associations` | ✅ | Resolved to AssocType, Role1, Role2 |
| PlaceID / SiteID | FK→PlaceTable | — | ❌ | |
| Date | Text | `genq list associations` | ✅ | |
| Description | Text | `genq list associations` | ✅ | |
| Note | Text | — | ❌ | |
| UTCModDate | Float | `genq list associations --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Core association data fully covered. Place and Note fields not yet exposed.

---

### FANTypeTable

Lookup for 15 built-in association types (Friends, Neighbors, Employment, Godparent, DNA Match, etc.).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| FANTypeID | PK | `genq list associations` | 🟡 | Used as FK |
| Name | Text | `genq list associations` | ✅ | Shown as AssocType |
| Role1 / Role2 | Text | `genq list associations` | ✅ | Shown per association |
| Sentence1 / Sentence2 | Text | — | ❌ | |
| UTCModDate | Float | — | 🟡 | |

---

### DNATable

DNA match records between persons in the database.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| RecID | PK | — | ❌ | |
| ID1 / ID2 | FK→PersonTable | — | ❌ | The matched individuals |
| Label1 / Label2 | Text | — | ❌ | Custom labels |
| DNAProvider | Integer | — | ❌ | 23andMe/Ancestry/FTDNA/LivingDNA/MyHeritage/GEDmatch |
| SharedCM / SharedPercent | Float | — | ❌ | cM and % shared |
| LargeSeg | Float | — | ❌ | Largest segment (cM) |
| SharedSegs | Integer | — | ❌ | Number of shared segments |
| Date | Text | — | ❌ | Test date |
| Relate1 / Relate2 | Integer | — | ❌ | Generations to MRCA |
| CommonAnc | FK | — | ❌ | Most Recent Common Ancestor |
| CommonAncType | Integer | — | ❌ | Single/couple MRCA |
| Note | Text | — | ❌ | |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** Entire table unreachable. DNA data is a growing priority for genealogical research.

---

### HealthTable

Medical/health conditions associated with persons.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| RecID | PK | — | ❌ | |
| OwnerID | FK→PersonTable | — | ❌ | |
| Condition | Integer | — | ❌ | 20 categories + Other |
| SubCondition | Text | — | ❌ | User-defined details |
| Date | Text | — | ❌ | |
| Note | Text | — | ❌ | |
| UTCModDate | Float | — | ❌ | |

---

### TaskTable

Research tasks / to-do items.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| TaskID | PK | — | ❌ | |
| TaskType | Integer | — | ❌ | Research/ToDo/Correspondence |
| RefNumber | Text | — | ❌ | |
| Name | Text | — | ❌ | |
| Status | Integer | — | ❌ | New/In Progress/Completed/On Hold/Problem/Cancelled |
| Priority | Integer | — | ❌ | 8-level priority |
| Date1 / Date2 / Date3 | Text | — | ❌ | Start/LastEdit/End dates |
| Filename | Text | — | ❌ | Attached file |
| Details | Text | — | ❌ | |
| Results | Text | — | ❌ | |
| Exclude | Integer | — | ❌ | Filter flag |
| UTCModDate | Float | — | ❌ | |

---

### TaskLinkTable

Maps tasks to persons, families, events, places, names, associations.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| TaskID | FK→TaskTable | — | ❌ | |
| OwnerType | Integer | — | ❌ | Person/Family/Event/Place/Name/PlaceDetail/Folder/Association |
| OwnerID | FK | — | ❌ | |
| UTCModDate | Float | — | ❌ | |

---

### AddressTable

Physical/contact addresses for persons, families, and repositories.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| AddressID | PK | — | ❌ | |
| AddressType | Integer | — | ❌ | 0=Person/Family, 1=Repository |
| Name / Street1 / Street2 / City / State / Zip / Country | Text | — | ❌ | |
| Phone1 / Phone2 / Fax / Email / URL | Text | — | ❌ | |
| Note | Text | — | ❌ | |
| UTCModDate | Float | — | 🟡 | |

---

### AddressLinkTable

Maps addresses to owners.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| OwnerType | Integer | — | ❌ | 0=Person, 1=Family, 3=Source (Repository), 6=Task |
| AddressID / OwnerID | FK | — | ❌ | |
| UTCModDate | Float | — | 🟡 | |

---

### FamilySearchTable

FamilySearch Family Tree linkage.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| rmID | FK→PersonTable | — | ❌ | |
| fsID | Text | — | ❌ | FamilySearch person ID |
| Modified | Integer | — | ❌ | Mismatch flag |
| fsVersion | Text | — | ❌ | |
| Status | Integer | — | ❌ | 0=Default, 4=Imported from FS |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** FS linkage IDs are unreachable. Critical for Discoverer edition.

---

### AncestryTable

Ancestry.com TreeShare linkage.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | ❌ | |
| LinkType | Integer | — | ❌ | 0=Person, 4=Citation, 11=Media |
| rmID | FK | — | ❌ | |
| anID | Text | — | ❌ | Ancestry person/citation/media ID |
| Modified | Integer | — | ❌ | Change flag |
| anVersion / anDate | Text/Float | — | ❌ | |
| Status | Integer | — | ❌ | |
| UTCModDate | Float | — | 🟡 | |

---

### Internal / Admin Tables (low priority)

These tables are internal to RM or support features with minimal genealogical reporting value:

| Table | Purpose | genq Priority |
|-------|---------|--------------|
| ConfigTable | RM app config (reports, problem settings) | ⚫ Skip |
| ExclusionTable | Merge / problem exclusion lists | ⚫ Skip |
| GroupTable | Person search groups | Low |
| PayloadTable | Saved searches / saved groups | Low |
| TagTable | Group names and task folders | Low |

---

## Coverage Summary

| Table | Coverage | Phase |
|-------|----------|-------|
| PersonTable | 🟡 Partial (6/15 fields) | Phase 2 |
| NameTable | 🟡 Good — all names accessible (8/16 fields) | ✅ Phase 1 done |
| FamilyTable | 🟡 Partial (5/14 fields) | Phase 2 |
| ChildTable | 🟡 Good — relationship types covered (5/8 user fields) | ✅ Phase 1 done |
| EventTable | 🟡 Partial (7/15 fields) | Phase 2 |
| PlaceTable | 🟡 Good — gazetteer with coords (4/9 fields) | ✅ Phase 1 done |
| FactTypeTable | 🟡 Partial — name only (1/9 fields) | Phase 3 |
| WitnessTable | 🟡 Good — all event types (5/7 fields) | ✅ Phase 1 done |
| RoleTable | 🟡 Partial — via witnesses (1/5 fields) | Phase 3 |
| CitationTable | 🟡 Partial (5/10 fields) | Phase 2 |
| CitationLinkTable | ❌ None | Phase 2 |
| SourceTable | 🟡 Good — free-form + template (4/8 fields) | ✅ Phase 1 done |
| SourceTemplateTable | 🟡 Partial — name via join (1/7 fields) | Phase 2 |
| MultimediaTable | ✅ Good (7/9 user fields) | Phase 3 (bug fix) |
| MediaLinkTable | ❌ None | Phase 2 |
| URLTable | 🟡 Partial — schema mismatch (1/6 fields) | Phase 2 |
| FANTable | 🟡 Good — core data accessible (6/8 fields) | ✅ Phase 1 done |
| FANTypeTable | 🟡 Partial — via associations (2/5 fields) | Phase 3 |
| DNATable | ❌ None | Phase 2 |
| HealthTable | ❌ None | Phase 3 |
| TaskTable | ❌ None | Phase 3 |
| TaskLinkTable | ❌ None | Phase 3 |
| AddressTable | ❌ None | Phase 3 |
| AddressLinkTable | ❌ None | Phase 3 |
| FamilySearchTable | ❌ None | Phase 2 |
| AncestryTable | ❌ None | Phase 2 |
| ConfigTable | ⚫ Skip | — |
| ExclusionTable | ⚫ Skip | — |
| GroupTable | ❌ None | Phase 4 |
| PayloadTable | ❌ None | Phase 4 |
| TagTable | ❌ None | Phase 4 |

**Current coverage: ~15 of 31 tables have meaningful exposure (up from ~4 in March 2026). UTCModDate accessible via `--mod-date` on all major commands.**

---

## Roadmap

### Phase 0 — UTCModDate Completeness ✅ Done (2026-04-14)

Added `--mod-date` flag to all commands that were missing it. `genq list sources` normalized to local time.

| Command | Flag | Column |
|---------|------|--------|
| `genq list people` | `--mod-date` | `LastUpdate` (PersonTable) |
| `genq list names` | `--mod-date` | `LastUpdate` (NameTable) |
| `genq list places` | `--mod-date` | `LastUpdate` (PlaceTable) |
| `genq list children` | `--mod-date` | `LastUpdate` (ChildTable) |
| `genq list associations` | `--mod-date` | `LastUpdate` (FANTable) |
| `genq list witnesses` | `--mod-date` | `LastUpdate` (WitnessTable) |
| `genq list media` | `--mod-date` | `LastUpdate` (MultimediaTable) |
| `genq list citations` | `--mod-date` | `LastUpdate` (CitationTable) |
| `genq list sources` | always | `LastUpdate` (normalized from `SourceDate`) |
| `genq list events` | always | `LastUpdate` (unchanged) |
| `genq list families` | always | `LastUpdate` (unchanged) |

### Phase 1 — Core Genealogical Data ✅ Mostly Done

| # | Command | Status |
|---|---------|--------|
| 1.1 | `genq list people --all-names` | ✅ Done |
| 1.2 | `genq list names` | ✅ Done |
| 1.3 | `genq list places` | ✅ Done |
| 1.4 | `genq list events --place-name` | ✅ Done |
| 1.5 | `genq list children` | ✅ Done |
| 1.6 | `genq list associations` | ✅ Done |
| 1.7 | `genq list witnesses` | ✅ Done |
| 1.8 | `genq list sources --all` | ✅ Done |
| 1.9 | `genq list citations --owner` | ❌ Remaining — CitationLinkTable owner filter |

### Phase 2 — Enhanced Existing Commands + New Data Domains

Enrich existing outputs; add DNA, media, and external linkage.

| # | Command | Fills Gap | Tables |
|---|---------|-----------|--------|
| 2.1 | `genq list people` add `--living`, `--color`, `--note` | Person notes, living status | PersonTable |
| 2.2 | `genq list events` add Proof, IsPrivate | Event proof/privacy status | EventTable |
| 2.3 | `genq list families` add Proof, Labels, Note | Family proof/spouse labels | FamilyTable |
| 2.4 | `genq list citations` add Comments, ActualText | Research notes in citations | CitationTable |
| 2.5 | `genq list media --for <RIN>` | Media for a person via link table | MediaLinkTable + MultimediaTable |
| 2.6 | `genq list media` (fix fullpath bug) | Bug: literal quotes in fullpath | MultimediaTable |
| 2.7 | `genq list dna` | DNA matches with cM, %, provider | DNATable |
| 2.8 | `genq list web-tags` | All web tags (all owner types) | URLTable |
| 2.9 | `genq list familysearch-links` | RM↔FS person ID mapping | FamilySearchTable |
| 2.10 | `genq list ancestry-links` | RM↔Ancestry ID mapping | AncestryTable |

### Phase 3 — Supporting Tables & Quality / Admin

Reference data, health, tasks, and cleanup.

| # | Command | Fills Gap | Tables |
|---|---------|-----------|--------|
| 3.1 | `genq list health` | Health conditions per person | HealthTable |
| 3.2 | `genq list tasks` | Research tasks with status/priority | TaskTable + TaskLinkTable |
| 3.3 | `genq list repositories` | Source repository addresses | AddressTable + AddressLinkTable |
| 3.4 | `genq list fact-types` | All fact type definitions | FactTypeTable |
| 3.5 | `genq list source-templates` | Template catalog | SourceTemplateTable |
| 3.6 | `genq list roles` | Role definitions for shared events | RoleTable |
| 3.7 | `genq list media` fix RefNumber, Date | Minor field gaps | MultimediaTable |

### Phase 4 — Admin / Power User

Group management, saved searches, bookmarks.

| # | Command | Fills Gap | Tables |
|---|---------|-----------|--------|
| 4.1 | `genq list groups` | Named person groups | GroupTable + TagTable |
| 4.2 | `genq list bookmarks` | Bookmarked persons | PersonTable.Bookmark |
| 4.3 | `genq list color <n>` | Persons by color code set | PersonTable.Color* |

---

## Priority Justification

**Phase 1** items are needed for basic genealogical research workflows:
- Alternate names (maiden names) are required to search across marriage name changes
- Places with coordinates enable mapping — a core genealogy visualization
- Child relationship types (birth vs. adopted) are fundamental to lineage research
- FAN club associations support the FAN club research methodology
- The `genq list sources --all` stub blocks access to the majority of sources

**Phase 2** items expand depth of existing data:
- DNA data is increasingly central to modern genealogical proof
- Media-per-person linkage enables photo-aware reporting
- FamilySearch/Ancestry IDs are the foundation of the Discoverer edition

**Phase 3 & 4** support research management workflows (tasks, health patterns, group queries) with lower urgency but real value for active researchers.

---

## Known Bugs to Fix Alongside Roadmap

| Bug | Location | Impact |
|-----|---------|--------|
| `fullpath` literal quotes | `genq list media/mod.nu` | Broken paths on macOS |
| `genq list findagrave` OwnerType=0 | `genq list findagrave/mod.nu` | URLTable schema has no OwnerType=0 — investigate |
| `genq list sources --all` stub | `genq list sources/mod.nu` | Silent no-op misleads users |
| `genq list events --citations` dead flag | `genq list events/mod.nu` | Flag declared but never implemented |
| `genq list people` writes tmpNames tables | `genq list people/mod.nu` | Mutates user DB; should use CTE or subquery |
