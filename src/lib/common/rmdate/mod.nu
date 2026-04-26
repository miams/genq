# RootsMagic date parsing, formatting, and querying.
#
# RM stores dates in a 24-character fixed-width format (or variable-length text dates).
# This module exposes three layers:
#
#   Layer 1 — atomic accessors as `rmdate <attr>` subcommands (type, modifier, year, etc.)
#   Layer 2 — `rmdate parse-full` returns a fully-structured record
#   Layer 3 — composite predicates as `rmdate is-<X>` subcommands (uncertain, partial, ranged, ...)
#
# Plus the original display-oriented commands: parse-rm-date, format-rm-date,
# format-sort-rm-date, upsert-rm-date, and the `rmdate` table-style entry point.
#
# See docs/date-cookbook.md for usage and the verified format reference.

# ============================================================================
# Display tables — lowercase to match RootsMagic 11's events-list display.
# ============================================================================

const MODIFIER_DISPLAY = {
    None:  ""
    Bef:   "bef "
    Aft:   "aft "
    By:    "by "
    To:    "to "
    From:  "from "
    Since: "since "
    Until: "until "
}

const QUALIFIER_DISPLAY = {
    "":     ""
    Maybe:  "maybe "
    Prhps:  "prhps "
    Appar:  "appar "
    Lkly:   "lkly "
    Poss:   "poss "
    Prob:   "prob "
    Cert:   "cert "
    Abt:    "abt "
    Ca:     "ca "
    Est:    "est "
    Calc:   "calc "
    Say:    "say "
}

