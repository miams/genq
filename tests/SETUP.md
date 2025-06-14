# GenQuery Testing Framework Setup

## Quick Start

### Run All Tests
```bash
nu tests/run-tests.nu run-all
```

### Run Path Tests Only
```bash
nu tests/run-tests.nu run-suite cross-platform-paths
```

### View Available Tests
```bash
nu tests/run-tests.nu list
```

## Test Files Created

1. **`tests/test-cross-platform-paths.nu`** - Cross-platform path validation tests
2. **`tests/run-tests.nu`** - Test orchestration and runner framework  
3. **`tests/README.md`** - Comprehensive testing documentation
4. **`tests/SETUP.md`** - This quick setup guide

## Test Functions Available

### Cross-Platform Path Tests
- `test-paths` - Basic path resolution and tilde expansion
- `test-genq-paths` - GenQuery-specific path resolution
- `test-platform-dirs` - Platform-specific directory functions  
- `test-path-construction` - Path join vs string concatenation
- `test-genq-config` - Configuration path validation

## Integration with Development Workflow

### Daily Development
```bash
# Quick path validation check
nu tests/run-tests.nu run-function cross-platform-paths test-genq-paths
```

### Before Commits
```bash
# Full test suite
nu tests/run-tests.nu run-all
```

### Cross-Platform Validation
```bash
# Run on Windows, macOS, and Linux before releases
nu tests/run-tests.nu run-suite cross-platform-paths
```

## Next Steps

1. Add tests to your development workflow
2. Run tests after making path-related changes
3. Use tests to validate cross-platform compatibility
4. Extend framework for additional GenQuery features

See `tests/README.md` for complete documentation.