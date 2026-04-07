# AI Agent Architecture Review and Recommendations for `genq`

Date: 2026-04-03

## Executive Summary

This review covers two things:

1. The architecture and implementation tactics used in this Claude Code source snapshot.
2. A recommended design for a much smaller, local-first AI agent for [`genq`](/Users/miams/Code/genq), aimed at non-technical genealogy users on Apple Silicon hardware such as an Apple M3 Pro with 16GB RAM.

The main conclusion is straightforward:

- `genq` should copy Claude Code's conversation-loop, tool-schema, permission-gate, and stateful session patterns.
- `genq` should not copy Claude Code's overall system size, feature-flag sprawl, multi-agent complexity, or product/platform integrations.
- For `genq`, the right architecture is a narrow, deterministic, single-agent tool-calling assistant with strong schema normalization, explicit ambiguity handling, genealogy-specific retrieval, and a read-only execution bridge over curated `genq` commands.
- For local inference on an M3 Pro with 16GB RAM, the safest starting point is a quantized Qwen-family model in the 3B to 4B range, hosted with `mlx-lm` first and optionally `llama.cpp` or Ollama as alternate runtimes.

Assumption note: the request says "Gwen"; I am treating that as "Qwen". If you meant a different model family, the architectural recommendations still hold, but the model shortlist would change.

## What Was Analyzed

### Claude Code source snapshot

I reviewed the repo at [`/Users/miams/Code/claude-code-source-code-full`](/Users/miams/Code/claude-code-source-code-full), with emphasis on:

- Entrypoints and startup: [`src/entrypoints/cli.tsx`](/Users/miams/Code/claude-code-source-code-full/src/entrypoints/cli.tsx), [`src/main.tsx`](/Users/miams/Code/claude-code-source-code-full/src/main.tsx), [`src/replLauncher.tsx`](/Users/miams/Code/claude-code-source-code-full/src/replLauncher.tsx)
- Core agent loop: [`src/QueryEngine.ts`](/Users/miams/Code/claude-code-source-code-full/src/QueryEngine.ts), [`src/query.ts`](/Users/miams/Code/claude-code-source-code-full/src/query.ts)
- Tool contract and registry: [`src/Tool.ts`](/Users/miams/Code/claude-code-source-code-full/src/Tool.ts), [`src/tools.ts`](/Users/miams/Code/claude-code-source-code-full/src/tools.ts)
- Tool execution and orchestration: [`src/services/tools/toolExecution.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/tools/toolExecution.ts), [`src/services/tools/toolOrchestration.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/tools/toolOrchestration.ts)
- Permission path: [`src/hooks/useCanUseTool.tsx`](/Users/miams/Code/claude-code-source-code-full/src/hooks/useCanUseTool.tsx), [`src/hooks/toolPermission/handlers/interactiveHandler.ts`](/Users/miams/Code/claude-code-source-code-full/src/hooks/toolPermission/handlers/interactiveHandler.ts)
- Memory and background summarization: [`src/memdir/memdir.ts`](/Users/miams/Code/claude-code-source-code-full/src/memdir/memdir.ts), [`src/services/SessionMemory/sessionMemory.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/SessionMemory/sessionMemory.ts)
- Multi-agent patterns: [`src/coordinator/coordinatorMode.ts`](/Users/miams/Code/claude-code-source-code-full/src/coordinator/coordinatorMode.ts), [`src/tools/AgentTool/AgentTool.tsx`](/Users/miams/Code/claude-code-source-code-full/src/tools/AgentTool/AgentTool.tsx)

### `genq`

I also reviewed the local `genq` project at [`/Users/miams/Code/genq`](/Users/miams/Code/genq), especially:

- Main CLI entry: [`src/main.nu`](/Users/miams/Code/genq/src/main.nu)
- Existing config flow: [`src/lib/common/genq config/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20config/mod.nu), [`src/lib/common/genq config/wizard.nu`](/Users/miams/Code/genq/src/lib/common/genq%20config/wizard.nu)
- Representative commands: [`src/lib/common/genq list people/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20list%20people/mod.nu), [`src/lib/common/genq list events/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20list%20events/mod.nu)
- Existing planning docs: [`docs/development/slm-client-interface.md`](/Users/miams/Code/genq/docs/development/slm-client-interface.md), [`docs/development/slm-training-patterns.md`](/Users/miams/Code/genq/docs/development/slm-training-patterns.md)

## Architecture Review of Claude Code

## 1. The strongest pattern: the agent is a loop, not a prompt

