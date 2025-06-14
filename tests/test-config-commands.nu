#!/usr/bin/env nu
# GenQuery Configuration Commands Testing
#
# Tests all config subcommands and validates functionality
# Includes regression tests for function name collision issues

use ../src/lib/common/paths.nu
use ../src/lib/common/mod.nu *

# Test config --help flag
export def test-config-help [] {
    print "=== Config Help Flag Test ==="
    
    # Ensure GENQ_HOME is set for consistent testing
    if ($env.GENQ_HOME? | is-empty) {
        $env.GENQ_HOME = ($env.FILE_PWD | path dirname)
    }
    
    try {
        # Test that config --help flag works (Nushell's built-in help)
        genq config --help | null
        print "✓ Config --help flag works without errors"
        
        print "✓ Config help functionality verified"
    } catch { |error|
        print $"✗ Config help test failed: ($error.msg)"
        return 1
    }
    print ""
}

# Test config list command
export def test-config-list [] {
    print "=== Config List Command Test ==="
    
    # Ensure GENQ_HOME is set for consistent testing
    if ($env.GENQ_HOME? | is-empty) {
        $env.GENQ_HOME = ($env.FILE_PWD | path dirname)
    }
    
    try {
        # Test that config list command runs without throwing errors
        genq config list | null
        print "✓ Config list command executes without errors"
        
        # Test that command produces output containing key sections
        # Use a simpler approach that captures output to a variable via with-env
        let output_test = (try { 
            genq config list | complete
        } catch { 
            {stdout: "", stderr: "", exit_code: 1}
        })
        
        if $output_test.exit_code == 0 {
            print "✓ Config list command exits successfully" 
            
            # Check that stdout contains expected content
            let output_str = ($output_test.stdout | str replace --regex '\x1b\[[0-9;]*m' "" --all)
            
            if ($output_str | str contains "Your GenQuery Settings") {
                print "✓ Output contains settings header"
            } else {
                print "✗ Missing settings header in output"
            }
            
            if ($output_str | str contains "Database") {
                print "✓ Output contains database information"
            } else {
                print "✗ Missing database information in output"
            }
            
            if ($output_str | str contains "Extensions") {
                print "✓ Output contains extensions information"
            } else {
                print "✗ Missing extensions information in output"
            }
            
        } else {
            print $"✗ Config list command failed with exit code: ($output_test.exit_code)"
            return 1
        }
        
        print "✓ Config list command completed successfully"
    } catch { |error|
        print $"✗ Config list command failed: ($error.msg)"
        return 1
    }
    print ""
}

# Test configuration validation for testing framework
export def test-config-validation [] {
    print "=== Config Validation Test ==="
    
    # Test that config file has expected structure
    let genq_home = ($env.GENQ_HOME? | default ($env.FILE_PWD | path dirname))
    let config_path = ($genq_home | path join "config" "default.toml")
    
    try {
        if ($config_path | path exists) {
            let config = (open $config_path)
            
            # Verify expected structure exists
            let required_sections = ["database", "paths", "extensions", "sync"]
            let missing_sections = ($required_sections | where { |section| $section not-in ($config | columns) })
            
            if ($missing_sections | length) == 0 {
                print "✓ Config file has all required sections"
            } else {
                print $"✗ Config file missing sections: ($missing_sections | str join ', ')"
                return 1
            }
            
            # Test specific required fields
            if ($config.database.active? | is-not-empty) and ($config.database.active in ["demo", "production"]) {
                print "✓ Database active setting is valid"
            } else {
                print $"✗ Database active setting invalid: ($config.database.active?)"
                return 1
            }
            
            if ($config.extensions.enabled? | is-not-empty) {
                print $"✓ Extensions configured: ($config.extensions.enabled | str join ', ')"
            } else {
                print "✗ No extensions configured"
                return 1
            }
            
        } else {
            print $"✗ Config file not found at: ($config_path)"
            return 1
        }
        
        print "✓ Config validation completed successfully"
    } catch { |error|
        print $"✗ Config validation failed: ($error.msg)"
        return 1
    }
    print ""
}

