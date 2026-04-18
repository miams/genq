# GenQuery — RM10 Database Coverage Matrix & Roadmap

**Date:** 2026-04-17
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
| Living | Integer | `genq list people --living` | ✅ | Decoded to Y/N; opt-in via `--living` |
| IsPrivate | ⚫ | — | ⚫ | Not implemented in RM10 |
| Proof | ⚫ | — | ⚫ | Not implemented in RM10 |
| Bookmark | Integer | — | ❌ | RM bookmark flag |
| Note | Text | `genq list people --note` | ✅ | Opt-in via `--note`; person-level note |
| UTCModDate | Float | `genq list people --mod-date` | ✅ | Opt-in via `--mod-date`; shows as `LastUpdate` (local time) |

**Gap summary:** Living status exposed via `--living`; Note exposed via `--note`. Color-coding and UniqueID remain unreachable.

---

### NameTable

One row per name fact per person. Primary + alternate names.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| NameID | PK | — | 🟡 | |
| OwnerID | FK→PersonTable | `genq list people` | ✅ | |
| Surname | Text | `genq list people` | ✅ | Primary name only |
| Given | Text | `genq list people` | ✅ | Primary name only |
| Prefix | Text | `genq list names --prefix` | ✅ | Opt-in via `--prefix`; Dr., Rev., Lord, etc. |
| Suffix | Text | `genq list names --suffix` | ✅ | Opt-in via `--suffix`; Jr., Sr., III, etc. |
| Nickname | Text | `genq list names --nickname` | ✅ | Opt-in via `--nickname` |
| NameType | Integer | `genq list names` | ✅ | Always shown; AKA/Birth/Immigrant/Maiden/Married/Nickname/Other |
| Date | Text | `genq list names --date` | ✅ | Opt-in via `--date`; date of alternate name fact |
| IsPrimary | Integer | `genq list people`, `genq list names` | ✅ | Used as `WHERE` filter for primary name; always shown as column in `genq list names` |
| IsPrivate | Integer | `genq list names --private` | ✅ | Opt-in via `--private`; decoded to Y/N |
| Proof | Integer | — | 🟡 | |
| Note | Text | `genq list names --note` | ✅ | Opt-in via `--note`; name fact note |
| BirthYear | Integer | `genq list people` | ✅ | Denormalized from EventTable |
| DeathYear | Integer | `genq list people` | ✅ | Denormalized from EventTable |
| SurnameMP / GivenMP / NicknameMP | Text | — | 🟡 | Metaphone variants; search-only |
| UTCModDate | Float | `genq list names --mod-date` | ✅ | Opt-in via `--mod-date` |

**Gap summary:** Alternate names fully covered by `genq list names`. Prefix, Suffix, Nickname, Date, IsPrivate, and Note all exposed via opt-in flags. Proof not yet exposed.

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
| Proof | Integer | `genq list families --proof` | ✅ | Decoded: Proven/Disproven/Disputed/blank; opt-in via `--proof` |
| FatherLabel / MotherLabel | Integer | `genq list families --labels` | ✅ | Decoded to Father/Husband/Partner/Other; FatherRole and MotherRole columns |
| FatherLabelStr / MotherLabelStr | Text | `genq list families --labels` | ✅ | Used when label=Other; merged into FatherRole/MotherRole |
| Note | Text | `genq list families --note` | ✅ | Family-level note; opt-in via `--note` |
| UTCModDate | Float | `genq list families` | ✅ | Always shown as `LastUpdate` (local time) |

**Gap summary:** Proof, spouse-role labels (FatherRole/MotherRole), and Note now all exposed via opt-in flags.

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
| ProofFather / ProofMother | Integer | `genq list children --proof` | ✅ | Opt-in via `--proof`; decoded Proven/Disproven/Disputed/blank |
| Note | ⚫ | — | ⚫ | Not implemented |
| UTCModDate | Float | `genq list children --mod-date` | ✅ | Opt-in via `--mod-date` |

