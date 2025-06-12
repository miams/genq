# Cross-platform path handling utilities for GenQuery
#
# Provides consistent path resolution across Windows, macOS, and Linux

# Resolve a path with tilde expansion and platform-appropriate separators
export def resolve-path [path: string] {
    # Handle tilde expansion
    let expanded = ($path | str replace "~" $env.HOME)
    
    # Convert to platform-appropriate separators
    if ($nu.os-info.name == "windows") {
        $expanded | str replace -a "/" "\\"
    } else {
        $expanded
    }
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

# Convert a relative path to absolute based on GenQuery home
export def resolve-genq-path [path: string, genq_home?: string] {
    let base_dir = ($genq_home | default (pwd))
    
    # Check if path is absolute (starts with / on Unix or drive letter on Windows)
    if ($path | str starts-with "/") or ($path | str contains ":\\") {
        resolve-path $path
    } else {
        resolve-path ($base_dir | path join $path)
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