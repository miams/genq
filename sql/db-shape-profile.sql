-- ============================================================================
-- db-shape-profile.sql — Standard "shape" report for any RootsMagic database.
--
-- Purpose: produce a customer-database fingerprint covering version metadata,
--          scalar counts (RM "Enhanced Properties" parity + extras), per-fact-
--          type usage, per-source-template usage, and time-bucketed counts.
--
-- Design notes
--   * Read-only — uses CTEs and SELECTs; no DDL, no temp tables in user DB.
--   * Six labelled result sets, each prefixed with `-- @section <name>`.
--   * Date-year extraction relies on the RM 24-char Date string positions:
--       D|Q|R<modifier><±><YYYY><MM><DD>...   (1-indexed positions 4..7 = YYYY)
--     Empty/text dates produce NULL years and are excluded from year buckets.
--   * Custom-vs-standard FactType: RM stores the user-defined flag in
--     `FactTypeTable.Flags`; bit 0x01 indicates "custom" in observed databases.
--     If that bit interpretation is wrong, swap the predicate in section 4.
--   * Custom-vs-standard SourceTemplate: RM ships with TemplateID < 200 as
--     built-ins in observed databases; user-defined templates use higher IDs.
--     Adjust the threshold in section 5 once verified against more DBs.
--   * Version metadata lives as XML in ConfigTable.DataRec (RecID=1). SQLite
--     has no XML parser, so we use INSTR/SUBSTR to lift named tags. Brittle
--     by design — if RM rotates the wrapper format, this section is the only
--     one that needs to change.
-- ============================================================================


-- @section version_metadata --------------------------------------------------
-- Single-row record of RM version + DB-level identifiers.
WITH cfg AS (
    SELECT CAST(DataRec AS TEXT) AS x
    FROM ConfigTable
    WHERE RecID = 1
),
xml_pick AS (
    SELECT
        x,
        INSTR(x, '<Version>')        AS p_ver,
        INSTR(x, '</Version>')       AS p_ver_e,
        INSTR(x, '<STVersion>')      AS p_st,
        INSTR(x, '</STVersion>')     AS p_st_e,
        INSTR(x, '<UniqueID>')       AS p_uid,
        INSTR(x, '</UniqueID>')      AS p_uid_e,
        INSTR(x, '<DefLang>')        AS p_lang,
        INSTR(x, '</DefLang>')       AS p_lang_e,
        INSTR(x, '<DateFormat>')     AS p_df,
        INSTR(x, '</DateFormat>')    AS p_df_e
    FROM cfg
)
SELECT
    (SELECT user_version FROM pragma_user_version)                          AS sqlite_user_version,
    (SELECT page_count   FROM pragma_page_count)                            AS sqlite_page_count,
    (SELECT page_size    FROM pragma_page_size)                             AS sqlite_page_size,
    (SELECT CAST(page_count AS INTEGER) * CAST(page_size AS INTEGER) / 1024 FROM pragma_page_count, pragma_page_size) AS db_size_kb,
    CASE WHEN p_ver  > 0 THEN SUBSTR(x, p_ver  + 9,  p_ver_e  - p_ver  - 9 ) END AS rm_version,
    CASE WHEN p_st   > 0 THEN SUBSTR(x, p_st   + 11, p_st_e   - p_st   - 11) END AS rm_st_version,
    CASE WHEN p_uid  > 0 THEN SUBSTR(x, p_uid  + 10, p_uid_e  - p_uid  - 10) END AS rm_unique_id,
    CASE WHEN p_lang > 0 THEN SUBSTR(x, p_lang + 9,  p_lang_e - p_lang - 9 ) END AS rm_default_language,
    CASE WHEN p_df   > 0 THEN SUBSTR(x, p_df   + 12, p_df_e   - p_df   - 12) END AS rm_date_format,
    (SELECT MAX(mx) FROM (
        SELECT MAX(UTCModDate) AS mx FROM PersonTable      UNION ALL
        SELECT MAX(UTCModDate) FROM EventTable             UNION ALL
        SELECT MAX(UTCModDate) FROM NameTable              UNION ALL
        SELECT MAX(UTCModDate) FROM SourceTable            UNION ALL
        SELECT MAX(UTCModDate) FROM CitationTable          UNION ALL
        SELECT MAX(UTCModDate) FROM PlaceTable             UNION ALL
        SELECT MAX(UTCModDate) FROM MultimediaTable        UNION ALL
        SELECT MAX(UTCModDate) FROM TaskTable
    ))                                                                      AS latest_utcmoddate_julian
