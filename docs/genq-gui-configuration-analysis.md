# GenQuery GUI Configuration Analysis

## Purpose

This document analyzes what would be involved in replacing or supplementing `genq`'s current terminal-based configuration flow with a more GUI-oriented configuration experience now that `genq` is paired with `genq-terminal`.

Short version: this is feasible, but "adding GUI with Zig" is not one simple task. In the current architecture, the hardest part is not rendering fields and buttons. The hard part is deciding **where the GUI lives** and **which layer owns the configuration logic**.

## Current State

`genq` already has a modular configuration flow, but it is entirely Nushell-driven:

- The main entry point routes `genq config` to a CLI wizard and `genq config list` to a read-only display view.
- The config file is `config/default.toml`.
- `src/main.nu` loads that TOML at startup and sets environment variables like `$env.GENQ_CONFIG` and `$env.rmdb`.

Relevant code:

- [`src/lib/common/genq config/mod.nu`](../src/lib/common/genq%20config/mod.nu) coordinates config commands and calls the wizard.
- [`src/lib/common/genq config/wizard.nu`](../src/lib/common/genq%20config/wizard.nu) implements the interactive setup flow.
- [`src/lib/common/genq config/persistence.nu`](../src/lib/common/genq%20config/persistence.nu) loads and saves TOML.
- [`src/main.nu`](../src/main.nu) consumes the config at startup.
- [`config/default.toml`](../config/default.toml) is the current persisted schema.

### What the wizard already handles

From the existing Nushell code, the current config domain is fairly small and well-bounded:

- active database: `demo` or `production`
- enabled extensions
- production RootsMagic source database path
- sync target paths and sync options already present in TOML

That is good news. A GUI settings screen does **not** need to invent a new domain model first. The domain model already exists.

## Important Architectural Reality

If the GUI is built in `genq-terminal`, then the work is **not purely Zig UI work**.

`genq-terminal` inherits Ghostty's architecture:

- Core behavior and config plumbing are in Zig.
- Platform runtime UI is not unified across all platforms.
- On macOS, there is Swift/AppKit code in the app wrapper.
- On Linux, there is GTK code.

That means "add a GUI config screen" can mean at least three different things:

1. Add a **native app settings window** to `genq-terminal`.
2. Add a **terminal-adjacent panel/overlay** inside the Ghostty surface/runtime.
3. Launch a **browser or webview-based settings UI** backed by `genq`.

These are very different projects.

## What `genq-terminal` Already Provides

The local `genq-terminal` checkout already has useful extension points:

- `open_config` is already a first-class app action in Zig, but today it means "open the config file", not "show a GenQuery settings screen".
- Ghostty already has config path resolution logic for app-owned config files.
- Ghostty already has an inspector UI, but it is a development/debug tool rather than a product settings surface.

Relevant code:

- [`/Users/miams/Code/genq-terminal/src/apprt/action.zig`](../../genq-terminal/src/apprt/action.zig) defines `open_config` and other app actions.
- [`/Users/miams/Code/genq-terminal/src/config/edit.zig`](../../genq-terminal/src/config/edit.zig) resolves which config file path should be opened.
- [`/Users/miams/Code/genq-terminal/src/config/file_load.zig`](../../genq-terminal/src/config/file_load.zig) defines default config file locations.
- [`/Users/miams/Code/genq-terminal/src/inspector/Inspector.zig`](../../genq-terminal/src/inspector/Inspector.zig) shows that Ghostty already embeds an ImGui-based inspector.
- [`/Users/miams/Code/genq-terminal/macos/Sources/Ghostty/Ghostty.App.swift`](../../genq-terminal/macos/Sources/Ghostty/Ghostty.App.swift) currently maps `openConfig()` to opening a file URL.

## The Core Design Question

Before writing GUI code, you need to choose which config should become canonical:

### Option A: Keep `genq` TOML as the source of truth

The GUI edits `genq`'s existing TOML schema and `genq` keeps reading it as it does now.

Pros:

- smallest conceptual change
- existing Nushell startup logic stays valid
- no migration required for current users
- GUI can ship incrementally

Cons:

- `genq-terminal` must know about `genq`'s TOML schema
- config path ownership needs to be cleaned up
- live reload requires coordination between app and shell session

### Option B: Move canonical config ownership into `genq-terminal`

The app owns settings and writes or generates `genq` config as a derived artifact.

Pros:

- better long-term app/product model
- easier to build a polished first-launch experience
- terminal can own discovery, validation, and UX

Cons:

- larger rewrite
- requires schema mapping or migration layer
- more coupling between `genq` and `genq-terminal`

### Recommendation

Use **Option A first**.

Keep `genq`'s TOML as canonical, then build a GUI editor for that schema in `genq-terminal`. That gives you a usable settings experience without rewriting startup, environment loading, or sync semantics.

## Feasible GUI Approaches

## 1. Native Settings Window In `genq-terminal`

This is the most product-correct approach if `genq-terminal` is becoming the main user-facing application.

### What it would involve

- define a GenQuery settings model in the app
- read `config/default.toml` or a relocated app-owned GenQuery config file
- render native controls for:
  - database mode
  - RootsMagic file picker
  - enabled extensions
  - sync options
- validate inputs before save
- write TOML back out
- trigger reload behavior for running sessions where possible

### Zig involvement

Zig would likely handle:

