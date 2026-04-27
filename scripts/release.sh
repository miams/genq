#!/usr/bin/env bash
# release.sh — lockstep semver release across the three GenQuery repos.
#
# Usage:
#   ./scripts/release.sh                # patch bump from latest genq tag
#   ./scripts/release.sh --minor        # minor bump
#   ./scripts/release.sh --major        # major bump
#   ./scripts/release.sh v0.3.0         # explicit version
#   ./scripts/release.sh --dry-run      # show plan, do not write
#
# What it does:
#   1. Bumps marketing version in all three repos.
#   2. Generates per-repo build numbers from `git rev-list HEAD --count`.
#   3. Commits the version bump and creates an annotated tag in each repo.
#   4. Stops short of pushing — you push manually after inspecting diffs.
#
# See docs/versioning.md for the full rationale.

set -euo pipefail

# ---------- repo paths (override via env if your layout differs) ----------
GENQ_DIR="${GENQ_DIR:-$HOME/Code/genq}"
TERMINAL_MAC_DIR="${TERMINAL_MAC_DIR:-$HOME/Code/genq-terminal}"
TERMINAL_WIN_DIR="${TERMINAL_WIN_DIR:-$HOME/Code/genq-terminal-windows}"

# ---------- arg parsing ----------
DRY_RUN=0
BUMP=""
EXPLICIT_VERSION=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --major)   BUMP="major" ;;
        --minor)   BUMP="minor" ;;
        --patch)   BUMP="patch" ;;
        v[0-9]*)   EXPLICIT_VERSION="$arg" ;;
        [0-9]*)    EXPLICIT_VERSION="v$arg" ;;
        -h|--help)
            sed -n '1,20p' "$0"; exit 0 ;;
        *)
            echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

[[ -z "$BUMP" && -z "$EXPLICIT_VERSION" ]] && BUMP="patch"

# ---------- helpers ----------
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '   [dry-run] %s\n' "$*"
    else
        eval "$@"
    fi
}

report_dirty() {
    # Report uncommitted state for one repo. Echoes the porcelain output if dirty.
    local dir="$1"
    [[ -d "$dir/.git" ]] || die "$dir is not a git repo"
    git -C "$dir" status --porcelain
}

confirm_or_exit() {
    # confirm_or_exit "<prompt>" — default is yes (Enter / y / Y); n exits.
    local prompt="$1"
    local reply
    read -r -p "$prompt [Y/n] " reply
    case "$reply" in
        ""|y|Y|yes|YES) return 0 ;;
        *) log "aborted by user"; exit 0 ;;
    esac
}

latest_tag() {
    local dir="$1"
    git -C "$dir" describe --tags --abbrev=0 2>/dev/null || echo ""
}

bump_semver() {
    # bump_semver v0.2.1 minor -> v0.3.0
    local current="${1#v}"
    local kind="$2"
    local major minor patch
    IFS='.' read -r major minor patch <<<"$current"
    case "$kind" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *) die "unknown bump kind: $kind" ;;
    esac
    echo "v${major}.${minor}.${patch}"
}

build_number() {
    # Commit count on current branch — monotonic, fits uint16 for a long time.
    git -C "$1" rev-list HEAD --count
}

# ---------- survey uncommitted state across all three repos ----------
DIRTY_REPORT=""
for entry in "genq:$GENQ_DIR" "genq-terminal:$TERMINAL_MAC_DIR" "genq-terminal-windows:$TERMINAL_WIN_DIR"; do
    label="${entry%%:*}"
    dir="${entry#*:}"
    porcelain="$(report_dirty "$dir")"
    if [[ -n "$porcelain" ]]; then
        DIRTY_REPORT+=$'\n'"  ── $label ($dir) ──"$'\n'
        DIRTY_REPORT+="$(echo "$porcelain" | sed 's/^/    /')"$'\n'
    fi
done

