# Cross-Platform Path Management Strategy for GenQuery

## Executive Summary

This document analyzes GenQuery's current path management implementation and provides recommendations for a reliable, cross-platform approach that maximizes Nushell's native capabilities.

## Current State Analysis

### Strengths
1. **Centralized Path Module** (`src/lib/common/paths.nu`)
   - Provides `resolve-path` for tilde expansion and platform-specific separators
   - Offers platform-aware directory functions (`genq-data-dir`, `genq-config-dir`)
   - Includes path validation utilities

2. **Configuration System** (`src/lib/common/config.nu`)
   - Manages paths through TOML configuration
   - Resolves relative paths to absolute using `GENQ_HOME`
   - Supports configuration hierarchy (defaults → user → project → environment)

### Issues Identified

1. **Inconsistent Path Construction**
   - Some modules use `path join` (correct)
   - Others use string concatenation with hardcoded separators (incorrect)
   - Example: `genq list media` module uses string concatenation and manual separator handling

2. **Platform-Specific Logic Duplication**
   - Multiple files implement their own platform detection
   - Manual separator replacement instead of using centralized utilities

3. **Mixed Path Representations**
   - Configuration uses forward slashes (/)
   - Manual conversion to backslashes on Windows
   - Not leveraging Nushell's automatic path normalization

## Nushell Native Capabilities

### Path Commands
- `path join` - Cross-platform path construction
- `path exists` - Check file/directory existence
- `path type` - Determine if path is file/directory
- `path expand` - Expand tilde and environment variables
- `path parse` - Extract path components
- `path relative-to` - Get relative paths
- `path split` - Split path into components

### Platform Detection
- `$nu.os-info.name` - Returns "windows", "macos", "linux"
- `$nu.os-info.family` - Returns "unix" or "windows"
- `$nu.home-path` - Cross-platform home directory

### Key Insight
Nushell automatically handles path separators when using `path join` and other path commands. Manual separator conversion is usually unnecessary.

## Recommended Architecture

### 1. Path Construction Rules

```nu
# ALWAYS use path join for building paths
let config_path = ($env.GENQ_HOME | path join "config" "default.toml")

# NEVER use string concatenation
# BAD: let config_path = $env.GENQ_HOME + "/config/default.toml"
# BAD: [$env.GENQ_HOME, "config", "default.toml"] | str join "/"

# Use path expand for tilde and environment variables
let user_path = ("~/Documents/genealogy" | path expand)
```

### 2. Configuration Path Handling

```nu
# In config files, always use forward slashes
# Nushell will normalize these automatically
[paths]
sql_dir = "sql"
data_dir = "data/databases"
output_dir = "vault/reports"

# For absolute paths in config, use forward slashes
[sync.sources]
production = "~/Genealogy/RootsMagic/Database/Iiams.rmtree"
```

### 3. Enhanced Path Module

```nu
# Recommended enhancements to paths.nu

# Use Nushell's path expand instead of manual tilde replacement
export def resolve-path [path: string] {
    $path | path expand
}

# Simplified path resolution - let Nushell handle separators
export def resolve-genq-path [path: string, base_dir?: string] {
    let base = ($base_dir | default (pwd))
    
    # Check if path is absolute using Nushell's detection
    if ($path | path split | first) == "" or ($path | str substring 1..2) == ":" {
        $path | path expand
    } else {
        $base | path join $path | path expand
    }
}

# Platform-specific directories using consistent patterns
export def platform-dirs [] {
    {
        config: (match $nu.os-info.family {
            "windows" => ($env.APPDATA | path join "GenQuery")
            "unix" => (match $nu.os-info.name {
                "macos" => ($nu.home-path | path join "Library" "Application Support" "GenQuery")
                _ => ($nu.home-path | path join ".config" "genq")
            })
        })
        data: (match $nu.os-info.family {
            "windows" => ($env.LOCALAPPDATA | path join "GenQuery" "data")
            "unix" => (match $nu.os-info.name {
                "macos" => ($nu.home-path | path join "Library" "Application Support" "GenQuery" "data")
                _ => ($nu.home-path | path join ".local" "share" "genq")
            })
        })
    }
}
```