**Gap summary:** Child relationship types and proof fully covered by `genq list children`.

---

### EventTable

All facts/events for persons (OwnerType=0) and families (OwnerType=1).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| EventID | PK | `genq list events`; `genq list citations --event-id` | ✅ | Also exposed in citations output via `--event-id` for cross-command filtering |
| EventType | FK→FactTypeTable | `genq list events` | ✅ | Resolved to name |
| OwnerType | Integer | `genq list events` | 🟡 | Not shown (always 0 for person, 1 for family) |
| OwnerID | FK | `genq list events` | ✅ | Shown as RIN (or MRIN for family events) |
| FamilyID | FK→FamilyTable | — | 🟡 | For adoption/LDS seal events |
| PlaceID | FK→PlaceTable | `genq list events` | 🟡 | PlaceID visible but place name not always joined |
| SiteID | FK→PlaceTable | — | ❌ | Place details (sub-place) |
| Date | Text | `genq list events` | ✅ | Raw RM-encoded date |
| SortDate | BigInt | — | 🟡 | |
| IsPrimary | Integer | — | 🟡 | |
| IsPrivate | Integer | `genq list events --private` | ✅ | Y if private; opt-in via `--private` |
| Proof | Integer | `genq list events --proof` | ✅ | Decoded: Proven/Disproven/Disputed/blank; opt-in via `--proof` |
| Status | Integer | — | 🟡 | LDS ordinance status |
| Sentence | Text | — | ❌ | Custom sentence override |
| Details | Text | `genq list events` | ✅ | Description field |
| Note | Text | `genq list events` | 🟡 | Shown in raw output but not formatted |
| UTCModDate | Float | `genq list events` | ✅ | Always shown as `LastUpdate` (local time) |

**Gap summary:** Proof and IsPrivate now exposed via `--proof` and `--private`. Place name resolution available via `--place-name`. Unsourced events via `--unsourced`. SiteID (sub-place), IsPrimary, and Sentence still missing.

---

### PlaceTable

Canonical place names. PlaceType: 0=Place, 1=LDS Temple, 2=Place Details.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| PlaceID | PK | `genq list places` | ✅ | |
| PlaceType | Integer | `genq list places` | ✅ | Decoded to Place / LDS Temple / Place Details |
| Name | Text | `genq list places` | ✅ | |
| Abbrev | Text | — | ❌ | |
| Normalized | Text | `genq list places` | ✅ | Standardized/geocoded name |
| Latitude / Longitude | Integer | `genq list places --coordinates` | ✅ | Decoded from ×1e7 to decimal degrees; used by `genq distance-from` |
| MasterID | FK→PlaceTable | — | ❌ | Parent place for place-details |
| Note | Text | — | ❌ | |
| UTCModDate | Float | `genq list places --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Good coverage — PlaceID, Name, Normalized, PlaceType, and coordinates all exposed. Abbrev, MasterID, and Note still missing.

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
| Comments | Text | `genq list citations --research-notes` | ✅ | Research annotation; opt-in via `--research-notes` |
| ActualText | Text | `genq list citations --research-notes` | ✅ | Verbatim transcript; opt-in via `--research-notes` |
| RefNumber | Text | — | 🟡 | Ref# field; not shown |
| Footnote | Text | `genq list citations` | ✅ | |
| ShortFootnote | Text | `genq list citations` | ✅ | |
| Bibliography | Text | `genq list citations` | ✅ | |
| Fields | Blob/XML | — | 🟡 | Template field values; not parsed |
| CitationName | Text | — | 🟡 | Auto-generated citation name |
| UTCModDate | Float | `genq list citations --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** All major citation fields now exposed. Comments/ActualText via `--research-notes` (QUOTE() SQL bug also fixed). Template field values (XML blob) not parsed.

---

### CitationLinkTable

