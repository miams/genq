# Fast tests for RootsMagic date formatting helpers.
# Label: [fast] — no database required

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *

const STANDARD_DATE = "D.+17910213..+00000000.."
const YEAR_ONLY_DATE = "D.+17910000..+00000000.."
const MONTH_ONLY_DATE = "D.+17910200..+00000000.."
const TEXT_DATE = "Spring 1791"

@test
def "fast rmdate defaults without RDMF env" [] {
    try { hide-env RDMF } catch { null }
    let parsed = (rmdate $STANDARD_DATE | first)

    assert equal $parsed.FormattedDate "13 Feb 1791"
    assert equal $parsed.SortableDate "1791-02-13"
}

@test
def "fast parse-rm-date returns parsed record" [] {
    let parsed = (parse-rm-date $STANDARD_DATE --format 3)

    assert equal $parsed.FormattedDate "13 February 1791"
    assert equal $parsed.SortableDate "1791-02-13"
    assert equal $parsed.DateType "Standard"
    assert equal $parsed.DateModifier "None"
    assert equal $parsed.DateYear "1791"
    assert equal $parsed.MonthShortName "Feb"
    assert equal $parsed.DayofMonth "13"
}

@test
def "fast format-rm-date returns display string" [] {
    assert equal (format-rm-date $STANDARD_DATE --format 4) "February 13, 1791"
}

@test
def "fast format-rm-date formats year-only dates" [] {
    assert equal (format-rm-date $YEAR_ONLY_DATE --format 3) "1791"
}

@test
def "fast format-sort-rm-date returns display and sort strings" [] {
    let formatted = (format-sort-rm-date $STANDARD_DATE --format 3)

    assert equal $formatted.FormattedDate "13 February 1791"
    assert equal $formatted.SortableDate "1791-02-13"
}

@test
def "fast format-sort-rm-date handles partial dates" [] {
    let year_only = (format-sort-rm-date $YEAR_ONLY_DATE --format 3)
    let month_only = (format-sort-rm-date $MONTH_ONLY_DATE --format 3)

    assert equal $year_only.FormattedDate "1791"
    assert equal $year_only.SortableDate "1791-01-01"
    assert equal $month_only.FormattedDate "February 1791"
    assert equal $month_only.SortableDate "1791-02-01"
}

@test
def "fast format-sort-rm-date passes text dates through" [] {
    let formatted = (format-sort-rm-date $TEXT_DATE --format 3)

    assert equal $formatted.FormattedDate $TEXT_DATE
    assert equal $formatted.SortableDate ""
}

@test
def "fast format-sort-rm-date handles standard qualifiers" [] {
    let after = (format-sort-rm-date "DA+17910213..+00000000.." --format 3)
    let about = (format-sort-rm-date "D.+17910213.A+00000000.." --format 3)

    assert equal $after.FormattedDate "aft 13 February 1791"
    assert equal $after.SortableDate "1791-02-13"
    assert equal $about.FormattedDate "abt 13 February 1791"
    assert equal $about.SortableDate "1791-02-13"
}

@test
def "fast format-rm-date handles Bet/And year-only range" [] {
    let r = (format-sort-rm-date "DR+18710000..+18720000.." --format 1)
    assert equal $r.FormattedDate "bet 1871 and 1872"
    assert equal $r.SortableDate "1871-01-01"
}

@test
def "fast format-rm-date handles Bet/And full-date range" [] {
    let r = (format-rm-date "DR+18310819..+18311005.." --format 1)
    assert equal $r "bet 19 Aug 1831 and 05 Oct 1831"
}

@test
def "fast format-rm-date handles From/To range with mixed precision" [] {
    let r = (format-sort-rm-date "DS+19470800..+19520400.." --format 3)
    assert equal $r.FormattedDate "from August 1947 to April 1952"
    assert equal $r.SortableDate "1947-08-01"
}

