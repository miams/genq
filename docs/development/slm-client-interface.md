# SLM Client Interface Design — Lessons from Claude Code

> **Context**: This document covers how to design the genq client-side interface to a genealogy
> SLM — specifically, how to structure the conversation loop, tool execution, streaming, error
> handling, and UX. Patterns are drawn from Claude Code's architecture (analyzed April 2026).
>
> Sister document: `slm-training-patterns.md` covers the model training side.

---

## 1. The Fundamental Architecture: Conversation Loop

Claude Code's core is a **conversation loop**, not a single-shot query. The genq SLM interface
should follow the same pattern:

```
User input
    ↓
Send to SLM (with system prompt + conversation history)
    ↓
SLM responds with text AND/OR tool calls
    ↓
If tool calls present:
    Execute each tool call against genq
    Collect results
    Append results to conversation as "tool result" messages
    Send back to SLM
    Repeat from "SLM responds"
If no tool calls:
    Display final text response to user
    Wait for next user input
```

This loop continues until the SLM produces a response with no tool calls. This is different from
a simple "ask genq a question, get an answer" design — the model may need 3-5 tool calls to
answer a complex genealogical question.

### Nushell Implementation Sketch

```nushell
# Pseudocode for the conversation loop
def genq-chat [] {
    mut history = []
    loop {
        let user_input = (input "You: ")
        $history = ($history | append {role: "user", content: $user_input})

        mut response = (slm-call $history)

        # Tool call loop
        while ($response | has-tool-calls) {
            let tool_calls = ($response | extract-tool-calls)
            let tool_results = ($tool_calls | each { |call|
                execute-genq-command $call.command $call.args
            })
            $history = ($history
                | append {role: "assistant", content: $response}
                | append {role: "tool", content: $tool_results})
            $response = (slm-call $history)
        }

        print $"Assistant: ($response.text)"
        $history = ($history | append {role: "assistant", content: $response.text})
    }
}
```

---

## 2. Message Protocol Design

Claude Code uses a typed message protocol with UUIDs and timestamps. For genq, adopt a simpler
but still structured approach:

### Message Types

```nushell
# Message record structure
{
    uuid: string        # Unique identifier (for tracking, logging)
    timestamp: string   # ISO 8601
    role: string        # "user" | "assistant" | "tool_result" | "system"
    content: any        # String for user/assistant; record for tool results
    metadata: record    # Tool name, execution time, error state, etc.
}
```

### What Goes in Conversation History vs. What Gets Stripped

Claude Code separates **display messages** (what the user sees) from **API messages** (what gets
sent to the model). Apply this distinction in genq:

| Message type | Send to SLM? | Show to user? |
|---|---|---|
| User text input | Yes | Yes |
| SLM text response | Yes (as history) | Yes |
| Tool call (from SLM) | Yes (as history) | Show as "running genq..." |
| Tool result (from genq) | Yes | Show optionally (verbose mode) |
| Progress/status messages | No | Yes (spinner, progress bar) |
| Debug/trace messages | No | No (log file only) |
| System prompt | Yes (first message only) | No |

**Key rule**: Never drop conversation history mid-session. The SLM needs full context.
Context compaction (summarizing old history to save tokens) is an advanced optimization;
don't implement it until basic looping works reliably.

---

## 3. Tool Schema Design

Claude Code exposes tools to the model via JSON Schema definitions. Each tool definition has:
- A `name` the model uses to invoke it
- A `description` that shapes when the model chooses it
- An `input_schema` that constrains what arguments the model can pass

For genq, design SLM-facing tool schemas that differ from the raw Nushell command signatures.
The SLM-facing schema should be **simpler and more forgiving** than the underlying command.

### Example: genq list people → SLM Tool

