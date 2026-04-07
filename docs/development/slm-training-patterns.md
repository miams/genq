# SLM Training Patterns — Lessons from Claude Code

> **Context**: This document distills architectural patterns from Anthropic's Claude Code source
> (analyzed April 2026) to guide the training and fine-tuning of a small language model (SLM)
> specialized for genealogy content and genq tool use. Claude Code is the most deeply engineered
> open-source-adjacent LLM CLI available; its patterns represent years of observing where models
> fail in agentic settings and encoding the fixes.

---

## 1. The Two-Layer Reality of Model Capability

Claude Code makes an important distinction that should inform SLM design:

| Layer | What it provides | How to influence |
|---|---|---|
| **Base model weights** | Can use tools at all; generates valid JSON; chains tool calls; understands schemas | Training data + fine-tuning |
| **Runtime instructions** | Which tool to pick; when to parallelize; safety protocols; domain-specific behavior | System prompt + tool descriptions |

**Implication for genq's SLM**: You cannot prompt-engineer a model into competent tool use if the
base model hasn't seen tool-use training data. But equally, a capable base model will behave badly
without good runtime instruction. Both layers require investment.

The split in practice:
- "Can the model call a genq command at all?" → training problem
- "Does it prefer `genq list people` over a raw SQL query?" → instruction problem
- "Does it know RIN means Record Identification Number?" → training problem
- "Does it format dates in RootsMagic format?" → can be either, prefer instruction

---

## 2. Domain Vocabulary Must Be in the Weights

Claude Code's model performs well on coding tasks because coding vocabulary, idioms, and patterns
are saturated in its training data. For a genealogy SLM, this saturation doesn't exist in general
models. You must deliberately add it.

### Genealogy-Specific Vocabulary to Include in Training Data

**Identifiers and data model concepts:**
- RIN (Record Identification Number) — the primary key for persons in RootsMagic
- GEDCOM field names: BIRT, DEAT, MARR, OCCU, RESI, CENS, etc.
- Source vs. citation vs. repository distinction
- Primary vs. alternate names
- Witness vs. principal relationship to an event
- Collateral vs. direct-line ancestry

**RootsMagic schema concepts:**
- PersonTable, NameTable, EventTable, FamilyTable, CitationTable, SourceTable
- The `OwnerID` foreign key pattern (events belong to persons via OwnerID)
- The `EventType` integer codes (birth=1, death=2, marriage=3, census=14, etc.)
- RootsMagic date encoding format (RDMF — packed integer representing date precision)

**Genealogical reasoning patterns:**
- FAN club analysis (Family, Associates, Neighbors) — census neighbors as research leads
- Cluster research — using relatives to find records for a target
- Reasonably exhaustive search — the standard of evidence evaluation
- Conflicting evidence resolution — when two sources disagree

### What Training Data Should Look Like

Training examples should show the SLM:

```
# Good training example: domain vocabulary → tool action
User: Who are the siblings of RIN 42?
Assistant: I'll query the family table to find all children who share a parent with RIN 42.
<tool_call>genq list children --family-of 42</tool_call>

# Good training example: genealogy reasoning → explanation
User: Why might census records show a different birth year than a death certificate?
Assistant: Census birth years are typically self-reported estimates, often rounded to the
nearest 5 years, and recorded by an enumerator who may have misheard. Death certificates
rely on an informant (often a child) who may not know the exact year. A 2-5 year discrepancy
is common and expected. The death certificate is generally considered more reliable for
the year, but a church baptism record would be authoritative.
```

---

## 3. Tool Descriptions Are Behavioral Specifications, Not Just Documentation

The most important insight from Claude Code: tool descriptions are not documentation for humans.
They are **behavioral specifications that shape model output at inference time**.

Claude Code's `BashTool/prompt.ts` is 370 lines. It encodes:
- Which other tools to prefer instead of Bash for common operations
- Exact protocols for multi-step operations (git commit: 4-step process)
- Safety guardrails ("NEVER run destructive commands without user confirmation")
- Anti-patterns to avoid ("do not retry in a sleep loop")

### Four Levels of Tool Description

For each genq command you expose to the SLM, write descriptions at four scales:

**Level 1 — Searchable one-liner** (for tool discovery):
```
"List all people in the RootsMagic database with optional alternate names"
```

**Level 2 — Parameter schema descriptions** (per-field guidance):
```
rin: "The Record Identification Number (PersonID) of the target person.
      Use genq list people to find RINs. Required for person-specific queries."

--all-names: "Include alternate names (AKA, married names, name changes).
              Default: false (primary name only)."
```

