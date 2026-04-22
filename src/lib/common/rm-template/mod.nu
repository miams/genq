# RootsMagic source template interpreter.
# Renders SourceTemplateTable format strings against SourceTable.Fields values.
#
# Public API: render-template
# See docs/rm-template-interpreter-analysis.md for the grammar specification.

# ── Public API ──────────────────────────────────────────────────────────────

# Render a RootsMagic source template format string against a Fields XML blob.
# Returns the rendered citation string.
#
# format_string: SourceTemplateTable.Footnote / ShortFootnote / Bibliography
# fields_xml:    SourceTable.Fields XML blob (cast as TEXT from SQLite)
# --plain-text:  strip <i> and <sc> HTML tags, leaving plain text
export def render-template [
    format_string: string
    fields_xml: string
    --plain-text
] {
    if ($format_string | is-empty) { return "" }
    let fields = (parse-rm-fields $fields_xml)
    let tokens = (tokenize-template $format_string)
    let rendered = (eval-tokens $tokens $fields)
    let cleaned = (cleanup-punct $rendered)
    if $plain_text {
        $cleaned | str replace --all --regex '</?(?:i|sc)>' ''
    } else {
        $cleaned
    }
}

# Render a template format string against an already-parsed fields record.
# Use this when you need to merge fields from multiple sources (e.g. source-level
# fields overlaid with citation-level fields) before rendering.
export def render-template-fields [
    format_string: string
    fields: record
    --plain-text
] {
    if ($format_string | is-empty) { return "" }
    let tokens = (tokenize-template $format_string)
    let rendered = (eval-tokens $tokens $fields)
    let cleaned = (cleanup-punct $rendered)
    if $plain_text {
        $cleaned | str replace --all --regex '</?(?:i|sc)>' ''
    } else {
        $cleaned
    }
}

# Extract a named field from a free-form source's Fields XML blob.
# Free-form sources store Footnote/ShortFootnote/Bibliography as named fields.
export def extract-freeform-field [fields_xml: string, field_name: string] {
    if ($fields_xml | is-empty) { return "" }
    try {
        $fields_xml | from xml
                    | get content.0.content
                    | where {|f| ($f | get --optional content.0.content.0.content | default "") == $field_name }
                    | first
                    | get --optional content.1.content.0.content
                    | default ""
    } catch { "" }
}

# ── Field XML parser ────────────────────────────────────────────────────────

# Parse a SourceTable.Fields XML blob into a flat record {FieldName: value, ...}.
# Handles empty values and malformed XML gracefully.
export def parse-rm-fields [xml: string] {
    if ($xml | is-empty) { return {} }
    try {
        let field_nodes = ($xml | from xml | get content.0.content)
        mut result = {}
        for f in $field_nodes {
            let name  = ($f | get --optional content.0.content.0.content | default "")
            let value = ($f | get --optional content.1.content.0.content | default "")
            if ($name | is-not-empty) {
                $result = ($result | upsert $name $value)
            }
        }
        $result
    } catch {
        {}
    }
}

# ── Tokenizer ───────────────────────────────────────────────────────────────
#
# Token shapes:
#   {type: "lit",     text: string}
#   {type: "field",   name: string, mods: list<string>}
#   {type: "cond",    tokens: list}         suppress block if any field inside is empty
#   {type: "defval",  name: string, mods: list<string>, fallback: string}
#   {type: "ternary", name: string, mods: list<string>, present: list, absent: list}

# Find the matching '>' for '<' at position `from`, tracking nested depth.
# Takes pre-split chars list for O(1) character access.
def find-close-angle [chars: list<string>, from: int] {
    let len = ($chars | length)
    mut depth = 1
    mut i = ($from + 1)
    while $i < $len and $depth > 0 {
        let ch = ($chars | get $i)
        if $ch == "<" {
            $depth = $depth + 1
        } else if $ch == ">" {
            $depth = $depth - 1
        }
        if $depth > 0 { $i = $i + 1 }
    }
    $i
}

# Find the matching ']' for '[' at position `from` (brackets are never nested in field refs).
# Takes pre-split chars list for O(1) character access.
def find-close-bracket [chars: list<string>, from: int] {
    let len = ($chars | length)
    mut i = ($from + 1)
    while $i < $len {
        if ($chars | get $i) == "]" { return $i }
        $i = $i + 1
    }
    $i
}

