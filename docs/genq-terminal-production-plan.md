# GenQuery Terminal — Production Project Plan

This plan advances the POC (see `genq-terminal-poc-plan.md`) to a finished, production-quality product.

---

## Phase 1 — Stabilize the Fork (Week 1–2)

**Goal:** POC is reproducible, maintainable, and CI-verified.

- [ ] Set up GitHub Actions to build the fork on push (Zig + macOS runner)
- [ ] Pin Zig version in CI to match `.zigversion`
- [ ] Resolve bundle-relative paths (no hardcoded `/Users/miams/...` paths)
- [ ] Automate DMG creation in CI as a build artifact
- [ ] Document the fork's divergence from upstream in `FORK.md`
- [ ] Establish upstream sync cadence (e.g., monthly rebase onto Ghostty releases)

---

## Phase 2 — Branding & UX Polish (Week 2–4)

**Goal:** Looks and feels like a GenQuery product, not a skinned Ghostty.

- [ ] Custom app icon (requires macOS asset catalog work in `macos/`)
- [ ] Custom color theme aligned with GenQuery visual identity
- [ ] Remove or rename Ghostty-specific menu items ("About Ghostty" → "About GenQuery Terminal")
- [ ] Custom "About" panel with GenQuery version and attribution to Ghostty
- [ ] Suppress irrelevant Ghostty settings from the preferences UI
- [ ] Custom window chrome if desired (title bar, toolbar)

---

## Phase 3 — GenQuery-Specific Shell Integration (Week 3–6)

**Goal:** The terminal is aware it's running GenQuery, not just a generic shell.

- [ ] Bundle Nushell binary inside the app (users don't need to install Nu separately)
- [ ] Bundle GenQuery scripts versioned alongside the terminal build
- [ ] Implement bundle-relative config and script path resolution
- [ ] Auto-detect user's RootsMagic databases on first launch (`genq config` wizard)
- [ ] Custom welcome screen / splash on first launch
- [ ] Persist GenQuery-specific settings independently of Ghostty config

---

## Phase 4 — Cross-Platform (Month 2–3)

**Goal:** Linux support (Windows is lower priority for genealogy software).

- [ ] Linux GTK4 build working in CI
- [ ] AppImage or Flatpak packaging
- [ ] AUR package for Arch Linux users
- [ ] Linux-specific path resolution (XDG standards)
- [ ] Test matrix across macOS versions (13, 14, 15) and Ubuntu LTS

---

## Phase 5 — Distribution Infrastructure (Month 2–3)

**Goal:** Users can download and install without technical knowledge.

- [ ] Apple Developer account → proper code signing certificate
- [ ] macOS notarization pipeline (required for Gatekeeper on other machines)
- [ ] Homebrew tap: `brew install --cask miams/tap/genq-terminal`
- [ ] GitHub Releases with versioned DMG/AppImage artifacts
- [ ] Auto-update mechanism (Ghostty has Sparkle integration on macOS — leverage it)
- [ ] Release versioning strategy (genq-terminal version vs. upstream ghostty version)

---

## Phase 6 — GenQuery Feature Integration (Month 3–6)

**Goal:** The terminal adds value beyond what any terminal + GenQuery provides.

This phase depends on your product vision. Possible directions:

- [ ] **Sidebar panel** showing current database, person count, active filters
- [ ] **Tab management** tied to GenQuery contexts (one tab per database)
- [ ] **Custom renderer** for GenQuery tabular output (clickable rows, sorting)
- [ ] **Protocol extension** — GenQuery emits custom escape sequences, terminal renders them as rich UI
- [ ] **Keyboard shortcuts** mapped to GenQuery commands (not just terminal keybindings)

---

## Phase 7 — Production Hardening (Month 4–6)

- [ ] Automated integration tests (Ghostty launches, GenQuery loads, basic commands work)
- [ ] Crash reporting integration
- [ ] Telemetry / usage analytics (opt-in)
- [ ] User documentation and help system
- [ ] Upstream Ghostty security patches applied promptly

---

## Ongoing Maintenance

| Cadence | Task |
|---------|------|
| Monthly | Rebase fork onto latest Ghostty release |
| Per GenQuery release | Bump bundled scripts version, tag genq-terminal release |
| Quarterly | Audit dependency licenses, check for Ghostty API changes |
| As needed | Respond to macOS/Zig/Nu version incompatibilities |

---

## Licensing Notes

Ghostty is MIT licensed (copyright Mitchell Hashimoto and Ghostty contributors). Requirements:
- Include the MIT license text in the distribution
- Include copyright attribution
- GTK4 (Linux only) is LGPL 2.1+ — use dynamic linking
- Clearly distinguish the fork from upstream Ghostty (name, branding, no official Ghostty icons)
- Suggested attribution: "GenQuery Terminal is based on [Ghostty](https://ghostty.org), used under the MIT License."