const MONTH_SHORT = [Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
const MONTH_LONG  = [January February March April May June July August September October November December]

# ============================================================================
# Code → name lookups for the structured parser.
# ============================================================================

def code-to-type [code: string] {
    match $code {
        "." => "Empty"
        "D" => "Standard"
        "R" => "Standard"   # Year-only double-date variant — RM uses R when precision is year-only AND double-dated
        "Q" => "Quaker"
        "T" => "Text"
        _   => "Unknown"
    }
}

def code-to-modifier [code: string] {
    match $code {
        "." => "None"
        "B" => "Bef"
        "A" => "Aft"
        "Y" => "By"
        "T" => "To"
        "F" => "From"
        "I" => "Since"
        "U" => "Until"
        "R" => "Range"
        "S" => "Range"
        "-" => "Range"
        "O" => "Range"
        _   => "None"
    }
}

def code-to-range-style [code: string] {
    match $code {
        "R" => "BetAnd"
        "S" => "FromTo"
        "-" => "Dash"
        "O" => "Or"
        _   => null
    }
}

def code-to-qualifier [code: string] {
    match $code {
        "." => ""
        "?" => "Maybe"
        "1" => "Prhps"
        "2" => "Appar"
        "3" => "Lkly"
        "4" => "Poss"
        "5" => "Prob"
        "6" => "Cert"
        "A" => "Abt"
        "C" => "Ca"
        "E" => "Est"
        "L" => "Calc"
        "S" => "Say"
        _   => ""
    }
}

def code-to-era [code: string] {
    match $code {
        "+" => "AD"
        "-" => "BC"
        _   => "AD"
    }
}

# ============================================================================
# Internal: parse a 11-char date segment (positions 3-13 of a standard date,
# i.e. era/year/month/day/double/qualifier). Returns a Start/End-shaped record.
# ============================================================================

def parse-segment [
    era_c: string
    year_s: string
    month_s: string
    day_s: string
    double_c: string
    qualifier_c: string
] {
    let era = (code-to-era $era_c)
    let year = if $year_s == "0000" { null } else { $year_s | into int }
    let month_int = ($month_s | into int)
    let month = if $month_int == 0 { null } else { $month_int }
    let day_int = ($day_s | into int)
    let day = if $day_int == 0 { null } else { $day_int }
    let qualifier = (code-to-qualifier $qualifier_c)
    let is_double = $double_c == "/"

    let precision = if $year == null {
        "none"
    } else if $month == null {
        "year"
    } else if $day == null {
        "month"
    } else {
        "day"
    }

    {
        Era: $era
        Year: $year
        Month: $month
        Day: $day
        Precision: $precision
        Qualifier: $qualifier
        IsDoubleDated: $is_double
    }
}

# ============================================================================
# Internal: full structured parse of a raw RM date string.
# Returns the canonical record used by every accessor and predicate.
# ============================================================================

def parse-internal [eventdate: string] {
    let raw = $eventdate
    let empty = {
        DateType: "Empty"
        Modifier: "None"
        RangeStyle: null
        IsRanged: false
        IsDoubleDated: false
        Start: null
        End: null
        FormattedDate: ""
        SortableDate: ""
        Raw: $raw
    }

    if ($raw | is-empty) or $raw == "." {
        return $empty
    }

    let first_char = ($raw | str substring 0..0)

    if $first_char == "T" {
        let text = ($raw | str substring 1..)
        return {
            DateType: "Text"
            Modifier: "None"
            RangeStyle: null
            IsRanged: false
            IsDoubleDated: false
            Start: null
            End: null
            FormattedDate: $text
            SortableDate: ""
            Raw: $raw
        }
    }

    if $first_char != "D" and $first_char != "Q" and $first_char != "R" {
        # Unrecognized first char — treat as text passthrough for safety.
        return {
            DateType: "Text"
            Modifier: "None"
            RangeStyle: null
            IsRanged: false
            IsDoubleDated: false
            Start: null
            End: null
            FormattedDate: $raw
            SortableDate: ""
            Raw: $raw
        }
    }

    if ($raw | str length) < 13 {
        return $empty
    }

    let date_type = (code-to-type $first_char)
    let modifier_code = ($raw | str substring 1..1)
    let modifier = (code-to-modifier $modifier_code)
    let range_style = (code-to-range-style $modifier_code)
    let is_ranged = $modifier == "Range"

    let start = (parse-segment
        ($raw | str substring 2..2)
        ($raw | str substring 3..6)
        ($raw | str substring 7..8)
        ($raw | str substring 9..10)
        ($raw | str substring 11..11)
        ($raw | str substring 12..12))

    let end = if $is_ranged and ($raw | str length) >= 24 {
        (parse-segment
            ($raw | str substring 13..13)
            ($raw | str substring 14..17)
            ($raw | str substring 18..19)
            ($raw | str substring 20..21)
            ($raw | str substring 22..22)
            ($raw | str substring 23..23))
    } else {
        null
    }

    let is_double = $start.IsDoubleDated or (if $end == null { false } else { $end.IsDoubleDated })

    {
        DateType: $date_type
        Modifier: $modifier
        RangeStyle: $range_style
        IsRanged: $is_ranged
        IsDoubleDated: $is_double
        Start: $start
        End: $end
        FormattedDate: ""   # filled in by parse-full when format requested
        SortableDate: ""    # filled in by parse-full when format requested
        Raw: $raw
    }
}

# ============================================================================
# Internal: format a parsed segment for display, given a date-format style.
# format codes: 1/2 = short month, 3/4 = long month, 5/6 = short upper, 7/8 = long upper
# odd  = day-month-year order ("13 feb 1791")
# even = month-day-year order ("feb 13, 1791")
# ============================================================================

def format-segment [seg: record, date_format: int, qualifier_word: bool] {
    if $seg == null { return "" }

    let qualifier_word_str = if $qualifier_word {
        $QUALIFIER_DISPLAY | get $seg.Qualifier
    } else {
        ""
    }

    let era_suffix = if $seg.Era == "BC" { " BC" } else { "" }

    if $seg.Year == null {
        # No year — fall back to month/day display only
        if $seg.Month == null and $seg.Day == null {
            return ""
        }
        let month_str = if $seg.Month != null {
            month-name $seg.Month $date_format
        } else { "" }
        let day_str = if $seg.Day != null { ($seg.Day | format-day) } else { "" }
        let body = if ($month_str | is-not-empty) and ($day_str | is-not-empty) {
            if ($date_format mod 2) == 0 {
                $"($month_str) ($day_str)"
            } else {
                $"($day_str) ($month_str)"
            }
        } else if ($month_str | is-not-empty) {
            $month_str
        } else {
            $day_str
        }
        return $"($qualifier_word_str)($body)($era_suffix)"
    }

    let year_str = ($seg.Year | into string)
    let double_marker = if $seg.IsDoubleDated { "/" + (($seg.Year + 1) mod 100 | into string | fill --alignment right --character "0" --width 2) } else { "" }

    if $seg.Month == null {
        return $"($qualifier_word_str)($year_str)($double_marker)($era_suffix)"
    }

    let month_str = (month-name $seg.Month $date_format)

    if $seg.Day == null {
        return $"($qualifier_word_str)($month_str) ($year_str)($double_marker)($era_suffix)"
    }

    let day_str = ($seg.Day | format-day)

    let body = if ($date_format mod 2) == 0 {
        $"($month_str) ($day_str), ($year_str)"
    } else {
        $"($day_str) ($month_str) ($year_str)"
    }

    $"($qualifier_word_str)($body)($double_marker)($era_suffix)"
}

def format-day [] {
    let n = $in
    $n | into string | fill --alignment right --character "0" --width 2
}

def month-name [month_int: int, date_format: int] {
    let idx = $month_int - 1
    let short = ($MONTH_SHORT | get $idx)
    let long  = ($MONTH_LONG  | get $idx)
    match $date_format {
        1 | 2 => $short
        3 | 4 => $long
        5 | 6 => ($short | str upcase)
        7 | 8 => ($long | str upcase)
        _ => $short
    }
}

# ============================================================================
# Internal: compute display + sortable strings from a parsed record.
# ============================================================================

def render-display [parsed: record, date_format: int] {
    if $parsed.DateType == "Empty" {
        return { FormattedDate: "", SortableDate: "" }
    }
    if $parsed.DateType == "Text" {
        return { FormattedDate: $parsed.FormattedDate, SortableDate: "" }
    }

    let sortable = sortable-from-segment $parsed.Start

    if not $parsed.IsRanged {
        let modifier_word = ($MODIFIER_DISPLAY | get $parsed.Modifier)
        let segment_str = (format-segment $parsed.Start $date_format true)
        return {
            FormattedDate: $"($modifier_word)($segment_str)"
            SortableDate: $sortable
        }
    }

    # Range
    let first  = (format-segment $parsed.Start $date_format true)
    let second = (format-segment $parsed.End   $date_format true)
    let display = match $parsed.RangeStyle {
        "BetAnd" => $"bet ($first) and ($second)"
        "FromTo" => $"from ($first) to ($second)"
        "Dash"   => $"($first) – ($second)"
        "Or"     => $"($first) or ($second)"
        _ => $first
    }
    {
        FormattedDate: $display
        SortableDate: $sortable
    }
}

def sortable-from-segment [seg: record] {
    if $seg == null { return "" }
    if $seg.Year == null { return "" }
    let year_str = ($seg.Year | into string | fill --alignment right --character "0" --width 4)
    let month = if $seg.Month == null { 1 } else { $seg.Month }
    let day = if $seg.Day == null { 1 } else { $seg.Day }
    let m = ($month | into string | fill --alignment right --character "0" --width 2)
    let d = ($day   | into string | fill --alignment right --character "0" --width 2)
    $"($year_str)-($m)-($d)"
}

# ============================================================================
# Public: rmdate (main) — table-style output of one date for `rmdate <date>`.
# ============================================================================

# Parse a RootsMagic date string and return a single-row table with all components.
@category "genq-platform"
@search-terms "convert date Julian Gregorian"
@example "parse a standard date" {
    rmdate "D.+17910213..+00000000.."
}
export def main [
    eventdate: string       # event date string from RootsMagic
    --format(-f): int       # desired date output format (1-8); defaults to $env.RDMF or 1
] {
    let date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }

    let parsed = (parse-internal $eventdate)
    let display = (render-display $parsed $date_format)

    let row = {
        FormattedDate: $display.FormattedDate
        SortableDate: $display.SortableDate
        DateType: $parsed.DateType
        DateModifier: $parsed.Modifier
        DateERA: (if $parsed.Start == null { "" } else { $parsed.Start.Era })
        DateYear: (if $parsed.Start == null or $parsed.Start.Year == null { "" } else { $parsed.Start.Year | into string })
        MonthShortName: (segment-month-short $parsed.Start)
        MonthLongName: (segment-month-long $parsed.Start)
        DayofMonth: (segment-day-str $parsed.Start)
        CalendarDate: (if $parsed.Start == null { "" } else if $parsed.Start.IsDoubleDated { "JG Double Date" } else { "Conventional" })
        DateQualifier: (if $parsed.Start == null { "" } else { $parsed.Start.Qualifier })
    }
    [$row]
}

