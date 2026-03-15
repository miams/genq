# GenQuery Improvement Ideas

Based on a thorough code review of all modules in `src/`. Ranked by impact on functionality and usability.

---

## 1. `genq list people` — Replace 7 DB Opens + Persistent Tables with a Single CTE (Safety + Performance)

**Files:** `src/lib/common/genq list people/mod.nu`

**Problem:** The command opens the database 7 separate times and creates two persistent tables (`tmpNames`, `tmpFullNames`) using `CREATE TABLE` (not `CREATE TEMP TABLE`). This means a "read-only" tool is actually writing to and modifying your `.rmtree` genealogy file on every run. If the process is interrupted mid-run, orphaned tables accumulate in your database.

**Fix:** Replace all 7 DB calls with a single SQL CTE:
```sql
WITH PrimaryNames AS (
    SELECT OwnerID, Given, Surname, BirthYear, DeathYear
    FROM NameTable WHERE IsPrimary=1
)
SELECT p.PersonID AS RIN, n.Given, n.Surname,
    CASE WHEN p.Sex = 1 THEN 'F' ELSE 'M' END AS Sex,
    n.BirthYear, n.DeathYear
FROM PrimaryNames n
INNER JOIN PersonTable p ON n.OwnerID = p.PersonID
```
One `open $env.rmdb | query db $sql` call, zero writes.

---

## 2. `genq list sources --all` — Implement Template-Based Sources

**Files:** `src/lib/common/genq list sources/mod.nu`

**Problem:** The `--all` flag currently prints "The ability to print all sources is pending." and returns an empty table. Template-based sources (Evidence Explained templates with `TemplateID != 0`) are heavily used by RootsMagic researchers and are completely inaccessible via genq.

**Fix:** Implement the `--all` branch to query `SourceTable` without the `WHERE TemplateID = 0` filter, then join with `SourceTemplateTable` to retrieve the template name. The XML field structure for templated sources differs from freeform, so these need separate (simpler) handling.

---

## 3. `genq census` — Eliminate Copy-Pasted SQL by Extracting a Helper

**Files:** `src/lib/ext/miams/genq census/mod.nu`

**Problem:** The exact same 4 SQL VIEW creation statements (`tmp_census_attached_minimal`, `tmp_census_prime_minimal`, `tmp_census_minimal`) are copy-pasted verbatim in both the `"rin"` branch (lines 29–56) and the `"year"` branch (lines 87–113). Any bug fix or schema change must be applied twice. Additionally, the views are never dropped after the query, accumulating in the database permanently.

**Fix:** Extract the view creation into a private helper `def build-census-views []`, call it once before the `match` block, and add cleanup (`DROP VIEW IF EXISTS`) at the end of each branch.

---

## 4. `rmdate` Performance — Add a Batch Mode to Fix 50x Slowdown

**Files:** `src/lib/common/rmdate/mod.nu`, `src/lib/common/genq list events/mod.nu`

**Problem:** `genq list events --ParseDate` is documented as "50x slower" because `rmdate` is called row-by-row via a closure in `insert MoreColumns {|row| rmdate $row.FullDate}`. For a database with thousands of events, this makes the command impractically slow.

**Fix:** Two options in priority order:
1. Pull as much date parsing as possible into SQL (`SUBSTR(Date, 1, 1)` for DateType, `SUBSTR(Date, 3, 3)` for era, etc.) and do final formatting in a single Nushell pass.
2. Add a `--batch` variant that processes all dates in a single vectorized operation rather than per-row closure calls.

---

## 5. `genq list events --citations` — Implement or Remove the Dead Flag

**Files:** `src/lib/common/genq list events/mod.nu`

**Problem:** The `--citations(-c)` flag is declared in the function signature (`# Include citations`) but there is zero code that uses `$citations`. Users who discover this flag and try it will get the same output as without it, with no warning or error.

**Fix:** Either implement it (join `CitationTable` on `EventID` and include citation count or citation details as additional columns), or remove the flag definition until it's ready.

