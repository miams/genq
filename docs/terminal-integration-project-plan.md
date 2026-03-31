# GenQuery Terminal — Integration Project Plan

**Date**: 2026-03-26
**Status**: Active

---

## Repository Responsibilities

This plan governs work across three repositories. Each has a distinct focus:

| Repository | Focus | Platform |
|------------|-------|----------|
| `miams/genq` **(this repo)** | Integration, CI pipeline, launch scripts, testing, distribution | All |
| `miams/genq-terminal` | Tailoring Ghostty builds to genq requirements | macOS, Linux |
| `miams/genq-terminal-windows` | Tailoring Windows Terminal builds to genq requirements | Windows |

Work that crosses repositories (CI orchestration, launch scripts, integration tests, release packaging) lives here. Terminal-specific source changes (branding, bundling, upstream sync) live in the terminal repos.

---

## Current State (as of 2026-03-30)

### genq-terminal (Ghostty fork)
- **Branch**: `genq` — clean, but customizations are **not yet committed**
- **Working local build**: `zig-out/Ghostty.app` (63 MB, built 2026-03-21)
- **Customizations applied in build but uncommitted**: bundle ID `com.zephyrsystems.genquery`, display name "GenQuery Terminal"
- **Files that need source changes committed**:
  - `src/build_config.zig` — bundle ID
  - `macos/Ghostty-Info.plist` — CFBundleName
  - `macos/Ghostty.xcodeproj/project.pbxproj` — Xcode bundle settings

### genq-terminal-windows (Windows Terminal fork)
- **Branch**: `genq` — customizations committed
- **Modified**: `Resources.resw` (app name strings), `defaults.json` (GenQuery profile + defaultProfile), `CascadiaPackage.wapproj` (genq content items)
- **Added**: `genq/scripts/genquery-start.ps1`, `genq/scripts/env.nu` — package launch scripts
- **Build verified**: Windows 11 ARM64 VM (local) and CI (x64)
- **Phase 4 Windows**: integrated build + .msixbundle installer complete

### genq (this repo)
- **CI workflow**: `.github/workflows/build-terminal.yml` — builds all 3 platforms
- **Last CI commit**: 2026-03-26 — "fix Windows Terminal build — NuGet restore and MSBuild invocation"
- **Launch scripts**: `scripts/genquery-start` (bash/macOS) and `scripts/genquery-start.ps1` (PowerShell/Windows) — written, not yet end-to-end tested from a bundled build
- **Missing color scheme**: `defaults.json` references "GenQuery Dark" theme — not yet defined

---

## Phases

---

### Phase 1 — Baseline Commit & CI Green
**Goal**: All three platforms build successfully in CI from committed source. No uncommitted customizations.
**Owner**: genq-terminal repo + genq repo

#### Tasks

**genq-terminal repo**
- [ ] Commit the three source customizations to the `genq` branch:
  - `src/build_config.zig` — set bundle ID to `com.zephyrsystems.genquery`
  - `macos/Ghostty-Info.plist` — set CFBundleName / CFBundleDisplayName
  - `macos/Ghostty.xcodeproj/project.pbxproj` — update Xcode bundle settings
- [ ] Verify clean `zig build` from committed source produces matching app

**genq-terminal-windows repo**
- [ ] Define "GenQuery Dark" color scheme in `defaults.json` (referenced but missing)
- [ ] Verify local Windows build produces GenQuery-branded terminal with correct default profile

**genq repo (this repo)**
- [ ] Confirm `build-terminal.yml` passes on all three matrix jobs (macOS, Linux, Windows)
- [ ] Fix any remaining CI failures surfaced by the 2026-03-26 Windows build fix
- [ ] Verify build artifacts are produced and downloadable from CI (14-day retention)
- [ ] Document minimum CI green criteria in `docs/terminal-integration-project-plan.md` (this file)

**Acceptance criteria**:
- `build-terminal.yml` passes on push to `main` for all three matrix jobs
- macOS artifact: `GenQuery-Terminal-macOS.dmg` downloadable from CI
- Windows artifact: `GenQuery-Terminal-Windows.zip` downloadable from CI
- Linux artifact: tarball downloadable from CI

---

### Phase 2 — Launch Script Verification
**Goal**: Both launch scripts (`genquery-start`, `genquery-start.ps1`) work correctly from a CI-produced artifact.
**Owner**: genq repo

These scripts already handle two modes: **bundle mode** (when `GENQUERY_RESOURCES_DIR` is set) and **dev mode** (repo-relative). Phase 2 tests both modes systematically.

#### Tasks

