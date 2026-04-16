#!/usr/bin/env nu
# Cross-Platform Path Testing Script for GenQuery
#
# Tests path construction and resolution across different platforms
# Run this script to validate that GenQuery's path handling works correctly

use ../src/lib/common/paths.nu

# Test path resolution on different platforms
export def test-paths [] {
    print $"=== GenQuery Cross-Platform Path Testing ==="
    print $"Platform: ($nu.os-info.name) ($nu.os-info.family)"
    print $"Path separator: (char path_sep)"
    print ""
    
    let test_cases = [
        {input: "~/Documents/test.txt", description: "Tilde expansion"}
        {input: "./relative/path", description: "Relative path from current directory"}
        {input: "../parent/path", description: "Parent directory navigation"}
        {input: "/absolute/unix/path", description: "Unix absolute path"}
        {input: "C:\\Windows\\Path", description: "Windows absolute path"}
        {input: "data/files", description: "Simple relative path"}
        {input: "src/lib/common", description: "Multi-level relative path"}
    ]
    
    print "=== Path Resolution Tests ==="
    for test_case in $test_cases {
        try {
            let resolved = (paths resolve-path $test_case.input)
            print $"✓ ($test_case.description)"
            print $"  Input:    ($test_case.input)"
            print $"  Resolved: ($resolved)"
        } catch {
            print $"✗ ($test_case.description) - Failed: ($in)"
        }
        print ""
    }
}

# Test GenQuery-specific path resolution
export def test-genq-paths [] {
    print "=== GenQuery Path Resolution Tests ==="
    
    # Set up test GENQ_HOME (parent directory of tests)
    $env.GENQ_HOME = (pwd | path dirname)
    
    let genq_test_cases = [
        {input: "config/default.toml", description: "Config file path"}
        {input: "src/lib/common", description: "Library directory"}
        {input: "data/pres2025.rmtree", description: "Database file"}
        {input: "./sql/queries", description: "SQL directory"}
        {input: "vault/reports", description: "Output directory"}
    ]
    
    for test_case in $genq_test_cases {
        try {
            let resolved = (paths resolve-genq-path $test_case.input $env.GENQ_HOME)
            print $"✓ ($test_case.description)"
            print $"  Input:    ($test_case.input)"
            print $"  Resolved: ($resolved)"
            print $"  Exists:   (($resolved | path exists))"
        } catch {
            print $"✗ ($test_case.description) - Failed: ($in)"
        }
        print ""
    }
}

# Test platform-specific directory functions
export def test-platform-dirs [] {
    print "=== Platform Directory Tests ==="
    
    try {
        let dirs = (paths platform-dirs)
        print "Standard platform directories:"
        print $"  Config:         ($dirs.config)"
        print $"  Data:           ($dirs.data)"
        print $"  Nushell Config: ($dirs.nushell_config)"
        print ""
        
        print "GenQuery-specific directories:"
        print $"  GenQuery Data:   (paths genq-data-dir)"
        print $"  GenQuery Config: (paths genq-config-dir)"
    } catch {
        print $"✗ Platform directory test failed: ($in)"
    }
    print ""
}

# Test path join vs string concatenation
export def test-path-construction [] {
    print "=== Path Construction Method Comparison ==="
    
    let base = "/home/user"
    let components = ["Documents", "genealogy", "database.rmtree"]
    
    try {
        # Correct method using path join
        let correct_path = ([$base] | append $components | path join)
        print $"✓ Using path join: ($correct_path)"
        
        # Incorrect method using string concatenation (for comparison)
        let incorrect_path = ([$base] | append $components | str join "/")
        print $"⚠ String concatenation: ($incorrect_path)"
        
        print $"Path join handles separators correctly for this platform"
    } catch {
        print $"✗ Path construction test failed: ($in)"
    }
    print ""
}

# Validate current GenQuery configuration paths
export def test-genq-config [] {
    print "=== GenQuery Configuration Path Validation ==="
    
    let config_paths = [
        {name: "GENQ_HOME", path: ($env.GENQ_HOME? | default "Not set")}
        {name: "rmdb", path: ($env.rmdb? | default "Not set")}
        {name: "genq_sql", path: ($env.genq_sql? | default "Not set")}
    ]
    
    for config in $config_paths {
        print $"($config.name): ($config.path)"
        if ($config.path != "Not set") and ($config.path | path exists) {
            print $"  ✓ Path exists"
        } else {
            print $"  ⚠ Path not found or not set"
        }
        print ""
    }
}

# Run all tests or a specific test function
export def main [
    function_name?: string  # Optional: specific test function to run
] {
    if ($function_name | is-not-empty) {
        match $function_name {
            "test-paths" => { test-paths }
            "test-genq-paths" => { test-genq-paths }
            "test-platform-dirs" => { test-platform-dirs }
            "test-path-construction" => { test-path-construction }
            "test-genq-config" => { test-genq-config }
            _ => {
                print $"Unknown test function: ($function_name)"
                print "Available functions: test-paths, test-genq-paths, test-platform-dirs, test-path-construction, test-genq-config"
                return 1
            }
        }
        return
    }
    test-paths
    test-genq-paths  
    test-platform-dirs
    test-path-construction
    test-genq-config
    
    print "=== Test Summary ==="
    print "All path handling tests completed."
    print "Review any ✗ or ⚠ messages above for potential issues."
    print ""
    print "To run individual test sections:"
    print "  nu tests/test-cross-platform-paths.nu test-paths"
    print "  nu tests/test-cross-platform-paths.nu test-genq-paths"
    print "  nu tests/test-cross-platform-paths.nu test-platform-dirs"
    print "  nu tests/test-cross-platform-paths.nu test-path-construction"
    print "  nu tests/test-cross-platform-paths.nu test-genq-config"
}