```json
{
  "name": "search_people",
  "description": "Search for people in the RootsMagic database by name.
                  Use this to find a person's RIN before querying their records.
                  Always search by name when the user hasn't provided a RIN.",
  "input_schema": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "Full or partial name to search. Case-insensitive.
                        Examples: 'Smith', 'John Smith', 'Johann Schmitt'"
      },
      "surname_only": {
        "type": "boolean",
        "description": "Search surname field only. Default: false (searches given + surname)."
      },
      "include_alternates": {
        "type": "boolean",
        "description": "Include alternate names (maiden names, AKAs). Default: false."
      }
    },
    "required": ["name"]
  }
}
```

### Example: genq list events → SLM Tool

```json
{
  "name": "get_person_events",
  "description": "Get all recorded life events for a specific person.
                  Requires a RIN. Use search_people first if you only have a name.
                  Returns events sorted chronologically.",
  "input_schema": {
    "type": "object",
    "properties": {
      "rin": {
        "type": "integer",
        "description": "Record Identification Number (PersonID) of the target person."
      },
      "event_type": {
        "type": "string",
        "enum": ["BIRT", "DEAT", "MARR", "CENS", "RESI", "OCCU", "all"],
        "description": "Filter to specific event type. Default: 'all'.
                        BIRT=birth, DEAT=death, MARR=marriage, CENS=census,
                        RESI=residence, OCCU=occupation."
      }
    },
    "required": ["rin"]
  }
}
```

### Schema Design Principles

1. **Name tools by intent, not by command name**: `search_people` not `genq_list_people`
2. **Use enums** for constrained fields — models respect enums well
3. **Make `required` minimal** — the model will hallucinate required fields it doesn't have
4. **Write descriptions for the model, not the user** — include when/why to use this tool
5. **Accept looser types** — accept both `42` and `"42"` for RIN; normalize in the bridge layer

---

## 4. The Tool Execution Bridge

Between the SLM's tool calls and actual genq execution, you need a **bridge layer** that:

1. Validates and normalizes SLM output
2. Maps SLM tool names to genq commands
3. Handles errors gracefully and formats them for the SLM
4. Enforces safety constraints (read-only, no destructive commands)

```nushell
# Bridge: maps SLM tool calls to genq commands
def execute-slm-tool-call [tool_name: string, args: record] -> string {
    match $tool_name {
        "search_people" => {
            let name = ($args.name? | default "")
            let flags = if ($args.include_alternates? | default false) { "--all-names" } else { "" }
            genq list people | where ($it.Given + " " + $it.Surname | str contains $name)
        }
        "get_person_events" => {
            let rin = ($args.rin | into int)  # normalize string "42" to int 42
            genq list events --rin $rin
        }
        "get_census_records" => {
            let rin = ($args.rin | into int)
            genq census RIN $rin
        }
        _ => {
            error make {msg: $"Unknown tool: ($tool_name)"}
        }
    }
    | to json  # Always return structured JSON to SLM
}
```

### Error Formatting for the SLM

When a genq command fails, format the error to help the SLM recover:

```nushell
def format-tool-error [tool_name: string, error: string, input: record] -> string {
    $"Tool '($tool_name)' failed.\n" +
    $"Error: ($error)\n" +
    $"Input provided: ($input | to json)\n" +
    (match $tool_name {
        "get_person_events" => "Hint: Verify the RIN is valid with search_people first.",
        "get_census_records" => "Hint: This person may have no census records in the database.",
        _ => "Hint: Check the input parameters and try again."
    })
}
```

**Claude Code lesson**: Errors tell the model what failed, why, and how to recover. A bare error
string leaves the model guessing. A structured error message with a hint produces self-correction.

---

## 5. Streaming and Progress Display

Claude Code streams model output token-by-token and displays progress for long-running tool calls.
For a genealogy SLM, streaming matters less (responses are shorter), but tool-call progress matters.

### Progress Pattern

Some genq queries are slow (large databases, complex JOINs). Show progress:

```nushell
# While executing a slow tool call, show a spinner
def with-progress [message: string, block: closure] {
    print $"  ⟳ ($message)..."
    let result = (do $block)
    print $"\r  ✓ ($message)   "
    $result
}

# Usage in bridge layer
with-progress "Searching census records for RIN 42" {
    genq census RIN 42
}
```