FROM xml_pick;


-- @section people_counts ------------------------------------------------------
SELECT
    COUNT(*)                                              AS total,
    SUM(CASE WHEN Sex = 0       THEN 1 ELSE 0 END)        AS male,
    SUM(CASE WHEN Sex = 1       THEN 1 ELSE 0 END)        AS female,
    SUM(CASE WHEN Sex NOT IN (0,1) THEN 1 ELSE 0 END)     AS unknown_sex,
    SUM(CASE WHEN Living = 1    THEN 1 ELSE 0 END)        AS living,
    SUM(CASE WHEN IsPrivate = 1 THEN 1 ELSE 0 END)        AS private,
    SUM(CASE WHEN Bookmark = 1  THEN 1 ELSE 0 END)        AS bookmarked
FROM PersonTable;


-- @section name_counts --------------------------------------------------------
SELECT
    COUNT(*)                                              AS total,
    SUM(CASE WHEN IsPrimary = 1 THEN 1 ELSE 0 END)        AS primary_names,
    SUM(CASE WHEN IsPrimary = 0 THEN 1 ELSE 0 END)        AS alternate_names,
    SUM(CASE WHEN BirthYear > 0 THEN 1 ELSE 0 END)        AS with_birth_year,
    SUM(CASE WHEN DeathYear > 0 THEN 1 ELSE 0 END)        AS with_death_year
FROM NameTable;


-- @section family_counts ------------------------------------------------------
SELECT
    (SELECT COUNT(*)               FROM FamilyTable)                                       AS total,
    (SELECT SUM(CASE WHEN (FatherID = 0) <> (MotherID = 0) THEN 1 ELSE 0 END) FROM FamilyTable) AS one_parent,
    (SELECT SUM(CASE WHEN FatherID = 0 AND MotherID = 0    THEN 1 ELSE 0 END) FROM FamilyTable) AS no_parents,
    (SELECT COUNT(*)               FROM ChildTable)                                        AS child_links,
    (SELECT COUNT(DISTINCT FamilyID) FROM ChildTable)                                      AS with_children;


-- @section fact_type_counts ---------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM FactTypeTable)                                                   AS total,
    (SELECT SUM(CASE WHEN OwnerType = 0 THEN 1 ELSE 0 END) FROM FactTypeTable)             AS person_scoped,
    (SELECT SUM(CASE WHEN OwnerType = 1 THEN 1 ELSE 0 END) FROM FactTypeTable)             AS family_scoped,
    (SELECT SUM(CASE WHEN COALESCE(GedcomTag,'') = '' THEN 1 ELSE 0 END) FROM FactTypeTable) AS likely_custom,
    (SELECT COUNT(DISTINCT EventType) FROM EventTable)                                     AS used;


-- @section event_counts -------------------------------------------------------
SELECT
    COUNT(*)                                                                               AS total,
    SUM(CASE WHEN OwnerType = 0 THEN 1 ELSE 0 END)                                         AS person_events,
    SUM(CASE WHEN OwnerType = 1 THEN 1 ELSE 0 END)                                         AS family_events,
    SUM(CASE WHEN Date IS NOT NULL AND Date <> '' AND Date <> '.' THEN 1 ELSE 0 END)       AS with_date,
    SUM(CASE WHEN PlaceID > 0   THEN 1 ELSE 0 END)                                         AS with_place,
    SUM(CASE WHEN Proof = 1     THEN 1 ELSE 0 END)                                         AS proven,
    SUM(CASE WHEN Proof = 2     THEN 1 ELSE 0 END)                                         AS disproven,
    SUM(CASE WHEN Proof = 3     THEN 1 ELSE 0 END)                                         AS disputed,
    SUM(CASE WHEN IsPrivate = 1 THEN 1 ELSE 0 END)                                         AS private
