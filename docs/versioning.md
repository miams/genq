# Versioning & Release Across the GenQuery Repos

This document disentangles the three concepts that get conflated when releasing
GenQuery, names every file the version lives in, and explains how
`scripts/release.sh` automates the whole sweep.

## The three things you keep mixing up

| Concept | Example | What it's for | Who needs it |
|---|---|---|---|
| **Marketing version** | `0.3.0` | Human-facing semver. You choose this. | Everyone (config, About box, install dialogs) |
| **Build number** | `142` | Monotonically increasing integer. Auto-generated, never decreases. | App Store, MSIX installer (required by their rules) |
| **Git tag** | `v0.3.0` | A label on a specific commit. Usually equals the marketing version, prefixed with `v`. | GitHub releases, `git describe` |

> The git tag is *not* the version — it's a pointer to the commit that **was** that version. You can have a marketing version `0.3.0` in source files before the `v0.3.0` tag exists, and you can re-tag a different commit if you have to.

There's a fourth thing you'll see in `genq-terminal` that is **not** a version of yours:

| Concept | Example | What it's for |
|---|---|---|
| **Upstream fork base** | Ghostty `v1.3.1` | Documents which commit of the upstream project you forked from. Pure metadata. Doesn't change when you ship a release. |

## The three repos

| Repo | What it is | Marketing version lives in | Build number lives in | Upstream base |
|---|---|---|---|---|
| `genq` | The Nushell engine | `VERSION` (root) + `config/default.toml` | n/a — CLI doesn't need one | none |
| `genq-terminal` | macOS terminal (Ghostty fork) | `macos/Ghostty.xcodeproj/project.pbxproj` (`MARKETING_VERSION`) | same file (`CURRENT_PROJECT_VERSION`) | Ghostty `v1.3.1` (in `build.zig.zon`) |
| `genq-terminal-windows` | Windows terminal (Windows Terminal fork) | `custom.props` (`VersionMajor`/`VersionMinor`) + MSIX manifest `Version="X.Y.Z.B"` | last component of MSIX `Version` | Windows Terminal (in git history) |

## The lockstep rule

**All three repos ship the same marketing version.** A release of "GenQuery 0.3.0" means:

- `genq` is tagged `v0.3.0`
- `genq-terminal` is tagged `v0.3.0`
- `genq-terminal-windows` is tagged `v0.3.0`

Build numbers are **per-repo** and **auto-generated** from `git rev-list HEAD --count` (the number of commits on the branch). They're monotonic, unique per repo, and always fit in a 16-bit field (the MSIX `Version` constraint).

Why lockstep: one user, three components that ship together. The "which terminal goes with which engine?" question never comes up.

## What `scripts/release.sh` does

```bash
# From the genq repo root:
./scripts/release.sh                  # auto-bump patch (v0.2.1 → v0.2.2)
./scripts/release.sh --minor          # auto-bump minor (v0.2.1 → v0.3.0)
./scripts/release.sh --major          # auto-bump major (v0.2.1 → v1.0.0)
./scripts/release.sh v0.3.0           # explicit version
./scripts/release.sh --dry-run        # show what would change, don't write
```

The script:

1. **Discovers the last tag** with `git describe --tags --abbrev=0` in the `genq` repo. You don't need to look it up.
2. **Computes the next version** based on the bump flag (default: patch).
3. **Updates every file** that holds a marketing version (see table above).
4. **Computes per-repo build numbers** from `git rev-list HEAD --count` after the version-bump commit.
5. **Commits the version bump** in each repo with a message like `chore: bump to v0.3.0`.
6. **Tags each repo** with `v0.3.0` (annotated tag).
7. **Reports** what's ready to push. **Does not push** — that's your call.

The script is idempotent in the sense that running it again with the same version is a no-op (it detects the tag already exists and exits).

## What the script touches in each repo

### `genq`
- `VERSION` — plain text, e.g. `0.3.0` (no `v` prefix). Created if missing.
- `config/default.toml` — `[metadata]` table, `version = "v0.3.0"` (with prefix, matching existing format).

### `genq-terminal`
- `macos/Ghostty.xcodeproj/project.pbxproj`:
  - `MARKETING_VERSION = 0.3.0;` (every occurrence — there are several build configs)
  - `CURRENT_PROJECT_VERSION = <commit-count>;` (every occurrence)
- *Not* `build.zig.zon` — that holds the upstream Ghostty version and stays at `1.3.1`.

### `genq-terminal-windows`
- `custom.props`:
  - `<VersionMajor>0</VersionMajor>`
  - `<VersionMinor>3</VersionMinor>`
  - (no patch field — Windows scheme is X.Y only at the props level; the patch goes in the manifest)
- `src/cascadia/CascadiaPackage/Package.appxmanifest`:
  - `Version="0.3.0.<commit-count>"` (4 dotted uint16s — required by MSIX)

## Day-to-day workflow

```bash
# 1. Make sure you're on main with a clean working tree in all three repos.
# 2. From genq root:
./scripts/release.sh --minor

# 3. Inspect the diffs and tags:
cd ~/Code/genq && git log -1 && git show v0.3.0 --stat
cd ~/Code/genq-terminal && git log -1 && git show v0.3.0 --stat
cd ~/Code/genq-terminal-windows && git log -1 && git show v0.3.0 --stat

# 4. Push when satisfied (one repo at a time so you can stop if something looks wrong):
cd ~/Code/genq && git push && git push --tags
cd ~/Code/genq-terminal && git push && git push --tags
cd ~/Code/genq-terminal-windows && git push && git push --tags
```

## What this scheme deliberately does not do

- **No release branches.** Tag on `main`. If you need a hotfix later, branch from the tag.
- **No automated push.** The script stops after committing and tagging locally. You always look before you push.
- **No multi-version coexistence.** If you ship `v0.3.0` of `genq`, you ship `v0.3.0` of both terminals. Splitting cadences is a future problem.
- **No semver discipline enforcement.** Whether a change is "minor" vs "patch" is your call — the script just does the arithmetic.

## When this scheme will start to hurt

If any of these become true, revisit:

- You start having other people ship terminal builds independently.
- Apple or Microsoft rejects a build because you bumped marketing without bumping the build number high enough relative to a previous store submission. (Build numbers must be monotonic *per store*, not per repo — the script's commit-count approach is monotonic per repo, which is sufficient unless you start force-pushing or rebasing main.)
- You want to ship a terminal-only patch without bumping `genq`.

At that point, switch to independent semvers per repo with a coordinating manifest (`releases.toml`) that records which trio shipped together.