if [[ -n "$DIRTY_REPORT" ]]; then
    warn "uncommitted changes detected:"
    printf '%s\n' "$DIRTY_REPORT"
    echo "These files will NOT be included in the version-bump commit."
    echo "Tagging will still apply to the bump commit only."
    if [[ "$DRY_RUN" != "1" ]]; then
        confirm_or_exit "Proceed anyway?"
    fi
fi

CURRENT_TAG="$(latest_tag "$GENQ_DIR")"
[[ -z "$CURRENT_TAG" ]] && CURRENT_TAG="v0.0.0"

if [[ -n "$EXPLICIT_VERSION" ]]; then
    NEW_TAG="$EXPLICIT_VERSION"
else
    NEW_TAG="$(bump_semver "$CURRENT_TAG" "$BUMP")"
fi

NEW_VERSION="${NEW_TAG#v}"   # 0.3.0
IFS='.' read -r MAJOR MINOR PATCH <<<"$NEW_VERSION"

log "current genq tag: $CURRENT_TAG"
log "next version:     $NEW_TAG  (marketing: $NEW_VERSION)"
[[ "$DRY_RUN" == "1" ]] && log "DRY RUN — no files will be written"

# Sanity: refuse to re-tag an existing tag.
for d in "$GENQ_DIR" "$TERMINAL_MAC_DIR" "$TERMINAL_WIN_DIR"; do
    if git -C "$d" rev-parse "$NEW_TAG" >/dev/null 2>&1; then
        die "$d already has tag $NEW_TAG — bump again or delete it first"
    fi
done

# ---------- 1. genq ----------
log "updating genq → $NEW_VERSION"
GENQ_BUILD="$(build_number "$GENQ_DIR")"

# VERSION file (single source of truth for genquery-start)
if [[ "$DRY_RUN" == "1" ]]; then
    printf '   [dry-run] write %s/VERSION = %s\n' "$GENQ_DIR" "$NEW_VERSION"
else
    echo "$NEW_VERSION" > "$GENQ_DIR/VERSION"
fi

# config/default.toml (keeps the v-prefix to match existing format)
CONFIG_FILE="$GENQ_DIR/config/default.toml"
if [[ "$DRY_RUN" == "1" ]]; then
    printf '   [dry-run] sed version = ... → "%s" in %s\n' "$NEW_TAG" "$CONFIG_FILE"
else
    # macOS sed wants -i ''
    sed -i '' -E "s/^version = \"v?[0-9]+\.[0-9]+\.[0-9]+\"/version = \"$NEW_TAG\"/" "$CONFIG_FILE"
fi

# ---------- 2. genq-terminal (macOS) ----------
log "updating genq-terminal → $NEW_VERSION (build $(build_number "$TERMINAL_MAC_DIR"))"
MAC_BUILD="$(build_number "$TERMINAL_MAC_DIR")"
PBXPROJ="$TERMINAL_MAC_DIR/macos/Ghostty.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    die "pbxproj not found at $PBXPROJ"
fi

if [[ "$DRY_RUN" == "1" ]]; then
    printf '   [dry-run] sed MARKETING_VERSION = ... → %s in pbxproj\n' "$NEW_VERSION"
    printf '   [dry-run] sed CURRENT_PROJECT_VERSION = ... → %s in pbxproj\n' "$MAC_BUILD"
else
    sed -i '' -E "s/MARKETING_VERSION = [0-9]+(\.[0-9]+)*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $MAC_BUILD;/g" "$PBXPROJ"
fi

# ---------- 3. genq-terminal-windows ----------
log "updating genq-terminal-windows → $NEW_VERSION (build $(build_number "$TERMINAL_WIN_DIR"))"
WIN_BUILD="$(build_number "$TERMINAL_WIN_DIR")"
WIN_BUILD_FOR_MSIX="$WIN_BUILD"