### Streaming SLM Response Text

If your SLM supports streaming, display text as it arrives rather than waiting for completion.
This makes the interface feel responsive even when the model is generating a long explanation.

```nushell
# Pseudocode: stream SLM output
def stream-slm-response [stream: any] {
    for chunk in $stream {
        if ($chunk.type == "text_delta") {
            print -n $chunk.text  # Print without newline, as it arrives
        } else if ($chunk.type == "tool_call") {
            print ""  # End current line
            execute-tool-call $chunk
        }
    }
    print ""  # Final newline
}
```

---

## 6. Context Window Management

Claude Code implements **context compaction** — when the conversation history grows too large,
it summarizes old turns to free up token budget. For a small language model, this is critical
because SLMs have smaller context windows than large models.

### Strategy: Session Summarization

When conversation history approaches the context limit:

```
1. Keep last N turns verbatim (recent context is most important)
2. Summarize earlier turns into a "session summary" block:
   - What person(s) are being researched (name + RIN)
   - Key facts established so far
   - Outstanding questions / research gaps
   - Tools already run (avoid re-running same queries)
3. Replace old turns with the summary in the history sent to SLM
4. Always keep the original full history in local storage for the user's reference
```

### Session Context Block (inject when resuming)

```
[SESSION_SUMMARY]
Researching: Margaret Eleanor Iiams (RIN 203)
Established:
  - Birth: abt 1872, Coshocton County, Ohio (1880 census, RIN=203)
  - Father: Joseph Iiams (RIN 87), Mother: Sarah Hoskins (RIN 88)
  - 1900 census: not yet found
  - Death: unknown — no death record in database
Outstanding questions:
  - What happened after 1880? (marriage? moved?)
  - Is there a death certificate in Ohio vital records?
Tools already run:
  - search_people("Iiams"), get_person_events(203), get_census_records(203)
```

This block replaces potentially hundreds of tokens of raw conversation history with a compact,
semantically rich summary that gives the SLM exactly what it needs.

---

## 7. Permission and Safety Model

Claude Code has a sophisticated permission system. For genq's SLM, implement a simpler version:

### Read-Only Enforcement

genq is already read-only by design. Make this explicit in the SLM interface:

```
SYSTEM: You have READ-ONLY access to the database. You cannot add, modify,
or delete records. If the user asks you to edit data, explain that genq is
a query tool and direct them to RootsMagic for data entry.
```

### Scope Limiting

For privacy reasons (genealogy databases contain living persons), consider limiting what the SLM
can retrieve:

```nushell
# Bridge layer: filter out living persons
def safe-person-results [results: table] -> table {
    $results | where DeathYear != null or BirthYear < (date now | format date "%Y" | into int) - 110
}
```

### User Confirmation for Expensive Operations

Some operations are slow and expensive (full database scans). Prompt for confirmation:

```nushell
# Before running a query that will scan all 50,000+ records:
if ($estimated_row_count > 10000) {
    let confirm = (input $"This query will scan (~($estimated_row_count)) records. Continue? [y/N] ")
    if $confirm != "y" { return null }
}
```

---

## 8. CLI UX Patterns from Claude Code

### Fast-Path vs. Full-Path Architecture

Claude Code's CLI has immediate response paths that bypass full initialization:

```
genq ai --version  → immediate response, no SLM loaded
genq ai --help     → immediate response, no SLM loaded
genq ai "..."      → full initialization, conversation loop
```

Apply this to the SLM subcommand:

```nushell
def "genq ai" [
    query?: string   # Optional: single-shot query mode
    --interactive    # Force interactive mode
    --verbose        # Show tool calls and results
    --no-stream      # Wait for complete response (default: stream)
] {
    if ($query | is-empty) and not $interactive {
        print "Usage: genq ai <query>  or  genq ai --interactive"
        return
    }

    if ($query | is-not-empty) and not $interactive {
        # Single-shot mode: one question, one answer, exit
        single-shot-query $query
    } else {
        # Interactive mode: full conversation loop
        interactive-chat-loop
    }
}
```