**macOS / bash (`scripts/genquery-start`)**
- [ ] End-to-end test: unzip CI artifact → launch `genquery-start` in dev mode → genq loads
- [ ] Test Nu binary resolution: bundled path → PATH fallback → common install locations
- [ ] Test env config resolution: bundled minimal config → user `~/.config/nushell/env.nu` fallback
- [ ] Verify error messages are clear when Nu is not found or `main.nu` is missing
- [ ] Test on clean macOS install (no developer tools, no Homebrew)

**Windows / PowerShell (`scripts/genquery-start.ps1`)**
- [ ] End-to-end test: unzip CI artifact → launch `genquery-start.ps1` in dev mode → genq loads
- [ ] Test Nu binary resolution: `%LOCALAPPDATA%`, `%ProgramFiles%` fallback paths
- [ ] Test env config: `%APPDATA%\nushell\env.nu` fallback
- [ ] Verify error handling when ExecutionPolicy blocks script
- [ ] Test on clean Windows install (no developer tools, Nu not in PATH)

**Both platforms**
- [ ] Verify `genq list people` executes successfully after terminal launch
- [ ] Verify `genq config list` shows correct active database path
- [ ] Document any edge cases discovered in `docs/launch-script-notes.md`

**Acceptance criteria**:
- Both launch scripts start genq from a CI artifact on a clean machine
- Helpful error message shown (not a crash) when Nu is missing

---

### Phase 3 — Integration Test Suite
**Goal**: Automated integration tests in CI that verify genq works correctly inside each terminal environment.
**Owner**: genq repo

#### Test Matrix

| Test | macOS/Ghostty | Linux/Ghostty | Windows/WT |
|------|:---:|:---:|:---:|
| Terminal launches without error | ✓ | ✓ | ✓ |
| genq help displays | ✓ | ✓ | ✓ |
| `genq list people` returns rows | ✓ | ✓ | ✓ |
| `genq config list` shows active DB | ✓ | ✓ | ✓ |
| `genq tabulate trees` completes | ✓ | ✓ | ✓ |
| Launch script dev mode works | ✓ | ✓ | ✓ |
| Launch script bundle mode works | Phase 4 | Phase 4 | Phase 4 |

#### Tasks
- [ ] Design headless test strategy for terminal launches (likely: run Nu directly via `genquery-start` in a subprocess, capture output, assert on results — does not require a display)
- [ ] Add `test-terminal-integration` job to `build-terminal.yml` or a new `tests-terminal.yml` workflow
- [ ] Reuse existing `tests/helpers.nu` patterns for consistency with existing test infrastructure
- [ ] Integrate test database setup (download `Iiams.rmtree` from S3 as in existing `tests.yaml`)
- [ ] Set pass/fail criteria and surface results in GitHub Actions summary

**Note**: Full GUI terminal automation (keyboard input, screen capture) is deferred to Phase 7. Phase 3 tests the genq invocation layer, not the terminal emulator rendering itself.

---

### Phase 4 — Bundling (Self-Contained Install)
**Goal**: Users can install GenQuery Terminal and run it with no prerequisites (no separate Nu install, no genq repo clone).
**Owner**: genq-terminal repo (macOS/Linux) + genq-terminal-windows repo (Windows) + genq repo (CI packaging)

#### Windows — COMPLETE ✅