def segment-month-short [seg: any] {
    if $seg == null { return "" }
    if $seg.Month == null { return "" }
    $MONTH_SHORT | get ($seg.Month - 1)
}

def segment-month-long [seg: any] {
    if $seg == null { return "" }
    if $seg.Month == null { return "" }
    $MONTH_LONG | get ($seg.Month - 1)
}

def segment-day-str [seg: any] {
    if $seg == null { return "" }
    if $seg.Day == null { return "00" }
    $seg.Day | into string | fill --alignment right --character "0" --width 2
}

# ============================================================================
# Public: parse-rm-date — single record return (legacy display-oriented parser).
# ============================================================================

# Parse a RootsMagic date string; return one record (not a table).
export def "parse-rm-date" [
    eventdate: string
    --format(-f): int
] {
    if ($format | is-empty) {
        main $eventdate | first
    } else {
        main $eventdate --format $format | first
    }
}

# ============================================================================
# Public: format-rm-date / format-sort-rm-date / upsert-rm-date.
# ============================================================================

# Format a RootsMagic date string for display.
export def "format-rm-date" [
    eventdate: string
    --format(-f): int
] {
    let date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }
    let parsed = (parse-internal $eventdate)
    let display = (render-display $parsed $date_format)
    $display.FormattedDate
}