Claude Code's key architectural idea is not "chat UI" or "tool list". It is the stateful turn loop:

- accept user input
- expand prompt context
- call the model
- detect tool calls
- execute tools
- append tool results as conversation state
- repeat until the model emits a final answer

That shape is visible in [`src/QueryEngine.ts`](/Users/miams/Code/claude-code-source-code-full/src/QueryEngine.ts) and delegated API/tool loop logic in [`src/query.ts`](/Users/miams/Code/claude-code-source-code-full/src/query.ts).

This is the single most reusable idea for `genq`.

Why it matters:

- Natural-language user requests are often underspecified.
- The model usually needs 2 to 5 tool invocations, not 1.
- Tool results become context for follow-up reasoning and clarification.
- Recovery from ambiguity or bad tool inputs becomes part of the same session.

For `genq`, this means the correct mental model is not "translate English to one Nushell command". It is "run a bounded tool-calling dialogue over a curated genealogy tool surface".

## 2. The second strongest pattern: tools are first-class contracts

Claude Code does not treat tools as ad hoc functions. Each tool has:

- name and behavioral prompt
- schema
- permission logic
- execution logic
- result mapping
- concurrency metadata

That is visible in [`src/Tool.ts`](/Users/miams/Code/claude-code-source-code-full/src/Tool.ts), the registry in [`src/tools.ts`](/Users/miams/Code/claude-code-source-code-full/src/tools.ts), and implementations such as [`src/tools/TaskCreateTool/TaskCreateTool.ts`](/Users/miams/Code/claude-code-source-code-full/src/tools/TaskCreateTool/TaskCreateTool.ts).

This is a very strong tactic because it reduces three common failure modes:

- vague model decisions about when to use a tool
- malformed tool inputs
- inconsistent post-tool recovery behavior

For `genq`, this strongly argues against exposing raw shell access or raw SQL as the primary model interface. The model should call intent-level tools with narrow schemas.

## 3. The permission model is central, not peripheral

Claude Code's permission system is not bolted on later. Tool execution flows through a centralized decision path in [`src/hooks/useCanUseTool.tsx`](/Users/miams/Code/claude-code-source-code-full/src/hooks/useCanUseTool.tsx), which routes to handlers such as [`src/hooks/toolPermission/handlers/interactiveHandler.ts`](/Users/miams/Code/claude-code-source-code-full/src/hooks/toolPermission/handlers/interactiveHandler.ts).

That is important architecturally because:

- unsafe tool use is not left to the model
- policy is evaluated before execution
- UI, logging, and tool invocation stay aligned

For `genq`, a simplified version is still necessary even if the system is "read only". The relevant permissions are:

- database read allowed
- local docs read allowed
- shell denied by default
- network denied by default
- config-changing commands require explicit user opt-in

## 4. The orchestration layer is separate from tool implementations

Claude Code separates "how tools run" from "what each tool does". [`src/services/tools/toolOrchestration.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/tools/toolOrchestration.ts) batches concurrency-safe tools and runs unsafe ones serially. [`src/services/tools/toolExecution.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/tools/toolExecution.ts) handles validation, permission checks, hooks, telemetry, and result processing.

This is a good tactic because it preserves:

- uniform execution semantics
- easier debugging
- centralized observability
- consistent error formatting

For `genq`, you want the same separation, but much smaller:

- tool schema and metadata
- bridge execution layer
- loop controller

Do not let tool implementations own retries, prompting rules, or session logic.

## 5. Claude Code distinguishes display state from model state

This is one of the more mature implementation tactics in the repo. There is a repeated distinction between:

- user-visible progress and notifications
- normalized message state
- model-facing API messages

That separation appears throughout [`src/QueryEngine.ts`](/Users/miams/Code/claude-code-source-code-full/src/QueryEngine.ts), [`src/query.ts`](/Users/miams/Code/claude-code-source-code-full/src/query.ts), and the tool execution utilities.

This matters for `genq` because non-technical users need reassuring, simple UI:

- "Searching people..."
- "I found 3 matches for John Smith."
- "Checking events and citations..."

But the model should receive structured messages and tool results, not all UI noise.

## 6. Prompt assembly is modular and contextual

Claude Code dynamically builds system/user context instead of using one monolithic prompt. The QueryEngine pulls prompt parts, model settings, memory prompts, and extra context at runtime.

This is a good pattern for `genq` because genealogy work has sharply different modes:

- find a person
- explain a report
- investigate evidence quality
- guide a novice through setup
- help the user refine a query

