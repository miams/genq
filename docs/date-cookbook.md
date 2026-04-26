# GenQuery Date Cookbook

A practical guide to filtering, extracting, and reasoning about dates in your RootsMagic database. RootsMagic stores dates in a 24-character fixed-width format that encodes much more than "year, month, day" — it encodes **how confident you are** in the date, **whether it's a range**, **what era it belongs to**, and more. This cookbook shows how to get at every dimension.

> **How to read the examples**  
> The `|` symbol is a *pipe* — it passes the output of one step into the next.  
> `--flag` options modify what a command returns. Run any command with `--help` to see all options.

> **Vocabulary status**: every modifier code, qualifier code, and combination in this document has been verified against RootsMagic 11 by entering 30 test dates into the `Iiams.rmtree` database and inspecting the raw `EventTable.Date` column. Display vocabulary (lowercase `bef`, `abt`, `lkly`, etc.) matches what RM 11 emits in its events list.

---

## Contents

1. [Why Dates Are Complicated](#1-why-dates-are-complicated)
2. [The Three Layers](#2-the-three-layers)
3. [Layer 1 — Atomic Accessors](#3-layer-1--atomic-accessors)
4. [Layer 2 — The Cumulative Record](#4-layer-2--the-cumulative-record)
5. [Layer 3 — Composite Predicates](#5-layer-3--composite-predicates)
6. [Filtering by Date Type](#6-filtering-by-date-type)
7. [Filtering by Modifier](#7-filtering-by-modifier)
8. [Filtering by Qualifier](#8-filtering-by-qualifier)
9. [Filtering by Precision](#9-filtering-by-precision)
10. [Filtering by Era and Double Dates](#10-filtering-by-era-and-double-dates)
11. [Range Dates](#11-range-dates)
12. [Verified Format Reference](#12-verified-format-reference)
13. [Edge Cases & Known Quirks](#13-edge-cases--known-quirks)
14. [Common Workflows](#14-common-workflows)

---

## 1. Why Dates Are Complicated

A genealogist might write the same fact in many ways:

| What you wrote in RootsMagic | What RM stores in the DB | What it means |
|---|---|---|
| `13 Feb 1791` | `D.+17910213..+00000000..` | Standard date, day-precision |
| `Feb 1791` | `D.+17910200..+00000000..` | Month-precision (no day) |
| `1791` | `D.+17910000..+00000000..` | Year-precision |
| `Abt 1791` | `D.+17910000.A+00000000..` | Year-precision, "About" qualifier |
| `Bef 1791` | `DB+17910000..+00000000..` | Modifier "Before" |
| `Bet 1871 and 1872` | `DR+18710000..+18720000..` | Range, Bet/And |
| `1947–1952` | `D-+19470000..+19520000..` | Range, dash style |
| `From Aug 1947 to Apr 1952` | `DS+19470800..+19520400..` | Range, From/To |
| `Spring 1791` | `TSpring 1791` | Free-text date |

A useful filter lets you ask any of these questions independently:

- "Show me everyone whose birth date has only year-precision."
- "Show me every fact whose date is `abt`, `ca`, or `est` — i.e., approximated."
- "Show me events stored as ranges (Bet/And, From/To, dash, Or)."
- "Show me events with BC dates."
- "Show me text dates so I can clean them up."

Without structured access to each *dimension*, these questions become string-mangling exercises against the raw 24-character format. The layered API below makes each dimension queryable.

### RM's official vocabulary

RootsMagic distinguishes two semantic categories at Position 13:

- **Date qualifiers** — *factual approximations*: about, circa, estimated, calculated, say
- **Qualitative modifiers** — *confidence levels*: certainly, probably, possibly, likely, apparently, perhaps, maybe

Both occupy the same byte slot but mean different things. Layer 3 composite predicates split them.

---

## 2. The Three Layers

GenQuery's date API has three layers, each useful for different jobs:

| Layer | Use when | Cost |
|---|---|---|
| **Atomic** — `rmdate type`, `rmdate year`, etc. | You want one specific attribute, and you don't want to think about the rest | One small parse per call |
| **Cumulative** — `rmdate parse-full` returning a structured record | You want several attributes at once, or want to inspect everything | One full parse, then field access |
| **Composite** — `rmdate is-uncertain`, `rmdate is-partial` | You want a semantic answer like "is this an iffy date?" | Built on top of Layer 2 |

You'll almost always start with Layer 1. Drop to Layer 2 when you need multiple attributes from the same row. Reach for Layer 3 when an English phrase ("approximate", "uncertain", "partial") names what you want.

---

## 3. Layer 1 — Atomic Accessors

Each accessor takes one raw RootsMagic date string and returns one value. Designed to drop into `where` clauses.

> **Pattern: process raw, display human-readable.** The raw 24-character `FullDate` is for *processing*, not for *reading*. By default, `genq list events` and `genq list people` only expose the formatted `EventDate` / `BirthDate` / `DeathDate` columns. When you need the raw form for a `where` or `insert`, opt in with `--full-date` — that adds a `FullDate` column (or `BirthFullDate` / `DeathFullDate` on `people`). Once you're done filtering and computing, shape the final view with `select` / `reject` / `move` to drop `FullDate` and put the human-readable columns in the order you want. The cookbook examples below use `--full-date` for processing; in the examples that show a final view, the cleanup pipe at the end keeps the display tidy.

### Accessors

| Accessor | Returns | Possible values |
|---|---|---|
| `rmdate type` | `string` | `Standard` \| `Quaker` \| `Text` \| `Empty` |
| `rmdate modifier` | `string` | `None` \| `Bef` \| `Aft` \| `By` \| `To` \| `From` \| `Since` \| `Until` \| `Range` |
| `rmdate range-style` | `string \| null` | `BetAnd` \| `FromTo` \| `Dash` \| `Or` (only when `modifier == "Range"`, else `null`) |
| `rmdate qualifier` | `string` | `""` \| `Maybe` \| `Prhps` \| `Appar` \| `Lkly` \| `Poss` \| `Prob` \| `Cert` \| `Abt` \| `Ca` \| `Est` \| `Calc` \| `Say` |
| `rmdate era` | `string` | `AD` \| `BC` |
| `rmdate year` | `int \| null` | 4-digit year, or `null` if year not specified |
| `rmdate month` | `int \| null` | 1–12, or `null` |
| `rmdate day` | `int \| null` | 1–31, or `null` |
| `rmdate precision` | `string` | `day` \| `month` \| `year` \| `none` |
| `rmdate is-double-dated` | `bool` | `true` if Position 12 or 23 = `/` |

> **Note on enum values**: accessor return values use **title-case** (e.g., `"Bef"`, `"Abt"`) so they're stable string identifiers. The display strings emitted by `format-rm-date` use **lowercase** (e.g., `"bef 1791"`) to match RM 11's events-list display.

### Examples

**All Birth events that are year-precision only**
```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| (rmdate precision $r.FullDate) == "year" }
```

**Find every event with an "About" qualifier**
```nu
genq list events --full-date
| where { |r| (rmdate qualifier $r.FullDate) == "Abt" }
| select RIN Given Surname Event EventDate
```

**Just the BC dates**
```nu
genq list events --full-date
| where { |r| (rmdate era $r.FullDate) == "BC" }
```

**Every event whose date is a range, regardless of which range style**
```nu
genq list events --full-date
| where { |r| (rmdate modifier $r.FullDate) == "Range" }
```

**Only the "Bet 1871 and 1872" style ranges**
```nu
genq list events --full-date
| where { |r| (rmdate range-style $r.FullDate) == "BetAnd" }
```

**Free-text dates that need cleanup**
```nu
genq list events --full-date
| where { |r| (rmdate type $r.FullDate) == "Text" }
| select RIN Given Surname Event EventDate
```

---

## 4. Layer 2 — The Cumulative Record

When you need several attributes at once, parse the date once and read fields off the result.

### Shape of `rmdate parse-full` output

```nu
{
    DateType: "Standard"         # Standard | Quaker | Text | Empty
    Modifier: "Range"            # None | Bef | Aft | By | To | From | Since | Until | Range
    RangeStyle: "BetAnd"         # BetAnd | FromTo | Dash | Or | null
    IsRanged: true               # convenience: Modifier == "Range"
    IsDoubleDated: false         # Position 12 OR Position 23 == "/"

    Start: {
        Era: "AD"                # AD | BC
        Year: 1871               # int | null
        Month: null              # 1-12 | null
        Day: null                # 1-31 | null
        Precision: "year"        # day | month | year | none
        Qualifier: ""            # "" | Maybe | Prhps | Appar | Lkly | Poss | Prob | Cert | Abt | Ca | Est | Calc | Say
        IsDoubleDated: false
    }

    End: { ... same shape as Start ... } | null   # null when not a range

    FormattedDate: "bet 1871 and 1872"
    SortableDate: "1871-01-01"
    Raw: "DR+18710000..+18720000.."
}
```

### Examples

**Inspect one date completely**
```nu
rmdate parse-full "DR+18710000..+18720000.."
# → {DateType: Standard, Modifier: Range, RangeStyle: BetAnd, ...}
```

**Filter on multiple attributes at once**
```nu
genq list events --full-date
| insert ParsedDate { |r| rmdate parse-full $r.FullDate }
| where { |r| $r.ParsedDate.DateType == "Standard"
              and $r.ParsedDate.Start.Precision == "year"
              and $r.ParsedDate.Start.Qualifier == "Abt" }
```

**Show the start year of every range**
```nu
genq list events --full-date
| where { |r| (rmdate modifier $r.FullDate) == "Range" }
| insert RangeStart { |r| (rmdate parse-full $r.FullDate).Start.Year }
| insert RangeEnd   { |r| (rmdate parse-full $r.FullDate).End.Year }
| select RIN Given Surname Event RangeStart RangeEnd
```

**Find ranges that span more than 5 years**
```nu
genq list events --full-date
| where { |r| (rmdate modifier $r.FullDate) == "Range" }
| insert Span { |r|
    let p = rmdate parse-full $r.FullDate
    if ($p.Start.Year != null) and ($p.End.Year != null) {
        $p.End.Year - $p.Start.Year
    } else { null }
}
| where Span != null and Span > 5
| select RIN Given Surname Event EventDate Span
```

---

## 5. Layer 3 — Composite Predicates

Names for common semantic questions. Built on top of Layer 2 but cheap to call.

### Predicates

| Predicate | True when |
|---|---|
| `rmdate is-approximated` | Qualifier is one of: `Abt`, `Ca`, `Est`, `Calc`, `Say` (RM's "date qualifiers" — factual approximations) |
| `rmdate is-low-confidence` | Qualifier is one of: `Maybe`, `Prhps`, `Appar`, `Lkly`, `Poss`, `Prob` (RM's "qualitative modifiers" — confidence levels below "Certainly") |
| `rmdate is-uncertain` | `is-approximated` OR `is-low-confidence` |
| `rmdate is-certain` | Qualifier is `""` or `Cert` |
| `rmdate is-partial` | Precision is not `day` (year and/or month and/or day missing) |
| `rmdate is-ranged` | Modifier is `Range` |
| `rmdate is-directional` | Modifier is one of: `Bef`, `Aft`, `By`, `To`, `From`, `Since`, `Until` |
| `rmdate is-bce` | Either segment has Era `BC` |
| `rmdate is-double-dated` | Either segment has Position 12 or 23 = `/` |
| `rmdate is-text` | DateType is `Text` |
| `rmdate is-empty` | DateType is `Empty` |
| `rmdate before YEAR` | Has a year and that year is < `YEAR` |
| `rmdate after YEAR` | Has a year and that year is > `YEAR` |
| `rmdate between Y1 Y2` | Has a year `Y` where `Y1 <= Y <= Y2` |

### Examples

**Every approximated date in the database**
```nu
genq list events --full-date
| where { |r| rmdate is-approximated $r.FullDate }
| select RIN Given Surname Event EventDate
```

**Every low-confidence date (the ones flagged with `Maybe`, `Lkly`, `Poss`, etc.)**
```nu
genq list events --full-date
| where { |r| rmdate is-low-confidence $r.FullDate }
| select RIN Given Surname Event EventDate
```

**Partial dates (not full day-precision) — research targets**
```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| rmdate is-partial $r.FullDate }
| select RIN Given Surname EventDate
```

**Find directional dates ("Before 1900", "After 1850", etc.)**
```nu
genq list events --full-date
| where { |r| rmdate is-directional $r.FullDate }
| select RIN Given Surname Event EventDate
```

**All events involving BC dates**
```nu
genq list events --full-date
| where { |r| rmdate is-bce $r.FullDate }
```

**Combine: events that are both uncertain AND partial**
```nu
genq list events --full-date
| where { |r| (rmdate is-uncertain $r.FullDate) and (rmdate is-partial $r.FullDate) }
```

**Births before 1850**
```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| rmdate before $r.FullDate 1850 }
```

---

## 6. Filtering by Date Type

Position 1 of the format (`D` / `Q` / `T` / `.`) determines what kind of date this is.

### List every text date so you can audit them
```nu
genq list events --full-date
| where { |r| (rmdate type $r.FullDate) == "Text" }
| select RIN Given Surname Event EventDate
```

### Quaker dates
```nu
genq list events --full-date
| where { |r| (rmdate type $r.FullDate) == "Quaker" }
```

### Events with no date entered at all
```nu
genq list events --full-date
| where { |r| (rmdate type $r.FullDate) == "Empty" }
| select RIN Given Surname Event
```

### Histogram: how many of each type do I have?
```nu
genq list events --full-date
| insert DateTypeCol { |r| rmdate type $r.FullDate }
| histogram DateTypeCol
```

---

## 7. Filtering by Modifier

Position 2 of the format. The modifier tells you the *direction* or *shape* of the date.

### Modifier values and how they display

| Accessor value | Display in `format-rm-date` | Meaning |
|---|---|---|
| `None` | (nothing prepended) | Plain date |
| `Bef` | `bef <date>` | Before |
| `Aft` | `aft <date>` | After |
| `By` | `by <date>` | By |
| `To` | `to <date>` | To |
| `From` | `from <date>` | From |
| `Since` | `since <date>` | Since |
| `Until` | `until <date>` | Until |
| `Range` (with `RangeStyle == "BetAnd"`) | `bet <date> and <date>` | Between/And |
| `Range` (with `RangeStyle == "FromTo"`) | `from <date> to <date>` | From/To |
| `Range` (with `RangeStyle == "Dash"`) | `<date> – <date>` | En-dash range |
| `Range` (with `RangeStyle == "Or"`) | `<date> or <date>` | Either-or |

### Find every "Before" date
```nu
genq list events --full-date
| where { |r| (rmdate modifier $r.FullDate) == "Bef" }
```

### Find dates that are not plain — i.e., have any modifier set
```nu
genq list events --full-date
| where { |r| (rmdate modifier $r.FullDate) != "None" }
```

### Histogram of modifiers
```nu
genq list events --full-date
| insert Mod { |r| rmdate modifier $r.FullDate }
| histogram Mod
```

---

## 8. Filtering by Qualifier

Position 13 of the format. The qualifier tells you *how confident* you are in the date itself, OR (separately) that the date is a known approximation.

### Qualifier values

| Accessor value | Display | Category | Meaning |
|---|---|---|---|
| `""` | (nothing prepended) | — | No qualifier — confident |
| `Cert` | `cert <date>` | qualitative | Certainly |
| `Prob` | `prob <date>` | qualitative | Probably |
| `Poss` | `poss <date>` | qualitative | Possibly |
| `Lkly` | `lkly <date>` | qualitative | Likely |
| `Appar` | `appar <date>` | qualitative | Apparently |
| `Prhps` | `prhps <date>` | qualitative | Perhaps |
| `Maybe` | `maybe <date>` | qualitative | Maybe |
| `Abt` | `abt <date>` | factual | About |
| `Ca` | `ca <date>` | factual | Circa |
| `Est` | `est <date>` | factual | Estimated |
| `Calc` | `calc <date>` | factual | Calculated |
| `Say` | `say <date>` | factual | Say |

### List every "Estimated" date
```nu
genq list events --full-date
| where { |r| (rmdate qualifier $r.FullDate) == "Est" }
| select RIN Given Surname Event EventDate
```

### All factual approximations (RM's "date qualifiers")
```nu
genq list events --full-date
| where { |r| rmdate is-approximated $r.FullDate }
```

### All confidence flags below "Certainly" (RM's "qualitative modifiers")
```nu
genq list events --full-date
| where { |r| rmdate is-low-confidence $r.FullDate }
```

### Histogram of qualifiers across the whole database
```nu
genq list events --full-date
| insert Qual { |r| rmdate qualifier $r.FullDate }
| where Qual != ""
| histogram Qual
```

---

## 9. Filtering by Precision

Precision is *derived*, not stored directly — but it's one of the most useful filters.

| Value | Means |
|---|---|
| `day` | Year, month, AND day all set |
| `month` | Year and month set; day is `00` |
| `year` | Year set; month and day are `00` |
| `none` | Year is `0000` (e.g., "Jan", "1 Jan", "1 ??? 1900") |

### Every Birth that has only year-level precision
```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| (rmdate precision $r.FullDate) == "year" }
```

### Every event with full day-month-year precision
```nu
genq list events --full-date
| where { |r| (rmdate precision $r.FullDate) == "day" }
```

### Histogram: how precise is my data overall?
```nu
genq list events --full-date
| insert Prec { |r| rmdate precision $r.FullDate }
| histogram Prec
```

### Identify weak Birth dates (no day) for research targeting
```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| (rmdate precision $r.FullDate) in [year month none] }
| select RIN Given Surname EventDate
| sort-by Surname Given
```

---

## 10. Filtering by Era and Double Dates

### BC dates

```nu
genq list events --full-date
| where { |r| (rmdate era $r.FullDate) == "BC" }
```

### Double-dated entries (Julian/Gregorian transitions like 1583/84)

These appear when an event spans the calendar transition. Common for colonial American records pre-1752.

```nu
genq list events --full-date
| where { |r| rmdate is-double-dated $r.FullDate }
| select RIN Given Surname Event EventDate
```

---

## 11. Range Dates

Range dates have *two* date segments. Layer 2's cumulative record exposes both as `Start` and `End`.

### List every "Bet/And" range
```nu
genq list events --full-date
| where { |r| (rmdate range-style $r.FullDate) == "BetAnd" }
```

### Show start and end years of every range
```nu
genq list events --full-date
| where { |r| rmdate is-ranged $r.FullDate }
| insert P { |r| rmdate parse-full $r.FullDate }
| insert StartYear { |r| $r.P.Start.Year }
| insert EndYear   { |r| $r.P.End.Year }
| select RIN Given Surname Event StartYear EndYear
| reject P
```

### Find ranges that span many years (potential data-entry sloppiness)
```nu
genq list events --full-date
| where { |r| rmdate is-ranged $r.FullDate }
| insert P { |r| rmdate parse-full $r.FullDate }
| insert Span { |r|
    if ($r.P.Start.Year != null) and ($r.P.End.Year != null) {
        $r.P.End.Year - $r.P.Start.Year
    } else { null }
}
| where Span != null and Span >= 10
| select RIN Given Surname Event EventDate Span
```

### Distribution of range styles
```nu
genq list events --full-date
| where { |r| rmdate is-ranged $r.FullDate }
| insert Style { |r| rmdate range-style $r.FullDate }
| histogram Style
```

### Bet/And vs From/To — different semantic meaning

- `BetAnd` — "the event happened *somewhere* between these two dates" (single point in time, uncertain)
- `FromTo` — "the event spanned this entire period" (durative, e.g., an occupation, a residence)
- `Dash` — display-only range, semantically vague
- `Or` — "this event happened on one of these two dates"

If you're using ranges for date arithmetic, knowing which style you have matters.

---

## 12. Verified Format Reference

The 24-character RM 11 date format, verified against RootsMagic 11 by entering 30 test dates and inspecting the raw `EventTable.Date` column. Display strings are what RM emits in the events list (lowercase abbreviations).

### Position 1 — Date Type

| Code | Type | Display | Notes |
|---|---|---|---|
| `.` | Empty | (empty string) | Single character `.` only |
| `D` | Standard | varies | Most common |
| `R` | Standard | varies | Year-only double-dated variant — RM emits `R` instead of `D` when precision is year-only AND the date spans the Julian/Gregorian transition (e.g. `1719/20`). Month- and day-precision double dates use `D`. From the parser's perspective, `R` is just `Standard` with the Position-12 `/` marker — accessors and predicates treat them identically. |
| `Q` | Quaker | varies | Quaker calendar |
| `T` | Text | (free text after `T`) | Variable length |

### Position 2 — Modifier

| Code | Modifier | Display | Verified |
|---|---|---|---|
| `.` | None | (none) | ✅ |
| `B` | Bef | `bef <date>` | ✅ |
| `A` | Aft | `aft <date>` | ✅ |
| `Y` | By | `by <date>` | ✅ |
| `T` | To | `to <date>` | ✅ |
| `F` | From | `from <date>` | ✅ |
| `I` | Since | `since <date>` | ✅ |
| `U` | Until | `until <date>` | ✅ |
| `R` | Range (BetAnd) | `bet <date> and <date>` | ✅ |
| `S` | Range (FromTo) | `from <date> to <date>` | ✅ |
| `-` | Range (Dash) | `<date> – <date>` | ✅ |
| `O` | Range (Or) | `<date> or <date>` | ✅ |

### Position 3 — First Date Era

| Code | Era |
|---|---|
| `+` | AD |
| `-` | BC |

### Positions 4-7 — First Date Year (`yyyy` or `0000`)
### Positions 8-9 — First Date Month (`01`-`12` or `00`)
### Positions 10-11 — First Date Day (`01`-`31` or `00`)

### Position 12 — First Date Double-Date Indicator

| Code | Meaning |
|---|---|
| `.` | Not a double date |
| `/` | Double date (e.g., 1583/84 across Julian/Gregorian transition) |

### Position 13 — First Date Qualifier

| Code | Qualifier | Display | Category | Verified |
|---|---|---|---|---|
| `.` | (none) | — | — | ✅ |
| `?` | Maybe | `maybe <date>` | qualitative | ✅ |
| `1` | Prhps | `prhps <date>` | qualitative | ✅ |
| `2` | Appar | `appar <date>` | qualitative | ✅ |
| `3` | Lkly | `lkly <date>` | qualitative | ✅ |
| `4` | Poss | `poss <date>` | qualitative | ✅ |
| `5` | Prob | `prob <date>` | qualitative | ✅ |
| `6` | Cert | `cert <date>` | qualitative | ✅ |
| `A` | Abt | `abt <date>` | factual | ✅ |
| `C` | Ca | `ca <date>` | factual | ✅ |
| `E` | Est | `est <date>` | factual | ✅ |
| `L` | Calc | `calc <date>` | factual | ✅ |
| `S` | Say | `say <date>` | factual | ✅ |

### Positions 14-22 — Second Date (Era/Year/Month/Day)

Same layout as positions 3-11. Used only for ranges.

### Position 23 — Second Date Double-Date Indicator

Same encoding as Position 12, applied to the second segment of a range.

### Position 24 — Second Date Qualifier

Same encoding as Position 13, applied to the second segment of a range. **Range descriptors split correctly**: a qualifier on the first half of a range goes at Position 13; on the second half, at Position 24.

### Notes from verification

- RM 11 `EventTable.SortDate` is computed as a BIGINT proprietary form. For ranges, RM uses the *start* of the range as the sort key, with a small +3 offset per range style (BetAnd → FromTo → Dash → Or). Qualifiers do not affect SortDate.
- Combined modifier+qualifier is supported in any combination tested (e.g., `Bef Abt 1791` → `DB+17910000.A+00000000..`).
- RM accepts dates copy-pasted from text. The text "Spring 1791" becomes `TSpring 1791` (Text type, free-form).

---

## 13. Edge Cases & Known Quirks

### Empty / null dates

The string `.` (just a period) means "no date entered." Both `rmdate is-empty` predicate and `rmdate type` return `Empty`.

```nu
genq list events --full-date
| where { |r| rmdate is-empty $r.FullDate }
```

### Text dates have no structure

If `rmdate type` returns `Text`, all other accessors return `null` or sensible defaults. Use `rmdate is-text` to guard:

```nu
genq list events --full-date
| where { |r| not (rmdate is-text $r.FullDate) }
| where { |r| (rmdate year $r.FullDate) > 1900 }
```

Without the guard, year extraction on a text date returns `null`, and `null > 1900` is false — so the second `where` silently drops text dates. That's usually fine, but be explicit when it matters.

### Partial-date `00` placeholders

A date like `D.+00000101..+00000000..` means "1 January, year unknown." Be aware:

- `rmdate year` returns `null` for `0000`, not `0`.
- `rmdate precision` returns `none` (because the year is missing).

### BC dates don't fast-format

The fast-path formatter currently bails on BC dates and falls back to the slow path. This affects performance on BC-heavy datasets but not correctness.

### Range descriptors can attach to either segment

In a range like `D-+16700000.C+16800000..`, the descriptor `C` (Ca) belongs to the **first** segment. In `D-+18710000..+18720000.A`, the `A` (Abt) belongs to the **second**. Layer 2's `Start.Qualifier` and `End.Qualifier` track these separately.

### Modifiers on single dates vs ranges

Position 2 distinguishes whether a date is a single date with a directional modifier, or a range. There's no "Bef + Range" — the modifier slot encodes one or the other.

### Quaker dates use a different month-numbering convention

In Quaker dates, the months were renumbered after the calendar reform. RootsMagic stores them numerically (so May 1588 = `0512`). Display as Quaker-style ("12da 5mo 1588") rather than Gregorian ("12 May 1588") if your output is meant for a Quaker context.

---

## 14. Common Workflows

### Audit "iffy" data — all uncertain or partial Birth events

```nu
genq list events --full-date
| where Event == "Birth"
| where { |r| (rmdate is-uncertain $r.FullDate) or (rmdate is-partial $r.FullDate) }
| select RIN Given Surname EventDate
| sort-by Surname Given
```

### Compute a "research-target score" — birth-date weakness

```nu
genq list events --full-date
| where Event == "Birth"
| insert Score { |r|
    let p = rmdate precision $r.FullDate
    let q = rmdate qualifier $r.FullDate
    mut score = 0
    if $p == "none" { $score = $score + 4 }
    if $p == "year" { $score = $score + 2 }
    if $p == "month" { $score = $score + 1 }
    if $q in [Abt Ca Est Calc Say Maybe Poss] { $score = $score + 1 }
    $score
}
| where Score > 0
| sort-by Score --reverse
| select RIN Given Surname EventDate Score
```

### Convert a date column to multiple structured columns

Useful for piping into CSV or external tools.

```nu
genq list events --full-date
| insert P { |r| rmdate parse-full $r.FullDate }
| insert StartYear  { |r| $r.P.Start.Year }
| insert StartMonth { |r| $r.P.Start.Month }
| insert StartDay   { |r| $r.P.Start.Day }
| insert Qualifier  { |r| $r.P.Start.Qualifier }
| insert Modifier   { |r| $r.P.Modifier }
| insert IsRanged   { |r| $r.P.IsRanged }
| reject P
| to csv
| save events_dates_expanded.csv
```

### Find date entries that look broken

If `rmdate type` returns `Standard` but no parseable year — those rows likely have malformed data.

```nu
genq list events --full-date
| where { |r|
    let t = rmdate type $r.FullDate
    let y = rmdate year $r.FullDate
    ($t == "Standard") and ($y == null) and (($r.FullDate | str length) >= 13)
}
| select RIN Given Surname Event FullDate
```

### Histogram a database's "date health"

```nu
genq list events --full-date
| insert Type   { |r| rmdate type $r.FullDate }
| insert Prec   { |r| rmdate precision $r.FullDate }
| insert Cert   { |r| if (rmdate is-uncertain $r.FullDate) { "uncertain" } else { "certain" } }
| group-by Type Prec Cert
| transpose Bucket rows
| insert Count {|r| $r.rows | length}
| reject rows
| sort-by Count --reverse
```