### 4. Environment Setup Best Practices

```nu
# In env.nu or initialization
# Use path join for all path construction
$env.NU_LIB_DIRS = ($env.NU_LIB_DIRS | append [
    ($env.GENQ_HOME | path join "src" "lib")
    ($env.GENQ_HOME | path join "src" "lib" "ext")
])

# Set GENQ_HOME with proper expansion
$env.GENQ_HOME = (($env.GENQ_HOME? | default (pwd)) | path expand)
```

## Implementation Guidelines

### 1. Path Variables in Code
- Always store paths in their native format (forward slashes on Unix, either on Windows)
- Use `path join` when constructing paths
- Use `path expand` for user-provided paths
- Never manually convert separators

### 2. Configuration Files
- Use forward slashes in all configuration files
- Document that paths support tilde expansion
- Validate paths exist after resolution

### 3. SQL and External Commands
- When passing paths to SQL or external commands, use Nushell's string interpolation
- For quoted paths: `$"\"($path)\""`
- Nushell will use the correct separators

### 4. Migration Strategy
1. Update all string concatenation to use `path join`
2. Remove manual separator replacements
3. Centralize all path operations through `paths.nu`
4. Add validation tests for cross-platform paths

## Testing Strategy

### Cross-Platform Validation Script
```nu
# Test path resolution on different platforms
export def test-paths [] {
    let test_cases = [
        "~/Documents/test.txt"
        "./relative/path"
        "../parent/path"
        "/absolute/unix/path"
        "C:\\Windows\\Path"
        "data/files"
    ]
    
    print $"Platform: ($nu.os-info.name)"
    print $"Path separator: (char path_sep)"
    
    for test_path in $test_cases {
        let resolved = (resolve-genq-path $test_path)
        print $"Input: ($test_path) → Resolved: ($resolved)"
    }
}
```

## Summary of Key Principles

1. **Use Nushell's path commands exclusively** - They handle cross-platform concerns automatically
2. **Store paths in configuration using forward slashes** - Nushell normalizes these
3. **Avoid manual separator conversion** - Let Nushell handle platform differences
4. **Centralize path operations** - Use the `paths.nu` module for all path handling
5. **Test on target platforms regularly** - Don't assume macOS behavior applies to Windows

## Action Items

1. **✓ COMPLETED**: Fix `genq list media` module to use `path join` instead of string concatenation
2. **✓ COMPLETED**: Update all modules to use centralized path utilities
3. **✓ COMPLETED**: Enhance `paths.nu` with the recommended improvements  
4. **✓ COMPLETED**: Create automated tests for cross-platform path handling
5. **PENDING**: Fix installer scripts path construction issues

## Implementation Summary

### Fixed Modules
- **`genq list media`**: Replaced platform-specific string concatenation with unified `path join` approach
- **`genq list citations`**: Fixed SQL script path construction using `path join`
- **`genq md people`**: Fixed output path construction using `path join`

### Enhanced `paths.nu` Module
- Simplified `resolve-path` to use `path expand` instead of manual processing
- Enhanced `resolve-genq-path` with better absolute path detection
- Added `platform-dirs` function for standardized cross-platform directory access
- All functions now leverage Nushell's native path capabilities

### Created Testing Infrastructure
- **`tests/test-cross-platform-paths.nu`**: Comprehensive test script for validating path handling
- **`tests/run-tests.nu`**: Test runner and orchestration framework
- **`tests/README.md`**: Complete testing documentation with automated and manual execution instructions
- Tests path resolution, GenQuery-specific paths, platform directories, and configuration validation
- Provides comparison between correct (`path join`) and incorrect (string concatenation) methods

### Testing Framework
The new `tests/` directory provides:
- Automated test execution with `nu tests/run-tests.nu run-all`
- Individual test function execution for targeted validation
- Cross-platform testing strategy for development and pre-release validation
- Comprehensive documentation for manual and automated testing procedures

By following these guidelines, GenQuery will have predictable, reliable path handling across all platforms while leveraging Nushell's native capabilities to their fullest extent.