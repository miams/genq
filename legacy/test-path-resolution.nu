#!/usr/bin/env nu
# Test that database paths are correctly resolved regardless of current working directory

use config-test-utils.nu *

# Test database path resolution with GENQ_HOME
export def test-db-path-resolution [] {
    print "=== Testing Database Path Resolution ==="
    
    with-test-scenario 'production_basic' { |config_path|
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        # Set up a test GENQ_HOME
        let test_genq_home = ($config_path | path dirname | path dirname)
        
        try {
            # Load the config and test environment setup
            let config = (open $config_path)
            
            # Test with GENQ_HOME set
            with-env {GENQ_HOME: $test_genq_home} {
                reload-genq-environment $config
                
                # Check that rmdb is an absolute path
                let rmdb_path = $env.rmdb
                
                if ($rmdb_path | str starts-with "/") {
                    print $"✓ Database path is absolute: ($rmdb_path)"
                } else {
                    print $"✗ Database path is still relative: ($rmdb_path)"
                    return 1
                }
                
                # Check that the path includes the GENQ_HOME
                if ($rmdb_path | str contains $test_genq_home) {
                    print "✓ Database path correctly uses GENQ_HOME"
                } else {
                    print $"✗ Database path doesn't use GENQ_HOME: ($rmdb_path)"
                    print $"Expected to contain: ($test_genq_home)"
                    return 1
                }
            }
            
            print "✓ Database path resolution test passed"
        } catch { |error|
            print $"✗ Database path resolution test failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Test different path formats
export def test-path-formats [] {
    print "=== Testing Different Path Formats ==="
    
    # Test config with different path formats
    let mixed_paths_config = {
        database: {
            active: "production"
            connections: {
                demo: "./data/pres2025.rmtree"                           # Relative
                production: "/absolute/path/to/database.rmtree"          # Absolute
                test: "~/home/user/database.rmtree"                     # Tilde
            }
        }
        extensions: {
            enabled: ["test"]
        }
    }
    
    with-test-config $mixed_paths_config { |config_path|
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        let test_genq_home = ($config_path | path dirname | path dirname)
        let config = (open $config_path)
        
        # Test relative path resolution
        try {
            with-env {GENQ_HOME: $test_genq_home} {
                # Update config to use demo (relative path)
                let demo_config = ($config | upsert database.active "demo")
                reload-genq-environment $demo_config
                
                let rmdb_path = $env.rmdb
                if ($rmdb_path | str starts-with $test_genq_home) {
                    print "✓ Relative path correctly resolved with GENQ_HOME"
                } else {
                    print $"✗ Relative path not resolved correctly: ($rmdb_path)"
                    return 1
                }
            }
            
            # Test absolute path handling
            with-env {GENQ_HOME: $test_genq_home} {
                # Update config to use production (absolute path)
                let prod_config = ($config | upsert database.active "production")
                reload-genq-environment $prod_config
                
                let rmdb_path = $env.rmdb
                if ($rmdb_path == "/absolute/path/to/database.rmtree") {
                    print "✓ Absolute path preserved correctly"
                } else {
                    print $"✗ Absolute path not preserved: ($rmdb_path)"
                    return 1
                }
            }
            
            print "✓ Path formats test passed"
        } catch { |error|
            print $"✗ Path formats test failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Run all tests
export def main [] {
    print "Running Database Path Resolution Tests\n"
    
    let test1 = (test-db-path-resolution)
    let test2 = (test-path-formats)
    
    if ([$test1, $test2] | all { |result| ($result | default 0) == 0 }) {
        print "🎉 All path resolution tests passed!"
        return 0
    } else {
        print "❌ Some path resolution tests failed"
        return 1
    }
}