@test
def "fast format-rm-date handles dash range" [] {
    let r = (format-rm-date "D-+19470000..+19670000.." --format 1)
    assert equal $r "1947 – 1967"
}

@test
def "fast format-rm-date handles Or range" [] {
    let r = (format-rm-date "DO+18000000..+18010000.." --format 1)
    assert equal $r "1800 or 1801"
}

@test
def "fast format-rm-date preserves descriptor on first range half" [] {
    # Descriptor "C" (Ca) at position 12 belongs to the first half. Real example from production.
    let r = (format-rm-date "D-+16700000.C+16800000.." --format 1)
    assert equal $r "ca 1670 – 1680"
}

@test
def "fast format-rm-date preserves descriptor on second range half" [] {
    # Descriptor "A" (Abt) at position 23 belongs to the second half.
    let r = (format-rm-date "D-+18710000..+18720000.A" --format 1)
    assert equal $r "1871 – abt 1872"
}

@test
def "fast upsert-rm-date applies range parsing to a column" [] {
    let rows = [
        { RIN: 1, FullDate: "DR+18710000..+18720000.." }
        { RIN: 2, FullDate: "DS+19470800..+19520400.." }
    ]
    let result = ($rows | upsert-rm-date FullDate EventDate SortDate --format 1)

    assert equal ($result | get EventDate.0) "bet 1871 and 1872"
    assert equal ($result | get SortDate.0) "1871-01-01"
    assert equal ($result | get EventDate.1) "from Aug 1947 to Apr 1952"
    assert equal ($result | get SortDate.1) "1947-08-01"
}

@test
def "fast parse-rm-date passes text dates through" [] {
    let parsed = (parse-rm-date $TEXT_DATE --format 3)

    assert equal $parsed.FormattedDate $TEXT_DATE
    assert equal $parsed.SortableDate ""
    assert equal $parsed.DateType "Text"
}

@test
def "fast parse-rm-date handles empty dates" [] {
    let parsed = (parse-rm-date "." --format 3)

    assert equal $parsed.FormattedDate ""
    assert equal $parsed.SortableDate ""
    assert equal $parsed.DateType "Empty"
}

@test
def "fast upsert-rm-date adds display and sort columns" [] {
    let rows = [
        { RIN: 1, FullDate: $STANDARD_DATE }
        { RIN: 2, FullDate: $TEXT_DATE }
    ]

    let result = ($rows | upsert-rm-date FullDate EventDate SortDate --format 3)

    assert equal ($result | get EventDate.0) "13 February 1791"
    assert equal ($result | get SortDate.0) "1791-02-13"
    assert equal ($result | get EventDate.1) $TEXT_DATE
    assert equal ($result | get SortDate.1) ""
}

@test
def "fast upsert-rm-date can add display column only" [] {
    let result = ([{ RIN: 1, FullDate: $STANDARD_DATE }] | upsert-rm-date FullDate EventDate --format 3)
    let cols = ($result | columns)

    assert equal ($result | get EventDate.0) "13 February 1791"
    assert not ($cols | any {|col| $col == "SortDate" })
}

# ============================================================================
# Layer 1 — atomic accessors
# ============================================================================

@test
def "fast rmdate type returns Standard for D-prefix dates" [] {
    assert equal (rmdate type $STANDARD_DATE) "Standard"
}

@test
def "fast rmdate type returns Empty for empty input" [] {
    assert equal (rmdate type ".") "Empty"
    assert equal (rmdate type "") "Empty"
}

@test
def "fast rmdate type returns Text for text dates" [] {
    assert equal (rmdate type $TEXT_DATE) "Text"
}