### Verbose Mode for Debugging

Show tool calls and results when `--verbose`:

```
# Normal output:
Assistant: Margaret Iiams (RIN 203) was born around 1872 in Coshocton County, Ohio.

# Verbose output:
[Tool call] search_people(name="Margaret Iiams")
[Tool result] 2 matches found: RIN 203 (b.1872), RIN 441 (b.1901)
[Tool call] get_person_events(rin=203, event_type="BIRT")
[Tool result] Birth event: abt 1872, Coshocton Co., Ohio. Source: 1880 Census.
Assistant: Margaret Iiams (RIN 203) was born around 1872 in Coshocton County, Ohio.
```

This is invaluable during development and for power users who want to verify the SLM's reasoning.

### History Persistence

Save conversation history between sessions:

```nushell
# Save session on exit
def save-session [history: list, session_file: path] {
    $history | to json | save $session_file
}

# Load on startup
def load-session [session_file: path] -> list {
    if ($session_file | path exists) {
        open $session_file | from json
    } else {
        []
    }
}
```

Allow users to resume: `genq ai --resume` or `genq ai --resume my-iiams-research`.

---

## 9. Output Formatting

Claude Code's TUI renders rich output with colors, tables, and interactive elements. For genq's
SLM interface, align with genq's existing Nushell table output style.

### Principle: SLM Text + Structured Data

The SLM should produce **prose explanations**, while tool results produce **structured tables**.
Don't try to make the SLM produce markdown tables — let Nushell render the data.

```
# Good output pattern:
Assistant: I found 3 census appearances for John Iiams. Here are the records:
[Nushell table rendered from tool result]
│ Year │ Location          │ Age │ Occupation │ Household members        │
│ 1870 │ Coshocton Co., OH │ 28  │ Farmer     │ Sarah (wife), 2 children │
│ 1880 │ Coshocton Co., OH │ 38  │ Farmer     │ Sarah, 5 children        │
│ 1900 │ Licking Co., OH   │ 58  │ Retired    │ Sarah, 1 child           │

The 10-year gap between 1880 and 1900 suggests the family moved to Licking County
sometime in the 1880s or 1890s. No 1890 census record is expected — those records
were destroyed in a 1921 fire.
```

---

## 10. Recommended Implementation Sequence

Based on Claude Code's architecture, build in this order:

**Phase 1: Skeleton**
1. Single-shot SLM call (no looping, no tool use)
2. Basic conversation history accumulation
3. `--verbose` flag to see raw SLM output

**Phase 2: Tool Loop**
4. Parse tool calls from SLM output
5. Execute genq commands from tool calls
6. Feed results back into conversation
7. Loop until no more tool calls

**Phase 3: UX Polish**
8. Spinner/progress for slow queries
9. Streaming SLM text output
10. Session save/resume

**Phase 4: Robustness**
11. Context window management / session summarization
12. Error recovery (bad RIN, empty results, ambiguous names)
13. Verbose mode with tool call display
14. Single-shot mode (`genq ai "who are the children of RIN 42?"`)

**Phase 5: SLM Specialization**
15. Fine-tune SLM on genealogy + genq tool use corpus
16. A/B test instruction variants
17. Iterate on tool descriptions based on failure log

---

## Summary: Interface Design Principles

1. **Use a conversation loop**, not single-shot queries — genealogy research is multi-step
2. **Separate display messages from API messages** — the SLM only sees its own conversation
3. **Bridge layer normalizes SLM output** — accept loose types, normalize before execution
4. **Format errors for SLM recovery** — include what failed, why, and how to fix it
5. **Show progress** for slow tool calls — genealogy databases can be large
6. **Manage context proactively** — SLMs have smaller windows; summarize old turns
7. **Enforce read-only in the bridge**, not just in the prompt — defense in depth
8. **Match genq's existing output style** — SLM prose + Nushell table rendering
9. **Build verbose mode from day one** — you'll need it for debugging
10. **Start simple** (single-shot) and iterate toward full conversation loop
