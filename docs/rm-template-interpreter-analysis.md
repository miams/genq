# RootsMagic Source Template Interpreter — Implementation Analysis

**Date:** 2026-04-14  
**Author:** Michael Iams / Claude Code  
**Scope:** Full implementation feasibility of a RM10 source template interpreter in Nushell, enabling `genq list sources --all` to emit rendered Footnote, ShortFootnote, and Bibliography text for template-based sources.

---

## Background

RootsMagic stores sources in two flavors:

| Flavor | `TemplateID` | `Fields` XML |
|--------|-------------|-------------|
| Free-form | `0` | Contains `Footnote`, `ShortFootnote`, `Bibliography` directly as field values — ready to display |
| Template-based | `> 0` | Contains named data values (Author, Title, PubDate, …) — must be rendered through a format string |

The format strings live in `SourceTemplateTable.Footnote`, `.ShortFootnote`, and `.Bibliography`. There are **433 templates** in the Iiams database, covering 113 sources. The most-used template in the Iiams DB is `_Book, General (Author(s) known) (mdi)` with 35 sources.

---

## The Template Language

### 1. Field References

```
[FieldName]
[FieldName:Modifier]
[FieldName:Modifier1:Modifier2]
```

The `FieldName` matches the `<Name>` keys in the source's `Fields` XML blob. Example:

Template: `[Author]<, [Role]>, <i>[Title]</i>, [Page].`  
Fields: `Author=Weaver, Michael E.`, `Title=Guard Wars`, `Page=42`  
Output: `Weaver, Michael E., <i>Guard Wars</i>, 42.`

---

### 2. Modifiers

Applied with `:` after the field name. Multiple modifiers chain left to right.

| Modifier | Applies to | Behavior |
|----------|-----------|----------|
| `:Year` | Date | Extract 4-digit year: `"2010"` → `"2010"`, `"15 Apr 1942"` → `"1942"` |
| `:Abbrev` | Text, Name | Use the **short form** after `\|\|` in the value; fall back to full value if no `\|\|` present |
| `:Caps` | Text | Title-case every word |
| `:Lower` / `:lower` | Text | Lowercase entire string |
| `:Proper` | Text | Title-case (same as `:Caps` in practice) |
| `:Reverse` | Name | `"Last, First Middle"` → `"First Middle Last"` |
| `:Surname` / `:Last` | Name | Extract surname: `"Weaver, Michael E."` → `"Weaver"` |
| `:First` | Name | Extract given name: `"Weaver, Michael E."` → `"Michael E."` |
| `:Shortened` | Text | Truncate to a shortened form — exact rule **undocumented** (appears once in 433 templates) |

**Case inconsistency:** RM templates use both `:Year` and `:year`, `:Lower` and `:lower`, `:Reverse` and `:reverse`. The interpreter must treat modifier names case-insensitively.

**Chaining example:** `[Edition:Lower:Abbrev]` — lowercase the value, then apply abbreviation. `[ItemType:Abbrev:Caps]` — take abbreviated form, then title-case it.

---

### 3. Double-Bar `||` in Field Values

Fields with type `Text` or `Name` can contain a full form and a short form separated by `||`:

```
Title=Guard Wars: the 28th Infantry Division in World War II||Guard Wars
Page=p. 23||23
```

- Plain `[Title]` → `Guard Wars: the 28th Infantry Division in World War II`
- `[Title:Abbrev]` → `Guard Wars`
- Plain `[Page]` → `p. 23`
- `[Page:Abbrev]` → `23`

The `||` split must be applied **before** other modifiers in the chain.

---

### 4. Multi-Value Name Fields

Name-type fields can contain semicolon-separated names:

```
Author=Doe, John;Smith, Bill;Jones, David
```

RM's rendering appears to join them with commas and a final "and". The exact separator
for `:Reverse` and `:Surname` on multi-value fields (e.g. "John Doe, Bill Smith, and David Jones"
vs. "Doe, Smith, and Jones") is undocumented and must be verified empirically.

---

### 5. Conditional Sections

This is the most complex part of the grammar. There are three distinct forms.

#### 5a. Simple conditional: `<content>`

```
<, [Role]>
<[PubPlace]: >
```