Maps citations to their owners (who cites what).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | `genq list citations` | 🟡 | Joined internally; not shown in output |
| CitationID | FK→CitationTable | `genq list citations` | 🟡 | Joined to resolve citations |
| OwnerType | Integer | — | 🟡 | Used in JOIN logic; not shown |
| OwnerID | FK | — | 🟡 | Used in JOIN logic; not shown |
| Quality | Text | `genq list citations --quality` | ✅ | 3-char decoded into Source (Primary/Secondary), Information (Direct/Indirect/Negative), Evidence (Original/Derivative); `SourceName` replaces `Source` column when flag set |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** Quality exposed via `--quality`; EventID exposed via `--event-id` on citations. Unsourced-event detection via `genq list events --unsourced`. OwnerType/OwnerID not directly surfaced. UTCModDate not exposed.

---

### SourceTable

Master source records (free-form and template-based).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| SourceID | PK | `genq list sources` | ✅ | Shown as SrcID |
| Name | Text | `genq list sources` | ✅ | Shown as AbbrevSourceName (truncated) |
| RefNumber | Text | — | 🟡 | |
| ActualText | Text | — | 🟡 | Source text/transcript |
| Comments | Text | — | 🟡 | Source comment |
| IsPrivate | ⚫ | — | ⚫ | Not implemented |
| TemplateID | FK→SourceTemplateTable | `genq list sources` | ✅ | Shown as TempID; `--all` renders template-based sources via `rm-template` |
| Fields | Blob/XML | `genq list sources --all` | ✅ | Footnote/ShortFootnote/Bibliography rendered for all source types |
| UTCModDate | Float | `genq list sources` | ✅ | Always shown as LastUpdate |

**Gap summary:** Good coverage. `genq list sources --all` renders both free-form and template-based sources. RefNumber, ActualText, and Comments not yet exposed.

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

**Gap summary:** No `genq list source-templates`. `genq list sources --all` now works via the `rm-template` engine without needing to expose this table directly; a list command would still be useful for discovery.

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

**Gap summary:** Coverage is reasonable. RefNumber and Date missing. Fullpath construction uses `path join` with cross-platform slash normalization (fixed from earlier literal-quotes bug).

---

### MediaLinkTable

Maps media items to owners (person/family/event/source/citation/place/name/association).

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | 🟡 | Joined internally via `--for` |
| MediaID | FK→MultimediaTable | `genq list media --for` | ✅ | Joined to get media details |
| OwnerType | Integer | — | 🟡 | Used in JOIN (OwnerType=0 for persons); not shown |
| OwnerID | FK | `genq list media --for` | ✅ | Supplied as `--for <RIN>` |
| IsPrimary | Integer | `genq list media --for` | ✅ | Decoded to Y/N |
| SortOrder | Integer | `genq list media --for` | ✅ | Shown |
| Comments | Text | `genq list media --for` | ✅ | Shown as TagComment |
| UTCModDate | Float | — | ❌ | |

**Gap summary:** Person media now accessible via `genq list media --for <RIN>`. Returns fullpath, IsPrimary, SortOrder, TagComment. Other OwnerTypes (family, event, source, etc.) and UTCModDate not yet exposed.

---

### URLTable

