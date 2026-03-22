# GenQuery Terminal — POC Build Plan

**Goal:** A buildable, runnable Ghostty binary named "GenQuery Terminal" that launches Nushell+GenQuery by default, packaged as a distributable macOS `.app`.

**Estimated time:** 4–5 hours

---

## Hour 0–0:30 — Fork & Environment Setup

**On GitHub:**
1. Fork `ghostty-org/ghostty` → `miams/genq-terminal`
2. Clone locally: `git clone git@github.com:miams/genq-terminal.git ~/Code/genq-terminal`
3. Add upstream: `git remote add upstream https://github.com/ghostty-org/ghostty.git`

**Install Zig** (must match Ghostty's required version):
```bash
# Check required version:
cat ~/Code/genq-terminal/.zigversion

# Install via zigup (version manager):
brew install zigup
zigup 0.14.0  # use whatever .zigversion says
```

**Verify environment:**
```bash
zig version  # must match .zigversion exactly
```

---

## Hour 0:30–1:30 — Verify Clean Build

Do this before touching anything. If it breaks, you know it's upstream, not your changes.

```bash
cd ~/Code/genq-terminal
zig build -Doptimize=Debug 2>&1 | tee build.log
```

On macOS this produces `zig-out/Ghostty.app`. Open it, confirm it runs. If the build fails, the most common issues are:
- Wrong Zig version (re-check `.zigversion`)
- Missing system libs — Ghostty's `README` lists macOS prerequisites
- Xcode Command Line Tools not installed: `xcode-select --install`

**Do not proceed until this works.**

---

## Hour 1:30–2:00 — Cosmetic Changes (App Name & Bundle ID)

These are the only source changes needed for the POC.

**`build.zig`** — find and change the app name and bundle identifier:
```zig
// Change:
.name = "ghostty"
// To:
.name = "GenQuery Terminal"
```

**`macos/Info.plist`** — update these keys:
```xml
<key>CFBundleName</key>
<string>GenQuery Terminal</string>

<key>CFBundleDisplayName</key>
<string>GenQuery Terminal</string>

<key>CFBundleIdentifier</key>
<string>com.miams.genq-terminal</string>

<key>CFBundleExecutable</key>
<string>GenQuery Terminal</string>
```

**Window title** — set via default config (next step), not source code.

For the POC, **skip the icon**. Changing the app icon requires asset catalog work; it's not worth the time now.

---

## Hour 2:00–2:30 — Wire GenQuery as Default Shell

Rather than modifying Ghostty source to hard-code the shell, **bundle a default config file**. Ghostty reads config from known locations; for a bundled app you can ship one inside the `.app`.

**Create `config/genq-terminal.config`** in your fork:
```
# GenQuery Terminal — default configuration
command = /usr/bin/env nu --env-config /Users/miams/.config/nushell/env.nu /Users/miams/Code/genq/src/main.nu

# Branding
title = GenQuery

# Theme — adjust to taste
background = #1e1e2e
foreground = #cdd6f4
cursor-color = #f5c2e7
font-size = 14

# UX
window-padding-x = 12
window-padding-y = 12
confirm-close-surface = false
```

**Wire this config into the build** — modify `build.zig` to copy it into the app bundle's `Resources/` directory, then modify Ghostty's config loading code to check for a bundled config as the baseline default.

Alternatively (faster for POC): hardcode the config path in source to look for `{bundle}/Contents/Resources/genq.config`.

The relevant source file is `src/config/Config.zig` — find the `loadDefaultFiles` or equivalent function that builds the config search path list and prepend your bundled path.

---

## Hour 2:30–3:00 — Bundle GenQuery Scripts

Modify `build.zig` to copy your GenQuery scripts into the app bundle:

```zig
// In build.zig, after the main install step:
const install_genq = b.addInstallDirectory(.{
    .source_dir = b.path("../genq/src"),  // path to your genq repo
    .install_dir = .{ .custom = "Ghostty.app/Contents/Resources/genq/src" },
    .install_subdir = "",
});
b.getInstallStep().dependOn(&install_genq.step);
```

Update your config to use bundle-relative paths:
```
command = /usr/bin/env nu --env-config ~/.config/nushell/env.nu {bundle}/Contents/Resources/genq/src/main.nu
```

For the POC, hardcoding absolute paths is acceptable. Resolve bundle-relative paths in a later phase.

---

## Hour 3:00–3:30 — Build & Smoke Test

```bash
zig build -Doptimize=ReleaseFast
open zig-out/GenQuery\ Terminal.app
```

Verify:
- App name shows "GenQuery Terminal" in menu bar and Dock
- Window title shows "GenQuery"
- GenQuery loads on launch (Nushell prompt with genq available)
- `genq list people` works

---

## Hour 3:30–4:30 — Package for Distribution

**Create a DMG** (macOS standard distribution format):

```bash
# Create a staging directory
mkdir -p /tmp/genq-dmg
cp -r zig-out/"GenQuery Terminal.app" /tmp/genq-dmg/

# Create the DMG
hdiutil create \
  -volname "GenQuery Terminal" \
  -srcfolder /tmp/genq-dmg \
  -ov -format UDZO \
  -o ~/Desktop/GenQuery-Terminal-POC.dmg
```

**Ad-hoc code signing** (required to run on macOS without Gatekeeper blocking):
```bash
codesign --force --deep --sign - \
  "/tmp/genq-dmg/GenQuery Terminal.app"
```

Note: Ad-hoc signing allows you to run it locally and share with known testers. App Store / full notarization is a production-phase concern.

**Test on a clean machine or account** — open the DMG, drag to Applications, launch. Confirm it works without your dev environment.

---

## POC Deliverable

A `GenQuery-Terminal-POC.dmg` containing a macOS app that:
- Is named "GenQuery Terminal"
- Launches GenQuery automatically on open
- Contains all GenQuery Nu scripts in the bundle
- Is ad-hoc signed and runnable without Xcode