# Split `s` on '|' at angle-bracket depth 0 only.
# Prevents splitting on '|' inside <[Field]|default> blocks within ternary branches.
def split-top-pipe [s: string] {
    let chars = ($s | split chars)
    let len = ($chars | length)
    mut depth = 0
    mut parts: list<string> = []
    mut seg_start = 0
    mut i = 0
    while $i < $len {
        let ch = ($chars | get $i)
        if $ch == "<" {
            $depth = $depth + 1
        } else if $ch == ">" {
            $depth = $depth - 1
        } else if $ch == "|" and $depth == 0 {
            if $i > $seg_start {
                $parts = ($parts | append ($chars | skip $seg_start | first ($i - $seg_start) | str join))
            } else {
                $parts = ($parts | append "")
            }
            $seg_start = $i + 1
        }
        $i = $i + 1
    }
    if $len > $seg_start {
        $parts | append ($chars | skip $seg_start | first ($len - $seg_start) | str join)
    } else {
        $parts | append ""
    }
}

# Parse a field-reference inner string (e.g. "Author:Reverse") into {name, mods}.
def parse-field-ref [inner: string] {
    let parts = ($inner | split row ":")
    {name: ($parts | first), mods: ($parts | skip 1)}
}

# Tokenize a template format string into a list of token records.
# Calls itself recursively for conditional branch content.
def tokenize-template [fmt: string] {
    let chars = ($fmt | split chars)   # O(n) once; all char access below is O(1) list get
    let len = ($chars | length)
    mut tokens: list = []
    mut lit = ""
    mut i = 0

    while $i < $len {
        let ch = ($chars | get $i)

        if $ch == "[" {
            # ── Field reference: [FieldName] or [FieldName:Mod:Mod] ──────────
            if ($lit | is-not-empty) {
                $tokens = ($tokens | append {type: "lit", text: $lit})
                $lit = ""
            }
            let close = (find-close-bracket $chars $i)
            let inner = if $close > ($i + 1) { $chars | skip ($i + 1) | first ($close - $i - 1) | str join } else { "" }
            let fr = (parse-field-ref $inner)
            $tokens = ($tokens | append {type: "field", name: $fr.name, mods: $fr.mods})
            $i = $close + 1

        } else if $ch == "<" {
            # ── Angle-bracket construct ───────────────────────────────────────
            if ($lit | is-not-empty) {
                $tokens = ($tokens | append {type: "lit", text: $lit})
                $lit = ""
            }
            let close = (find-close-angle $chars $i)
            let inner = if $close > ($i + 1) { $chars | skip ($i + 1) | first ($close - $i - 1) | str join } else { "" }
            let tag_text = ($chars | skip $i | first ($close - $i + 1) | str join)

            # HTML tags: <i>, </i>, <sc>, </sc> — treat as literal text
            if $tag_text == "<i>" or $tag_text == "</i>" or $tag_text == "<sc>" or $tag_text == "</sc>" {
                $tokens = ($tokens | append {type: "lit", text: $tag_text})
                $i = $close + 1

            } else if ($inner | str starts-with "/[") {
                # Special </[[Field]/]SUFFIX> construct (one template only).
                # Equivalent to <[Field]SUFFIX> — suppress block if field is empty.
                let slash_end = ($inner | str index-of "/]")
                let field_inner = if $slash_end > 2 { $inner | str substring 3..($slash_end - 1) } else { "" }
                let suffix = if (($slash_end + 2) < ($inner | str length)) { $inner | str substring ($slash_end + 2).. } else { "" }
                let fr = (parse-field-ref $field_inner)
                let sub = [{type: "field", name: $fr.name, mods: $fr.mods}] ++ (tokenize-template $suffix)
                $tokens = ($tokens | append {type: "cond", tokens: $sub})
                $i = $close + 1

            } else if ($inner | str starts-with "?") {
                # Ternary: <?[Field:Mod]|if-present|if-absent>
                let content = ($inner | str substring 1..)
                let parts = (split-top-pipe $content)
                let field_ref_str = ($parts | get 0 | default "")
                let field_inner = if ($field_ref_str | str length) > 2 {
                    $field_ref_str | str substring 1..($field_ref_str | str length | $in - 2)
                } else { "" }
                let fr = (parse-field-ref $field_inner)
                let present_str = if ($parts | length) > 1 { $parts | get 1 } else { "" }
                let absent_str  = if ($parts | length) > 2 { $parts | get 2 } else { "" }
                $tokens = ($tokens | append {
                    type:    "ternary"
                    name:    $fr.name
                    mods:    $fr.mods
                    present: (tokenize-template $present_str)
                    absent:  (tokenize-template $absent_str)
                })
                $i = $close + 1

            } else {
                # Default-value conditional <[Field:Mod]|literal default>
                # or simple conditional <content with field refs>
                let parts = (split-top-pipe $inner)
                let first_part = ($parts | get 0 | default "")

                if ($parts | length) == 2 and ($first_part | str starts-with "[") and not ($first_part | str contains "<") {
                    # <[Field:Mod]|default> — render field or fall back to default text
                    let field_inner = if ($first_part | str length) > 2 {
                        $first_part | str substring 1..($first_part | str length | $in - 2)
                    } else { "" }
                    let fr = (parse-field-ref $field_inner)
                    $tokens = ($tokens | append {
                        type:     "defval"
                        name:     $fr.name
                        mods:     $fr.mods
                        fallback: ($parts | get 1)
                    })
                    $i = $close + 1

                } else {
                    # Simple conditional — suppress entire block if any referenced field is empty
                    $tokens = ($tokens | append {type: "cond", tokens: (tokenize-template $inner)})
                    $i = $close + 1
                }
            }

        } else {
            $lit = $lit + $ch
            $i = $i + 1
        }
    }

    if ($lit | is-not-empty) {
        $tokens = ($tokens | append {type: "lit", text: $lit})
    }
    $tokens
}

