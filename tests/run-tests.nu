#!/usr/bin/env nu
# GenQuery Test Runner
#
# Orchestrates execution of all GenQuery validation tests
# Supports both individual and batch test execution

# Available test suites
const TEST_SUITES = [
    {
        name: "cross-platform-paths"
        script: "test-cross-platform-paths.nu"
        description: "Cross-platform path handling validation"
        functions: ["test-paths", "test-genq-paths", "test-platform-dirs", "test-path-construction", "test-genq-config"]
    }
    {
        name: "config-commands"
        script: "test-config-commands.nu"
        description: "Configuration command functionality and regression tests"
        functions: ["test-config-help", "test-config-list", "test-config-get-valid", "test-config-get-invalid", "test-config-file-access", "test-function-collision-regression", "test-error-handling-scope"]
    }
]

# Run all tests in a test suite
export def run-suite [
    suite_name: string  # Name of the test suite to run
] {
    let suite = ($TEST_SUITES | where name == $suite_name | first)
    
    if ($suite | is-empty) {
        error make {
            msg: $"Unknown test suite: ($suite_name)"
            help: $"Available suites: (($TEST_SUITES | get name) | str join ', ')"
        }
    }
    
    print $"=== Running Test Suite: ($suite.description) ==="
    print $"Script: ($suite.script)"
    print ""
    
    try {
        nu $"tests/($suite.script)"
        print $"✓ Test suite ($suite_name) completed successfully"
    } catch {
        print $"✗ Test suite ($suite_name) failed: ($in)"
        return 1
    }
}

# Run a specific test function from a suite
export def run-function [
    suite_name: string     # Name of the test suite
    function_name: string  # Name of the test function to run
] {
    let suite = ($TEST_SUITES | where name == $suite_name | first)
    
    if ($suite | is-empty) {
        error make {
            msg: $"Unknown test suite: ($suite_name)"
            help: $"Available suites: (($TEST_SUITES | get name) | str join ', ')"
        }
    }
    
    if ($function_name not-in $suite.functions) {
        error make {
            msg: $"Unknown function: ($function_name)"
            help: $"Available functions: (($suite.functions) | str join ', ')"
        }
    }
    
    print $"=== Running Test Function: ($function_name) ==="
    print $"Suite: ($suite.description)"
    print ""
    
    try {
        nu $"tests/($suite.script)" $function_name
        print $"✓ Test function ($function_name) completed successfully"
    } catch {
        print $"✗ Test function ($function_name) failed: ($in)"
        return 1
    }
}

# Run all available test suites
export def run-all [] {
    print "=== GenQuery Test Suite Runner ==="
    print $"Running all (($TEST_SUITES | length)) test suites"
    print ""
    
    let results = ($TEST_SUITES | each {|suite|
        print $"Running suite: ($suite.name)"
        
        try {
            run-suite $suite.name
            print ""
            {suite: $suite.name, status: "passed"}
        } catch {
            print $"Suite ($suite.name) failed"
            print ""
            {suite: $suite.name, status: "failed"}
        }
    })
    
    let passed = ($results | where status == "passed" | length)
    let failed = ($results | where status == "failed" | length)
    
    print "=== Test Summary ==="
    print $"Passed: ($passed)"
    print $"Failed: ($failed)"
    print $"Total:  (($passed + $failed))"
    
    if $failed > 0 {
        print ""
        print "⚠ Some tests failed. Review output above for details."
        return 1
    } else {
        print ""
        print "✓ All tests passed successfully!"
        return 0
    }
}

# List available test suites and functions
export def list [] {
    print "=== Available Test Suites ==="
    
    for suite in $TEST_SUITES {
        print $"($suite.name):"
        print $"  Description: ($suite.description)"
        print $"  Script: ($suite.script)"
        print $"  Functions:"
        
        for func in $suite.functions {
            print $"    - ($func)"
        }
        print ""
    }
    
    print "Usage Examples:"
    print "  nu tests/run-tests.nu run-all                    # Run all test suites"
    print "  nu tests/run-tests.nu run-suite cross-platform-paths  # Run specific suite"
    print "  nu tests/run-tests.nu run-function cross-platform-paths test-paths  # Run specific function"
    print "  nu tests/run-tests.nu list                       # Show this help"
}

# Main entry point with help
export def main [
    command?: string  # Command to execute (run-all, run-suite, run-function, list)
    ...args: string   # Additional arguments for the command
] {
    match $command {
        "run-all" => { run-all }
        "run-suite" => {
            if ($args | length) < 1 {
                error make {msg: "run-suite requires a suite name"}
            }
            run-suite $args.0
        }
        "run-function" => {
            if ($args | length) < 2 {
                error make {msg: "run-function requires suite name and function name"}
            }
            run-function $args.0 $args.1
        }
        "list" => { list }
        null => { list }
        _ => {
            print $"Unknown command: ($command)"
            print ""
            list
        }
    }
}