@test
def "fast rmdate modifier covers all 12 Position-2 codes" [] {
    assert equal (rmdate modifier "D.+17910213..+00000000..") "None"
    assert equal (rmdate modifier "DB+17910213..+00000000..") "Bef"
    assert equal (rmdate modifier "DA+17910213..+00000000..") "Aft"
    assert equal (rmdate modifier "DY+17910213..+00000000..") "By"
    assert equal (rmdate modifier "DT+17910213..+00000000..") "To"
    assert equal (rmdate modifier "DF+17910213..+00000000..") "From"
    assert equal (rmdate modifier "DI+17910213..+00000000..") "Since"
    assert equal (rmdate modifier "DU+17910213..+00000000..") "Until"
    assert equal (rmdate modifier "DR+17910213..+17920000..") "Range"
    assert equal (rmdate modifier "DS+17910213..+17920000..") "Range"
    assert equal (rmdate modifier "D-+17910213..+17920000..") "Range"
    assert equal (rmdate modifier "DO+17910213..+17920000..") "Range"
}

@test
def "fast rmdate range-style identifies all four range styles" [] {
    assert equal (rmdate range-style "DR+17910000..+17920000..") "BetAnd"
    assert equal (rmdate range-style "DS+17910000..+17920000..") "FromTo"
    assert equal (rmdate range-style "D-+17910000..+17920000..") "Dash"
    assert equal (rmdate range-style "DO+17910000..+17920000..") "Or"
    assert equal (rmdate range-style $STANDARD_DATE) null
}

@test
def "fast rmdate qualifier covers factual qualifiers" [] {
    assert equal (rmdate qualifier "D.+17910213.A+00000000..") "Abt"
    assert equal (rmdate qualifier "D.+17910213.C+00000000..") "Ca"
    assert equal (rmdate qualifier "D.+17910213.E+00000000..") "Est"
    assert equal (rmdate qualifier "D.+17910213.L+00000000..") "Calc"
    assert equal (rmdate qualifier "D.+17910213.S+00000000..") "Say"
}

@test
def "fast rmdate qualifier covers qualitative modifiers" [] {
    assert equal (rmdate qualifier "D.+17910213.?+00000000..") "Maybe"
    assert equal (rmdate qualifier "D.+17910213.1+00000000..") "Prhps"
    assert equal (rmdate qualifier "D.+17910213.2+00000000..") "Appar"
    assert equal (rmdate qualifier "D.+17910213.3+00000000..") "Lkly"
    assert equal (rmdate qualifier "D.+17910213.4+00000000..") "Poss"
    assert equal (rmdate qualifier "D.+17910213.5+00000000..") "Prob"
    assert equal (rmdate qualifier "D.+17910213.6+00000000..") "Cert"
}

@test
def "fast rmdate era handles AD and BC" [] {
    assert equal (rmdate era $STANDARD_DATE) "AD"
    assert equal (rmdate era "D.-04400000..+00000000..") "BC"
}

@test
def "fast rmdate year/month/day return numerics or null" [] {
    assert equal (rmdate year $STANDARD_DATE) 1791
    assert equal (rmdate month $STANDARD_DATE) 2
    assert equal (rmdate day $STANDARD_DATE) 13

    assert equal (rmdate year $YEAR_ONLY_DATE) 1791
    assert equal (rmdate month $YEAR_ONLY_DATE) null
    assert equal (rmdate day $YEAR_ONLY_DATE) null
}

@test
def "fast rmdate precision reflects available fields" [] {
    assert equal (rmdate precision $STANDARD_DATE) "day"
    assert equal (rmdate precision $MONTH_ONLY_DATE) "month"
    assert equal (rmdate precision $YEAR_ONLY_DATE) "year"
    assert equal (rmdate precision ".") "none"
}

@test
def "fast rmdate is-double-dated detects Julian/Gregorian marker" [] {
    assert equal (rmdate is-double-dated "D.+17910213/.+00000000..") true
    assert equal (rmdate is-double-dated $STANDARD_DATE) false
}

# ============================================================================
# Layer 2 — parse-full
# ============================================================================

