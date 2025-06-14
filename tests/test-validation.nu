#!/usr/bin/env nu
# Test the new validation and error handling functionality

use config-test-utils.nu *

# Test input sanitization
export def test-input-sanitization [] {
    print "=== Testing Input Sanitization ==="
    
    with-test-scenario 'demo_basic' { |config_path|
        use "../src/lib/common/genq config/validation.nu" sanitize-file-path
        
        # Test basic sanitization
        let result1 = try {
            sanitize-file-path "  ~/test/path.txt  " "test file"
        } catch { |error|
            print $"✗ Basic sanitization failed: ($error.msg)"
            return 1
        }
        
        if ($result1 | str contains "test/path.txt") {
            print "✓ Basic path sanitization works"
        } else {
            print $"✗ Basic sanitization incorrect: ($result1)"
            return 1
        }
        
        # Test control character removal
        let result2 = try {
            sanitize-file-path "test\r\n\tpath" "test file"
        } catch { |error|
            print $"✗ Control character sanitization failed: ($error.msg)"
            return 1
        }
        
        if ($result2 | str contains "test path") {
            print "✓ Control character sanitization works"
        } else {
            print $"✗ Control character sanitization incorrect: ($result2)"
            return 1
        }
        
        # Test empty input handling
        let result3 = try {
            sanitize-file-path "   " "test file"
            print "✗ Empty input should have failed"
            return 1
        } catch { |error|
            if ($error.msg | str contains "cannot be empty") {
                print "✓ Empty input properly rejected"
            } else {
                print $"✗ Wrong error for empty input: ($error.msg)"
                return 1
            }
        }
    }
    
    print ""
}

# Test RootsMagic file validation
export def test-rmtree-validation [] {
    print "=== Testing RootsMagic File Validation ==="
    
    with-test-scenario 'demo_basic' { |config_path|
        use "../src/lib/common/genq config/validation.nu" validate-rmtree-file
        
        # Test with non-existent file
        let result1 = try {
            validate-rmtree-file "/nonexistent/path/test.rmtree"
            print "✗ Non-existent file should have failed"
            return 1
        } catch { |error|
            if ($error.msg | str contains "not found") {
                print "✓ Non-existent file properly rejected"
            } else {
                print $"✗ Wrong error for non-existent file: ($error.msg)"
                return 1
            }
        }
        
        # Test with wrong extension
        let temp_file = (mktemp -t "test-XXXXXX.txt")
        let result2 = try {
            # Create a temporary file with wrong extension
            "test content" | save $temp_file
            
            validate-rmtree-file $temp_file
            rm -f $temp_file
            print "✗ Wrong extension should have failed"
            return 1
        } catch { |error|
            rm -f $temp_file
            if ($error.msg | str contains ".rmtree extension") {
                print "✓ Wrong extension properly rejected"
            } else {
                print $"✗ Wrong error for extension: ($error.msg)"
                return 1
            }
        }
    }
    
    print ""
}

# Test path validation functions
export def test-path-validation [] {
    print "=== Testing Path Validation Functions ==="
    
    with-test-scenario 'demo_basic' { |config_path|
        use "../src/lib/common/genq config/validation.nu" validate-directory-path
        
        # Test with existing directory
        let result1 = try {
            validate-directory-path "/tmp" "temp directory"
        } catch { |error|
            print $"✗ Valid directory failed: ($error.msg)"
            return 1
        }
        
        if ($result1 == "/tmp") {
            print "✓ Valid directory path accepted"
        } else {
            print $"✗ Directory validation returned wrong path: ($result1)"
            return 1
        }
        
        # Test with non-existent directory
        let result2 = try {
            validate-directory-path "/nonexistent/directory" "test directory"
            print "✗ Non-existent directory should have failed"
            return 1
        } catch { |error|
            if ($error.msg | str contains "not found") {
                print "✓ Non-existent directory properly rejected"
            } else {
                print $"✗ Wrong error for non-existent directory: ($error.msg)"
                return 1
            }
        }
    }
    
    print ""
}

# Test configuration validation
export def test-config-validation [] {
    print "=== Testing Configuration Validation ==="
    
    with-test-scenario 'demo_basic' { |config_path|
        use "../src/lib/common/genq config/validation.nu" [validate-database-mode, validate-extensions]
        
        # Test valid database mode
        let result1 = try {
            validate-database-mode "production"
        } catch { |error|
            print $"✗ Valid database mode failed: ($error.msg)"
            return 1
        }
        
        if ($result1 == "production") {
            print "✓ Valid database mode accepted"
        } else {
            print $"✗ Database mode validation incorrect: ($result1)"
            return 1
        }
        
        # Test invalid database mode
        let result2 = try {
            validate-database-mode "invalid"
            print "✗ Invalid database mode should have failed"
            return 1
        } catch { |error|
            if ($error.msg | str contains "Invalid database mode") {
                print "✓ Invalid database mode properly rejected"
            } else {
                print $"✗ Wrong error for invalid mode: ($error.msg)"
                return 1
            }
        }
        
        # Test extension validation
        let result3 = try {
            validate-extensions ["test1", "test2"] []
        } catch { |error|
            print $"✗ Extension validation failed: ($error.msg)"
            return 1
        }
        
        if ($result3 == ["test1", "test2"]) {
            print "✓ Extension validation works"
        } else {
            print $"✗ Extension validation incorrect: ($result3)"
            return 1
        }
    }
    
    print ""
}

# Run all validation tests
export def main [] {
    print "Running Enhanced Validation Tests\n"
    
    let test1 = (test-input-sanitization)
    let test2 = (test-rmtree-validation) 
    let test3 = (test-path-validation)
    let test4 = (test-config-validation)
    
    if ([$test1, $test2, $test3, $test4] | all { |result| ($result | default 0) == 0 }) {
        print "🎉 All validation tests passed!"
        return 0
    } else {
        print "❌ Some validation tests failed"
        return 1
    }
}