# Format a RootsMagic date string and return display + sortable dates.
export def "format-sort-rm-date" [
    eventdate: string
    --format(-f): int
] {
    let date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }
    let parsed = (parse-internal $eventdate)
    render-display $parsed $date_format
}

# Upsert formatted display and optional sort columns from a raw RM date column.
export def "upsert-rm-date" [
    raw_column: string
    display_column: string
    sort_column?: string
    --format(-f): int
] {
    $in | each {|row|
        let eventdate = ($row | get --optional $raw_column | default "")
        if ($sort_column | is-empty) {
            let display = if ($format | is-empty) {
                format-rm-date $eventdate
            } else {
                format-rm-date $eventdate --format $format
            }
            $row | upsert $display_column $display
        } else {
            let formatted = if ($format | is-empty) {
                format-sort-rm-date $eventdate
            } else {
                format-sort-rm-date $eventdate --format $format
            }
            $row | upsert $display_column $formatted.FormattedDate | upsert $sort_column $formatted.SortableDate
        }
    }
}

# ============================================================================
# Layer 2 — `rmdate parse-full`: full structured record.
# ============================================================================

# Return the full structured parse of a RootsMagic date string.
export def "rmdate parse-full" [
    eventdate: string
    --format(-f): int
] {
    let date_format = if ($format | is-empty) {
        $env.RDMF? | default 1
    } else {
        $format
    }
    let parsed = (parse-internal $eventdate)
    let display = (render-display $parsed $date_format)
    $parsed
        | upsert FormattedDate $display.FormattedDate
        | upsert SortableDate $display.SortableDate
}

# ============================================================================
# Layer 1 — atomic accessors.
# ============================================================================

# Return the date type: Standard | Quaker | Text | Empty.
export def "rmdate type" [eventdate: string] {
    (parse-internal $eventdate).DateType
}

# Return the Position-2 modifier: None | Bef | Aft | By | To | From | Since | Until | Range.
export def "rmdate modifier" [eventdate: string] {
    (parse-internal $eventdate).Modifier
}

# Return the range style (only meaningful when modifier == Range): BetAnd | FromTo | Dash | Or | null.
export def "rmdate range-style" [eventdate: string] {
    (parse-internal $eventdate).RangeStyle
}

# Return the Position-13 qualifier of the start segment.
export def "rmdate qualifier" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { "" } else { $p.Start.Qualifier }
}

