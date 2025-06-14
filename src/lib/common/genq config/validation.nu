# GenQuery Configuration Validation Utilities
#
# Provides input validation and path checking functions

# Validate that a file path exists and is accessible
@category "genq-common"
export def validate-file-path [
    path: string           # File path to validate
    description?: string   # Description for error messages
] {
    let desc = ($description | default "file")
    
    if ($path | str trim | is-empty) {
        error make {msg: $"($desc) path cannot be empty"}
    }
    
    let expanded_path = ($path | path expand)
    
    if not ($expanded_path | path exists) {
        error make {msg: $"($desc) not found at: ($expanded_path)"}
    }
    
    if (($expanded_path | path type) != "file") {
        error make {msg: $"($desc) path exists but is not a file: ($expanded_path)"}
    }
    
    return $expanded_path
}

# Validate that a directory path exists and is accessible
@category "genq-common"
export def validate-directory-path [
    path: string           # Directory path to validate
    description?: string   # Description for error messages
] {
    let desc = ($description | default "directory")
    
    if ($path | str trim | is-empty) {
        error make {msg: $"($desc) path cannot be empty"}
    }
    
    let expanded_path = ($path | path expand)
    
    if not ($expanded_path | path exists) {
        error make {msg: $"($desc) not found at: ($expanded_path)"}
    }
    
    if (($expanded_path | path type) != "dir") {
        error make {msg: $"($desc) path exists but is not a directory: ($expanded_path)"}
    }
    
    return $expanded_path
}

# Validate database mode selection
@category "genq-common"
export def validate-database-mode [
    mode: string           # Database mode to validate
] {
    if $mode not-in ["demo", "production"] {
        error make {msg: $"Invalid database mode: ($mode). Must be 'demo' or 'production'"}
    }
    
    return $mode
}

# Validate extension names against available extensions
@category "genq-common"
export def validate-extensions [
    extensions: list       # List of extension names to validate
    available?: list       # Optional list of available extensions
] {
    if ($extensions | length) == 0 {
        return []
    }
    
    # If no available list provided, just validate that they're strings
    if ($available | is-empty) {
        let invalid_extensions = ($extensions | where { |ext| ($ext | describe) != "string" })
        if ($invalid_extensions | length) > 0 {
            error make {msg: $"Invalid extension names: ($invalid_extensions | str join ', ')"}
        }
        return $extensions
    }
    
    # Validate against available extensions
    let available_names = ($available | get name)
    let invalid_extensions = ($extensions | where { |ext| $ext not-in $available_names })
    
    if ($invalid_extensions | length) > 0 {
        error make {msg: $"Unknown extensions: ($invalid_extensions | str join ', '). Available: ($available_names | str join ', ')"}
    }
    
    return $extensions
}

# Check if a path is writable (for config files)
@category "genq-common"
export def check-writable-path [
    path: string           # Path to check for write access
] {
    let parent_dir = ($path | path dirname)
    
    if not ($parent_dir | path exists) {
        error make {msg: $"Parent directory does not exist: ($parent_dir)"}
    }
    
    # Try to create a test file to verify write access
    let test_file = ($parent_dir | path join ".genq_write_test")
    
    try {
        "" | save $test_file
        rm $test_file
        return true
    } catch { |error|
        error make {msg: $"Cannot write to directory ($parent_dir): ($error.msg)"}
    }
}

# Sanitize and validate user input for file paths
@category "genq-common"
export def sanitize-file-path [
    input: string          # Raw user input
    description?: string   # Description for error messages
] {
    let desc = ($description | default "file")
    
    # Basic input sanitization
    let cleaned_input = ($input 
        | str trim                    # Remove leading/trailing whitespace
        | str replace --regex '[\r\n\t]+' ' ' --all  # Replace control characters with spaces
        | str replace --regex '\s+' ' ' --all        # Collapse multiple spaces
        | str trim                    # Trim again after cleanup
    )
    
    if ($cleaned_input | is-empty) {
        error make {msg: $"($desc) path cannot be empty"}
    }
    
    # Expand path (handles ~, environment variables, etc.)
    let expanded_path = try {
        $cleaned_input | path expand
    } catch { |error|
        error make {msg: $"Invalid ($desc) path format: ($cleaned_input) - ($error.msg)"}
    }
    
    return $expanded_path
}

# Validate RootsMagic database file specifically
@category "genq-common"
export def validate-rmtree-file [
    path: string           # Path to RootsMagic database file
] {
    let sanitized_path = (sanitize-file-path $path "RootsMagic database")
    
    # Check if file exists
    if not ($sanitized_path | path exists) {
        error make {msg: $"RootsMagic database file not found: ($sanitized_path)"}
    }
    
    # Check if it's actually a file
    if (($sanitized_path | path type) != "file") {
        error make {msg: $"Path exists but is not a file: ($sanitized_path)"}
    }
    
    # Check file extension
    if (($sanitized_path | path parse | get extension | str downcase) != "rmtree") {
        error make {msg: $"File does not have .rmtree extension: ($sanitized_path)"}
    }
    
    # Basic file readability check
    try {
        # Try to read first few bytes to ensure it's accessible
        open $sanitized_path --raw | take 10 | ignore
    } catch { |error|
        error make {msg: $"Cannot read RootsMagic database file: ($sanitized_path) - ($error.msg)"}
    }
    
    return $sanitized_path
}