@test
def "fast rmdate parse-full returns canonical record for standard date" [] {
    let p = (rmdate parse-full $STANDARD_DATE --format 3)
    assert equal $p.DateType "Standard"
    assert equal $p.Modifier "None"
    assert equal $p.IsRanged false
    assert equal $p.Start.Year 1791
    assert equal $p.Start.Month 2
    assert equal $p.Start.Day 13
    assert equal $p.Start.Precision "day"
    assert equal $p.End null
    assert equal $p.FormattedDate "13 February 1791"
    assert equal $p.SortableDate "1791-02-13"
}

@test
def "fast rmdate parse-full handles ranged dates with End segment" [] {
    let p = (rmdate parse-full "DR+18710000..+18720000.." --format 1)
    assert equal $p.IsRanged true
    assert equal $p.RangeStyle "BetAnd"
    assert equal $p.Start.Year 1871
    assert equal $p.End.Year 1872
    assert equal $p.FormattedDate "bet 1871 and 1872"
}

@test
def "fast rmdate parse-full passes through empty and text dates" [] {
    let e = (rmdate parse-full ".")
    assert equal $e.DateType "Empty"
    assert equal $e.Start null

    let t = (rmdate parse-full $TEXT_DATE)
    assert equal $t.DateType "Text"
    assert equal $t.FormattedDate $TEXT_DATE
}

# ============================================================================
# Layer 3 — composite predicates
# ============================================================================

@test
def "fast rmdate is-approximated true for factual qualifiers" [] {
    assert equal (rmdate is-approximated "D.+17910213.A+00000000..") true
    assert equal (rmdate is-approximated "D.+17910213.C+00000000..") true
    assert equal (rmdate is-approximated "D.+17910213.S+00000000..") true
    assert equal (rmdate is-approximated $STANDARD_DATE) false
    assert equal (rmdate is-approximated "D.+17910213.?+00000000..") false
}

@test
def "fast rmdate is-low-confidence true only for Maybe..Prob" [] {
    assert equal (rmdate is-low-confidence "D.+17910213.?+00000000..") true
    assert equal (rmdate is-low-confidence "D.+17910213.5+00000000..") true
    assert equal (rmdate is-low-confidence "D.+17910213.6+00000000..") false
    assert equal (rmdate is-low-confidence "D.+17910213.A+00000000..") false
}

@test
def "fast rmdate is-uncertain unifies factual and qualitative qualifiers" [] {
    assert equal (rmdate is-uncertain "D.+17910213.A+00000000..") true
    assert equal (rmdate is-uncertain "D.+17910213.?+00000000..") true
    assert equal (rmdate is-uncertain $STANDARD_DATE) false
    assert equal (rmdate is-uncertain "D.+17910213.6+00000000..") false
}

@test
def "fast rmdate is-certain true for unmarked or Cert dates only" [] {
    assert equal (rmdate is-certain $STANDARD_DATE) true
    assert equal (rmdate is-certain "D.+17910213.6+00000000..") true
    assert equal (rmdate is-certain "D.+17910213.A+00000000..") false
    assert equal (rmdate is-certain $TEXT_DATE) false
    assert equal (rmdate is-certain ".") false
}

@test
def "fast rmdate is-partial true unless precision is day" [] {
    assert equal (rmdate is-partial $STANDARD_DATE) false
    assert equal (rmdate is-partial $MONTH_ONLY_DATE) true
    assert equal (rmdate is-partial $YEAR_ONLY_DATE) true
}

@test
def "fast rmdate is-ranged matches all four range styles" [] {
    assert equal (rmdate is-ranged "DR+17910000..+17920000..") true
    assert equal (rmdate is-ranged "DS+17910000..+17920000..") true
    assert equal (rmdate is-ranged "D-+17910000..+17920000..") true
    assert equal (rmdate is-ranged "DO+17910000..+17920000..") true
    assert equal (rmdate is-ranged $STANDARD_DATE) false
}