---

## 6. `genq md people` — Add Bulk/Batch Export Capability

**Files:** `src/lib/common/genq md people/mod.nu`

**Problem:** The command exports exactly one person's markdown file per invocation. The `--gens` flag only follows ancestors/descendants of that one person. For a genealogy tool, the primary use case is exporting a surname group, all ancestors of a starting person, or the entire database to Obsidian.

**Fix:** Add flags and argument modes:
- `genq md people --surname Iams` — export all people with that surname
- `genq md people --all` — export everyone in the database
- `genq md people 1575 --gens 3` already works for one person; extend to generate files for all people encountered during the traversal, not just the focal person.

Also: the WikiLink format is inconsistent — `[[$fname|Given Surname]]` in one place vs `[[Person - Given Surname (RINxxx)]]` in another. This should be standardized.

---

## 7. `genq list media` — Fix Literal Quotes Embedded in `fullpath` Values

**Files:** `src/lib/common/genq list media/mod.nu:22`

**Problem:** The fullpath is constructed as `$"\"($full_media_path)\""`, which wraps the path in literal double-quote characters. The `fullpath` column contains strings like `"/Users/name/Pictures/photo.jpg"` with quotes as part of the string value, not as string delimiters. This breaks any downstream use of the path (e.g., `open ($row.fullpath)` would fail).

**Fix:** Remove the escaped quotes: `let full_media_path = ($filepath | path join $media_subpath $row.MediaFile)` — no wrapping quotes needed.

---

## 8. `genq list sources` — Add Per-Row Error Handling for XML Parsing

**Files:** `src/lib/common/genq list sources/mod.nu:18-21`

**Problem:** The Footnote, ShortFootnote, and Bibliography fields are extracted using hardcoded positional XML path traversals (`get content.0.content.0.content.1.content.content`). If any source row has malformed XML, a missing field, or a different structure, the entire command fails for all sources. There's no per-row isolation.

**Fix:** Wrap each `insert` closure in a `try { ... } catch { "" }` so a single bad source produces an empty string rather than crashing the command. Also consider a helper function to encapsulate the XML path extraction with a fallback.

---

## 9. `genq list polars events` — Finish It or Remove It

**Files:** `src/lib/common/genq list polars events/mod.nu`

**Problem:** This module:
- Has a stray debug line on line 14 (`help modules --find rmdate | get commands | flatten | flatten`) that would produce unexpected output.
- Has all actual query/transform logic commented out.
- Is not exported from `src/lib/common/mod.nu`, making it unreachable dead code.

The module was clearly an experiment to use Polars for faster date processing (to fix the `rmdate` 50x slowdown from idea #4), but was abandoned mid-implementation.

**Fix:** Either complete the Polars-based approach and export it from `common/mod.nu`, or delete the file to reduce confusion and clutter.

---

## 10. Add Filtering Options to `genq list people`

**Files:** `src/lib/common/genq list people/mod.nu`

**Problem:** `genq list people` returns every person in the database with no filtering. Users must pipe to `where` manually after the fact, which means the full dataset is always loaded even when only a subset is needed. For databases with thousands of people, this is unnecessarily slow.

**Fix:** Add optional filter flags so SQL-side filtering reduces the result set before it reaches Nushell:
```nu
genq list people --surname Iams         # WHERE Surname LIKE 'Iams'
genq list people --born-after 1800      # WHERE BirthYear >= 1800
genq list people --born-before 1900     # WHERE BirthYear <= 1900
genq list people --rin 1575             # WHERE PersonID = 1575
```
These flags translate directly into SQL `WHERE` clauses, keeping the query efficient.

---

## Bonus: Hardcoded Username in `persistence.nu`

**Files:** `src/lib/common/genq config/persistence.nu:38,44`

The fallback production database path is hardcoded as `"./data/Iiams.rmtree"`. This is a personal surname-specific path that should not be in shared code. The fallback should be a generic placeholder like `"./data/production.rmtree"` or derived from the user's config.
