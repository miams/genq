#!/usr/bin/env nu
# Test that database.connections always point to local target files

use config-test-utils.nu *

# Test that save-config fixes database.connections inconsistency
export def test-path-consistency [] {
    print "=== Testing Database Path Consistency ==="
    
    # Create a scenario with inconsistent paths (like the bug)
    let inconsistent_config = {
        database: {
            active: "production"
            connections: {
                demo: "Code/genq/data/pres2025.rmtree"      # Wrong path
                production: "Code/genq/data/data/Iiams.rmtree"  # Wrong path with doubled folder
            }
        }
        extensions: {
            enabled: ["miams", "pres2025"]
        }
        sync: {
            targets: {
                production: "./data/Iiams.rmtree"     # Correct target path
                demo: "./data/pres2025.rmtree"        # Correct target path
            }
            sources: {
                production: "/Users/miams/Genealogy/RootsMagic/Database/Iiams.rmtree"
                demo: "~/Genealogy/RootsMagic/Database/pres2025.rmtree"
            }
        }
        paths: {
            sql_dir: "sql"
            output_dir: "vault"
        }
    }
    
    with-test-config $inconsistent_config { |config_path|
        use "../src/lib/common/genq config/persistence.nu" [save-config, load-config]
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        # Save config - this should fix the inconsistent database.connections
        try {
            let saved_config = (save-config $config_path "production" ["miams", "pres2025"] "/test/source/path.rmtree")
            reload-genq-environment $saved_config
            
            # Verify the configuration was corrected
            let updated_config = (open $config_path)
            
            # Check that database.connections now point to correct local targets
            if $updated_config.database.connections.production == "./data/Iiams.rmtree" {
                print "✓ Production database.connections fixed to correct local target"
            } else {
                print $"✗ Production database.connections incorrect: ($updated_config.database.connections.production)"
                return 1
            }
            
            if $updated_config.database.connections.demo == "./data/pres2025.rmtree" {
                print "✓ Demo database.connections fixed to correct local target"
            } else {
                print $"✗ Demo database.connections incorrect: ($updated_config.database.connections.demo)"
                return 1
            }
            
            # Verify sync.targets are preserved
            if $updated_config.sync.targets.production == "./data/Iiams.rmtree" {
                print "✓ Sync targets preserved correctly"
            } else {
                print $"✗ Sync targets changed unexpectedly: ($updated_config.sync.targets.production)"
                return 1
            }
            
            # Verify sync.sources was updated
            if $updated_config.sync.sources.production == "/test/source/path.rmtree" {
                print "✓ Sync sources updated correctly"
            } else {
                print $"✗ Sync sources not updated: ($updated_config.sync.sources.production)"
                return 1
            }
            
            print "✓ Database path consistency test passed"
        } catch { |error|
            print $"✗ Path consistency test failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Test switching between demo and production modes
export def test-mode-switching [] {
    print "=== Testing Database Mode Switching ==="
    
    with-test-scenario 'production_basic' { |config_path|
        use "../src/lib/common/genq config/persistence.nu" [save-config, load-config]
        use "../src/lib/common/genq config/environment.nu" reload-genq-environment
        
        # Switch from production to demo
        try {
            let saved_config = (save-config $config_path "demo" ["pres2025"])
            reload-genq-environment $saved_config
            
            let updated_config = (open $config_path)
            
            if $updated_config.database.active == "demo" {
                print "✓ Database mode switched to demo"
            } else {
                print $"✗ Database mode not switched: ($updated_config.database.active)"
                return 1
            }
            
            # Verify database.connections still point to local targets
            if $updated_config.database.connections.demo == "./data/pres2025.rmtree" {
                print "✓ Demo database.connections correct after mode switch"
            } else {
                print $"✗ Demo database.connections incorrect after switch: ($updated_config.database.connections.demo)"
                return 1
            }
            
            print "✓ Mode switching test passed"
        } catch { |error|
            print $"✗ Mode switching test failed: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Run all tests
export def main [] {
    print "Running Database Path Consistency Tests\n"
    
    let test1 = (test-path-consistency)
    let test2 = (test-mode-switching)
    
    if ([$test1, $test2] | all { |result| ($result | default 0) == 0 }) {
        print "🎉 All path consistency tests passed!"
        return 0
    } else {
        print "❌ Some path consistency tests failed"
        return 1
    }
}