Rendered **only if every field reference inside is non-empty**. If any referenced field is empty, the entire `<...>` block (including surrounding punctuation) is suppressed.

Example: `[Author]<, [Role]>, <i>[Title]</i>`  
If `Role` is empty: `Weaver, Michael E., <i>Guard Wars</i>` (the `, ` disappears with the block).

#### 5b. Default-value conditional: `<[Field]|default>`

```
<[PubPlace]|N.p.>
<[Publisher]|n.p.>
<[PubDate]|n.d.>
<[AccessType]|accessed>
```

If `Field` is non-empty, use the field value. If empty, use the literal default text after `|`.  
This is always rendered (never fully suppressed), just substituted.

#### 5c. Ternary conditional: `<?[Field]|if-present|if-absent>`

```
<?[ItemTitle]|"[ItemTitle]," <[ItemType:Lower:Abbrev], >|<[ItemType:Lower:Abbrev]|database>, >
<?[DatabaseTitle]|"[DatabaseTitle]," <[ItemType:lower:Abbrev]|database>, <i>[WebsiteTitle]</i>|<i>[WebsiteTitle]</i>, <[ItemType:lower:Abbrev]|database>>
```

If `Field` is non-empty, render the `if-present` branch; otherwise render `if-absent`. Both branches can themselves contain nested field refs, modifiers, simple conditionals, and default-value conditionals.

The `if-absent` branch is **optional** — some ternaries have only one branch:

```
<?[CreditLine]|; [CreditLine]>
<?[Conference]|, [Sponsor], [Conference]: [ConfLoc], [Year]>
```

When omitted and the field is absent, nothing is rendered.

---

### 6. HTML Markup

Four HTML tags appear inline in format strings, mixed with the conditional `<...>` syntax:

| Tag | Count | Meaning |
|-----|-------|---------|
| `<i>` | 624 | Italic (book/journal title) |
| `</i>` | 624 | Close italic |
| `<sc>` | 115 | Small caps |
| `</sc>` | 115 | Close small caps |

**Disambiguation rule:** HTML tags are always lowercase ASCII letters only (`<i>`, `<sc>`). Conditional sections always start with `[` or `?`. The parser can reliably distinguish them by inspecting the first character after `<`.

For plain-text output these tags should be stripped. For HTML output they can be preserved or translated (e.g., `<sc>` → CSS small-caps span).

---

### 7. Literal Brackets

Some templates contain `[TEXT]` that is **not** a field reference — it is meant to appear literally in the output:

```
Template 3: The Church of Jesus Christ of Latter-day Saints [LDS], "Ancestral File," ...
Category fields: [EE, sec 7.32, p 346-7]
```

The FieldDefs for template 3 defines no field named `LDS`. The safe handling rule: **if `[NAME]` does not match any key in the source's Fields XML, output it literally as `[NAME]`**.

---

### 8. The `</[[Field]/]` Construct

Appears in exactly **one** template (template 15, `Book, General (Author(s) unknown or unidentified)`):

```
</[[Author]/], ><i>[Title]</i> ...
```

This renders `Author, ` only if Author is non-empty — functionally equivalent to `<[Author], >`. The `/` characters appear to be an RM-internal escape for an optional author attribution that can be suppressed entirely. It is the only instance in 433 templates.

**Recommendation:** Handle it as a special-case alias for `<[Author], >` detected by the `/]` suffix pattern.

---

### 9. XML Entity Encoding

Field values in the `Fields` blob are XML-encoded:

| Encoded | Decoded |
|---------|---------|
| `&quot;` | `"` |
| `&amp;` | `&` |
| `&lt;` | `<` |
| `&gt;` | `>` |
| `&apos;` | `'` |

Nushell's `from xml` handles this automatically. Values extracted via the XML parser will already be decoded.

---

### 10. Punctuation Cleanup

When conditional blocks are suppressed, residual punctuation can accumulate:

- Double commas: `Smith, , <i>Title</i>` (when Role is empty and the pattern is `[Author], [Role], <i>[Title]</i>`)
- Trailing commas before closing parens: `(N.p.: n.p., )` when PubDate is absent but outside a conditional
- Leading/trailing spaces from suppressed blocks

RM's actual engine must perform post-processing to collapse these artifacts. The exact rules are undocumented but empirically the most common cases are:
- `, ,` → `,`
- ` ,` → `,`
- `, )` → `)`
- `( :` → `(`
- Multiple spaces → single space

