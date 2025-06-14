# GenQuery Testing Framework

This directory contains validation tests for the GenQuery genealogy reporting engine. Tests are designed to validate cross-platform functionality, path handling, configuration management, and core features.

## Test Organization

### Directory Structure
```
tests/
├── README.md                       # This documentation
├── run-tests.nu                    # Test runner and orchestration
├── test-cross-platform-paths.nu   # Cross-platform path handling tests
└── [future test files]             # Additional test suites as needed
```

### Test Suites

#### Cross-Platform Path Tests (`test-cross-platform-paths.nu`)
Validates that GenQuery's path handling works correctly across Windows, macOS, and Linux platforms.

**Test Functions:**
- `test-paths` - Basic path resolution and tilde expansion
- `test-genq-paths` - GenQuery-specific path resolution 
- `test-platform-dirs` - Platform-specific directory functions
- `test-path-construction` - Path join vs string concatenation comparison
- `test-genq-config` - Configuration path validation

## Running Tests

### Automated Execution

#### Run All Tests
```bash
# Execute all test suites
nu tests/run-tests.nu run-all
```

#### Run Specific Test Suite
```bash
# Run only cross-platform path tests
nu tests/run-tests.nu run-suite cross-platform-paths
```

#### Run Individual Test Function
```bash
# Run specific test function
nu tests/run-tests.nu run-function cross-platform-paths test-paths
```

#### List Available Tests
```bash
# Show all available test suites and functions
nu tests/run-tests.nu list
```

### Manual Execution

#### Direct Test Script Execution
```bash
# Run all tests in the cross-platform paths suite
nu tests/test-cross-platform-paths.nu

# Run specific test function
nu tests/test-cross-platform-paths.nu test-paths
nu tests/test-cross-platform-paths.nu test-genq-paths
nu tests/test-cross-platform-paths.nu test-platform-dirs
nu tests/test-cross-platform-paths.nu test-path-construction
nu tests/test-cross-platform-paths.nu test-genq-config
```

#### Step-by-Step Manual Testing

1. **Environment Setup**
   ```bash
   cd /path/to/genq
   export GENQ_HOME=$(pwd)
   ```

2. **Load GenQuery Environment**
   ```bash
   nu src/main.nu
   ```

3. **Run Path Tests**
   ```bash
   nu tests/test-cross-platform-paths.nu
   ```

4. **Verify Test Results**
   - Look for ✓ (success) vs ✗ (failure) markers
   - Check that paths resolve correctly for your platform
   - Verify that configuration paths exist and are accessible

## Test Interpretation

### Success Indicators
- **✓** Green checkmarks indicate successful tests
- Paths resolve to expected locations for the current platform
- Platform-specific directories are detected correctly
- All path construction methods work as expected

### Warning Indicators  
- **⚠** Yellow warnings indicate potential issues but not failures
- Missing optional configuration files (normal for test environment)
- Environment variables not set (normal when not running from GenQuery)
- Paths that don't exist but may be created later

### Failure Indicators
- **✗** Red X marks indicate test failures
- Path resolution errors
- Missing required files or directories  
- Platform detection issues
- Module import failures

### Example Output
```
=== GenQuery Cross-Platform Path Testing ===
Platform: macos unix
Path separator: /

=== Path Resolution Tests ===
✓ Tilde expansion
  Input:    ~/Documents/test.txt
  Resolved: /Users/username/Documents/test.txt

✓ Relative path from current directory
  Input:    ./relative/path
  Resolved: /Users/username/Code/genq/relative/path

=== GenQuery Path Resolution Tests ===
✓ Config file path
  Input:    config/default.toml
  Resolved: /Users/username/Code/genq/config/default.toml
  Exists:   true
```

## Cross-Platform Testing Strategy

### Development Testing (macOS)
Since development occurs primarily on macOS, these tests help ensure compatibility patterns are followed:

1. **Daily Development**: Run `nu tests/run-tests.nu run-suite cross-platform-paths`
2. **Before Commits**: Run `nu tests/run-tests.nu run-all`
3. **Path Changes**: Run `nu tests/test-cross-platform-paths.nu test-path-construction`

### Pre-Release Testing (Windows/Linux)
Before releasing or distributing GenQuery:

1. **Windows Testing**:
   ```cmd
   nu tests/run-tests.nu run-all
   ```
   - Verify backslash path separators work correctly
   - Test Windows-specific directories (AppData, etc.)
   - Validate installer script compatibility

2. **Linux Testing**:
   ```bash
   nu tests/run-tests.nu run-all
   ```
   - Verify Unix path conventions
   - Test XDG directory standards
   - Validate shell environment setup

### Continuous Integration Recommendations

For automated testing in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow snippet
- name: Run GenQuery Tests
  run: |
    cd genq
    nu tests/run-tests.nu run-all
```

## Adding New Tests

### Creating a New Test Suite

1. **Create Test Script**: `tests/test-new-feature.nu`
2. **Follow Naming Convention**: Use descriptive, hyphenated names
3. **Update Test Runner**: Add entry to `TEST_SUITES` in `run-tests.nu`
4. **Document in README**: Add section describing the new test suite

### Test Script Template
```nu
#!/usr/bin/env nu
# Description of what this test validates

use ../src/lib/common/module.nu

export def test-feature-name [] {
    print "=== Feature Test Description ==="
    
    try {
        # Test implementation
        print "✓ Test passed"
    } catch {
        print "✗ Test failed: ($in)"
    }
}

export def main [] {
    test-feature-name
    # Add more test functions as needed
}
```

## Troubleshooting

### Common Issues

1. **Module Import Errors**
   - Ensure you're running from the GenQuery root directory
   - Check that `src/lib/common/` modules exist
   - Verify relative paths in test scripts

2. **Environment Variables Not Set**
   - Run `nu src/main.nu` to initialize GenQuery environment
   - Check `$env.GENQ_HOME`, `$env.rmdb`, `$env.genq_sql`

3. **Path Resolution Failures**
   - Verify file permissions
   - Check that required directories exist
   - Confirm platform-specific path patterns

4. **Test Runner Issues**
   - Use absolute paths when running from different directories
   - Check Nushell version compatibility
   - Verify test script permissions

### Getting Help

- Review test output for specific error messages
- Check the main GenQuery documentation in `CLAUDE.md`
- Run individual test functions to isolate issues
- Use `nu tests/run-tests.nu list` to verify test availability

## Maintenance

### Regular Tasks
- Update tests when adding new path handling features
- Verify tests pass on all target platforms before releases
- Keep test documentation current with codebase changes
- Add regression tests for discovered platform-specific issues

### Performance Considerations
- Tests are designed to run quickly (< 30 seconds total)
- Avoid file system operations that require elevated permissions
- Use mock data when possible to avoid dependencies on external files