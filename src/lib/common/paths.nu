# Cross-platform path handling utilities for GenQuery
#
# Provides consistent path resolution across Windows, macOS, and Linux

# Resolve a path using Nushell's native capabilities
# This replaces manual tilde expansion and separator conversion
export def resolve-path [path: string] {
    $path | path expand
}

# Get the platform-appropriate GenQuery data directory
export def genq-data-dir [] {
    match $nu.os-info.name {
        "windows" => ($env.APPDATA | path join "GenQuery"),
        "macos" => ($env.HOME | path join "Library" "Application Support" "GenQuery"),
        _ => ($env.HOME | path join ".local" "share" "genq")
    }
}

# Get the platform-appropriate GenQuery config directory
export def genq-config-dir [] {
    match $nu.os-info.name {
        "windows" => ($env.APPDATA | path join "GenQuery"),
        "macos" => ($env.HOME | path join ".genq"),
        _ => ($env.HOME | path join ".config" "genq")
    }
}

# Get platform-specific standard directories following OS conventions
export def platform-dirs [] {
    {
        config: (match $nu.os-info.family {
            "windows" => ($env.APPDATA | path join "GenQuery")
            "unix" => (match $nu.os-info.name {
                "macos" => ($nu.home-dir | path join "Library" "Application Support" "GenQuery")
                _ => ($nu.home-dir | path join ".config" "genq")
            })
        })
        data: (match $nu.os-info.family {
            "windows" => ($env.LOCALAPPDATA | path join "GenQuery" "data")
            "unix" => (match $nu.os-info.name {
                "macos" => ($nu.home-dir | path join "Library" "Application Support" "GenQuery" "data")
                _ => ($nu.home-dir | path join ".local" "share" "genq")
            })
        })
        nushell_config: (match $nu.os-info.family {
            "windows" => ($env.APPDATA | path join "nushell")
            "unix" => ($nu.home-dir | path join ".config" "nushell")
        })
    }
}

# Convert a relative path to absolute based on GenQuery home
# Uses Nushell's native path detection and joining
export def resolve-genq-path [path: string, base_dir?: string] {
    let base = ($base_dir | default (pwd))
    
    # Use Nushell's path detection - if path is absolute, expand it directly
    if ($path | path split | first) == "" or ($path | str substring 1..2) == ":" {
        $path | path expand
    } else {
        $base | path join $path | path expand
    }
}

# Check if a database file exists and is accessible
export def validate-database-path [path: string] {
    let resolved = (resolve-path $path)
    
    if not ($resolved | path exists) {
        error make {
            msg: $"Database file not found: ($resolved)"
            help: "Check that the path is correct and the file exists"
        }
    }
    
    if not ($resolved | path type) == "file" {
        error make {
            msg: $"Database path is not a file: ($resolved)"
            help: "The database path must point to a .rmtree file"
        }
    }
    
    $resolved
}

# Ensure a directory exists, creating it if necessary
export def ensure-directory [path: string] {
    let resolved = (resolve-path $path)
    
    if not ($resolved | path exists) {
        mkdir $resolved
        print $"✓ Created directory: ($resolved)"
    }
    
    $resolved
}