#!/usr/bin/env nu
# GenQuery Test Runner — uses nutest framework
#
# Usage (from project root):
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu
#   nu --env-config ~/.config/nushell/env.nu tests/run-tests.nu --fail   # exit 1 on failure
#   nu tests/run-tests.nu --ci                                            # CI mode (no env config needed)

use ../deps/nutest/mod.nu *

const TESTS_DIR = path self | path dirname

def main [
    --fail  # Exit with code 1 if any tests fail
    --ci    # CI mode: JUnit report + test-summary.json + --fail
] {
    if $ci {
        (
            run-tests --path $TESTS_DIR
                --fail
                --display terminal
                --report { type: "junit", path: "test-report.xml" }
                --returns summary
        ) | to json | save --force test-summary.json
    } else if $fail {
        run-tests --path $TESTS_DIR --fail
    } else {
        run-tests --path $TESTS_DIR
    }
}
