# Tech Analysis: Datastar + http-nu + xs for genq

**Date**: 2026-03-26
**Status**: Research / Pre-proposal

## Executive Summary

Datastar, http-nu, and xs form a coherent, intentional stack — all authored by [cablehead](https://github.com/cablehead). They are designed to work together, and together they would transform genq from a terminal reporting tool into a **live, browser-accessible genealogy research environment** driven entirely by Nushell. The integration path is surprisingly low-friction because of deep Nushell-native support across all three.

---

## The Stack Relationship

```
┌─────────────────────────────────────────────────────┐
│  Browser                                            │
│  Datastar (~11.4KB)                                 │
│  · reactive signals   · SSE listener               │
│  · data-* attributes  · idiomorph DOM morphing      │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP + SSE
                       │ (text/event-stream)
┌──────────────────────▼──────────────────────────────┐
│  http-nu (Rust binary, Nu 0.111 embedded)           │
│  · route dispatcher   · to sse / to datastar-*      │
│  · request handler closures written in Nushell      │
│  · --datastar flag serves Datastar JS bundle        │
│  · --store flag integrates xs store                 │
└──────────────┬────────────────┬────────────────────-┘
               │                │
               ▼                ▼
┌──────────────────┐  ┌─────────────────────────────-─┐
│  genq modules    │  │  xs (cross.stream)             │
│  src/lib/common  │  │  · append-only event log       │
│  src/lib/ext/*   │  │  · actors / services           │
│  query db ...    │  │  · TTL + CAS storage           │
│                  │  │  · SSE native output           │
│  Iiams.rmtree    │  │  · Unix socket HTTP API        │
│  SQLite (ro)     │  │  · Nushell VFS (.nu topics)    │
└──────────────────┘  └───────────────────────────────-┘
```

---

## Technology Profiles

### Datastar
- **Repo/Docs**: https://data-star.dev/
- **What**: Hypermedia frontend framework replacing HTMX + Alpine.js combined
- **Size**: ~11.4KB gzipped, zero install (CDN `<script>` tag, no npm/build step)
- **Model**: Reactive signals (`$variable`) + SSE-driven DOM morphing
- **Reactivity engine**: preact/signals-core (fine-grained, only re-renders signal dependents)
- **DOM update strategy**: idiomorph morphing — diffs by element `id`, preserves focus/scroll

**Protocol — two event types:**

| SSE Event | Purpose |
|-----------|---------|
| `datastar-patch-elements` | Sends HTML fragment; morphed into live DOM by element ID |
| `datastar-patch-signals` | Sends JSON to update frontend reactive state |

**Backend contract**: Any server that can write `text/event-stream` wire format. No SDK required.

**Wire format example:**
```
Content-Type: text/event-stream
Cache-Control: no-cache

event: datastar-patch-elements
data: elements <div id="results"><p>John Iiams (1842)</p></div>

event: datastar-patch-signals
data: signals {"count": 42}

```

**CSP caveat**: Requires `unsafe-eval` (uses `Function()` for `data-*` expression evaluation). Acceptable for local tools; problematic for hosted deployments.

---

### http-nu
- **Repo**: https://github.com/cablehead/http-nu
- **Docs**: https://http-nu.cross.stream/
- **What**: Standalone Rust binary embedding Nu 0.111 — an HTTP server where request handlers are Nushell closures
- **Install**: `brew install cablehead/tap/http-nu`
- **Current version**: 0.13.0 (released 2026-03-02)

**Usage:**
```bash
http-nu :3001 ./serve.nu
# or inline:
http-nu :3001 -c '{|req| "Hello world"}'
```

Every request invokes the closure with a `$req` record (`proto`, `method`, `uri`, `path`, `remote_ip`, `headers`, `query`). Return value becomes the response body — content-type is inferred automatically (record → JSON, string → HTML, etc.).

**Key capabilities:**

| Feature | Detail |
|---------|--------|
| Routing | `use http-nu/router *` — `dispatch`/`route` with path params, method matching |
| SSE | `to sse` — first-class, auto-sets headers, streams chunks as Nu generates them |
| Datastar SDK | `use http-nu/datastar *` — `to datastar-patch-elements`, `to datastar-patch-signals`, `from datastar-signals` |
| xs integration | `--store ./xs-store` flag — handlers get `.cat`, `.append`, `.last` |
| TLS/HTTP2 | `--tls combined.pem` |
| Watch mode | `-w` hot-reloads script on file change (dev mode) |
| Static files | `.static "/dir" $req.path` with MIME inference |
| Templates | `.mj "template.html"` (Minijinja/Jinja2-compatible) |
| In-memory SQLite | Nushell's built-in `stor` commands work across requests |
| Module paths | `-I ./lib` for custom module search paths |

**Version coupling**: Embeds Nu 0.111 — must stay in sync with genq's Nu version.

---

### xs (cross.stream)
- **Repo**: https://github.com/cablehead/xs
- **Docs**: https://cablehead.github.io/xs/
- **What**: Local-first append-only event streaming store — personal NATS/Redis Streams without the infrastructure
- **Install**: `brew install cablehead/tap/cross-stream`
- **Current version**: 0.11.0 (released 2026-03-02)

**Mental model**: Every "event" is a **frame** on an immutable timeline. Append frames, replay them, subscribe to live updates, wire up automated responders.

**Storage architecture:**

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Metadata index | fjall (LSM-tree) | Frame headers, topics, IDs — fast range queries |
| Payload storage | cacache (CAS) | Large payloads by content hash — automatic deduplication |

Frame IDs use **SCRU128** — 128-bit sortable unique IDs with embedded millisecond timestamp (sortable chronologically, usable as efficient range cursors).

**Key operations:**
```nushell
# Append events
null | .append research.session.start --meta {db: "Iiams"}
"note text" | .append notes --ttl last:1   # keep only latest

# Query
.cat --follow --topic "person.*"           # live stream, wildcard filter
.last notes                                # most recent frame on topic
.cat --after <id>                          # resume from position

# Server-side evaluation
xs eval ./store -c '.last notes'
```

**TTL modes:**

| TTL | Behavior |
|-----|---------|
| `forever` | Kept indefinitely (default) |
| `ephemeral` | Never stored; live subscribers only |
| `time:<ms>` | Expires after N milliseconds |
| `last:<n>` | Topic retains only N most recent frames |

**Processing primitives:**

| Primitive | Purpose |
|-----------|---------|
| **Services** | Background producers — run a closure, emit output as frames, auto-restart |
| **Actors** | Stateful event reactors — fire on each frame, thread state via `next:` |
| **Actions** | Stateless on-demand — append to `<name>.call`, result on `<name>.response` |

**Operational model**: Requires a running `xs serve` process (unlike genq's stateless CLI). A single locked process holds the store; clients connect via Unix domain socket.

**SSE support**: Native — `Accept: text/event-stream` on `GET /` returns live stream. Standard wire format with SCRU128 IDs.

---

## Integration Analysis

### Layer 1: http-nu + genq (Minimum Viable Web Layer)

The most direct integration. genq's Nushell modules become HTTP endpoints.

```nushell
# serve.nu — http-nu handler
use http-nu/router *

{|req|
  dispatch $req [
    (route {method: "GET", path: "/people"} {|req ctx|
      # genq modules loaded via NU_LIB_DIRS or -I flag
      open $env.rmdb | query db "SELECT p.PersonID as RIN, n.Given, n.Surname, n.BirthYear, n.DeathYear
        FROM PersonTable p JOIN NameTable n ON p.PersonID = n.OwnerID WHERE n.IsPrimary = 1"
    })
    (route {method: "GET", path: "/people/:rin"} {|req ctx|
      # person detail
    })
  ]
}
```

Launch with genq's library paths:
```bash
http-nu :3001 -I ./src/lib -I ./src/lib/ext ./serve.nu
```

**Critical dependency**: `$env.rmdb` must be set. Either pass via environment or set in handler preamble. The embedded Nu engine does not inherit the shell's env vars automatically.

**Feasibility**: High. genq's read-only SQLite access pattern works in any Nu context.

---

### Layer 2: http-nu + Datastar + genq (Reactive Web UI)

```html
<!-- Person search -->
<input data-bind:query type="search" placeholder="Search people...">
<button data-on-input="@get('/people/search')">Search</button>
<div id="results"></div>
```

```nushell
# /people/search handler — streams results as HTML fragments
{|req|
  let query = $req.query.datastar | from json | get query? | default ""
  open $env.rmdb
  | query db $"SELECT p.PersonID as RIN, n.Given, n.Surname, n.BirthYear, n.DeathYear
      FROM PersonTable p JOIN NameTable n ON p.PersonID = n.OwnerID
      WHERE n.IsPrimary = 1 AND n.Surname LIKE '%($query)%'"
  | each {|row|
      $"<div class='person' id='p-($row.RIN)'>($row.Given) ($row.Surname) \(($row.BirthYear)–($row.DeathYear)\)</div>"
    }
  | str join "\n"
  | {elements: $in}
  | to datastar-patch-elements
  | to sse
}
```

**Genealogy-specific UI opportunities:**

| Feature | Implementation |
|---------|---------------|
| Live person search | `data-on-input` → SSE stream of person HTML fragments |
| Family tree expansion | Click person → SSE pushes parents/children, morphed into DOM by ID |
| Long-running reports | `genq tabulate trees` streams progress events while computing |
| Citation preview | Hover source → SSE pushes citation detail fragment |
| Filter signals | `$surname`, `$year_range`, `$sex` → server-side WHERE clause |

**Signal model maps to genealogy filters:**
```html
<input data-bind:surname>
<input data-bind:birth_year_min type="number">
<input data-bind:birth_year_max type="number">
<select data-bind:sex>
  <option value="">Any</option>
  <option value="M">Male</option>
  <option value="F">Female</option>
</select>
<div data-on-change="@get('/people')" id="people-list"></div>
```

**Key architectural fit**: Datastar's "backend as source of truth" model aligns perfectly with genq's design philosophy — the SQLite database is the canonical truth; the browser is just a view.

---

### Layer 3: Full Stack with xs (Event-Sourced Research)

xs adds an event backbone for research workflow automation.

**Research session tracking:**
```nushell
null | .append research.session.start --meta {db: "Iiams", researcher: "miams"}
null | .append person.viewed --meta {rin: 1234, name: "John Iiams"}
null | .append citation.found --meta {rin: 1234, source: "1880 Census", url: "..."}
```

**Actor: auto-generate Obsidian notes on person view:**
```nushell
# Registered actor fires on each research event
{|frame, state|
  if $frame.topic == "person.viewed" {
    let rin = $frame.meta.rin
    null | .append markdown.generate.call --meta {rin: $rin}
  }
  null  # no state needed
}
```

**xs TTL modes for genealogy use cases:**

| Topic | TTL | Purpose |
|-------|-----|---------|
| `research.current` | `last:1` | Currently focused person — always latest |
| `research.session.*` | `time:3600000` | Session expires after 1 hour |
| `citation.found` | `forever` | Permanent research evidence log |
| `db.sync.status` | `last:1` | Latest database sync result |

**xs service: watch .rmtree for external changes:**
```nushell
{run: {||
  fswatch $env.rmdb
  | lines
  | each {|_| {event: "db.changed", ts: (date now | format date "%+")} | to json}
}}
```

**http-nu + xs live activity stream to browser:**
```nushell
{|req|
  .cat --follow --topic "person.*"
  | each {|frame|
      {elements: $"<li id='evt-($frame.id)'>($frame.meta.name)</li>"}
      | to datastar-patch-elements
    }
  | to sse
}
```

---

## Risk Assessment

### High Risk / Must Resolve Before Committing

| Risk | Detail | Mitigation |
|------|--------|-----------|
| **Nu version coupling** | http-nu embeds Nu 0.111 — genq must stay on matching version | Pin both; watch http-nu releases actively |
| **NU_LIB_DIRS in http-nu** | Embedded Nu engine does not inherit shell environment | Use `-I ./src/lib -I ./src/lib/ext` flags on http-nu startup |
| **`$env.rmdb` not set** | All genq data access depends on this env var | Set explicitly in handler preamble or http-nu startup wrapper |
| **xs operational model** | Requires persistent `xs serve` daemon — new ops concern for a CLI tool | `brew services start cross-stream` for dev; launchd plist for persistent |

### Medium Risk / Manageable

| Risk | Detail |
|------|--------|
| **CSP + Datastar** | `unsafe-eval` required — fine for local tools, blocks CSP-strict hosted deployments |
| **SQLite concurrent reads** | Multiple http-nu request handlers reading simultaneously — safe in WAL mode |
| **http-nu maturity** | v0.13.0, 23 releases — capable but API may shift |
| **xs no auth** | Unix socket = filesystem permissions only — fine for personal/local use |

### Low Risk

| Risk | Detail |
|------|--------|
| **Datastar protocol** | Wire format is minimal text — trivial to write manually if SDK gaps appear |
| **xs append-only model** | Immutable log aligns naturally with genealogy's evidence-based methodology |
| **SSE browser support** | Universal modern browser support |
| **genq read-only DB** | No write conflicts; SQLite handles multiple concurrent readers natively |

---

## Recommended Implementation Phases

### Phase 1: Proof of Concept
**Goal**: Verify genq modules load correctly inside http-nu handlers.

```bash
GENQ_RMDB=/Users/miams/Code/genq/data/Iiams.rmtree \
  http-nu :3001 -I ./src/lib -I ./src/lib/ext \
  -c '{|req| open $env.GENQ_RMDB | query db "SELECT count(*) as n FROM PersonTable" | get 0.n | to text}'

curl localhost:3001  # should return "11692"
```

This single test validates the core integration assumption. If it works, the path forward is clear.

### Phase 2: JSON API
Route `genq list people`, `genq list sources`, etc. to HTTP endpoints returning JSON. No frontend yet — validate the data layer end-to-end.

### Phase 3: Datastar Frontend
Add HTML templates and SSE streaming. Start with person search (highest value, clearest user story). Use `to datastar-patch-elements` to stream search results as HTML fragments morphed into DOM.

### Phase 4: xs Integration
Add xs for research session tracking and background processing. Start with a `last:1` topic for "current person being researched" — the simplest useful case before introducing actors/services.

---

## Verdict

| Technology | Fit for genq | Priority |
|------------|-------------|----------|
| **http-nu** | Excellent — Nushell-native, same ecosystem, Datastar-ready | High |
| **Datastar** | Excellent — SSE-first, no build step, genealogy UI maps naturally to signals + morphing | High |
| **xs** | Good — powerful for research workflows, adds operational complexity; additive not required | Medium |

The **http-nu + Datastar** combination is the high-value, lower-complexity starting point. xs becomes compelling once persistent research sessions, background DB sync, or actor-driven automation are needed. The three tools are designed as a coherent stack, and genq's Nushell-native architecture means the integration avoids the impedance mismatch you would face bridging to a Node or Python backend.

---

## References

- Datastar: https://data-star.dev/
- http-nu: https://github.com/cablehead/http-nu — https://http-nu.cross.stream/
- xs: https://github.com/cablehead/xs — https://cablehead.github.io/xs/
- TodoMVC example (http-nu + xs + Datastar): https://cablehead.github.io/xs/tutorials/datastar-todomvc/