@test
def "fast rmdate is-directional true for directional modifiers only" [] {
    assert equal (rmdate is-directional "DB+17910213..+00000000..") true
    assert equal (rmdate is-directional "DA+17910213..+00000000..") true
    assert equal (rmdate is-directional "DU+17910213..+00000000..") true
    assert equal (rmdate is-directional $STANDARD_DATE) false
    assert equal (rmdate is-directional "DR+17910000..+17920000..") false
}

@test
def "fast rmdate is-bce true when era marker is minus" [] {
    assert equal (rmdate is-bce "D.-04400000..+00000000..") true
    assert equal (rmdate is-bce $STANDARD_DATE) false
}

@test
def "fast rmdate is-text and is-empty discriminate non-numeric dates" [] {
    assert equal (rmdate is-text $TEXT_DATE) true
    assert equal (rmdate is-text $STANDARD_DATE) false
    assert equal (rmdate is-empty ".") true
    assert equal (rmdate is-empty "") true
    assert equal (rmdate is-empty $STANDARD_DATE) false
}

# ============================================================================
# Double-dated entries (Position 1 = R for year-only DD; D otherwise)
# ============================================================================

@test
def "fast R-prefix year-only double dates classify as Standard" [] {
    assert equal (rmdate type "R.+17190000/.+00000000/.") "Standard"
    assert equal (rmdate type "R.+17190000/A+00000000/.") "Standard"
    assert equal (rmdate is-double-dated "R.+17190000/.+00000000/.") true
    assert equal (rmdate is-text "R.+17190000/.+00000000/.") false
}

@test
def "fast R-prefix year-only double date renders with /YY suffix" [] {
    assert equal (format-rm-date "R.+17190000/.+00000000/.") "1719/20"
    assert equal (format-rm-date "R.+16940000/C+00000000/.") "ca 1694/95"
    assert equal (format-rm-date "R.+17190000/A+00000000/.") "abt 1719/20"
    assert equal (format-rm-date "R.+17190000/3+00000000/.") "lkly 1719/20"
}

@test
def "fast R-prefix double date carries modifier through" [] {
    assert equal (format-rm-date "RB+17190000/.+00000000/.") "bef 1719/20"
    assert equal (format-rm-date "RA+17190000/.+00000000/.") "aft 1719/20"
    assert equal (rmdate modifier "RB+17190000/.+00000000/.") "Bef"
}

@test
def "fast R-prefix double date supports range modifier" [] {
    let r = (rmdate parse-full "RR+17190000/.+17200000/.")
    assert equal $r.DateType "Standard"
    assert equal $r.Modifier "Range"
    assert equal $r.RangeStyle "BetAnd"
    assert equal $r.IsRanged true
    assert equal $r.IsDoubleDated true
    assert equal $r.Start.Year 1719
    assert equal $r.End.Year 1720
    assert equal $r.FormattedDate "bet 1719/20 and 1720/21"
}

@test
def "fast D-prefix month/day double dates still render correctly" [] {
    assert equal (format-rm-date "D.+17190200/.+00000000/.") "Feb 1719/20"
    assert equal (format-rm-date "D.+17190213/.+00000000/.") "13 Feb 1719/20"
    assert equal (format-rm-date "D.+17190100/A+00000000/.") "abt Jan 1719/20"
    assert equal (rmdate type "D.+17190213/.+00000000/.") "Standard"
    assert equal (rmdate is-double-dated "D.+17190213/.+00000000/.") true
}

@test
def "fast rmdate before/after/between gate by start year" [] {
    assert equal (rmdate before $STANDARD_DATE 1800) true
    assert equal (rmdate before $STANDARD_DATE 1700) false
    assert equal (rmdate after  $STANDARD_DATE 1700) true
    assert equal (rmdate after  $STANDARD_DATE 1800) false
    assert equal (rmdate between $STANDARD_DATE 1700 1800) true
    assert equal (rmdate between $STANDARD_DATE 1800 1900) false
    assert equal (rmdate before  $TEXT_DATE 9999) false
    assert equal (rmdate between "." 1700 1900) false
}