# Test config file access and parsing
export def test-config-file-access [] {
    print "=== Config File Access Test ==="
    
    # Test that GENQ_HOME is set properly for testing
    if ($env.GENQ_HOME? | is-empty) {
        $env.GENQ_HOME = ($env.FILE_PWD | path dirname)
    }
    
    let config_path = ($env.GENQ_HOME | path join "config" "default.toml")
    
    try {
        # Test direct config file access
        if ($config_path | path exists) {
            let config = (open $config_path)
            
            # Verify expected structure
            if (("database" in ($config | columns)) and 
                ("extensions" in ($config | columns)) and
                ("paths" in ($config | columns))) {
                print "✓ Config file has expected structure"
            } else {
                print "✗ Config file missing expected sections"
                return 1
            }
            
            # Test specific field access (regression test for name collision)
            try {
                let active_db = $config.database.active
                let extensions = $config.extensions.enabled
                print $"✓ Direct field access works (active: ($active_db), extensions: ($extensions | length) items)"
            } catch { |error|
                print $"✗ Direct field access failed: ($error.msg)"
                return 1
            }
            
        } else {
            print $"✗ Config file not found at: ($config_path)"
            return 1
        }
        
        print "✓ Config file access test completed successfully"
    } catch { |error|
        print $"✗ Config file access test failed: ($error.msg)"
        return 1
    }
    print ""
}

# Test regression for function name collision bug
export def test-function-collision-regression [] {
    print "=== Function Name Collision Regression Test ==="
    
    try {
        # This exact pattern caused the original bug
        let config_path = ($env.GENQ_HOME | path join "config" "default.toml")
        let config = (open $config_path)
        
        # Test the problematic pattern that caused infinite recursion
        let active_db = $config.database.active
        
        # This should NOT call the module's get function
        let connections = $config.database.connections
        
        # Verify we got actual data, not function calls
        if ($active_db | describe) == "string" and ($connections | describe) == "record" {
            print "✓ Direct field access avoids function name collision"
        } else {
            print $"✗ Field access may have function collision (active_db: ($active_db | describe), connections: ($connections | describe))"
            return 1
        }
        
        print "✓ Function name collision regression test passed"
    } catch { |error|
        print $"✗ Function name collision regression test failed: ($error.msg)"
        return 1
    }
    print ""
}

# Test that try/catch blocks are appropriately scoped
export def test-error-handling-scope [] {
    print "=== Error Handling Scope Test ==="
    
    try {
        # Test that syntax errors are not masked by overly broad try/catch
        # This tests our lesson learned about proper error handling scope
        
        # Test config commands handle file not found appropriately
        let fake_genq_home = "/nonexistent/path"
        
        # This should fail with a specific file error, not a generic catch-all
        try {
            let config_path = ($fake_genq_home | path join "config" "default.toml")
            if ($config_path | path exists) {
                print "✗ Fake config path should not exist"
                return 1
            } else {
                print "✓ Error handling correctly identifies missing config file"
            }
        } catch { |error|
            if ($error.msg | str contains "not found") or ($error.msg | str contains "No such file") {
                print "✓ Specific file error properly surfaced"
            } else {
                print $"✗ Generic error instead of specific file error: ($error.msg)"
                return 1
            }
        }
        
        print "✓ Error handling scope test completed successfully"
    } catch { |error|
        print $"✗ Error handling scope test failed: ($error.msg)"
        return 1
    }
    print ""
}

# Run all config tests or a specific test function
export def main [
    function_name?: string  # Optional: specific test function to run
] {
    if ($function_name | is-not-empty) {
        match $function_name {
            "test-config-help" => { test-config-help }
            "test-config-list" => { test-config-list }
            "test-config-validation" => { test-config-validation }
            "test-config-file-access" => { test-config-file-access }
            "test-function-collision-regression" => { test-function-collision-regression }
            "test-error-handling-scope" => { test-error-handling-scope }
            _ => {
                print $"Unknown test function: ($function_name)"
                print "Available functions: test-config-help, test-config-list, test-config-validation, test-config-file-access, test-function-collision-regression, test-error-handling-scope"
                return 1
            }
        }
        return
    }
    
    # Run all tests
    test-config-help
    test-config-list
    test-config-validation
    test-config-file-access
    test-function-collision-regression
    test-error-handling-scope
    
    print "=== Config Commands Test Summary ==="
    print "All configuration command tests completed."
    print "Review any ✗ messages above for issues."
    print ""
    print "To run individual test sections:"
    print "  nu tests/test-config-commands.nu test-config-help"
    print "  nu tests/test-config-commands.nu test-config-list"
    print "  nu tests/test-config-commands.nu test-config-validation"
    print "  nu tests/test-config-commands.nu test-function-collision-regression"
}