**Package layout** (inside the MSIX at `[install dir]\`):
```
genq\
  nu.exe                   ← bundled Nushell (arch-specific: x64 or ARM64)
  src\
    main.nu                ← genq entry point
    lib\common\**          ← genq core library
    lib\ext\**             ← genq extensions (miams, pres2020)
  config\
    default.toml           ← clean distribution config (no dev paths)
  scripts\
    genquery-start.ps1     ← PowerShell launcher; invokes nu.exe by package-relative path
    env.nu                 ← sets NU_LIB_DIRS + GENQ_HOME from $nu.current-exe
```

**How it works**:
- Windows Terminal profile `commandline`: `powershell.exe -ExecutionPolicy Bypass -File "%__APPDIR__%\genq\scripts\genquery-start.ps1"`
- `genquery-start.ps1` uses `$PSScriptRoot` to find `nu.exe` and `main.nu` by package-relative path
- `env.nu` uses `$nu.current-exe | path dirname` to set `NU_LIB_DIRS` and `GENQ_HOME` — completely independent of any system Nushell install
- Bundled `nu.exe` is called by absolute path; no conflict with user's system Nushell

**CI**: `build-terminal.yml` `build-windows` job:
- Downloads latest Nushell x64 + ARM64 from GitHub releases
- Stages genq source + launch scripts into `CascadiaPackage/genq/`
- Builds x64 MSIX → swaps ARM64 `nu.exe` → builds ARM64 MSIX
- Bundles both into a single `.msixbundle`
- Signs with self-signed cert (subject `CN=Zephyr Systems`)
- Uploads to `s3://$GENQ_RELEASES_BUCKET/windows/latest/` and per-commit path
- Uploads as GitHub artifact (14-day retention)

**Signing**: temporary self-signed cert until EV cert arrives. To switch to EV cert:
1. Base64-encode the `.pfx`: `certutil -encode cert.pfx cert.b64 && type cert.b64`
2. Add `GENQ_SIGNING_PFX_B64` (base64 pfx) and `GENQ_SIGNING_PFX_PASSWORD` as repository secrets
3. The workflow auto-detects the presence of `GENQ_SIGNING_PFX_B64` and uses it instead of generating a self-signed cert

**Infrastructure needed**:
- [ ] Create S3 bucket for release artifacts and add `GENQ_RELEASES_BUCKET` as a repository variable
- [ ] (When EV cert arrives) Add `GENQ_SIGNING_PFX_B64` + `GENQ_SIGNING_PFX_PASSWORD` secrets

#### macOS / Linux — Not started
- [ ] Modify Ghostty build to bundle `nu` binary in `Contents/Resources/genq/`
- [ ] Bundle genq scripts: `Contents/Resources/genq/src/`
- [ ] Create `env.nu` equivalent for macOS/Linux (sets `NU_LIB_DIRS` + `GENQ_HOME`)
- [ ] Update DMG packaging to include genq in the app bundle
- [ ] Test on clean macOS install (no developer tools, no Homebrew)

**Acceptance criteria**:
- macOS: drag-install from DMG → open GenQuery Terminal → genq loads, no other installs required
- Windows: install `.msixbundle` → open GenQuery Terminal → genq loads, no other installs required ✅

---

### Phase 5 — Distribution Pipeline
**Goal**: Versioned, signed, notarized releases available for download.
**Owner**: genq repo

#### macOS
- [ ] Obtain Apple Developer account / code signing certificate
- [ ] Add proper code signing to `build-terminal.yml` (replace ad-hoc `codesign --sign -`)
- [ ] Add macOS notarization step to CI (`xcrun notarytool submit`)
- [ ] Add staple step (`xcrun stapler staple`)
- [ ] Test Gatekeeper acceptance on a machine without the signing certificate installed
- [ ] Create Homebrew cask tap: `brew install --cask miams/tap/genq-terminal`

#### Windows — COMPLETE ✅
- [x] MSIX packaging — `.msixbundle` (x64 + ARM64)
- [x] Self-signed cert for dev/preview distribution
- [x] S3 + GitHub artifact upload in CI
- [ ] EV certificate (purchasing — see Phase 4 signing notes above)
- [ ] Windows Store submission (after EV cert)

#### Release automation (both platforms)
- [ ] Define version tagging strategy (see Version Coordination below)
- [ ] Add `release.yml` workflow: triggered by version tag → builds all platforms → creates GitHub Release with artifacts
- [ ] Changelog generation from git log
- [ ] GitHub Release notes template

**Acceptance criteria**:
- macOS DMG passes Gatekeeper on a machine that has never had this app installed
- GitHub Release page has downloadable artifacts for all platforms with checksums

---

### Phase 6 — Version Coordination & Upstream Sync
**Goal**: Clear version strategy across 3 repos; monthly upstream sync cadence established and tested.
**Owner**: genq repo (coordination) + terminal repos (execution)

#### Version Strategy

```
genq-terminal release: v1.2.3
  └── bundles genq: v1.2.3 (matching version tag in this repo)
  └── based on ghostty: 1.1.x (upstream version, tracked in genq-terminal)

genq-terminal-windows release: v1.2.3
  └── bundles genq: v1.2.3
  └── based on windows terminal: v1.x.x (upstream version, tracked in genq-terminal-windows)
```

Rationale: User-facing version matches across all platforms. Upstream terminal version is internal metadata.

#### Tasks
- [ ] Document version tagging convention in `docs/release-process.md`
- [ ] Add version validation to CI: verify bundled genq scripts version matches release tag
- [ ] Test upstream sync procedure (documented in terminal repos) against a real upstream Ghostty release
- [ ] Test upstream sync for Windows Terminal
- [ ] Add monthly sync reminder / issue template

#### Upstream sync (terminal repos — documented here for coordination)
- **Ghostty**: monthly rebase of `genq` branch onto latest upstream release. Conflicts expected in 3 files only: `src/build_config.zig`, `macos/Ghostty-Info.plist`, `macos/Ghostty.xcodeproj/project.pbxproj`
- **Windows Terminal**: monthly rebase of `genq` branch. Conflicts expected in 2 files only: `Resources.resw`, `defaults.json`

---

### Phase 7 — Hardening & Production Readiness
**Goal**: Production-quality reliability; automated smoke tests; user-facing documentation.
**Owner**: genq repo

- [ ] Automated GUI smoke test: launch terminal, assert window opens, take screenshot (using `xctest` or similar)
- [ ] Crash reporting integration (Ghostty has crash handler infrastructure)
- [ ] Error telemetry (opt-in only)
- [ ] User-facing installation documentation (`docs/install-macos.md`, `docs/install-windows.md`)
- [ ] In-app first-launch experience: detect missing RootsMagic database, guide user through `genq config`
- [ ] Verify Nu version compatibility matrix (Nu version bundled vs. Nu version genq requires)

---

## Ongoing Maintenance Cadence

| Cadence | Task | Owner |
|---------|------|-------|
| Monthly | Rebase both terminal forks onto latest upstream releases | Terminal repos |
| Per genq release | Tag release, rebuild all terminal artifacts, update bundled scripts | genq repo |
| Per genq release | Verify Nu version still compatible with bundled nu binary | genq repo |
| Quarterly | Audit dependency licenses (MIT, LGPL, Zig std) | genq repo |
| As needed | Respond to macOS/Zig/Nu version incompatibilities | genq-terminal repo |
| As needed | Respond to Windows SDK / .NET version changes | genq-terminal-windows repo |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Zig version upgrade breaks Ghostty build | Medium | High | Pin Zig version in CI; test upgrade in a branch before adopting |
| Apple notarization API changes | Low | High | Monitor Apple Developer news; notarization is a one-time setup |
| Ghostty upstream changes the 3 customized files | Medium | Medium | Monthly sync catches conflicts early; minimal diff reduces conflict surface |
| Windows Terminal upstream changes defaults.json schema | Low | Medium | Monthly sync; keep genq profile additions minimal |
| Nu version bundled != Nu version genq needs | Medium | High | Pin Nu version in both build and in genq's requirements; test matrix |
| Ghostty Windows support matures → retire WT fork | Future | Positive | Documented in `genq-terminal/docs/windows.md`; retirement is planned |

---

## File Map

```
genq/ (this repo)
├── .github/workflows/
│   ├── build-terminal.yml        ← CI: builds all 3 platforms (exists, Phase 1: fix/verify)
│   ├── tests.yaml                ← Existing genq tests
│   └── release.yml               ← Phase 5: release automation (to be created)
├── scripts/
│   ├── genquery-start            ← macOS/Linux launch script (exists, Phase 2: test)
│   └── genquery-start.ps1        ← Windows launch script (exists, Phase 2: test)
├── installers/
│   ├── genq-full-install-MacOS.sh
│   └── genq-full-install-Win11.ps1
└── docs/
    ├── terminal-integration-project-plan.md  ← this file
    ├── genq-terminal-poc-plan.md             ← original POC (completed)
    ├── genq-terminal-production-plan.md      ← original production plan
    └── launch-script-notes.md               ← Phase 2: edge cases (to be created)

genq-terminal/ (Ghostty fork)
└── docs/
    ├── architecture.md, customizations.md, roadmap.md
    ├── upstream-sync.md, windows.md

genq-terminal-windows/ (Windows Terminal fork)
├── genq/
│   └── scripts/
│       ├── genquery-start.ps1    ← MSIX launch script (calls nu.exe by pkg-relative path)
│       └── env.nu                ← sets NU_LIB_DIRS + GENQ_HOME for bundled Nushell
├── src/cascadia/CascadiaPackage/
│   ├── Package.appxmanifest      ← identity: com.zephyrsystems.genquery / CN=Zephyr Systems
│   └── CascadiaPackage.wapproj   ← includes genq/** content when nu.exe is staged
├── src/cascadia/TerminalSettingsModel/
│   └── defaults.json             ← GenQuery profile; commandline uses %__APPDIR__%
└── docs/
    ├── architecture.md, customizations.md, roadmap.md
    ├── upstream-sync.md, lessons-learned.md
```

---

## Phase Summary

| Phase | Description | Primary Repo | Status |
|-------|-------------|-------------|--------|
| **1** | Baseline commit & CI green | genq + terminal repos | In progress |
| **2** | Launch script verification | genq | Not started |
| **3** | Integration test suite | genq | Not started |
| **4** | Bundling (self-contained) | All 3 repos | Windows complete; macOS/Linux not started |
| **5** | Distribution pipeline | genq | Windows: MSIX+S3 complete; macOS pending |
| **6** | Version coordination & upstream sync | genq (coord) | Not started |
| **7** | Hardening & production readiness | genq | Not started |
