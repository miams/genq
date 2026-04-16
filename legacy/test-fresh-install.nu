#!/usr/bin/env nu
# Test fresh installation scenarios

use config-test-utils.nu *

# Test minimal fresh install configuration (only demo database)
export def test-fresh-install [] {
    print "=== Testing Fresh Installation Configuration ==="
    
    # Minimal config that would ship with GenQuery (only demo data)
    let fresh_config = {
        database: {
            active: "demo"
            connections: {
                demo: "./data/pres2025.rmtree"
            }
        }
        extensions: {
            enabled: ["pres2025"]
        }
        paths: {
            sql_dir: "sql"
            lib_dir: "src/lib"
            ext_dir: "src/lib/ext"
            output_dir: "vault"
        }
        display: {
            date_format: 1
            table_mode: "rounded"
        }
    }
    
    with-test-config $fresh_config { |config_path|
        use "../src/lib/common/genq config/display.nu" list-config
        
        # Test that config list works without sync section
        try {
            print "Testing config list with minimal fresh install..."
            list-config $config_path
            print "✓ Config list works with fresh install"
        } catch { |error|
            print $"✗ Config list failed with fresh install: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Test switching to production mode in fresh install
export def test-fresh-to-production [] {
    print "=== Testing Fresh Install -> Production Mode Switch ==="
    
    # Fresh install config
    let fresh_config = {
        database: {
            active: "demo"
            connections: {
                demo: "./data/pres2025.rmtree"
            }
        }
        extensions: {
            enabled: ["pres2025"]
        }
        paths: {
            sql_dir: "sql"
            output_dir: "vault"
        }
    }
    
    with-test-config $fresh_config { |config_path|
        use "../src/lib/common/genq config/persistence.nu" [save-config, load-config]
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        # Try to switch to production mode
        try {
            print "Testing switch from fresh install to production mode..."
            let saved_config = (save-config $config_path "production" ["miams"] "/test/user/database.rmtree")
            reload-genq-environment $saved_config
            
            let updated_config = (open $config_path)
            
            # Check that production database.connections was created
            if "production" in ($updated_config.database.connections | columns) {
                print "✓ Production database.connections created"
            } else {
                print "✗ Production database.connections not created"
                return 1
            }
            
            # Check that sync section was created
            if "sync" in ($updated_config | columns) {
                print "✓ Sync section created"
            } else {
                print "✗ Sync section not created"
                return 1
            }
            
            print "✓ Fresh install to production switch works"
        } catch { |error|
            print $"✗ Fresh install to production switch failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Run all tests
export def main [] {
    print "Running Fresh Installation Tests\n"
    
    let test1 = (test-fresh-install)
    let test2 = (test-fresh-to-production)
    
    if ([$test1, $test2] | all { |result| ($result | default 0) == 0 }) {
        print "🎉 All fresh installation tests passed!"
        return 0
    } else {
        print "❌ Some fresh installation tests failed"
        return 1
    }
}