---

## Implementation Plan

### Data Flow

```
SourceTable.Fields (XML)  →  parse fields dict  →  { Author: "Weaver, ...", Title: "...", ... }
SourceTemplateTable.Footnote (format string)  →  tokenizer  →  AST  →  evaluator(fields dict)  →  rendered string
```

### Parser (Tokenizer + AST)

The grammar is not recursive in the field-reference sense but conditionals can be nested. A recursive descent parser is the right approach.

**Token types:**
1. `Literal(text)` — plain text (including HTML tags)
2. `Field(name, [modifiers])` — `[FieldName:Mod:Mod]`
3. `Conditional(blocks)` — `<...>` with sub-AST
4. `DefaultConditional(field, modifiers, default_text)` — `<[Field:Mod]|default>`
5. `TernaryConditional(field, modifiers, if_present_ast, if_absent_ast_or_null)` — `<?[Field]|...|...>`

**Parsing `<...>` blocks:** After encountering `<`, inspect next character:
- `?` → TernaryConditional
- `/` → HTML close tag or the `</[` special construct
- lowercase letter → HTML open tag (literal, pass through)
- `[` → DefaultConditional if contains `|`, else SimpleConditional
- anything else → SimpleConditional

### Evaluator

```
def eval(ast, fields):
    for node in ast:
        match node:
            Literal(t) → emit t
            Field(name, mods) → apply_mods(lookup(fields, name), mods)
            Conditional(sub_ast) →
                if all fields referenced in sub_ast are non-empty:
                    emit eval(sub_ast, fields)
            DefaultConditional(name, mods, default) →
                val = lookup(fields, name)
                emit (if val != "" then apply_mods(val, mods) else default)
            TernaryConditional(name, mods, present_ast, absent_ast) →
                if lookup(fields, name) != "":
                    emit eval(present_ast, fields)
                else if absent_ast:
                    emit eval(absent_ast, fields)
```

### Modifier Pipeline

```
def apply_mods(value, modifiers):
    # Split full||short first
    parts = value | split row "||"
    full = parts.0
    short = parts.1? | default full

    for mod in modifiers (case-insensitive):
        match mod:
            "abbrev"   → value = short
            "year"     → value = extract_year(value)
            "caps"     → value = title_case(value)
            "lower"    → value = $value | str downcase
            "proper"   → value = title_case(value)
            "reverse"  → value = name_reverse(value)   # "Last, First" → "First Last"
            "surname"  → value = name_surname(value)   # "Last, First" → "Last"
            "last"     → value = name_surname(value)
            "first"    → value = name_first(value)
            "shortened"→ value = value  # fallback: identity (semantics unknown)
    value
```

### Language Implementation in Nushell

Nushell does not have a built-in parser combinator or regex engine powerful enough for nested conditionals. The implementation options are:

**Option A — Pure Nushell recursive parser**  
Feasible but verbose. Nushell closures cannot be recursive (no named self-reference), so recursion must be unrolled via a stack or depth limit. Nested ternary conditionals (max observed depth: ~3 levels) are manageable with an explicit stack.

**Option B — Delegate to `nu-script` subprocess calling an embedded Python/JS snippet**  
Cleanest for complex parsing. A small Python script embedded as a heredoc could handle tokenization and emit JSON; Nushell then processes the JSON. Adds a Python dependency.

**Option C — SQLite-only approach**  
Not feasible. SQLite's string functions cannot handle the recursive conditional grammar.

**Recommendation: Option A** — pure Nushell, depth-limited recursive descent (max 4 levels covers all observed templates), stack-based. No external dependencies.

---

## Identified Blockers

### Blocker 1 — `:Shortened` modifier is undefined

**Severity: Minor**  
`:Shortened` appears in `[Series:Shortened]` in exactly one template. Its exact truncation rule (character limit? sentence? word count?) is not documented in the RM schema or any RM developer resource found. The safe fallback (identity — return value unchanged) will produce readable but potentially long output. Does not block implementation.

### Blocker 2 — Multi-value Name field join rule is undocumented