Web tags attached to sources, citations, places, tasks, and place details.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | `genq list web-tags` | ✅ | |
| OwnerType | Integer | `genq list web-tags` | ✅ | Decoded: Person/Source/Citation/Place/Task/PlaceDetail; filterable via `--type` |
| OwnerID | FK | `genq list web-tags` | ✅ | Shown; OwnerName resolved via JOIN to appropriate table |
| LinkType | ⚫ | — | ⚫ | Not implemented |
| Name | Text | `genq list web-tags` | ✅ | Shown as TagName |
| URL | Text | `genq list web-tags` | ✅ | |
| Note | Text | `genq list web-tags` | ✅ | |
| UTCModDate | Float | `genq list web-tags --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** All URLTable fields now accessible via `genq list web-tags`. Supports all owner types with name resolution; filterable via `--type person|source|citation|place|task|placedetail`. `genq list findagrave` (ext/miams) remains for backward compatibility.

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
| RecID | PK | `genq list dna` | ✅ | |
| ID1 / ID2 | FK→PersonTable | `genq list dna` | ✅ | Both resolved to full names (Given + Surname) |
| Label1 / Label2 | Text | — | ❌ | Custom labels not yet shown |
| DNAProvider | Integer | `genq list dna` | ✅ | Decoded: 23andMe/Ancestry/FTDNA/LivingDNA/MyHeritage/GEDmatch/Unknown |
| SharedCM / SharedPercent | Float | `genq list dna` | ✅ | Rounded to 1 and 2 decimal places |
| LargeSeg | Float | `genq list dna` | ✅ | Shown as LargestSeg |
| SharedSegs | Integer | `genq list dna` | ✅ | |
| Date | Text | `genq list dna` | ✅ | |
| Relate1 / Relate2 | Integer | — | ❌ | Generations to MRCA; not in SELECT |
| CommonAnc | FK | — | ❌ | MRCA PersonID not yet resolved to name |
| CommonAncType | Integer | — | ❌ | |
| Note | Text | `genq list dna` | ✅ | |
| UTCModDate | Float | `genq list dna --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Core match metrics exposed. Label1/Label2, Relate1/Relate2, and CommonAnc/CommonAncType not yet shown. Table is empty in the Iiams test DB — untested against live data.

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
| LinkID | PK | — | 🟡 | Joined internally |
| rmID | FK→PersonTable | `genq list familysearch-links` | ✅ | Shown as RIN; person name resolved |
| fsID | Text | `genq list familysearch-links` | ✅ | Shown as FamilySearchID |
| Modified | Integer | `genq list familysearch-links` | ✅ | Decoded to Y/N |
| fsVersion | Text | — | ❌ | Internal version string |
| Status | Integer | `genq list familysearch-links` | ✅ | Decoded: Linked / Imported |
| UTCModDate | Float | `genq list familysearch-links --mod-date` | 🟡 | Opt-in via `--mod-date` |

**Gap summary:** Core linkage fields now exposed. fsVersion not shown. Table may be empty if FamilySearch sync has not been used.

---

### AncestryTable

Ancestry.com TreeShare linkage.

