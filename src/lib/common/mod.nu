# common submodules
export module 'rmdate'
export module 'genq list associations'
export module 'genq list children'
export module 'genq list citations'
export module 'genq list events'
export module 'genq list families'
export module 'genq list media'
export module 'genq list names'
export module 'genq list people'
export module 'genq list places'
export module 'genq list sources'
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
    enumerate | flatten | each { |row| $row | upsert index ($row.index + 1) }
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