Those should not all use the same prompt payload.

## 7. Memory exists at multiple layers

Claude Code uses several kinds of persistence:

- transcript history
- file state cache
- persistent memory directory in [`src/memdir/memdir.ts`](/Users/miams/Code/claude-code-source-code-full/src/memdir/memdir.ts)
- session memory summarization in [`src/services/SessionMemory/sessionMemory.ts`](/Users/miams/Code/claude-code-source-code-full/src/services/SessionMemory/sessionMemory.ts)

Architecturally this is sophisticated, but much of it is too heavy for `genq`.

For `genq`, the useful distinction is only:

- short-term session state
- persistent user preferences
- curated genealogy/domain knowledge

Anything beyond that is likely premature.

## 8. Multi-agent capability is impressive but mostly wrong for this use case

Coordinator mode and the Agent tool are real strengths of this codebase, visible in [`src/coordinator/coordinatorMode.ts`](/Users/miams/Code/claude-code-source-code-full/src/coordinator/coordinatorMode.ts) and [`src/tools/AgentTool/AgentTool.tsx`](/Users/miams/Code/claude-code-source-code-full/src/tools/AgentTool/AgentTool.tsx).

But for `genq`, this is mostly the wrong abstraction.

Reasons:

- the task is narrow and mostly read-only
- user trust matters more than parallel throughput
- ambiguity resolution should happen with the user, not with subagents
- local 3B to 4B models do not justify coordinator overhead
- novice users need predictability, not autonomous swarming

Recommendation: do not build multi-agent support into the first two generations of the `genq` assistant.

## 9. Where Claude Code is overbuilt for `genq`

The repo shows signs of a mature commercial product:

- huge entrypoint complexity
- heavy feature-flagging
- multiple modes: REPL, SDK, bridge, daemon, background sessions, remote control
- dense analytics and telemetry plumbing
- large UI/state surface
- multiple tool families and extensibility systems

This is rational for Claude Code. It is not rational for `genq`.

For `genq`, copying this whole architecture would create exactly the wrong outcome:

- slow iteration
- high maintenance cost
- high debugging burden
- fragile local UX

## What `genq` Should Copy, Adapt, and Avoid

| Decision | Claude Code pattern | Recommendation for `genq` |
|---|---|---|
| Copy | Stateful tool-calling loop | Yes, directly |
| Copy | Tool schemas with descriptions and examples | Yes, directly |
| Copy | Central execution bridge | Yes, directly |
| Copy | Permission gate before tool execution | Yes, simplified |
| Copy | Separation of UI messages from model messages | Yes |
| Adapt | Memory layers | Reduce to session summary + preferences + retrieval corpus |
| Adapt | Context assembly | Keep modular, much smaller |
| Adapt | Tool concurrency | Allow only a small number of safe parallel reads if needed |
| Avoid | Multi-agent orchestration | Avoid |
| Avoid | Giant feature-flag architecture | Avoid |
| Avoid | Deep plugin system in v1 | Avoid |
| Avoid | Tight coupling to product analytics | Avoid |

## Review of `genq` As It Exists Today

## 1. `genq` is already a good candidate for a tool-calling assistant

The CLI is structured around domain commands rather than generic shell operations. That is good.

Examples:

- [`src/lib/common/genq list people/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20list%20people/mod.nu)
- [`src/lib/common/genq list events/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20list%20events/mod.nu)
- [`src/lib/common/genq config/mod.nu`](/Users/miams/Code/genq/src/lib/common/genq%20config/mod.nu)
- [`src/lib/common/genq config/wizard.nu`](/Users/miams/Code/genq/src/lib/common/genq%20config/wizard.nu)

This is much better than a CLI that only exposes SQL or filesystem primitives.

## 2. The metadata already present in Nushell modules is a hidden asset

Several commands carry:

- `@category`
- `@search-terms`
- `@example`

That is exactly the kind of structured metadata that can be harvested to auto-generate tool descriptions, few-shot examples, help prompts, and novice guidance.

This is one of the strongest implementation opportunities in `genq`.

## 3. The current command surface is still too shell-shaped for non-technical users

Examples from the current UX:

- `genq list people | first 10`
- `genq list events --place-name`
- downstream Nushell pipelines expected from the user

That is fine for technical users and power users. It is not good enough for the target audience described in this request.

The AI assistant should therefore sit above the CLI, not replace its internals.

## 4. The config wizard is valuable and should remain the fallback path