# ── Evaluator ───────────────────────────────────────────────────────────────

# Evaluate a token list against a fields record, returning a rendered string.
# Calls itself recursively for conditional branch content.
def eval-tokens [tokens: list, fields: record] {
    $tokens | each {|tok|
        let t = $tok.type
        if $t == "lit" {
            $tok.text
        } else if $t == "field" {
            lookup-field $tok.name $tok.mods $fields
        } else if $t == "defval" {
            let val = ($fields | get --optional $tok.name | default "")
            if ($val | is-not-empty) { apply-modifiers $val $tok.mods } else { $tok.fallback }
        } else if $t == "cond" {
            if (cond-all-present $tok.tokens $fields) { eval-tokens $tok.tokens $fields } else { "" }
        } else if $t == "ternary" {
            let val = ($fields | get --optional $tok.name | default "")
            if ($val | is-not-empty) { eval-tokens $tok.present $fields } else { eval-tokens $tok.absent $fields }
        } else {
            ""
        }
    } | str join
}

# Return true if every field token in `tokens` references a non-empty field.
# Both absent fields (null) and empty fields ("") cause suppression — this ensures
# that optional fields like Role, SubTitle, etc. suppress their surrounding punctuation.
# Literal-like names such as [LDS] that appear outside conditionals are unaffected
# because lookup-field still returns them as "[LDS]" text in the output.
# Nested cond/defval/ternary tokens always return true; they self-govern their own suppression.
def cond-all-present [tokens: list, fields: record] {
    $tokens | all {|tok|
        if $tok.type == "field" {
            let val = ($fields | get --optional $tok.name | default "")
            $val | is-not-empty
        } else {
            true
        }
    }
}

# Look up a field by name, apply modifiers, and return the rendered value.
# Unknown field names (not in the fields dict) are returned literally as [Name]
# so that constructs like [LDS] in template 3 pass through unchanged.
def lookup-field [name: string, mods: list<string>, fields: record] {
    let raw = ($fields | get --optional $name | default null)
    if $raw == null {
        $"[($name)]"      # not a known field — output literally
    } else if ($raw | is-empty) {
        ""
    } else {
        apply-modifiers $raw $mods
    }
}

# ── Modifier pipeline ────────────────────────────────────────────────────────