FROM EventTable;


-- @section event_citation_coverage --------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT OwnerID) FROM CitationLinkTable WHERE OwnerType = 2)            AS events_with_citations,
    (SELECT COUNT(*)                FROM WitnessTable)                                     AS witnesses_total;


-- @section place_counts -------------------------------------------------------
SELECT
    SUM(CASE WHEN PlaceType = 0 THEN 1 ELSE 0 END)                                         AS places,
    SUM(CASE WHEN PlaceType = 1 THEN 1 ELSE 0 END)                                         AS temples,
    SUM(CASE WHEN PlaceType = 2 THEN 1 ELSE 0 END)                                         AS place_details,
    SUM(CASE WHEN Latitude <> 0 OR Longitude <> 0 THEN 1 ELSE 0 END)                       AS geocoded,
    SUM(CASE WHEN Latitude  = 0 AND Longitude = 0 THEN 1 ELSE 0 END)                       AS not_geocoded
FROM PlaceTable;


-- @section place_usage --------------------------------------------------------
SELECT
    (SELECT COUNT(*)                  FROM PlaceTable)                                     AS places_total,
    (SELECT COUNT(DISTINCT PlaceID)   FROM EventTable WHERE PlaceID > 0)                   AS places_used;


-- @section source_counts ------------------------------------------------------
SELECT
    COUNT(*)                                                                               AS total,
    SUM(CASE WHEN TemplateID = 0 THEN 1 ELSE 0 END)                                        AS freeform,
    SUM(CASE WHEN TemplateID > 0 THEN 1 ELSE 0 END)                                        AS template_based
FROM SourceTable;


-- @section citation_counts ----------------------------------------------------
-- Combining many RM-collated subqueries in one row trips the planner; split per-table.
SELECT
    COUNT(*)                                                                               AS citations_total,
    SUM(CASE WHEN SourceID = 0 OR SourceID IS NULL THEN 1 ELSE 0 END)                      AS citations_no_source
FROM CitationTable;


-- @section citation_link_counts -----------------------------------------------
SELECT
    (SELECT COUNT(*)                   FROM CitationLinkTable)                             AS citation_links_total,
    (SELECT COUNT(DISTINCT CitationID) FROM CitationLinkTable)                             AS citations_used;


-- @section source_citation_coverage -------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT SourceID) FROM CitationTable WHERE SourceID > 0)                AS sources_with_citations;


-- @section source_template_counts ---------------------------------------------
SELECT
    COUNT(*)                                                                               AS total,
    SUM(CASE WHEN TemplateID >= 200 THEN 1 ELSE 0 END)                                     AS likely_custom
FROM SourceTemplateTable;


-- @section repository_and_address_counts --------------------------------------
SELECT
    SUM(CASE WHEN AddressType = 1  THEN 1 ELSE 0 END)                                      AS repositories,
    SUM(CASE WHEN AddressType <> 1 THEN 1 ELSE 0 END)                                      AS general_addresses
FROM AddressTable;


-- @section media_counts -------------------------------------------------------
SELECT
    (SELECT COUNT(*)                FROM MultimediaTable)                                  AS media_items,
    (SELECT COUNT(*)                FROM MediaLinkTable)                                   AS media_links,
    (SELECT COUNT(DISTINCT MediaID) FROM MediaLinkTable)                                   AS media_used;


-- @section task_counts --------------------------------------------------------
SELECT
    COUNT(*)                                          AS total,
    COUNT(DISTINCT CASE WHEN TaskType > 0 THEN TaskType END) AS task_folders
FROM TaskTable;


-- @section task_link_counts ---------------------------------------------------
SELECT COUNT(*) AS task_links FROM TaskLinkTable;


-- @section group_tag_role_counts ----------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT GroupID) FROM GroupTable)                                       AS groups,
    (SELECT COUNT(*)                FROM GroupTable)                                       AS group_id_ranges,
    (SELECT COUNT(*)                FROM TagTable)                                         AS tags,
    (SELECT COUNT(*)                FROM RoleTable)                                        AS roles;


