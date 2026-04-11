# GenQuery Terminal v0.1.2

## What's New

- macOS builds now ship as separate Apple Silicon (arm64) and Intel (x86_64) DMGs
- All builds are now versioned by tag (e.g. `v0.1.2`) in S3 storage
- Build workflows trigger on version tags (`v*`) in addition to main branch pushes
- README example video now renders inline in Typora and falls back to a clickable image on GitHub

## Downloads

| Platform | Architecture | File |
|----------|-------------|------|
| macOS | Apple Silicon (M1/M2/M3) | `GenQuery-Terminal-macOS-arm64.dmg` |
| macOS | Intel | `GenQuery-Terminal-macOS-x86_64.dmg` |
| Windows | x64 (Intel/AMD) | `GenQuery-Terminal-Windows-x64.msix` |
| Windows | ARM64 | `GenQuery-Terminal-Windows-ARM64.msix` |
| Linux | x86_64 | `GenQuery-Terminal-Linux.tar.gz` |

## Requirements

- macOS 13 (Ventura) or later
- Windows 10/11
- RootsMagic 8 or later (`.rmtree` database file)
