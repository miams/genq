# GenQuery DB shape profile — metric catalog
#
# Source of truth for every metric run as part of the database "shape profile"
# emitted by the telemetry pipeline. Refactored from the JS scratch file
# `scripts/db-shape-profile-metrics.js`, which existed only to iterate on the
# query set in a browser harness. The Nushell module is the production catalog.
#
# Field reference for each metric record:
#
#   section    1..16, matches docs/db-shape-profile.md section numbering.
#   qno        "SS.NN" identifier; auto-assigned by section position.
#   name       stable JSON key in the profile output. Dot-separated namespacing
#              ("people.total", "events.with_date") is preserved verbatim.
#   desc       short human description; surfaced in `genq telemetry view`.
#   impl       "Y" → executed during a profile run; "N" → catalog-only entry
#              kept for parity with the design doc.
#   rec        "Y" if recommended for downstream analysis (informational).
#   query      complete SELECT producing one row, one column named `v`. Null
#              means "deferred / not implemented" — runner skips it.
#   multi_row  when true, query may return many rows (histograms, usage tables).
#              Stored under a separate top-level `multi_rows` map in the
#              profile payload rather than inlined as a scalar.
#   format     optional renderer hint; "iso8601" tells consumers not to apply
#              numeric formatting to the scalar (it's a date string).
#
# Performance: see profile.nu for how the runner consolidates scalar metrics
# into a single mega-query (one connection, one execution plan) per the
# design call. Multi-row metrics are run individually but on the same
# connection, immediately after the scalar batch.

# ─── UTCModDate normalization ───────────────────────────────────────────────
#
# UTCModDate is stored in three different units across RM databases:
#   • OLE date     (days since 1899-12-30; small values ~46128)
#   • Julian Day   (~2461000)
#   • Unix epoch   (seconds since 1970-01-01; large values ~1.7e9)
# pres2025.rmtree uses OLE everywhere; Iiams.rmtree mixes OLE and Unix
# in different tables. The CASE below normalizes any of the three formats
# to a Julian Day so that comparisons and date rendering are correct.
export const UTC_TO_JD = "(CASE WHEN UTCModDate < 100000 THEN UTCModDate + 2415018.5 WHEN UTCModDate > 1000000000 THEN UTCModDate / 86400.0 + 2440587.5 ELSE UTCModDate END)"

# Tables RM stamps with UTCModDate. Used for cross-table activity metrics.
export const UTC_TABLES = [
    "PersonTable" "EventTable" "NameTable" "SourceTable"
    "CitationTable" "PlaceTable" "MultimediaTable" "TaskTable"
]

# UNION ALL of MAX/MIN(UTCModDate) per table — cheap, hits each table's
# UTCModDate index for a single value.
export def utc-agg-union [agg: string] {
    $UTC_TABLES | each {|t| $"SELECT ($agg)\(UTCModDate) AS UTCModDate FROM ($t) WHERE UTCModDate > 0" } | str join " UNION ALL "
}

# Sum of per-table COUNT(*) where the normalized UTCModDate is within `days`
# of "now". Each subquery normalizes UTCModDate inline.
export def utc-recent-sum [days: int] {
    let d = ($days | into string)
    $UTC_TABLES | each {|t| $"\(SELECT COUNT\(*) FROM ($t) WHERE UTCModDate > 0 AND ($UTC_TO_JD) > julianday\('now') - ($d))" } | str join " + "
}

# Per-table records-modified-by-year histogram (year, n) ordered ASC.
export def utc-by-year-for-table [table: string] {
    $"WITH norm AS \(SELECT CAST\(strftime\('%Y', ($UTC_TO_JD)) AS INTEGER) AS year FROM ($table) WHERE UTCModDate > 0) SELECT year, COUNT\(*) AS n FROM norm GROUP BY year ORDER BY year"
}

# Per-table aggregate (MIN/MAX) of normalized UTCModDate as ISO 8601 UTC.
export def utc-agg-iso-for-table [table: string, agg: string] {
    $"SELECT strftime\('%Y-%m-%dT%H:%M:%SZ', ($agg)\(($UTC_TO_JD))) AS v FROM ($table) WHERE UTCModDate > 0"
}

# Section name table — index = section number.
export const SECTIONS = [
    "Version & database metadata"  # 1
    "People"                       # 2
    "Names"                        # 3
    "Families"                     # 4
    "Fact types"                   # 5
    "Roles & witnesses"            # 6
    "Events"                       # 7
    "Places"                       # 8
    "Sources, citations, templates" # 9
    "Repositories & addresses"     # 10
    "Media"                        # 11
    "Tasks, groups, tags"          # 12
    "Associations"                 # 13
    "External links"               # 14
    "Time-bucketed histograms"     # 15
    "Activity & recency"           # 16
]

# Format hint constants.
export const FORMAT_ISO8601 = "iso8601"

# ─── Catalog ────────────────────────────────────────────────────────────────
#
# Returns the full metric catalog as a list of records, with `qno` auto-
# assigned by section position. This is invoked once per profile run.