The interactive configuration flow in [`src/lib/common/genq config/wizard.nu`](/Users/miams/Code/genq/src/lib/common/genq%20config/wizard.nu) already solves an important user problem without an LLM.

That should stay.

The LLM should call into that experience or reuse its validation logic. It should not replace deterministic setup with free-form model improvisation.

## Recommended Architecture for a Local `genq` AI Agent

## Design goal

Allow a novice user to say things like:

- "Show me everyone named Smith born in Ohio."
- "Find census records for my grandfather John Iiams."
- "Why does this person have two different birth years?"
- "Help me set up genq to use my RootsMagic file."

And have the assistant turn that into a safe sequence of `genq` tool calls plus a plain-language answer.

## Recommended top-level architecture

```text
User plain-language input
  -> session controller
  -> local SLM
  -> tool call(s) over curated genq bridge
  -> normalized tool results
  -> local SLM synthesis
  -> user-facing answer
```

### Layer 1: Session Controller

Responsibilities:

- manage conversation history
- inject the right system sections
- call the model
- detect tool calls
- execute the tool loop
- cap turn count and token budget
- ask for clarification when ambiguity remains

This is the `genq` equivalent of Claude Code's QueryEngine, but it should be a few hundred lines, not tens of thousands.

### Layer 2: `genq` Tool Bridge

Responsibilities:

- expose a small set of intent-level tools
- validate arguments
- coerce adjacent types
- map tool calls to `genq` commands or direct internal functions
- normalize results into JSON
- return structured errors with recovery hints

This layer should be deterministic and heavily tested.

### Layer 3: User UX Layer

Responsibilities:

- streaming or chunked answer display
- progress/status phrases
- disambiguation questions
- novice-oriented wording
- optional "show command" or "show raw table" mode for power users

## Tool surface recommendation

Do not expose the whole CLI to the model in v1.

Start with 8 to 12 tools.

Recommended initial tools:

1. `search_people`
2. `get_person_summary`
3. `get_person_events`
4. `get_person_citations`
5. `get_family_members`
6. `get_census_records`
7. `search_sources`
8. `explain_genq_command`
9. `get_config_status`
10. `start_config_wizard`

Optional later tools:

1. `search_places`
2. `search_media`
3. `get_research_gaps`
4. `compare_evidence_for_person`

Do not expose:

- raw shell commands
- raw SQL
- arbitrary filesystem writes
- extension loading/unloading

## Recommended message and control protocol

For a local assistant, use a simple message model:

- `system`
- `user`
- `assistant`
- `tool`

Each message should have:

- `id`
- `role`
- `content`
- `timestamp`
- optional `metadata`

Keep a separate display/event stream for:

- progress
- logs
- debug traces

## Ambiguity handling policy

Genealogy work is ambiguity-heavy. The assistant must be taught to stop and ask when:

- multiple people match the requested name
- the user did not specify a person and several plausible candidates exist
- a date or location reference is vague
- the database has conflicting evidence

This should be a product rule, not an optional model behavior.

## Retrieval and domain context strategy

Do not try to put "genealogy knowledge" directly into the prompt every turn.

Use three retrieval buckets:

### A. Static domain corpus

Curated files describing:

- RootsMagic concepts
- GEDCOM event types
- evidence tiers
- genealogy terminology
- date interpretation caveats

### B. `genq` operational corpus

Generated from the repo:

- command names
- examples
- flags
- categories
- extension-specific commands

### C. User environment/session corpus

- active database name
- whether config is valid
- recent person under discussion
- user preference hints such as "prefer concise explanations"

For v1, this can be simple lexical retrieval over markdown and structured command metadata. A vector database is not required.

## Recommended SLM Stack for Apple M3 Pro 16GB

## Primary runtime recommendation: `mlx-lm`

This is the best fit for Apple Silicon.

Why:

- Apple's MLX ecosystem is optimized for Apple Silicon.
- `mlx-lm` explicitly supports generation and fine-tuning on Apple Silicon.
- It supports quantization, streaming, prompt caching, and large-model handling.

This recommendation is directly supported by official MLX-LM documentation.

## Secondary runtime recommendation: `llama.cpp`

Use this when you want:

- a lightweight GGUF-based runtime
- broad quantized model availability
- easy embedding/server deployment
- maximum portability

`llama.cpp` is also a strong option on Apple Silicon because its project explicitly treats Apple Silicon as a first-class target and supports multiple quantization levels.

## Tertiary runtime recommendation: Ollama