-- @section association_counts -------------------------------------------------
SELECT
    COUNT(*)                                              AS total,
    SUM(CASE WHEN ID1 = 0 OR ID2 = 0 THEN 1 ELSE 0 END)   AS missing_person
FROM FANTable;


-- @section association_type_counts --------------------------------------------
-- COUNT(FANTypeID) avoids the RMNOCASE-collated idxFANTypeName index path.
SELECT COUNT(FANTypeID) AS total FROM FANTypeTable;


-- @section external_link_counts -----------------------------------------------
SELECT
    (SELECT COUNT(*) FROM URLTable)             AS urls,
    (SELECT COUNT(*) FROM AncestryTable)        AS ancestry_links,
    (SELECT COUNT(*) FROM FamilySearchTable)    AS familysearch_links,
    (SELECT COUNT(*) FROM DNATable)             AS dna_records,
    (SELECT COUNT(*) FROM HealthTable)          AS health_records;


-- @section fact_type_usage ----------------------------------------------------
-- One row per fact type with its usage count. Names included so that custom
-- types are interpretable. Standard RM types are recognizable by GedcomTag
-- being non-empty; custom types typically have a blank GedcomTag.
SELECT
    f.FactTypeID                                                         AS fact_type_id,
    f.Name                                                               AS fact_type_name,
    CASE f.OwnerType WHEN 0 THEN 'person' WHEN 1 THEN 'family' ELSE 'other' END AS owner_kind,
    COALESCE(f.GedcomTag, '')                                            AS gedcom_tag,
    CASE WHEN COALESCE(f.GedcomTag, '') = '' THEN 1 ELSE 0 END           AS likely_custom,
    (SELECT COUNT(*) FROM EventTable e WHERE e.EventType = f.FactTypeID) AS use_count
FROM FactTypeTable f
ORDER BY use_count DESC, f.Name COLLATE NOCASE;


-- @section source_template_usage ---------------------------------------------
-- One row per source template with the count of sources referencing it.
-- TemplateID = 0 is the synthetic "free-form" template (no actual row).
SELECT
    t.TemplateID                                                              AS template_id,
    t.Name                                                                    AS template_name,
    COALESCE(t.Category, '')                                                  AS category,
    CASE WHEN t.TemplateID >= 200 THEN 1 ELSE 0 END                           AS likely_custom,
    (SELECT COUNT(*) FROM SourceTable s WHERE s.TemplateID = t.TemplateID)    AS source_count
FROM SourceTemplateTable t
UNION ALL
SELECT 0, '(free-form)', '', 0,
       (SELECT COUNT(*) FROM SourceTable WHERE TemplateID = 0)
ORDER BY source_count DESC, template_name COLLATE NOCASE;


-- @section events_by_decade ---------------------------------------------------
-- Histogram of events keyed off the start-year encoded in the RM Date string.
-- Excludes empty/text dates (which carry no parseable year).
WITH dated AS (
    SELECT
        CAST(SUBSTR(Date, 4, 4) AS INTEGER) AS yr
    FROM EventTable
    WHERE SUBSTR(Date, 1, 1) IN ('D','Q','R')
      AND SUBSTR(Date, 3, 1) IN ('+','-')
      AND SUBSTR(Date, 4, 4) GLOB '[0-9][0-9][0-9][0-9]'
)
SELECT
    (yr / 10) * 10 AS decade,
    COUNT(*)       AS event_count
FROM dated
WHERE yr > 0
GROUP BY decade
ORDER BY decade;


-- @section people_by_birth_decade ---------------------------------------------
-- Uses NameTable.BirthYear (RM auto-populates this from the primary Birth event).
SELECT
    (BirthYear / 10) * 10 AS decade,
    COUNT(DISTINCT OwnerID) AS people_count
FROM NameTable
WHERE IsPrimary = 1 AND BirthYear > 0
GROUP BY decade
ORDER BY decade;