export def metrics-catalog [] {
    let raw = [
        # ─── 1. Version & database metadata ────────────────────────────────
        { section: 1, name: "sqlite_user_version",        impl: "Y", rec: "Y",
          desc: "SQLite user_version pragma (RM never sets it)",
          query: "SELECT user_version AS v FROM pragma_user_version" }
        { section: 1, name: "sqlite_page_count",          impl: "Y", rec: "N",
          desc: "SQLite page count",
          query: "SELECT page_count AS v FROM pragma_page_count" }
        { section: 1, name: "sqlite_page_size",           impl: "Y", rec: "N",
          desc: "SQLite page size in bytes",
          query: "SELECT page_size AS v FROM pragma_page_size" }
        { section: 1, name: "db_size_kb",                 impl: "Y", rec: "Y",
          desc: "Database size in KB",
          query: "SELECT (CAST(page_count AS INTEGER) * CAST(page_size AS INTEGER)) / 1024 AS v FROM pragma_page_count, pragma_page_size" }
        { section: 1, name: "rm_version",                 impl: "Y", rec: "Y",
          desc: "RootsMagic version (from ConfigTable XML)",
          query: "WITH cfg AS (SELECT CAST(DataRec AS TEXT) AS x FROM ConfigTable WHERE RecID = 1) SELECT CASE WHEN INSTR(x, '<Version>') > 0 THEN SUBSTR(x, INSTR(x, '<Version>') + 9, INSTR(x, '</Version>') - INSTR(x, '<Version>') - 9) END AS v FROM cfg" }
        { section: 1, name: "rm_st_version",              impl: "Y", rec: "Y",
          desc: "Source-template definition version",
          query: "WITH cfg AS (SELECT CAST(DataRec AS TEXT) AS x FROM ConfigTable WHERE RecID = 1) SELECT CASE WHEN INSTR(x, '<STVersion>') > 0 THEN SUBSTR(x, INSTR(x, '<STVersion>') + 11, INSTR(x, '</STVersion>') - INSTR(x, '<STVersion>') - 11) END AS v FROM cfg" }
        { section: 1, name: "rm_unique_id",               impl: "Y", rec: "Y",
          desc: "Stable RM database GUID",
          query: "WITH cfg AS (SELECT CAST(DataRec AS TEXT) AS x FROM ConfigTable WHERE RecID = 1) SELECT CASE WHEN INSTR(x, '<UniqueID>') > 0 THEN SUBSTR(x, INSTR(x, '<UniqueID>') + 10, INSTR(x, '</UniqueID>') - INSTR(x, '<UniqueID>') - 10) END AS v FROM cfg" }
        { section: 1, name: "rm_default_language",        impl: "Y", rec: "Y",
          desc: "RM default sentence language",
          query: "WITH cfg AS (SELECT CAST(DataRec AS TEXT) AS x FROM ConfigTable WHERE RecID = 1) SELECT CASE WHEN INSTR(x, '<DefLang>') > 0 THEN SUBSTR(x, INSTR(x, '<DefLang>') + 9, INSTR(x, '</DefLang>') - INSTR(x, '<DefLang>') - 9) END AS v FROM cfg" }
        { section: 1, name: "rm_date_format",             impl: "Y", rec: "Y",
          desc: "RM preferred date format setting",
          query: "WITH cfg AS (SELECT CAST(DataRec AS TEXT) AS x FROM ConfigTable WHERE RecID = 1) SELECT CASE WHEN INSTR(x, '<DateFormat>') > 0 THEN SUBSTR(x, INSTR(x, '<DateFormat>') + 12, INSTR(x, '</DateFormat>') - INSTR(x, '<DateFormat>') - 12) END AS v FROM cfg" }
        { section: 1, name: "latest_utcmoddate_julian",   impl: "Y", rec: "Y",
          desc: "Most recent UTCModDate across major tables (ISO 8601 UTC; format-aware: OLE / Julian / Unix epoch)",
          format: $FORMAT_ISO8601,
          query: ("WITH per_table AS (" + (utc-agg-union "MAX") + "), normalized AS (SELECT " + $UTC_TO_JD + " AS jd FROM per_table WHERE UTCModDate IS NOT NULL) SELECT strftime('%Y-%m-%dT%H:%M:%SZ', MAX(jd)) AS v FROM normalized") }
        { section: 1, name: "sqlite_version",             impl: "Y", rec: "Y",
          desc: "SQLite library version of the host",
          query: "SELECT sqlite_version() AS v" }
        { section: 1, name: "pragma_journal_mode",        impl: "N", rec: "N",
          desc: "PRAGMA journal_mode (read-only sessions don't care)",
          query: null }
        { section: 1, name: "pragma_encoding",            impl: "N", rec: "N",
          desc: "PRAGMA encoding (always UTF-8 in RM)",
          query: null }
        { section: 1, name: "pragma_application_id",      impl: "N", rec: "N",
          desc: "PRAGMA application_id (RM doesn't set it)",
          query: null }
        { section: 1, name: "config_record_count",        impl: "N", rec: "N",
          desc: "COUNT(*) FROM ConfigTable (always tiny)",
          query: null }
        { section: 1, name: "earliest_utcmoddate_julian", impl: "N", rec: "N",
          desc: "Earliest UTCModDate across tables (ISO 8601 UTC; format-aware)",
          format: $FORMAT_ISO8601,
          query: ("WITH per_table AS (" + (utc-agg-union "MIN") + "), normalized AS (SELECT " + $UTC_TO_JD + " AS jd FROM per_table WHERE UTCModDate IS NOT NULL) SELECT strftime('%Y-%m-%dT%H:%M:%SZ', MIN(jd)) AS v FROM normalized") }
        { section: 1, name: "record_count_total",         impl: "N", rec: "N",
          desc: "Sum of COUNT(*) across user tables (redundant)",
          query: null }

        # ─── 2. People ─────────────────────────────────────────────────────
        { section: 2, name: "people.total",        impl: "Y", rec: "Y",
          desc: "PersonTable row count",
          query: "SELECT COUNT(*) AS v FROM PersonTable" }
        { section: 2, name: "people.male",         impl: "Y", rec: "Y",
          desc: "Persons with Sex = 0 (male)",
          query: "SELECT SUM(CASE WHEN Sex = 0 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.female",       impl: "Y", rec: "Y",
          desc: "Persons with Sex = 1 (female)",
          query: "SELECT SUM(CASE WHEN Sex = 1 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.unknown_sex",  impl: "Y", rec: "Y",
          desc: "Persons with Sex not in {0,1}",
          query: "SELECT SUM(CASE WHEN Sex NOT IN (0,1) THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.living",       impl: "Y", rec: "Y",
          desc: "Persons flagged Living = 1",
          query: "SELECT SUM(CASE WHEN Living = 1 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.private",      impl: "Y", rec: "N",
          desc: "Persons flagged IsPrivate = 1",
          query: "SELECT SUM(CASE WHEN IsPrivate = 1 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.bookmarked",   impl: "Y", rec: "N",
          desc: "Persons flagged Bookmark = 1",
          query: "SELECT SUM(CASE WHEN Bookmark = 1 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.with_note",    impl: "Y", rec: "Y",
          desc: "Persons with non-empty Note",
          query: "SELECT SUM(CASE WHEN Note IS NOT NULL AND Note <> '' THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.with_color",   impl: "Y", rec: "N",
          desc: "Persons with any Color1..Color9 > 0",
          query: "SELECT SUM(CASE WHEN (Color1+Color2+Color3+Color4+Color5+Color6+Color7+Color8+Color9) > 0 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.with_proof",   impl: "Y", rec: "N",
          desc: "Persons with Proof > 0 (legacy column)",
          query: "SELECT SUM(CASE WHEN Proof > 0 THEN 1 ELSE 0 END) AS v FROM PersonTable" }
        { section: 2, name: "people.relate1_max",  impl: "Y", rec: "N",
          desc: "MAX(Relate1) (internal RM cache)",
          query: "SELECT MAX(Relate1) AS v FROM PersonTable" }
        { section: 2, name: "people.records_modified_by_year", impl: "Y", rec: "N",
          desc: "PersonTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "PersonTable") }
        { section: 2, name: "people.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in PersonTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "PersonTable" "MIN") }
        { section: 2, name: "people.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in PersonTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "PersonTable" "MAX") }

        # ─── 3. Names ──────────────────────────────────────────────────────
        { section: 3, name: "names.total",              impl: "Y", rec: "Y",
          desc: "NameTable row count (all names)",
          query: "SELECT COUNT(*) AS v FROM NameTable" }
        { section: 3, name: "names.primary_names",      impl: "Y", rec: "Y",
          desc: "Primary names (IsPrimary = 1)",
          query: "SELECT SUM(CASE WHEN IsPrimary = 1 THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.alternate_names",    impl: "Y", rec: "Y",
          desc: "Alternate names (IsPrimary = 0)",
          query: "SELECT SUM(CASE WHEN IsPrimary = 0 THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.with_birth_year",    impl: "Y", rec: "Y",
          desc: "Names with BirthYear > 0",
          query: "SELECT SUM(CASE WHEN BirthYear > 0 THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.with_death_year",    impl: "Y", rec: "Y",
          desc: "Names with DeathYear > 0",
          query: "SELECT SUM(CASE WHEN DeathYear > 0 THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.distinct_surnames",  impl: "Y", rec: "Y",
          desc: "Distinct Surname (NOCASE) on primary names",
          query: "SELECT COUNT(DISTINCT Surname COLLATE NOCASE) AS v FROM NameTable WHERE IsPrimary = 1" }
        { section: 3, name: "names.distinct_given_names", impl: "Y", rec: "N",
          desc: "Distinct Given (NOCASE) on primary names",
          query: "SELECT COUNT(DISTINCT Given COLLATE NOCASE) AS v FROM NameTable WHERE IsPrimary = 1" }
        { section: 3, name: "names.with_prefix",        impl: "Y", rec: "N",
          desc: "Names with non-empty Prefix",
          query: "SELECT SUM(CASE WHEN Prefix IS NOT NULL AND Prefix <> '' THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.with_suffix",        impl: "Y", rec: "N",
          desc: "Names with non-empty Suffix",
          query: "SELECT SUM(CASE WHEN Suffix IS NOT NULL AND Suffix <> '' THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "names.with_nickname",      impl: "Y", rec: "N",
          desc: "Names with non-empty Nickname",
          query: "SELECT SUM(CASE WHEN Nickname IS NOT NULL AND Nickname <> '' THEN 1 ELSE 0 END) AS v FROM NameTable" }
        { section: 3, name: "name_type_distribution",   impl: "Y", rec: "Y",
          desc: "NameType histogram",
          multi_row: true,
          query: "SELECT NameType AS name_type, COUNT(*) AS n FROM NameTable GROUP BY NameType ORDER BY n DESC" }
        { section: 3, name: "names.records_modified_by_year", impl: "Y", rec: "N",
          desc: "NameTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "NameTable") }
        { section: 3, name: "names.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in NameTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "NameTable" "MIN") }
        { section: 3, name: "names.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in NameTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "NameTable" "MAX") }

        # ─── 4. Families ───────────────────────────────────────────────────
        { section: 4, name: "families.total",          impl: "Y", rec: "Y",
          desc: "FamilyTable row count",
          query: "SELECT COUNT(*) AS v FROM FamilyTable" }
        { section: 4, name: "families.one_parent",     impl: "Y", rec: "Y",
          desc: "Families with exactly one parent",
          query: "SELECT SUM(CASE WHEN (FatherID = 0) <> (MotherID = 0) THEN 1 ELSE 0 END) AS v FROM FamilyTable" }
        { section: 4, name: "families.no_parents",     impl: "Y", rec: "Y",
          desc: "Families with no parent set",
          query: "SELECT SUM(CASE WHEN FatherID = 0 AND MotherID = 0 THEN 1 ELSE 0 END) AS v FROM FamilyTable" }
        { section: 4, name: "families.child_links",    impl: "Y", rec: "Y",
          desc: "Total parent-child links",
          query: "SELECT COUNT(*) AS v FROM ChildTable" }
        { section: 4, name: "families.with_children",  impl: "Y", rec: "Y",
          desc: "Families with at least one child",
          query: "SELECT COUNT(DISTINCT FamilyID) AS v FROM ChildTable" }
        { section: 4, name: "families.with_marriage_event", impl: "Y", rec: "N",
          desc: "Distinct families with >=1 event whose FactType has GedcomTag=MARR",
          query: "SELECT COUNT(DISTINCT OwnerID) AS v FROM EventTable WHERE OwnerType = 1 AND EventType IN (SELECT FactTypeID FROM FactTypeTable WHERE GedcomTag = 'MARR')" }
        { section: 4, name: "families.child_count_distribution", impl: "Y", rec: "N",
          desc: "Histogram: families by number of children",
          multi_row: true,
          query: "SELECT cnt AS children_per_family, COUNT(*) AS family_count FROM (SELECT FamilyID, COUNT(*) AS cnt FROM ChildTable GROUP BY FamilyID) GROUP BY cnt ORDER BY cnt" }
        { section: 4, name: "families.relationship_type_distribution", impl: "Y", rec: "Y",
          desc: "ChildTable.(RelFather, RelMother) pair histogram",
          multi_row: true,
          query: "SELECT RelFather AS rel_father, RelMother AS rel_mother, COUNT(*) AS n FROM ChildTable GROUP BY RelFather, RelMother ORDER BY n DESC" }

        # ─── 5. Fact types ─────────────────────────────────────────────────
        { section: 5, name: "fact_types.total",          impl: "Y", rec: "Y",
          desc: "FactTypeTable row count",
          query: "SELECT COUNT(*) AS v FROM FactTypeTable" }
        { section: 5, name: "fact_types.person_scoped",  impl: "Y", rec: "Y",
          desc: "Fact types with OwnerType = 0",
          query: "SELECT SUM(CASE WHEN OwnerType = 0 THEN 1 ELSE 0 END) AS v FROM FactTypeTable" }
        { section: 5, name: "fact_types.family_scoped",  impl: "Y", rec: "Y",
          desc: "Fact types with OwnerType = 1",
          query: "SELECT SUM(CASE WHEN OwnerType = 1 THEN 1 ELSE 0 END) AS v FROM FactTypeTable" }
        { section: 5, name: "fact_types.likely_custom",  impl: "Y", rec: "Y",
          desc: "Fact types with empty GedcomTag",
          query: "SELECT SUM(CASE WHEN COALESCE(GedcomTag,'') = '' THEN 1 ELSE 0 END) AS v FROM FactTypeTable" }
        { section: 5, name: "fact_types.used",           impl: "Y", rec: "Y",
          desc: "Distinct EventType values in events",
          query: "SELECT COUNT(DISTINCT EventType) AS v FROM EventTable" }
        { section: 5, name: "fact_type_usage",           impl: "Y", rec: "Y",
          desc: "Per-fact-type usage table (id, name, owner, gedcom, count)",
          multi_row: true,
          query: "SELECT f.FactTypeID AS fact_type_id, f.Name AS fact_type_name, CASE f.OwnerType WHEN 0 THEN 'person' WHEN 1 THEN 'family' ELSE 'other' END AS owner_kind, COALESCE(f.GedcomTag, '') AS gedcom_tag, (SELECT COUNT(*) FROM EventTable e WHERE e.EventType = f.FactTypeID) AS use_count FROM FactTypeTable f ORDER BY f.FactTypeID" }
        { section: 5, name: "fact_types.unused_fact_types", impl: "Y", rec: "N",
          desc: "Fact types never used in events",
          query: "SELECT COUNT(*) AS v FROM FactTypeTable WHERE FactTypeID NOT IN (SELECT DISTINCT EventType FROM EventTable)" }
        { section: 5, name: "fact_types.sentence_overrides", impl: "Y", rec: "N",
          desc: "Fact types with non-empty Sentence",
          query: "SELECT SUM(CASE WHEN Sentence IS NOT NULL AND Sentence <> '' THEN 1 ELSE 0 END) AS v FROM FactTypeTable" }

        # ─── 6. Roles & witnesses ─────────────────────────────────────────
        # RM auto-creates one "Witness" role per fact type; user-added roles are
        # anything else. WitnessTable.Role -> RoleTable.RoleID is where each
        # person-attached-to-event lives.
        { section: 6, name: "roles.total",                impl: "Y", rec: "Y",
          desc: "RoleTable row count (catalog of named roles)",
          query: "SELECT COUNT(*) AS v FROM RoleTable" }
        { section: 6, name: "roles.custom",               impl: "Y", rec: "Y",
          desc: "Roles whose name is not the default 'Witness' (user additions)",
          query: "SELECT SUM(CASE WHEN LOWER(COALESCE(RoleName,'')) <> 'witness' THEN 1 ELSE 0 END) AS v FROM RoleTable" }
        { section: 6, name: "roles.used",                 impl: "Y", rec: "Y",
          desc: "Distinct RoleTable.RoleID values referenced by WitnessTable",
          query: "SELECT COUNT(DISTINCT Role) AS v FROM WitnessTable WHERE Role IS NOT NULL" }
        { section: 6, name: "roles.unused",               impl: "Y", rec: "N",
          desc: "Roles defined in RoleTable but never assigned in WitnessTable",
          query: "SELECT COUNT(*) AS v FROM RoleTable WHERE RoleID NOT IN (SELECT DISTINCT Role FROM WitnessTable WHERE Role IS NOT NULL)" }
        { section: 6, name: "roles.with_sentence",        impl: "Y", rec: "N",
          desc: "Roles with a non-empty Sentence template (per-role narrative)",
          query: "SELECT SUM(CASE WHEN Sentence IS NOT NULL AND Sentence <> '' THEN 1 ELSE 0 END) AS v FROM RoleTable" }
        { section: 6, name: "roles.fact_types_covered",   impl: "Y", rec: "N",
          desc: "Distinct fact types that have at least one user-added (non-Witness) role",
          query: "SELECT COUNT(DISTINCT EventType) AS v FROM RoleTable WHERE LOWER(COALESCE(RoleName,'')) <> 'witness'" }
        { section: 6, name: "role_usage",                 impl: "Y", rec: "Y",
          desc: "Per-role usage table (id, role_name, fact_type_name, witness_count)",
          multi_row: true,
          query: "SELECT r.RoleID AS role_id, r.RoleName AS role_name, COALESCE(ft.Name,'') AS fact_type_name, (SELECT COUNT(*) FROM WitnessTable w WHERE w.Role = r.RoleID) AS use_count FROM RoleTable r LEFT JOIN FactTypeTable ft ON ft.FactTypeID = r.EventType ORDER BY use_count DESC, r.RoleID" }
        { section: 6, name: "witnesses.total",            impl: "Y", rec: "Y",
          desc: "WitnessTable row count (people-attached-to-events)",
          query: "SELECT COUNT(*) AS v FROM WitnessTable" }
        { section: 6, name: "roles.oldest_mod_date",      impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in RoleTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "RoleTable" "MIN") }
        { section: 6, name: "roles.most_recent_mod_date", impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in RoleTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "RoleTable" "MAX") }
        { section: 6, name: "witnesses.records_modified_by_year", impl: "Y", rec: "N",
          desc: "WitnessTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "WitnessTable") }
        { section: 6, name: "witnesses.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in WitnessTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "WitnessTable" "MIN") }
        { section: 6, name: "witnesses.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in WitnessTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "WitnessTable" "MAX") }

        # ─── 7. Events ─────────────────────────────────────────────────────
        { section: 7, name: "events.total",                  impl: "Y", rec: "Y",
          desc: "EventTable row count",
          query: "SELECT COUNT(*) AS v FROM EventTable" }
        { section: 7, name: "events.person_events",          impl: "Y", rec: "Y",
          desc: "Events with OwnerType = 0",
          query: "SELECT SUM(CASE WHEN OwnerType = 0 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.family_events",          impl: "Y", rec: "Y",
          desc: "Events with OwnerType = 1",
          query: "SELECT SUM(CASE WHEN OwnerType = 1 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.with_date",              impl: "Y", rec: "Y",
          desc: "Events with a non-empty Date string",
          query: "SELECT SUM(CASE WHEN Date IS NOT NULL AND Date <> '' AND Date <> '.' THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.with_place",             impl: "Y", rec: "Y",
          desc: "Events with PlaceID > 0",
          query: "SELECT SUM(CASE WHEN PlaceID > 0 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.proven",                 impl: "Y", rec: "Y",
          desc: "Events with Proof = 1",
          query: "SELECT SUM(CASE WHEN Proof = 1 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.disproven",              impl: "Y", rec: "Y",
          desc: "Events with Proof = 2",
          query: "SELECT SUM(CASE WHEN Proof = 2 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.disputed",               impl: "Y", rec: "Y",
          desc: "Events with Proof = 3",
          query: "SELECT SUM(CASE WHEN Proof = 3 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.private",                impl: "Y", rec: "Y",
          desc: "Events flagged IsPrivate = 1",
          query: "SELECT SUM(CASE WHEN IsPrivate = 1 THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.events_with_citations",  impl: "Y", rec: "Y",
          desc: "Distinct events that have >=1 citation link",
          query: "SELECT COUNT(DISTINCT OwnerID) AS v FROM CitationLinkTable WHERE OwnerType = 2" }
        { section: 7, name: "events.with_note",              impl: "Y", rec: "Y",
          desc: "Events with non-empty Note",
          query: "SELECT SUM(CASE WHEN Note IS NOT NULL AND Note <> '' THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.with_sentence_override", impl: "Y", rec: "N",
          desc: "Events with non-empty Sentence (per-event narrative override)",
          query: "SELECT SUM(CASE WHEN Sentence IS NOT NULL AND Sentence <> '' THEN 1 ELSE 0 END) AS v FROM EventTable" }
        { section: 7, name: "events.date_modifier_distribution", impl: "Y", rec: "N",
          desc: "SUBSTR(Date,2,1) histogram (modifier byte: about/before/after/between)",
          multi_row: true,
          query: "SELECT SUBSTR(Date, 2, 1) AS modifier, COUNT(*) AS n FROM EventTable WHERE Date IS NOT NULL AND LENGTH(Date) >= 2 GROUP BY modifier ORDER BY n DESC" }
        { section: 7, name: "events.date_type_distribution", impl: "Y", rec: "N",
          desc: "SUBSTR(Date,1,1) histogram (type byte: D/Q/R/T)",
          multi_row: true,
          query: "SELECT SUBSTR(Date, 1, 1) AS type, COUNT(*) AS n FROM EventTable WHERE Date IS NOT NULL AND LENGTH(Date) >= 1 GROUP BY type ORDER BY n DESC" }
        { section: 7, name: "events.events_per_person",      impl: "Y", rec: "Y",
          desc: "person_events / distinct OwnerID (research depth)",
          query: "SELECT ROUND(CAST(SUM(CASE WHEN OwnerType=0 THEN 1 ELSE 0 END) AS REAL) / NULLIF(COUNT(DISTINCT CASE WHEN OwnerType=0 THEN OwnerID END), 0), 3) AS v FROM EventTable" }
        { section: 7, name: "events.records_modified_by_year", impl: "Y", rec: "N",
          desc: "EventTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "EventTable") }
        { section: 7, name: "events.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in EventTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "EventTable" "MIN") }
        { section: 7, name: "events.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in EventTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "EventTable" "MAX") }

        # ─── 8. Places ─────────────────────────────────────────────────────
        { section: 8, name: "places.places",         impl: "Y", rec: "Y",
          desc: "PlaceTable rows with PlaceType = 0",
          query: "SELECT SUM(CASE WHEN PlaceType = 0 THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.temples",        impl: "Y", rec: "N",
          desc: "PlaceTable rows with PlaceType = 1 (LDS)",
          query: "SELECT SUM(CASE WHEN PlaceType = 1 THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.place_details",  impl: "Y", rec: "Y",
          desc: "PlaceTable rows with PlaceType = 2 (sub-place)",
          query: "SELECT SUM(CASE WHEN PlaceType = 2 THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.geocoded",       impl: "Y", rec: "Y",
          desc: "Places with non-zero lat or lon",
          query: "SELECT SUM(CASE WHEN Latitude <> 0 OR Longitude <> 0 THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.not_geocoded",   impl: "Y", rec: "Y",
          desc: "Places with both lat and lon = 0",
          query: "SELECT SUM(CASE WHEN Latitude = 0 AND Longitude = 0 THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.places_total",   impl: "Y", rec: "Y",
          desc: "PlaceTable row count (all types)",
          query: "SELECT COUNT(*) AS v FROM PlaceTable" }
        { section: 8, name: "places.places_used",    impl: "Y", rec: "Y",
          desc: "Distinct PlaceID actually referenced by events",
          query: "SELECT COUNT(DISTINCT PlaceID) AS v FROM EventTable WHERE PlaceID > 0" }
        { section: 8, name: "places.with_note",      impl: "Y", rec: "N",
          desc: "Places with non-empty Note",
          query: "SELECT SUM(CASE WHEN Note IS NOT NULL AND Note <> '' THEN 1 ELSE 0 END) AS v FROM PlaceTable" }
        { section: 8, name: "places.country_count",  impl: "Y", rec: "N",
          desc: "Distinct countries (last comma-separated component of Name; PlaceType=0)",
          query: "WITH RECURSIVE walk AS (SELECT PlaceID, SUBSTR(Name, INSTR(Name, ',') + 1) AS rest FROM PlaceTable WHERE PlaceType = 0 AND INSTR(Name, ',') > 0 UNION ALL SELECT PlaceID, SUBSTR(rest, INSTR(rest, ',') + 1) FROM walk WHERE INSTR(rest, ',') > 0) SELECT COUNT(DISTINCT TRIM(rest) COLLATE NOCASE) AS v FROM walk WHERE INSTR(rest, ',') = 0" }
        { section: 8, name: "places.master_places",  impl: "Y", rec: "N",
          desc: "Master places (MasterID = 0)",
          query: "SELECT COUNT(*) AS v FROM PlaceTable WHERE MasterID = 0" }
        { section: 8, name: "places.records_modified_by_year", impl: "Y", rec: "N",
          desc: "PlaceTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "PlaceTable") }
        { section: 8, name: "places.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in PlaceTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "PlaceTable" "MIN") }
        { section: 8, name: "places.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in PlaceTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "PlaceTable" "MAX") }

        # ─── 9. Sources, citations, templates ──────────────────────────────
        { section: 9, name: "sources.total",                              impl: "Y", rec: "Y",
          desc: "SourceTable row count",
          query: "SELECT COUNT(*) AS v FROM SourceTable" }
        { section: 9, name: "sources.freeform",                           impl: "Y", rec: "Y",
          desc: "Sources with TemplateID = 0",
          query: "SELECT SUM(CASE WHEN TemplateID = 0 THEN 1 ELSE 0 END) AS v FROM SourceTable" }
        { section: 9, name: "sources.template_based",                     impl: "Y", rec: "Y",
          desc: "Sources with TemplateID > 0",
          query: "SELECT SUM(CASE WHEN TemplateID > 0 THEN 1 ELSE 0 END) AS v FROM SourceTable" }
        { section: 9, name: "citations.citations_total",                  impl: "Y", rec: "Y",
          desc: "CitationTable row count",
          query: "SELECT COUNT(*) AS v FROM CitationTable" }
        { section: 9, name: "citations.citations_no_source",              impl: "Y", rec: "Y",
          desc: "Citations with no SourceID set (orphans)",
          query: "SELECT SUM(CASE WHEN SourceID = 0 OR SourceID IS NULL THEN 1 ELSE 0 END) AS v FROM CitationTable" }
        { section: 9, name: "citation_links.citation_links_total",        impl: "Y", rec: "Y",
          desc: "CitationLinkTable row count",
          query: "SELECT COUNT(*) AS v FROM CitationLinkTable" }
        { section: 9, name: "citation_links.citations_used",              impl: "Y", rec: "Y",
          desc: "Distinct CitationID referenced by any link",
          query: "SELECT COUNT(DISTINCT CitationID) AS v FROM CitationLinkTable" }
        { section: 9, name: "source_citation_coverage.sources_with_citations", impl: "Y", rec: "Y",
          desc: "Distinct SourceID with >=1 citation",
          query: "SELECT COUNT(DISTINCT SourceID) AS v FROM CitationTable WHERE SourceID > 0" }
        { section: 9, name: "source_template_counts.total",               impl: "Y", rec: "Y",
          desc: "SourceTemplateTable row count",
          query: "SELECT COUNT(*) AS v FROM SourceTemplateTable" }
        { section: 9, name: "source_template_counts.likely_custom",       impl: "Y", rec: "Y",
          desc: "Templates with TemplateID >= 200",
          query: "SELECT SUM(CASE WHEN TemplateID >= 200 THEN 1 ELSE 0 END) AS v FROM SourceTemplateTable" }
        { section: 9, name: "source_template_usage",                      impl: "Y", rec: "Y",
          desc: "Per-template usage table (id, source_count, custom, name, category)",
          multi_row: true,
          query: "SELECT template_id, source_count, likely_custom, template_name, category FROM (SELECT t.TemplateID AS template_id, (SELECT COUNT(*) FROM SourceTable s WHERE s.TemplateID = t.TemplateID) AS source_count, CASE WHEN t.TemplateID >= 200 THEN 1 ELSE 0 END AS likely_custom, t.Name AS template_name, COALESCE(t.Category, '') AS category FROM SourceTemplateTable t UNION ALL SELECT 0, (SELECT COUNT(*) FROM SourceTable WHERE TemplateID = 0), 0, '(free-form)', '') ORDER BY template_id" }
        { section: 9, name: "citation_links_by_owner_type",               impl: "Y", rec: "Y",
          desc: "CitationLinkTable.OwnerType histogram",
          multi_row: true,
          query: "SELECT OwnerType AS owner_type, COUNT(*) AS n FROM CitationLinkTable GROUP BY OwnerType ORDER BY n DESC" }
        { section: 9, name: "citations.citations_with_quality",           impl: "N", rec: "N",
          desc: "Citations with any Quality field set",
          query: null }
        { section: 9, name: "citations.citations_with_note",              impl: "N", rec: "N",
          desc: "Citations with non-empty CitationName",
          query: null }
        { section: 9, name: "template_categories",                        impl: "N", rec: "N",
          desc: "Template Category histogram (covered by usage table)",
          query: null }
        { section: 9, name: "sources.records_modified_by_year",   impl: "Y", rec: "N",
          desc: "SourceTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "SourceTable") }
        { section: 9, name: "sources.oldest_mod_date",            impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in SourceTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "SourceTable" "MIN") }
        { section: 9, name: "sources.most_recent_mod_date",       impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in SourceTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "SourceTable" "MAX") }
        { section: 9, name: "citations.records_modified_by_year", impl: "Y", rec: "N",
          desc: "CitationTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "CitationTable") }
        { section: 9, name: "citations.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in CitationTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "CitationTable" "MIN") }
        { section: 9, name: "citations.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in CitationTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "CitationTable" "MAX") }

        # ─── 10. Repositories & addresses ──────────────────────────────────
        { section: 10, name: "addresses.repositories",      impl: "Y", rec: "Y",
          desc: "AddressTable rows with AddressType = 1",
          query: "SELECT SUM(CASE WHEN AddressType = 1 THEN 1 ELSE 0 END) AS v FROM AddressTable" }
        { section: 10, name: "addresses.general_addresses", impl: "Y", rec: "Y",
          desc: "AddressTable rows with AddressType <> 1",
          query: "SELECT SUM(CASE WHEN AddressType <> 1 THEN 1 ELSE 0 END) AS v FROM AddressTable" }
        { section: 10, name: "addresses.repositories_used", impl: "N", rec: "N",
          desc: "Distinct RepositoryID referenced by sources",
          query: null }

        # ─── 11. Media ─────────────────────────────────────────────────────
        { section: 11, name: "media.media_items",           impl: "Y", rec: "Y",
          desc: "MultimediaTable row count",
          query: "SELECT COUNT(*) AS v FROM MultimediaTable" }
        { section: 11, name: "media.media_links",           impl: "Y", rec: "Y",
          desc: "MediaLinkTable row count",
          query: "SELECT COUNT(*) AS v FROM MediaLinkTable" }
        { section: 11, name: "media.media_used",            impl: "Y", rec: "Y",
          desc: "Distinct MediaID referenced by any link",
          query: "SELECT COUNT(DISTINCT MediaID) AS v FROM MediaLinkTable" }
        { section: 11, name: "media.media_by_type",         impl: "Y", rec: "N",
          desc: "Media file extension histogram (rightmost dot of MediaFile)",
          multi_row: true,
          query: "WITH RECURSIVE walk AS (SELECT MediaID, SUBSTR(MediaFile, INSTR(MediaFile, '.') + 1) AS rest FROM MultimediaTable WHERE MediaFile IS NOT NULL AND MediaFile <> '' AND INSTR(MediaFile, '.') > 0 UNION ALL SELECT MediaID, SUBSTR(rest, INSTR(rest, '.') + 1) FROM walk WHERE INSTR(rest, '.') > 0) SELECT LOWER(rest) AS ext, COUNT(*) AS n FROM walk WHERE INSTR(rest, '.') = 0 GROUP BY ext ORDER BY n DESC" }
        { section: 11, name: "media.media_with_caption",    impl: "Y", rec: "N",
          desc: "Media items with non-empty Caption",
          query: "SELECT SUM(CASE WHEN Caption IS NOT NULL AND Caption <> '' THEN 1 ELSE 0 END) AS v FROM MultimediaTable" }
        { section: 11, name: "media_links_by_owner_type",   impl: "Y", rec: "Y",
          desc: "MediaLinkTable.OwnerType histogram with labels",
          multi_row: true,
          query: "WITH codes(owner_type, label) AS (VALUES (0,'Person'),(1,'Family'),(2,'Event'),(3,'Source'),(4,'Citation'),(5,'Place'),(6,'Place (LDS temple)'),(7,'Task'),(8,'Name'),(9,'Association'),(14,'Place Detail')), hist AS (SELECT OwnerType AS owner_type, COUNT(*) AS n FROM MediaLinkTable GROUP BY OwnerType), all_keys AS (SELECT owner_type FROM codes UNION SELECT owner_type FROM hist) SELECT k.owner_type, COALESCE(c.label, 'unknown') AS label, COALESCE(h.n, 0) AS n FROM all_keys k LEFT JOIN codes c USING (owner_type) LEFT JOIN hist h USING (owner_type) ORDER BY k.owner_type" }
        { section: 11, name: "media.records_modified_by_year", impl: "Y", rec: "N",
          desc: "MultimediaTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "MultimediaTable") }
        { section: 11, name: "media.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in MultimediaTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "MultimediaTable" "MIN") }
        { section: 11, name: "media.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in MultimediaTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "MultimediaTable" "MAX") }

        # ─── 12. Tasks, groups, tags ───────────────────────────────────────
        { section: 12, name: "tasks.total",         impl: "Y", rec: "Y",
          desc: "TaskTable row count",
          query: "SELECT COUNT(*) AS v FROM TaskTable" }
        { section: 12, name: "tasks.task_folders",  impl: "Y", rec: "N",
          desc: "Distinct positive TaskType values (fuzzy)",
          query: "SELECT COUNT(DISTINCT CASE WHEN TaskType > 0 THEN TaskType END) AS v FROM TaskTable" }
        { section: 12, name: "task_links",          impl: "Y", rec: "N",
          desc: "TaskLinkTable row count",
          query: "SELECT COUNT(*) AS v FROM TaskLinkTable" }
        { section: 12, name: "groups",              impl: "Y", rec: "Y",
          desc: "Distinct GroupID values in GroupTable",
          query: "SELECT COUNT(DISTINCT GroupID) AS v FROM GroupTable" }
        { section: 12, name: "group_id_ranges",     impl: "Y", rec: "Y",
          desc: "GroupTable row count (each row = one ID range)",
          query: "SELECT COUNT(*) AS v FROM GroupTable" }
        { section: 12, name: "tags",                impl: "Y", rec: "N",
          desc: "TagTable row count",
          query: "SELECT COUNT(*) AS v FROM TagTable" }
        { section: 12, name: "tasks.records_modified_by_year", impl: "Y", rec: "N",
          desc: "TaskTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "TaskTable") }
        { section: 12, name: "tasks.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in TaskTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "TaskTable" "MIN") }
        { section: 12, name: "tasks.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in TaskTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "TaskTable" "MAX") }

        # ─── 13. Associations ──────────────────────────────────────────────
        { section: 13, name: "associations.total",                  impl: "Y", rec: "Y",
          desc: "FANTable row count",
          query: "SELECT COUNT(*) AS v FROM FANTable" }
        { section: 13, name: "associations.missing_person",         impl: "Y", rec: "Y",
          desc: "Associations with ID1 = 0 or ID2 = 0",
          query: "SELECT SUM(CASE WHEN ID1 = 0 OR ID2 = 0 THEN 1 ELSE 0 END) AS v FROM FANTable" }
        { section: 13, name: "association_types.total",             impl: "Y", rec: "Y",
          desc: "FANTypeTable row count (RMNOCASE-safe)",
          query: "SELECT COUNT(FANTypeID) AS v FROM FANTypeTable" }
        { section: 13, name: "association_type_usage",              impl: "Y", rec: "Y",
          desc: "Per-FANType usage table (id, name, count)",
          multi_row: true,
          query: "SELECT t.FANTypeID AS type_id, t.Name AS type_name, (SELECT COUNT(*) FROM FANTable f WHERE f.FanTypeID = t.FANTypeID) AS use_count FROM FANTypeTable t ORDER BY t.FANTypeID" }

        # ─── 14. External links ────────────────────────────────────────────
        { section: 14, name: "external_links.urls",                impl: "Y", rec: "Y",
          desc: "URLTable row count",
          query: "SELECT COUNT(*) AS v FROM URLTable" }
        { section: 14, name: "external_links.ancestry_links",      impl: "Y", rec: "Y",
          desc: "AncestryTable row count",
          query: "SELECT COUNT(*) AS v FROM AncestryTable" }
        { section: 14, name: "external_links.familysearch_links",  impl: "Y", rec: "Y",
          desc: "FamilySearchTable row count",
          query: "SELECT COUNT(*) AS v FROM FamilySearchTable" }
        { section: 14, name: "external_links.dna_records",         impl: "Y", rec: "Y",
          desc: "DNATable row count",
          query: "SELECT COUNT(*) AS v FROM DNATable" }
        { section: 14, name: "external_links.health_records",      impl: "Y", rec: "N",
          desc: "HealthTable row count",
          query: "SELECT COUNT(*) AS v FROM HealthTable" }
        { section: 14, name: "external_links.urls_by_owner_type",  impl: "Y", rec: "N",
          desc: "URLTable.OwnerType histogram with labels",
          multi_row: true,
          query: "WITH codes(owner_type, label) AS (VALUES (0,'Person'),(1,'Family'),(2,'Event'),(3,'Source'),(4,'Citation'),(5,'Place'),(6,'Place (LDS temple)'),(7,'Task'),(8,'Name'),(9,'Association'),(14,'Place Detail')), hist AS (SELECT OwnerType AS owner_type, COUNT(*) AS n FROM URLTable GROUP BY OwnerType), all_keys AS (SELECT owner_type FROM codes UNION SELECT owner_type FROM hist) SELECT k.owner_type, COALESCE(c.label, 'unknown') AS label, COALESCE(h.n, 0) AS n FROM all_keys k LEFT JOIN codes c USING (owner_type) LEFT JOIN hist h USING (owner_type) ORDER BY k.owner_type" }
        { section: 14, name: "external_links.records_modified_by_year", impl: "Y", rec: "N",
          desc: "URLTable rows grouped by mod-date year (normalized UTCModDate)",
          multi_row: true,
          query: (utc-by-year-for-table "URLTable") }
        { section: 14, name: "external_links.oldest_mod_date",          impl: "Y", rec: "N",
          desc: "Earliest normalized UTCModDate in URLTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "URLTable" "MIN") }
        { section: 14, name: "external_links.most_recent_mod_date",     impl: "Y", rec: "N",
          desc: "Latest normalized UTCModDate in URLTable (ISO 8601 UTC)",
          format: $FORMAT_ISO8601,
          query: (utc-agg-iso-for-table "URLTable" "MAX") }

        # ─── 15. Time-bucketed histograms ──────────────────────────────────
        { section: 15, name: "events_by_decade",         impl: "Y", rec: "Y",
          desc: "Events grouped by start-year decade (excludes empty/text dates)",
          multi_row: true,
          query: "WITH dated AS (SELECT CAST(SUBSTR(Date, 4, 4) AS INTEGER) AS yr FROM EventTable WHERE SUBSTR(Date, 1, 1) IN ('D','Q','R') AND SUBSTR(Date, 3, 1) IN ('+','-') AND SUBSTR(Date, 4, 4) GLOB '[0-9][0-9][0-9][0-9]') SELECT (yr / 10) * 10 AS decade, COUNT(*) AS event_count FROM dated WHERE yr > 0 GROUP BY decade ORDER BY decade" }
        { section: 15, name: "people_by_birth_decade",   impl: "Y", rec: "Y",
          desc: "People grouped by NameTable.BirthYear decade (primary names only)",
          multi_row: true,
          query: "SELECT (BirthYear / 10) * 10 AS decade, COUNT(DISTINCT OwnerID) AS people_count FROM NameTable WHERE IsPrimary = 1 AND BirthYear > 0 GROUP BY decade ORDER BY decade" }
        { section: 15, name: "deaths_by_decade",         impl: "Y", rec: "Y",
          desc: "People grouped by NameTable.DeathYear decade (primary names only)",
          multi_row: true,
          query: "SELECT (DeathYear / 10) * 10 AS decade, COUNT(DISTINCT OwnerID) AS people_count FROM NameTable WHERE IsPrimary = 1 AND DeathYear > 0 GROUP BY decade ORDER BY decade" }
        { section: 15, name: "marriages_by_decade",      impl: "N", rec: "N",
          desc: "Marriage events bucketed by decade (needs marriage FactTypeID)",
          query: null }
        { section: 15, name: "events_by_year",           impl: "N", rec: "N",
          desc: "Events bucketed by year (too noisy)",
          query: null }
        { section: 15, name: "events_by_century",        impl: "N", rec: "N",
          desc: "Events bucketed by century (too coarse)",
          query: null }
        { section: 15, name: "events_by_decade_by_type", impl: "N", rec: "N",
          desc: "Decade x EventType cross-tab (combinatorial blow-up)",
          query: null }

        # ─── 16. Activity & recency ────────────────────────────────────────
        { section: 16, name: "records_modified_30d",      impl: "Y", rec: "Y",
          desc: "Major-table records with normalized UTCModDate > now-30d",
          query: ("SELECT " + (utc-recent-sum 30) + " AS v") }
        { section: 16, name: "records_modified_365d",     impl: "Y", rec: "Y",
          desc: "Major-table records with normalized UTCModDate > now-365d",
          query: ("SELECT " + (utc-recent-sum 365) + " AS v") }
        { section: 16, name: "oldest_record_age_days",    impl: "Y", rec: "N",
          desc: "Days since earliest normalized UTCModDate across major tables",
          query: ("WITH per_table AS (" + (utc-agg-union "MIN") + "), normalized AS (SELECT " + $UTC_TO_JD + " AS jd FROM per_table WHERE UTCModDate IS NOT NULL) SELECT CAST(julianday('now') - MIN(jd) AS INTEGER) AS v FROM normalized") }
        { section: 16, name: "record_count_total_user_tables", impl: "N", rec: "N",
          desc: "Synthesizable downstream from per-table counts",
          query: null }
    ]

    # Auto-assign qno = "SS.NN" (section, position-within-section, both
    # zero-padded). Computed once per call so the catalog stays declarative.
    # Uses `for` (not `each`) — closures cannot mutate captured `mut` vars.
    mut counters = {}
    mut out = []
    for m in $raw {
        let key = ($m.section | into string)
        let pos = (($counters | get --optional $key | default 0) + 1)
        $counters = ($counters | upsert $key $pos)
        let ss = ($m.section | into string | fill --alignment right --character "0" --width 2)
        let nn = ($pos | into string | fill --alignment right --character "0" --width 2)
        $out = ($out | append ($m | upsert qno $"($ss).($nn)"))
    }
    $out
}

# Convenience filter: only metrics flagged for execution and with non-null SQL.
export def runnable [] {
    metrics-catalog | where impl == "Y" and query != null
}

# Convenience filter: scalar metrics only (no histograms / usage tables).
export def runnable-scalars [] {
    runnable | where {|m| not (($m | get --optional multi_row) | default false) }
}

# Convenience filter: multi-row metrics only.
export def runnable-multirow [] {
    runnable | where {|m| ($m | get --optional multi_row) | default false }
}