# Return the era of the start segment: AD | BC.
export def "rmdate era" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { "AD" } else { $p.Start.Era }
}

# Return the year of the start segment, or null if not specified.
export def "rmdate year" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { null } else { $p.Start.Year }
}

# Return the month of the start segment (1-12), or null if not specified.
export def "rmdate month" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { null } else { $p.Start.Month }
}

# Return the day of the start segment (1-31), or null if not specified.
export def "rmdate day" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { null } else { $p.Start.Day }
}

# Return the precision: day | month | year | none.
export def "rmdate precision" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { "none" } else { $p.Start.Precision }
}

# Return true if either segment carries the double-date marker.
export def "rmdate is-double-dated" [eventdate: string] {
    (parse-internal $eventdate).IsDoubleDated
}

# ============================================================================
# Layer 3 — composite predicates.
# ============================================================================

# True when the qualifier is one of RM's "date qualifiers": Abt, Ca, Est, Calc, Say.
export def "rmdate is-approximated" [eventdate: string] {
    let q = (parse-internal $eventdate | get Start | default null)
    if $q == null { return false }
    $q.Qualifier in [Abt Ca Est Calc Say]
}

# True when the qualifier is one of RM's "qualitative modifiers" below Cert.
export def "rmdate is-low-confidence" [eventdate: string] {
    let q = (parse-internal $eventdate | get Start | default null)
    if $q == null { return false }
    $q.Qualifier in [Maybe Prhps Appar Lkly Poss Prob]
}

# True when the date is approximated OR has a sub-Cert confidence flag.
export def "rmdate is-uncertain" [eventdate: string] {
    let q = (parse-internal $eventdate | get Start | default null)
    if $q == null { return false }
    $q.Qualifier in [Abt Ca Est Calc Say Maybe Prhps Appar Lkly Poss Prob]
}

# True when the date carries no qualifier or is explicitly marked Cert.
export def "rmdate is-certain" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.DateType != "Standard" and $p.DateType != "Quaker" { return false }
    if $p.Start == null { return false }
    $p.Start.Qualifier == "" or $p.Start.Qualifier == "Cert"
}

# True when precision is not full day-precision.
export def "rmdate is-partial" [eventdate: string] {
    let p = (parse-internal $eventdate)
    if $p.Start == null { return false }
    $p.Start.Precision != "day"
}

# True when the date is a range (Bet/And, From/To, dash, or Or).
export def "rmdate is-ranged" [eventdate: string] {
    (parse-internal $eventdate).IsRanged
}

# True when the modifier is a directional one (Bef, Aft, By, To, From, Since, Until).
export def "rmdate is-directional" [eventdate: string] {
    (parse-internal $eventdate).Modifier in [Bef Aft By To From Since Until]
}

# True when either segment uses the BC era.
export def "rmdate is-bce" [eventdate: string] {
    let p = (parse-internal $eventdate)
    let s_bc = if $p.Start == null { false } else { $p.Start.Era == "BC" }
    let e_bc = if $p.End == null { false } else { $p.End.Era == "BC" }
    $s_bc or $e_bc
}

# True when DateType is Text.
export def "rmdate is-text" [eventdate: string] {
    (parse-internal $eventdate).DateType == "Text"
}

# True when DateType is Empty.
export def "rmdate is-empty" [eventdate: string] {
    (parse-internal $eventdate).DateType == "Empty"
}

# True when the start year is set and is < year_threshold.
export def "rmdate before" [eventdate: string, year_threshold: int] {
    let p = (parse-internal $eventdate)
    if $p.Start == null or $p.Start.Year == null { return false }
    $p.Start.Year < $year_threshold
}

# True when the start year is set and is > year_threshold.
export def "rmdate after" [eventdate: string, year_threshold: int] {
    let p = (parse-internal $eventdate)
    if $p.Start == null or $p.Start.Year == null { return false }
    $p.Start.Year > $year_threshold
}

# True when the start year is set and is in [low, high] inclusive.
export def "rmdate between" [eventdate: string, low: int, high: int] {
    let p = (parse-internal $eventdate)
    if $p.Start == null or $p.Start.Year == null { return false }
    $p.Start.Year >= $low and $p.Start.Year <= $high
}