**Severity: Minor**  
When `Author=Doe, John;Smith, Bill;Jones, David`, how RM joins the names for display (comma vs. semicolon, with/without "and") is not specified. Can be verified empirically by building a test source in RM with multiple authors and comparing output. Does not block implementation, but output may differ from RM's own display for multi-author sources until verified.

### Blocker 3 — Punctuation cleanup has no canonical rule

**Severity: Moderate**  
The most impactful correctness gap. When conditional blocks are omitted, the output can have dangling commas, double spaces, or empty parentheses. RM's actual cleanup rules are not documented. A heuristic cleanup pass (collapse `" , "` → `", "`, remove `"()"`, etc.) can cover 95%+ of real cases, but edge cases will differ from RM's display for sources with many empty optional fields.

### Blocker 4 — `<?...>` ternary branch content parsing is ambiguous at `|` boundaries

**Severity: Moderate (solvable)**  
The ternary `<?[Field]|branch1|branch2>` uses `|` as a delimiter, but `branch1` and `branch2` can themselves contain `<[Field]|default>` default conditionals which also use `|`. A naïve split on `|` will misparse these. The parser must track angle-bracket depth when splitting ternary branches.

Example:
```
<?[DatabaseTitle]|"[DatabaseTitle]," <[ItemType:lower:Abbrev]|database>, <i>[WebsiteTitle]</i>|<i>[WebsiteTitle]</i>>
```
Naïve `|` split produces 3 parts. Depth-aware split produces 2 (the `|database>` belongs to the inner `<[ItemType]|database>` default conditional, not the ternary boundary).

This is solvable with depth tracking. Not a true blocker.

### Blocker 5 — No impossible blockers identified

**Severity: None**  
There are no constructs in the 433 templates that are fundamentally non-parseable or require information unavailable in the database. Every piece of information needed to render a citation (field values, template format strings, field type metadata for Name handling) is present in the two tables.

---

## Scope and Effort Estimate

| Component | Complexity | Notes |
|-----------|-----------|-------|
| XML field value parser | Low | Nushell `from xml` does the heavy lifting |
| Tokenizer (literals, fields, HTML) | Low | Linear scan |
| Simple + default conditionals | Medium | Depth tracking for `\|` splits |
| Ternary conditionals | Medium-High | Nested content, depth-aware `\|` split |
| Modifier pipeline | Medium | 10 modifiers, case-insensitive, chainable |
| Name type handling (Reverse, Surname) | Medium | Semicolon multi-value, "Last, First" format |
| Date type handling (Year) | Low | Extract 4-digit year |
| `\|\|` full/short split | Low | `str split "||"` |
| HTML tag stripping (plain text output) | Low | Strip `<i>`, `</i>`, `<sc>`, `</sc>` |
| Punctuation cleanup | Medium | Heuristic; may have edge cases |
| `</[[Field]/]` special construct | Low | Single template, alias to `<[Field], >` |
| Literal `[NAME]` fallback | Low | Check against field dict |
| Integration into `genq list sources --all` | Low | Add columns to existing query |

**Estimated total:** 200–350 lines of Nushell across a `template-engine.nu` module.

---

## Recommended Deliverable Structure

```
src/lib/common/genq list sources/
  mod.nu                     # existing — add --all rendering call
  template-engine.nu         # new — tokenizer + evaluator
tests/
  test_template_engine.nu    # new — unit tests per modifier and conditional form
```

The template engine should be a standalone module with a single public function:

```nushell
# Render a RM source template format string against a field dict.
# Returns the rendered string.
export def render-template [
    format_string: string   # e.g. SourceTemplateTable.Footnote
    fields: record          # parsed from SourceTable.Fields XML
    --plain-text            # strip <i> and <sc> HTML tags from output
] -> string
```

This keeps it independently testable and reusable for citation-level rendering (CitationTable uses the same template system for the `Footnote`/`ShortFootnote` fields).

---

## Conclusion

A full template interpreter is **feasible in pure Nushell**. There are no impossible blockers. The hardest parts are depth-aware `|` parsing inside ternary conditionals and punctuation cleanup after omitted blocks, both of which are engineering problems with known solutions.

The output for most sources will be identical or near-identical to what RM displays. Edge cases (undocumented `:Shortened` modifier, multi-author join style, complex punctuation cleanup) will produce readable approximations that diverge from RM in cosmetic ways only.