**Level 3 — Tool usage prompt** (strategic guidance, ~10-30 lines):
```
Use this command when the user asks about a specific person by name or RIN.
Prefer this over raw SQL — it handles the NameTable JOIN and COLLATE NOCASE automatically.
When the user gives a name but not a RIN, run genq list people first to find the RIN,
then run the target command. Never guess a RIN.
```

**Level 4 — Domain protocol** (multi-step workflows, safety rules, ~50+ lines):
```
# Researching a person
When asked to "find everything about" a person:
1. First run: genq list people to confirm identity and get RIN
2. If name is ambiguous (multiple matches), ask the user to clarify before proceeding
3. Then run genq list events --rin <N> to get their life events
4. Then run genq list citations --rin <N> to see evidence quality
5. Summarize what is known and what is missing (no birth record, no death record, etc.)

# Evidence evaluation
Never state a fact as certain if the only citation is a user-added note or a tree import.
Flag these: "This appears in the database but the source is [X] — verify independently."
```

### Apply This Pattern to genq Commands

| Command | Level 3-4 guidance to write |
|---|---|
| `genq list people` | Never guess RIN; always search by name first; explain ambiguous matches |
| `genq list events` | Explain EventType codes; note missing event types as research gaps |
| `genq list citations` | Distinguish source quality tiers (original vs. derivative vs. authored) |
| `genq census RIN` | Cross-reference neighbors for FAN club leads; note transcription errors |
| `genq list sources` | Explain source template fields; note XML-encoded metadata |

---

## 4. Error Messages Are Training Opportunities

Claude Code formats validation errors in a precise, teachable structure:
1. **What failed** — specific field and value
2. **Why it failed** — the rule that was violated
3. **How to fix it** — example of correct usage
4. **What to do next** — the recovery action

For a genealogy SLM, errors are common because:
- RINs get confused (user says "person 42" but means something else)
- Date formats vary (user types "1 Jan 1880" but database uses RDMF encoding)
- Name spelling varies (census vs. birth certificate vs. naturalization paper)

### Error Training Pattern

Include training examples that show the SLM recovering from errors:

```
# Training: model recovers from invalid RIN
Tool result: ERROR: No person found with RIN 9999.
             Database contains RINs 1-847.
Assistant: RIN 9999 doesn't exist in this database. Let me search by name instead.
<tool_call>genq list people | where Surname == "Smith"</tool_call>

# Training: model handles ambiguous name
Tool result: 3 people named "John Smith": RIN 12 (b.1832), RIN 156 (b.1871), RIN 203 (b.1904)
Assistant: I found 3 people named John Smith. Which one are you researching?
- RIN 12: John Smith, born approximately 1832
- RIN 156: John Smith, born approximately 1871
- RIN 203: John Smith, born approximately 1904
```

---

## 5. Instruction Sections Should Be Composable, Not Monolithic

Claude Code builds its system prompt from **independent sections** that are conditionally included
based on context. This is critical for a resource-constrained SLM where context window is limited.

### System Prompt Architecture for genq SLM

Design the system prompt as named, swappable sections:

```
[IDENTITY]
You are a genealogy research assistant with access to a RootsMagic database via genq commands.
You help researchers find, analyze, and evaluate genealogical records.
Current database: {db_name} ({record_count} people)
Today's date: {date}

[TOOL_LIST]
Available commands: (only include what's actually configured)
- genq list people — find persons by name or list all
- genq list events --rin N — get life events for a person
...

[DOMAIN_CONTEXT]  ← include only when doing research tasks
RootsMagic database schema overview:
- RIN = Record Identification Number (unique person ID)
- Events use GEDCOM type codes...

[EVIDENCE_STANDARDS]  ← include only when evaluating sources
Apply the Genealogical Proof Standard:
1. Reasonably exhaustive search
2. Complete and accurate citations
...

[SESSION_CONTEXT]  ← include only when continuing a session
Currently researching: {person_name} (RIN {N})
Known facts: {summary}
Outstanding questions: {questions}
```

**Key principle**: Don't include the evidence standards section when the user is just listing people.
Don't include session context on the first turn. Token budget is finite — use it contextually.

---

## 6. Schema Coercion: Models Return Adjacent Types

Claude Code uses `semanticNumber()` and `semanticBoolean()` coercers because models frequently
return `"42"` instead of `42`, or `"true"` instead of `true`. This is not a model failure — it's
a known characteristic of LLM output.

For genq's SLM, design input handling to accept:

| Expected | Also accept |
|---|---|
| RIN as integer (`42`) | `"42"`, `"RIN 42"`, `"person 42"` |
| Boolean flag (`true`) | `"yes"`, `"true"`, `"1"` |
| Date string (`"1880-01-01"`) | `"1 Jan 1880"`, `"January 1, 1880"`, `"abt 1880"` |
| GEDCOM event code (`"BIRT"`) | `"birth"`, `"born"`, `"Birth"` |

Build a preprocessing layer in genq that normalizes SLM output before executing commands.
This is more reliable than trying to enforce strict output format through prompting alone.

---

## 7. Train on Failure Modes, Not Just Success Paths

Claude Code's training data almost certainly includes examples of the model making mistakes and
then recovering. For a genealogy SLM, the most important failure modes to include:

**Hallucination of genealogical facts:**
```
# BAD (what the SLM should NOT do):
User: When did John Smith (RIN 42) die?
Assistant: John Smith died on March 15, 1891 in Chicago, Illinois.

# GOOD (what the SLM SHOULD do):
User: When did John Smith (RIN 42) die?
Assistant: Let me check the database.
<tool_call>genq list events --rin 42 | where EventType == "DEAT"</tool_call>
Tool result: No death event found for RIN 42.
Assistant: There's no death record for John Smith (RIN 42) in this database.
He may have died after the records were entered, or the death record may not
have been found yet. His last known record is [X].
```

**Confusing similar people:**
```
# Training: model disambiguates before proceeding
User: Show me census records for William Iiams.
Assistant: I found 4 people named William Iiams in the database.
Before I pull census records, which one?
[list them with birth years and locations]
```

**Over-confident source evaluation:**
```
# Training: model flags source quality appropriately
Tool result: Birth: 1 Jan 1856, Source: "Family Group Sheet (user-submitted)"
Assistant: The database shows a birth date of January 1, 1856, but the only
source is a user-submitted family group sheet — not an original record.
This date should be treated as a research lead, not a proven fact.
```

---

## 8. The Parallel Tool Call Pattern

Claude Code explicitly instructs the model to make parallel tool calls for independent operations.
This is a trained behavior pattern, not something general models do by default.

For genealogy research, parallel calls are common:
- Fetch events AND citations for a person simultaneously
- Look up both parents simultaneously when building a family view
- Run census query AND source quality check at the same time

Include training examples that show this:
```
User: Give me a complete profile of RIN 42.
Assistant: I'll gather all information simultaneously.
<tool_call>genq list events --rin 42</tool_call>
<tool_call>genq list citations --rin 42</tool_call>
<tool_call>genq list names --rin 42</tool_call>
[All three results arrive]
Assistant: Here's what I found about [Name] (RIN 42)...
```

---

## 9. Feature Flags as Training Data Variants

Claude Code uses feature flags to A/B test instruction variants — different versions of tool
descriptions are shipped to different users to measure which produces better behavior.

For SLM training, simulate this with **instruction variant datasets**:

Create multiple versions of key instructions and include them in training with labels:
- `[VARIANT_A]` — verbose, step-by-step instructions
- `[VARIANT_B]` — concise, principle-based instructions
- `[VARIANT_C]` — example-heavy instructions

Eval the fine-tuned model on genealogy benchmarks with each variant active.
This tells you which instruction style the model responds to best, and informs
how to write the production system prompt.

---

## 10. The "Wisdom in the Prompt Files" Insight

The most operationally important insight from Claude Code: the `prompt.ts` files contain
**accumulated institutional knowledge** about where models fail. Each rule in those files
represents a real failure that was observed and then encoded as an instruction.

For genq, maintain a similar living document: `docs/development/slm-failure-log.md`.

Every time the SLM:
- Hallucinates a genealogical fact
- Uses a wrong RIN
- Fails to distinguish between persons with the same name
- Interprets a date incorrectly
- Mistakes a source quality tier

...add the case to the failure log, then encode the fix as either:
1. A new instruction in the system prompt, OR
2. A new fine-tuning example

Over time, this log becomes the most valuable artifact in your SLM development process.

---

## Summary: Training Checklist

- [ ] Build a genealogy vocabulary corpus (GEDCOM, RootsMagic schema, research terminology)
- [ ] Write Level 1-4 descriptions for every genq command
- [ ] Include failure-mode training examples (disambiguation, hallucination prevention, source skepticism)
- [ ] Include parallel tool call examples for common multi-query research patterns
- [ ] Include error recovery examples (bad RIN, no results, ambiguous names)
- [ ] Build a semantic coercion layer for SLM output normalization
- [ ] Design composable system prompt sections (identity, tools, domain, evidence, session)
- [ ] Start a failure log from day one of testing
- [ ] A/B test instruction variants to find what the base model responds to best
