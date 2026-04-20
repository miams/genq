# common submodules
export use rmdate *
export use rm-template *

export module 'rmdate'
export module 'rm-template'
export module 'genq list ancestry-links'
export module 'genq list associations'
export module 'genq list children'
export module 'genq list citations'
export module 'genq list dna'
export module 'genq list events'
export module 'genq list families'
export module 'genq list familysearch-links'
export module 'genq list groups'
export module 'genq list media'
export module 'genq list names'
export module 'genq list people'
export module 'genq list places'
export module 'genq distance-from'
export module 'genq list sources'
export module 'genq list tasks'
export module 'genq list web-tags'
export module 'genq list witnesses'
export module 'genq md people'
export module 'genq config'
export module 'genq tabulate trees'

# Path utilities
export module 'paths.nu'

# Shared utility functions used by sub-modules
# Exported here so tests can load them via `use common *`

# Start index at 1 instead of default 0.
export def startat1 [] {
    $in | enumerate | each { |row| $row.item | upsert index ($row.index + 1) }
}

export def "sort-date-by" [
    column: string
    --reverse(-r)
    --no-empty
    --only-empty
] {
    let rows = $in
    if ($rows | is-empty) {
        return $rows
    }

    let sort_column = if $column == "EventDate" and (($rows | columns) | any {|c| $c == "SortDate" }) {
        "SortDate"
    } else {
        $column
    }

    let with_dates = ($rows | where {|row| (($row | get --optional $sort_column | default "") | is-not-empty) })
    let without_dates = ($rows | where {|row| (($row | get --optional $sort_column | default "") | is-empty) })

    if $only_empty {
        return $without_dates
    }

    let sorted = if $reverse {
        $with_dates | sort-by {|row| $row | get $sort_column } --reverse
    } else {
        $with_dates | sort-by {|row| $row | get $sort_column }
    }

    if $no_empty {
        $sorted
    } else {
        [$sorted, $without_dates] | flatten
    }
}

# Limit text in column with ellipsis
export def limit [
    text: string   # string to shorten
    maxlen: int    # max length of string
] {
    if ($text | str length) > $maxlen {
        $text | str substring 0..$maxlen | [$in, "..."] | str join
    } else {
        $text
    }
}