Use Ollama for the fastest prototype, not for the most controllable production path.

It is a good POC route because:

- install is simple
- local run is simple
- Qwen models are already packaged

It is a weaker long-term choice than `mlx-lm` for this project if you want tight control over prompt caching, structured tool loops, and custom evaluation.

## Model recommendation

### Recommended production baseline

`Qwen2.5-3B-Instruct` in a 4-bit local format, preferably MLX or GGUF depending runtime.

Reasoning:

- Qwen2.5 officially supports tool use, structured outputs, and JSON-friendly behavior.
- Qwen2.5 is offered in 3B and 7B sizes.
- 3B-class models are much more realistic than 7B+ for low-latency, local interactive use on 16GB RAM.
- This use case needs reliability in tool invocation and novice explanation more than open-ended creative range.

This is partly an inference from official model sizes, official tool-use support, and the hardware budget. Qwen does not publish an official "best model for M3 Pro 16GB genealogy agent" recommendation.

### Recommended evaluation candidate

`Qwen3` 4B instruct-class variant, quantized, once your runtime path is stable.

Reasoning:

- Qwen3's current function-calling docs are active and official.
- 4B is still in the right size class for local experimentation.
- It may outperform Qwen2.5-3B in instruction following and tool selection.

This is a good benchmark target, but I would still start implementation with the more conservative Qwen2.5 family because the local deployment/docs/tooling path is currently clearer for your intended workflow.

### Developer-side specialist model

`Qwen2.5-Coder-3B-Instruct` or its quantized variant can be useful for:

- generating bridge code
- producing tests
- internal developer workflows

It is not my first recommendation for the end-user genealogy assistant, because the end-user task is domain understanding plus safe tool use, not coding.

### Stretch option

`Qwen2.5-7B-Instruct` 4-bit, if latency and memory use are acceptable in testing.

My assessment:

- likely usable in some quantized local setups
- likely less comfortable once prompt size, retrieval context, and KV cache grow
- probably not the best default for a 16GB machine targeting novice-interactive latency

That last judgment is an inference, not a vendor-published hardware rule.

## Recommended system behavior for the model

The assistant should be instructed to:

- prefer tools over free-form guessing
- never invent a RIN
- ask to disambiguate when name matches are plural
- distinguish evidence from interpretation
- explain uncertainty plainly
- keep novice responses simple by default
- offer raw command/output only when asked

## Fine-tuning and adaptation strategy

## Do not fine-tune first

Phase 1 should be:

- prompt engineering
- curated tools
- retrieval
- schema normalization
- transcript collection
- evaluation

You likely do not yet have enough high-quality, task-shaped data to justify immediate fine-tuning.

## When fine-tuning becomes worthwhile

Fine-tune only after you have collected a few hundred to a few thousand high-quality examples of:

- user request
- tool call sequence
- tool results
- assistant final answer
- clarification turns

Most valuable training targets:

- name disambiguation
- RIN lookup discipline
- evidence-language calibration
- `genq` tool selection
- command explanation for novices

## Recommended training method

Use LoRA or QLoRA-style adaptation over a 3B to 4B base/instruct model.

For this hardware class, full fine-tuning is the wrong priority. Low-rank adaptation is the more realistic path.

## Data strategy for genealogy specialization

Create three data sets:

### 1. Tool-use supervision

Examples:

- "Show me John Smith's events"
- `search_people`
- ask clarification because 4 matches
- `get_person_events` after disambiguation
- final explanation

### 2. Evidence-language supervision

Examples where the assistant must say:

- "the database says"
- "the citation suggests"
- "this is uncertain"
- "this conflict should be verified"

### 3. Novice UX supervision

Examples where the assistant:

- explains a command in plain language
- offers next-step options
- avoids shell jargon
- does not expose Nushell syntax unless asked

## Recommended implementation shape inside `genq`

## Add a parallel AI entrypoint, not a rewrite

Do not rewrite the existing CLI.

Add a new mode, for example:

- `genq ask "Find census entries for John Iiams"`
- `genq chat`
- `genq help me`

This preserves:

- existing power-user workflows
- test surface
- deterministic command modules

## Add a command metadata exporter

Because `genq` commands already include examples and search metadata, build a small exporter that turns Nushell command metadata into a machine-readable catalog.

Suggested output:

```json
{
  "name": "search_people",
  "backing_command": "genq list people",
  "description": "...",
  "examples": ["..."],
  "flags": [...],
  "search_terms": [...]
}
```

This will make your assistant architecture substantially cleaner.