# Apply a list of modifiers to a raw field value.
# Modifiers are applied left to right; :Abbrev selects the short form from
# the original value's full||short split; other modifiers transform current value
# and short value in parallel so cascaded :Abbrev still works.
def apply-modifiers [value: string, mods: list<string>] {
    let parts     = ($value | split row "||")
    let full_val  = ($parts | get 0 | default "")
    let short_val = if ($parts | length) > 1 { $parts | get 1 } else { $full_val }

    mut cur   = $full_val
    mut short = $short_val

    for mod in $mods {
        let m = ($mod | str downcase)
        if $m == "abbrev" {
            $cur = $short
        } else {
            $cur   = (apply-one-mod $cur   $m)
            $short = (apply-one-mod $short $m)
        }
    }
    $cur
}

def apply-one-mod [val: string, mod: string] {
    match $mod {
        "year"             => { extract-year $val }
        "caps" | "proper"  => { rm-title-case $val }
        "lower"            => { $val | str downcase }
        "reverse"          => { name-reverse $val }
        "surname" | "last" => { name-surname $val }
        "first"            => { name-first $val }
        "shortened"        => { $val }    # undocumented — identity fallback
        _                  => { $val }
    }
}

# ── Name manipulation ────────────────────────────────────────────────────────

# Reverse name order: "Last, First Middle" → "First Middle Last".
# Handles semicolon-separated multi-value name fields.
def name-reverse [name: string] {
    $name | split row ";"
           | each {|n|
               let t = ($n | str trim)
               if ($t | str contains ",") {
                   let idx   = ($t | str index-of ",")
                   let last  = if $idx > 0 { $t | str substring 0..($idx - 1) | str trim } else { "" }
                   let given = ($t | str substring ($idx + 1).. | str trim)
                   if ($given | is-not-empty) { $"($given) ($last)" } else { $last }
               } else {
                   $t
               }
             }
           | str join ", "
}

# Extract surname from "Last, First Middle".
# For multi-value names, returns the first name's surname only.
def name-surname [name: string] {
    let first = ($name | split row ";" | first | str trim)
    if ($first | str contains ",") {
        let idx = ($first | str index-of ",")
        if $idx > 0 { $first | str substring 0..($idx - 1) | str trim } else { "" }
    } else {
        $first
    }
}

# Extract given name(s) from "Last, First Middle".
def name-first [name: string] {
    let first = ($name | split row ";" | first | str trim)
    if ($first | str contains ",") {
        let idx = ($first | str index-of ",")
        $first | str substring ($idx + 1).. | str trim
    } else {
        $first
    }
}

# ── Date and text helpers ─────────────────────────────────────────────────────

# Extract first 4-digit year from a date string.
def extract-year [s: string] {
    $s | parse --regex '(?<yr>\d{4})' | get --optional 0.yr | default ""
}

# Title-case: capitalize the first letter of each whitespace-separated word.
def rm-title-case [s: string] {
    $s | split row " "
       | each {|w|
           if ($w | str length) > 0 {
               let f = ($w | str substring 0..0 | str upcase)
               let r = if ($w | str length) > 1 { $w | str substring 1.. } else { "" }
               $"($f)($r)"
           } else { $w }
         }
       | str join " "
}

# ── Post-processing ───────────────────────────────────────────────────────────

# Clean up punctuation artifacts left by suppressed conditional blocks.
# Handles the most common cases: double commas, orphaned commas before
# closing punctuation, and empty parentheses.
def cleanup-punct [s: string] {
    $s
    | str replace --all --regex ',\s*,'     ','    # double comma
    | str replace --all --regex ',\s*\.'    '.'    # comma before period
    | str replace --all --regex ',\s*;'     ';'    # comma before semicolon
    | str replace --all --regex ';\s*;'     ';'    # double semicolon
    | str replace --all --regex ',\s*\)'    ')'    # comma before close-paren
    | str replace --all --regex '\(\s*:'    '('    # open-paren then colon
    | str replace --all --regex '\(\s*,\s*' '('    # open-paren then comma
    | str replace --all --regex '\(\s*\)'   ''     # empty parens
    | str replace --all --regex '\s{2,}'    ' '    # multiple spaces
    | str replace --all --regex '\s+\.'     '.'    # space before period
    | str replace --all --regex '\s+,'      ','    # space before comma
    | str replace --all --regex '\s+;'      ';'    # space before semicolon
    | str trim
}
