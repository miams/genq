# genquery-start.ps1 — Launch script for GenQuery Terminal (Windows)
#
# Supports two runtime modes:
#   Bundle mode: Running inside GenQuery Terminal app (%GENQUERY_RESOURCES_DIR% is set)
#   Dev mode:    Running directly from a genq repo checkout
#
# Phase 3 note: Bundle mode requires a bundled Nu binary and a minimal
# genq-specific env.nu at %GENQUERY_RESOURCES_DIR%\genq\config\env.nu.
# Until those exist, bundle mode falls back to the user's nushell config.

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve runtime mode
# ---------------------------------------------------------------------------

$bundleResourcesDir = $env:GENQUERY_RESOURCES_DIR
$bundleMainNu = if ($bundleResourcesDir) { Join-Path $bundleResourcesDir "genq\src\main.nu" } else { $null }

if ($bundleResourcesDir -and (Test-Path $bundleMainNu)) {
    # --- Bundle mode ---
    $mainNu = $bundleMainNu

    # Prefer bundled Nu binary; fall back to PATH
    $bundledNu = Join-Path $bundleResourcesDir "bin\nu.exe"
    $nuExe = if (Test-Path $bundledNu) { $bundledNu } else { (Get-Command nu -ErrorAction SilentlyContinue)?.Source }

    # Prefer bundled minimal GenQuery env config; fall back to user's nushell env
    $bundledEnv = Join-Path $bundleResourcesDir "genq\config\env.nu"
    $userEnv = Join-Path $env:APPDATA "nushell\env.nu"
    $envConfig = if (Test-Path $bundledEnv) { $bundledEnv } elseif (Test-Path $userEnv) { $userEnv } else { $null }

} else {
    # --- Dev mode ---
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $mainNu = Join-Path $scriptDir "..\src\main.nu" | Resolve-Path

    # Find Nu in PATH or common install locations
    $nuExe = (Get-Command nu -ErrorAction SilentlyContinue)?.Source
    if (-not $nuExe) {
        $candidates = @(
            "$env:LOCALAPPDATA\Programs\nu\bin\nu.exe",
            "$env:ProgramFiles\nu\bin\nu.exe"
        )
        $nuExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    $userEnv = Join-Path $env:APPDATA "nushell\env.nu"
    $envConfig = if (Test-Path $userEnv) { $userEnv } else { $null }
}

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

if (-not $nuExe -or -not (Test-Path $nuExe)) {
    Write-Error "nushell not found. Install from https://www.nushell.sh or via: winget install nushell"
    exit 1
}

if (-not (Test-Path $mainNu)) {
    Write-Error "GenQuery main.nu not found at: $mainNu"
    exit 1
}

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------

$nuArgs = @("--interactive")
if ($envConfig) { $nuArgs += @("--env-config", $envConfig) }
$nuArgs += @("-e", "source '$mainNu'; genq")

& $nuExe @nuArgs
