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
    assert equal $parsed.DateType "Standard Date"
    assert equal $parsed.DateQualifier "On"
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

    assert equal $after.FormattedDate "After 13 February 1791"
    assert equal $after.SortableDate "1791-02-13"
    assert equal $about.FormattedDate "Abt 13 February 1791"
    assert equal $about.SortableDate "1791-02-13"
}

@test
def "fast parse-rm-date passes text dates through" [] {
    let parsed = (parse-rm-date $TEXT_DATE --format 3)

    assert equal $parsed.FormattedDate $TEXT_DATE
    assert equal $parsed.SortableDate ""
    assert equal $parsed.DateType "Text Date"
}

@test
def "fast parse-rm-date handles empty dates" [] {
    let parsed = (parse-rm-date "." --format 3)

    assert equal $parsed.FormattedDate ""
    assert equal $parsed.SortableDate ""
    assert equal $parsed.DateType "Empty Date"
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
