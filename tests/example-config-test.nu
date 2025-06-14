#!/usr/bin/env nu
# Example test showing how to use the new config testing utilities

use config-test-utils.nu *

# Example: Test saving configuration with the new save-config function
export def test-save-config-demo [] {
    print "=== Testing Configuration Save Functionality ==="
    
    with-test-scenario 'demo_basic' { |config_path|
        # Load the config modules in the test environment
        use "../src/lib/common/genq config/persistence.nu" save-config
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        # Test changing configuration
        try {
            let saved_config = (save-config $config_path "production" ["miams"] "/test/path.rmtree")
            reload-genq-environment $saved_config
            
            # Verify the changes were saved
            let updated_config = (open $config_path)
            
            if $updated_config.database.active == "production" {
                print "✓ Database mode changed to production"
            } else {
                print "✗ Database mode not changed correctly"
                return 1
            }
            
            if $updated_config.extensions.enabled == ["miams"] {
                print "✓ Extensions updated correctly"
            } else {
                print "✗ Extensions not updated correctly"
                return 1
            }
            
            print "✓ Configuration save test passed"
        } catch { |error|
            print $"✗ Configuration save test failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Example: Test with custom configuration
export def test-custom-config [] {
    print "=== Testing Custom Configuration Scenario ==="
    
    let custom_scenario = {
        database: {
            active: "demo"
            connections: {
                demo: "./test/custom.rmtree"
            }
        }
        extensions: {
            enabled: ["test_ext"]
        }
    }
    
    with-test-config $custom_scenario { |config_path|
        let config = (open $config_path)
        
        if $config.database.connections.demo == "./test/custom.rmtree" {
            print "✓ Custom database path set correctly"
        } else {
            print "✗ Custom database path not set correctly"
            return 1
        }
        
        if $config.extensions.enabled == ["test_ext"] {
            print "✓ Custom extensions set correctly"
        } else {
            print "✗ Custom extensions not set correctly"
            return 1
        }
        
        print "✓ Custom configuration test passed"
    }
    
    print ""
}

# Run all tests
export def main [] {
    print "Running Configuration Testing Examples\n"
    
    let test1 = (test-save-config-demo)
    let test2 = (test-custom-config)
    
    if ($test1 | default 0) == 0 and ($test2 | default 0) == 0 {
        print "🎉 All configuration tests passed!"
        return 0
    } else {
        print "❌ Some configuration tests failed"
        return 1
    }
}