# MSIX requires uint16 (max 65535). Guard.
if (( WIN_BUILD > 65535 )); then
    warn "windows commit count $WIN_BUILD exceeds uint16 — using mod 65535"
    WIN_BUILD_FOR_MSIX=$(( WIN_BUILD % 65536 ))
fi

CUSTOM_PROPS="$TERMINAL_WIN_DIR/custom.props"
APPX_MANIFEST="$TERMINAL_WIN_DIR/src/cascadia/CascadiaPackage/Package.appxmanifest"

if [[ "$DRY_RUN" == "1" ]]; then
    printf '   [dry-run] sed VersionMajor → %s in custom.props\n' "$MAJOR"
    printf '   [dry-run] sed VersionMinor → %s in custom.props\n' "$MINOR"
    printf '   [dry-run] sed Identity Version → "%s.%s.%s.%s" in appxmanifest\n' "$MAJOR" "$MINOR" "$PATCH" "$WIN_BUILD_FOR_MSIX"
else
    sed -i '' -E "s|<VersionMajor>[0-9]+</VersionMajor>|<VersionMajor>$MAJOR</VersionMajor>|" "$CUSTOM_PROPS"
    sed -i '' -E "s|<VersionMinor>[0-9]+</VersionMinor>|<VersionMinor>$MINOR</VersionMinor>|" "$CUSTOM_PROPS"
    # appxmanifest: Identity element has Version="X.Y.Z.B"
    sed -i '' -E "s|(<Identity[^>]*Version=)\"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\"|\1\"$MAJOR.$MINOR.$PATCH.$WIN_BUILD_FOR_MSIX\"|" "$APPX_MANIFEST"
fi

# ---------- commit + tag in each repo ----------
# Each call stages ONLY the listed paths (relative to the repo root) so any other
# uncommitted changes in the working tree are left alone.
commit_and_tag() {
    local dir="$1"
    local label="$2"
    shift 2
    local paths=("$@")
    log "committing + tagging $label"
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '   [dry-run] (cd %s && git add %s && git commit -m "chore: bump to %s" && git tag -a %s -m "Release %s")\n' \
            "$dir" "${paths[*]}" "$NEW_TAG" "$NEW_TAG" "$NEW_TAG"
        return
    fi

    # Stage only the version-bumped paths (skip ones that don't exist, e.g. VERSION on first run is fine since we just wrote it).
    local existing=()
    for p in "${paths[@]}"; do
        [[ -e "$dir/$p" ]] && existing+=("$p")
    done

    if [[ ${#existing[@]} -eq 0 ]]; then
        warn "$label: no version-bump paths to stage"
    else
        git -C "$dir" add -- "${existing[@]}"
    fi

    if git -C "$dir" diff --cached --quiet; then
        warn "$label has no staged diff (already at $NEW_VERSION?)"
    else
        git -C "$dir" commit -m "chore: bump to $NEW_TAG"
    fi
    git -C "$dir" tag -a "$NEW_TAG" -m "Release $NEW_TAG"
}

commit_and_tag "$GENQ_DIR" "genq" \
    VERSION config/default.toml

commit_and_tag "$TERMINAL_MAC_DIR" "genq-terminal" \
    macos/Ghostty.xcodeproj/project.pbxproj

commit_and_tag "$TERMINAL_WIN_DIR" "genq-terminal-windows" \
    custom.props src/cascadia/CascadiaPackage/Package.appxmanifest

# ---------- summary ----------
cat <<EOF

\033[1;32m==> release $NEW_TAG ready locally\033[0m

  genq                    tag $NEW_TAG  (build n/a)
  genq-terminal           tag $NEW_TAG  (build $MAC_BUILD)
  genq-terminal-windows   tag $NEW_TAG  (build $WIN_BUILD_FOR_MSIX)

To push (review diffs first):

  cd $GENQ_DIR && git push && git push --tags
  cd $TERMINAL_MAC_DIR && git push && git push --tags
  cd $TERMINAL_WIN_DIR && git push && git push --tags
EOF