## Add a deterministic bridge library

Create a small library that exposes functions like:

- `bridge_search_people`
- `bridge_get_person_events`
- `bridge_get_person_citations`
- `bridge_get_config_status`

That library should:

- accept structured args
- normalize types
- run the command or internal function
- capture structured output
- return predictable JSON

## Add an evaluation harness

Before worrying about training, create an eval set with categories:

- person lookup
- ambiguous names
- events
- citations
- census
- setup/config help
- command explanation
- conflict explanation

Each eval case should measure:

- correct tool chosen
- tool arguments valid
- clarification asked when required
- final answer accurate
- novice readability acceptable

## Suggested phased roadmap

### Phase 0: Architecture spike

- build a small external prototype using `mlx-lm` or Ollama
- expose 3 tools only: `search_people`, `get_person_events`, `get_config_status`
- collect 30 to 50 manual eval prompts

### Phase 1: Read-only production skeleton

- add `genq ask`
- implement full conversation loop
- add 8 to 10 tools
- add ambiguity policy
- add transcript logging

### Phase 2: Retrieval and session quality

- add static genealogy corpus
- add command metadata retrieval
- add session summaries
- add answer style controls

### Phase 3: Fine-tuning if justified

- build supervised dataset from real transcript traces
- run LoRA adaptation
- compare against prompt-only baseline

### Phase 4: Optional advanced features

- proactive research suggestions
- saved research sessions
- guided workflows
- evidence conflict explanation modules

## Risks and Failure Modes

## 1. Treating this as a shell-agent problem

If you give the model shell access, it will be harder to trust, harder to test, and harder to explain.

Do not build a mini Claude Code clone.

## 2. Overloading the model with raw genealogy knowledge

A narrow local model will degrade if you stuff too much static context into every prompt.

Use retrieval and compact summaries.

## 3. Letting the model resolve ambiguity silently

In genealogy, silent wrong-person selection is worse than asking a follow-up.

Bias toward clarification.

## 4. Fine-tuning too early

Without disciplined transcript data, early fine-tuning usually bakes in bad tool habits rather than solving them.

## 5. Overbuilding the orchestration layer

The Claude Code architecture is informative, but much of its complexity exists because it is a general coding agent, not a narrow local genealogy assistant.

## Final Recommendation

Build `genq`'s assistant as a small, local, single-agent tool-calling system with:

- `mlx-lm` as the primary Apple Silicon runtime
- a Qwen-family 3B to 4B instruct model as the first production baseline
- a deterministic read-only `genq` bridge
- strong schema normalization
- mandatory disambiguation policy
- retrieval over command metadata and genealogy guidance
- no multi-agent behavior
- no shell exposure
- no early fine-tuning

If I had to choose one concrete starting point today, I would start with:

- runtime: `mlx-lm`
- model: `Qwen2.5-3B-Instruct`, quantized for local inference
- interface: `genq ask` plus `genq chat`
- bridge tools: `search_people`, `get_person_events`, `get_person_citations`, `get_family_members`, `get_census_records`, `get_config_status`

Then I would benchmark that baseline against a Qwen3 4B instruct-class variant after the bridge and eval harness are stable.

## Sources

### Local source analysis

- Claude Code snapshot: [`/Users/miams/Code/claude-code-source-code-full`](/Users/miams/Code/claude-code-source-code-full)
- `genq`: [`/Users/miams/Code/genq`](/Users/miams/Code/genq)

### External sources used for current model/runtime recommendations

- Qwen overview: https://qwen.readthedocs.io/en/v2.5/index.html
- Qwen function calling: https://qwen.readthedocs.io/en/stable/framework/function_call.html
- Qwen local Ollama usage: https://qwen.readthedocs.io/en/v2.5/run_locally/ollama.html
- Qwen3 4B base model card: https://huggingface.co/Qwen/Qwen3-4B-Base
- Qwen2.5 Coder 3B AWQ model card: https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-AWQ
- Apple MLX-LM: https://github.com/ml-explore/mlx-lm
- llama.cpp: https://github.com/ggml-org/llama.cpp

### Notes on source usage

- The architecture review is based primarily on local source inspection, not the repo's added docs.
- The hardware/model sizing advice is partly an inference from official model sizes, quantization support, runtime capabilities, and the target hardware budget.
- No external source I found gives an official one-size-fits-all recommendation for "best Qwen model on Apple M3 Pro 16GB for a genealogy CLI assistant"; that part is design judgment built on the cited sources.