- config schema representation
- file IO
- validation helpers
- action wiring between app runtime and config subsystem

But the visible UI would still be platform-specific:

- macOS: Swift/AppKit or SwiftUI integration work
- Linux: GTK work

### Assessment

This is the best long-term direction, but it is **not** "one Zig screen". It is a cross-layer feature.

## 2. In-Terminal Overlay Or Sidebar

This means rendering GUI-ish controls inside the terminal application itself, closer to the terminal surface.

Possible forms:

- command palette flow
- side panel
- overlay dialog
- dedicated inspector-like panel

### What makes this tempting

- Ghostty already has concepts like actions, command palette hooks, and an inspector
- it can feel integrated with the terminal
- no separate browser window

### What makes it risky

- Ghostty is a terminal emulator first, not a general app shell
- the existing inspector is a debug tool, not a production settings framework
- product UI implemented this way can become awkward fast
- cross-platform parity becomes harder

### Assessment

This is viable for a narrow workflow, such as:

- "Choose RootsMagic file"
- "Switch demo/production"
- "Enable/disable extensions"

It is a poor fit for a larger polished settings product unless you want to invest heavily in custom runtime UI work.

## 3. Browser Or Webview-Based Settings UI

This uses `genq` as a backend and serves a local GUI in a browser or embedded webview.

You already have a relevant analysis in [`docs/tech-analysis-datastar-http-nu-xs.md`](./tech-analysis-datastar-http-nu-xs.md), and that path is worth taking seriously.

### What it would involve

- expose config read/update endpoints from Nushell or a small companion service
- render a local HTML settings app
- use native file selection through a helper or app bridge if needed
- persist changes back to the same TOML schema

### Advantages

- fastest way to get rich UI
- much easier layout and form work than native Zig/UI plumbing
- cross-platform with much less duplicated work
- ideal if future GenQuery UI grows beyond settings

### Disadvantages

- separate runtime model from the terminal
- may feel less "native"
- file picker and OS integration require extra glue

### Assessment

This is probably the **fastest path to a good GUI**, but it is a different product direction: more "local app with browser UI" than "terminal-native settings."

## What Needs To Be Standardized First

Regardless of GUI approach, a few things should be cleaned up first.

### 1. Stabilize the config schema

The current schema is good enough to start, but it should be documented explicitly as a contract.

At minimum:

- `database.active`
- `database.connections.*`
- `extensions.enabled`
- `sync.sources.*`
- `sync.targets.*`
- `sync.options.*`

### 2. Separate user config from repo config

Right now `genq` reads `config/default.toml` out of the repo tree. That is fine for development, but awkward for a GUI app.

For a polished GUI product, user configuration should live in an app/user config location, not inside the cloned source tree.

This matters because `genq-terminal` already has app-oriented config path logic, while `genq` still assumes repo-local paths.

### 3. Define reload semantics

You need to decide what happens after the GUI saves:

- apply to next launch only
- reload future shells/tabs
- reload current session if safe
- ask user to restart terminal session

For a first version, "save and apply on next new tab/session" is enough.

### 4. Define ownership of file discovery

The GUI should probably own:

- RootsMagic file picker
- recent database list
- path validation
- platform-specific path suggestions

The Nushell layer should keep owning:

- business rules about what config values mean
- sync logic
- query behavior

## Recommended Incremental Plan

## Phase 1: Make Config GUI-Friendly

- document the TOML schema formally
- move user config to a stable user path
- add a single command or function for "print effective config path"
- add a single command or function for "validate config payload"

Goal: make GUI code consume a clear contract instead of scraping repo assumptions.

## Phase 2: Build A Small Native Settings MVP In `genq-terminal`

Implement only:

- database mode toggle
- RootsMagic production file picker
- extensions multi-select
- save button

Do not start with:

- full sync workflow
- dynamic previews
- onboarding wizard
- cross-platform parity beyond the primary platform

If macOS is the current priority, build the first UI there and keep the save format compatible with `genq`.

## Phase 3: Add Session Integration

- add "Open GenQuery Settings" menu/action
- save settings
- offer "Apply to new tab" or "Restart session"
- optionally re-run startup/bootstrap for new surfaces

## Phase 4: Decide Whether To Expand Or Pivot

After the MVP, decide whether the long-term UI should be:

- native app settings only
- broader in-app GUI product
- browser/webview-based research interface

Do not overcommit before seeing whether the settings-only surface actually solves the user problem.

## Practical Recommendation

If the goal is specifically a **configuration screen** for users of `genq-terminal`, the best next move is:

1. Keep the existing `genq` TOML schema as canonical.
2. Move that config to a user-owned app config location.
3. Add a small native settings window in `genq-terminal` that edits those fields.
4. Treat live reload as a follow-up, not a day-one requirement.

That path has the best ratio of value to engineering risk.

## What To Avoid

- Do not start by inventing a fully new config system.
- Do not start by embedding a large custom UI inside the terminal rendering path.
- Do not assume Zig alone gives you a full cross-platform widget toolkit in this codebase.
- Do not bind the first implementation to hardcoded repo-relative paths.

## Bottom Line

You can absolutely add a GUI configuration experience, but the clean version is:

- `genq` keeps owning the config schema and behavior
- `genq-terminal` owns the user-facing settings UI
- the first GUI should edit a small, stable subset of the existing TOML

That is much smaller and safer than trying to turn the terminal surface itself into a general GUI framework.
