#!/usr/bin/env nu
# Test scenarios where production database config is missing

use config-test-utils.nu *

# Test production mode without sync.sources.production
export def test-missing-production-source [] {
    print "=== Testing Production Mode Without sync.sources.production ==="
    
    # Config with production mode but missing sync.sources.production
    let incomplete_config = {
        database: {
            active: "production"
            connections: {
                demo: "./data/pres2025.rmtree"
                production: "./data/Iiams.rmtree"
            }
        }
        extensions: {
            enabled: ["miams"]
        }
        paths: {
            output_dir: "vault"
        }
        sync: {
            targets: {
                production: "./data/Iiams.rmtree"
                demo: "./data/pres2025.rmtree"
            }
            # Note: missing sync.sources section
        }
    }
    
    with-test-config $incomplete_config { |config_path|
        use "../src/lib/common/genq config/display.nu" list-config
        
        # Test that config list handles missing production source gracefully
        try {
            print "Testing config list with missing production source..."
            list-config $config_path
            print "✓ Config list handles missing production source"
        } catch { |error|
            print $"✗ Config list failed with missing production source: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Test completely missing sync section
export def test-no-sync-section [] {
    print "=== Testing Configuration Without Sync Section ==="
    
    # Config with no sync section at all (fresh install scenario)
    let no_sync_config = {
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
            output_dir: "vault"
        }
    }
    
    with-test-config $no_sync_config { |config_path|
        use "../src/lib/common/genq config/display.nu" list-config
        
        # Test that config list handles completely missing sync section
        try {
            print "Testing config list with no sync section..."
            list-config $config_path
            print "✓ Config list handles missing sync section"
        } catch { |error|
            print $"✗ Config list failed with missing sync section: ($error.msg)"
            return 1
        }
    }
    
    print ""
}

# Run all tests
export def main [] {
    print "Running Missing Production Configuration Tests\n"
    
    let test1 = (test-missing-production-source)
    let test2 = (test-no-sync-section)
    
    if ([$test1, $test2] | all { |result| ($result | default 0) == 0 }) {
        print "🎉 All missing production tests passed!"
        return 0
    } else {
        print "❌ Some missing production tests failed"
        return 1
    }
}