| Field | Type | genq Command | Status | Notes |
|-------|------|-------------|--------|-------|
| LinkID | PK | — | 🟡 | Joined internally |
| LinkType | Integer | `genq list ancestry-links` | ✅ | Decoded: Person/Citation/Media |
| rmID | FK | `genq list ancestry-links` | ✅ | Shown; Name resolved from appropriate table |
| anID | Text | `genq list ancestry-links` | ✅ | Shown as AncestryID |
| Modified | Integer | `genq list ancestry-links` | ✅ | Decoded to Y/N |
| anVersion / anDate | Text/Float | — | ❌ | Internal sync metadata |
| Status | Integer | `genq list ancestry-links` | ✅ | Raw integer (decode unknown) |
| UTCModDate | Float | `genq list ancestry-links --mod-date` | 🟡 | Opt-in via `--mod-date` |

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
| PersonTable | 🟡 Good — Living field exposed via `--living` (7/15 fields) | Phase 2 |
| NameTable | 🟡 Good — all names accessible (8/16 fields) | ✅ Phase 1 done |
| FamilyTable | 🟡 Good — Proof/Labels/Note exposed via flags (8/14 fields) | ✅ Phase 2 done |
| ChildTable | 🟡 Good — relationship types covered (5/8 user fields) | ✅ Phase 1 done |
| EventTable | 🟡 Good — Proof/IsPrivate exposed via flags (9/15 fields) | ✅ Phase 2 done |
| PlaceTable | ✅ Good — PlaceID, Name, Normalized, PlaceType, Lat/Lon (5/9 fields) | ✅ Phase 1 done |
| FactTypeTable | 🟡 Partial — name only (1/9 fields) | Phase 3 |
| WitnessTable | 🟡 Good — all event types (5/7 fields) | ✅ Phase 1 done |
| RoleTable | 🟡 Partial — via witnesses (1/5 fields) | Phase 3 |
| CitationTable | 🟡 Good — Comments/ActualText exposed via `--research-notes` (7/10 fields) | ✅ Phase 2 done |
| CitationLinkTable | 🟡 Partial — Quality field exposed via `--quality` (4/6 fields joined) | Phase 2 |
| SourceTable | ✅ Good — free-form + template rendered; UTCModDate always shown (6/8 fields) | ✅ Phase 1 done |
| SourceTemplateTable | 🟡 Partial — name via join (1/7 fields) | Phase 2 |
| MultimediaTable | ✅ Good (7/9 user fields) | Phase 3 (bug fix) |
| MediaLinkTable | 🟡 Partial — IsPrimary, SortOrder, TagComment via `--for` (4/8 fields) | ✅ Phase 2 done |
| URLTable | 🟡 Good — all fields via `genq list web-tags` (5/6 fields) | ✅ Phase 2 done |
| FANTable | 🟡 Good — core data accessible (6/8 fields) | ✅ Phase 1 done |
| FANTypeTable | 🟡 Partial — via associations (2/5 fields) | Phase 3 |
| DNATable | 🟡 Good — core match metrics exposed (10/17 fields) | ✅ Phase 2 done |
| HealthTable | ❌ None | Phase 3 |
| TaskTable | ❌ None | Phase 3 |
| TaskLinkTable | ❌ None | Phase 3 |
| AddressTable | ❌ None | Phase 3 |
| AddressLinkTable | ❌ None | Phase 3 |
| FamilySearchTable | 🟡 Good — RIN, Name, FamilySearchID, Modified, Status (5/7 fields) | ✅ Phase 2 done |
| AncestryTable | 🟡 Good — LinkType, Name, AncestryID, Modified, Status (5/8 fields) | ✅ Phase 2 done |
| ConfigTable | ⚫ Skip | — |
| ExclusionTable | ⚫ Skip | — |
| GroupTable | ❌ None | Phase 4 |
| PayloadTable | ❌ None | Phase 4 |
| TagTable | ❌ None | Phase 4 |

**Current coverage: ~22 of 31 tables have meaningful exposure (up from ~4 in March 2026). Phase 2 complete. Remaining gaps: research management (tasks, health), reference lookup tables (fact-types, roles, source-templates), and admin tables (groups, bookmarks).**

---

## Non-Table Commands (cross-cutting / derived output)

These commands don't map to a single RM table but add significant reporting capability:

| Command | What it does | Tables touched |
|---------|-------------|----------------|
| `genq tabulate trees` | Count distinct family trees; list all members of a tree with generational distance from anchor | PersonTable, ChildTable, FamilyTable (via union-find) |
| `genq distance-from` | Pipe filter: adds Haversine `Distance` column to any table with Latitude/Longitude columns | PlaceTable (indirectly) |
| `genq md people` | Export Obsidian-compatible markdown files with YAML frontmatter for persons | PersonTable, EventTable, NameTable, ChildTable |

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
| 1.8 | `genq list sources --all` | ✅ Done — template rendering via `rm-template` |
| 1.9 | `genq list citations --owner` | ✅ N/A — RIN already in output; use `\| where RIN == X` |

### Phase 2 — Enhanced Existing Commands + New Data Domains

Enrich existing outputs; add DNA, media, and external linkage.

| # | Command | Fills Gap | Tables |
|---|---------|-----------|--------|
| ✅ | `genq list citations --quality` | GPS quality decoded: Source/Information/Evidence | CitationLinkTable |
| ✅ | `genq list citations --event-id` | EventID column for event-level citation lookup | CitationLinkTable + EventTable |
| ✅ | `genq list events --unsourced` | LEFT JOIN CitationLinkTable; events with no citations | EventTable + CitationLinkTable |
| ✅ | `genq list media` fullpath bug fixed | Cross-platform `path join`; no literal quotes | MultimediaTable |
| ✅ | `genq list people --living` | Living status decoded to Y/N | PersonTable |
| ✅ | `genq list events --proof --private` | Proof/IsPrivate decoded from EventTable | EventTable |
| ✅ | `genq list families --proof --labels --note` | Proof, FatherRole/MotherRole, Note | FamilyTable |
| ✅ | `genq list citations --research-notes` | ActualText + Comments; QUOTE() SQL bug fixed | CitationTable |
| ✅ | `genq list media --for <RIN>` | Media for a person via link table | MediaLinkTable + MultimediaTable |
| ✅ | `genq list dna` | DNA matches with cM, %, provider, cM/segments | DNATable |
| ✅ | `genq list web-tags` | All web tags; all owner types with name resolution; `--type` filter | URLTable |
| ✅ | `genq list familysearch-links` | RIN, FamilySearchID, Modified, Status | FamilySearchTable |
| ✅ | `genq list ancestry-links` | LinkType, Name, AncestryID, Modified, Status | AncestryTable |

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
- `genq list sources --all` now renders template-based sources (✅ fixed)

**Phase 2** items expand depth of existing data:
- DNA data is increasingly central to modern genealogical proof
- Media-per-person linkage enables photo-aware reporting
- FamilySearch/Ancestry IDs are the foundation of the Discoverer edition

**Phase 3 & 4** support research management workflows (tasks, health patterns, group queries) with lower urgency but real value for active researchers.

---

## Next Steps (as of 2026-04-16)

### Phase 1 — Complete ✅

All Phase 1 items done. Item 1.9 (`--owner` filter on citations) resolved as not needed — the output already includes RIN and supports `| where RIN == X`. CitationLinkTable now meaningfully covered via `--quality` and `--event-id`.

### Phase 2 — In Progress

**Recently completed:**

| Item | Command | What it adds |
|------|---------|-------------|
| ✅ | `genq list citations --quality` | GPS Source/Information/Evidence columns decoded from 3-char code |
| ✅ | `genq list citations --event-id` | EventID exposed for event-level citation cross-reference |
| ✅ | `genq list events --unsourced` | Find facts with no citations — core research gap tool |
| ✅ | `genq list media` fullpath fix | Cross-platform path construction via `path join` |
| ✅ | `genq list people --living` | Living status decoded to Y/N; privacy-aware reporting |
| ✅ | `genq list media --for <RIN>` | Person media via MediaLinkTable; fullpath, IsPrimary, SortOrder, TagComment |
| ✅ | `genq list dna` | DNA matches: cM, %, segments, provider decoded, both persons named |
| ✅ | `genq list events --proof --private` | Proof/IsPrivate decoded; evidence-quality filtering |
| ✅ | `genq list families --proof --labels --note` | Proof, FatherRole/MotherRole, family Note |
| ✅ | `genq list citations --research-notes` | ActualText + Comments; SQL QUOTE() bug fixed |
| ✅ | `genq list web-tags` | All URLTable owner types; OwnerName resolved; `--type` filter |
| ✅ | `genq list familysearch-links` | RIN↔FamilySearch ID; Modified/Status decoded |
| ✅ | `genq list ancestry-links` | rmID↔Ancestry ID; Person/Citation/Media link types |

### Phase 2 — Complete ✅

All Phase 2 items are done. Proceeding to Phase 3.

---

## Known Bugs

| Bug | Location | Impact | Status |
|-----|---------|--------|--------|
| `genq list findagrave` OwnerType=0 | `ext/miams/genq list findagrave/mod.nu:23` | Previously flagged as suspect; confirmed correct — OwnerType=0 IS the person type in URLTable (5,454 rows in Iiams) | ✅ Not a bug |
| `fullpath` literal quotes | `genq list media/mod.nu` | Broken paths on macOS | ✅ Fixed — uses `path join` with slash normalization |
| `genq list sources --all` stub | `genq list sources/mod.nu` | Silent no-op misleads users | ✅ Fixed — renders templates via `rm-template` |
| `genq list events --citations` dead flag | `genq list events/mod.nu` | Flag declared but never implemented | ✅ Fixed — flag removed |
