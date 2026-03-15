# Smoke tests — syntax checks for GenQuery source files
# These tests verify that all key source files parse without errors.
# No database required; safe for CI.

use std/testing *
use std assert

const PROJECT_ROOT = path self | path dirname | path join ".."

# Helper: syntax-check a file relative to project root by sourcing it.
# Sets NU_LIB_DIRS from the project layout so this works without user env config (CI-safe).
# Returns exit code (0 = ok, 1 = parse error).
def nu-check [rel_path: string]: nothing -> int {
    let abs_path  = ($PROJECT_ROOT | path join $rel_path | path expand)
    let lib_dirs  = ([$PROJECT_ROOT "src/lib" | path expand, $PROJECT_ROOT "src/lib/ext" | path expand]
                    | each { path expand }
                    | str join ":")
    with-env { NU_LIB_DIRS: $lib_dirs } {
        let result = (^nu --no-config-file --commands $"source '($abs_path)'" | complete)
        $result.exit_code
    }
}

# --- Core source files ---

@test
def "src/main.nu passes syntax check" [] {
    assert equal (nu-check "src/main.nu") 0
}

@test
def "src/lib/common/mod.nu passes syntax check" [] {
    assert equal (nu-check "src/lib/common/mod.nu") 0
}

@test
def "src/lib/common/paths.nu passes syntax check" [] {
    assert equal (nu-check "src/lib/common/paths.nu") 0
}

@test
def "genq config validation.nu passes syntax check" [] {
    assert equal (nu-check "src/lib/common/genq config/validation.nu") 0
}

@test
def "src/lib/common/genq list people/mod.nu passes syntax check" [] {
    assert equal (nu-check "src/lib/common/genq list people/mod.nu") 0
}

@test
def "src/lib/common/genq list events/mod.nu passes syntax check" [] {
    assert equal (nu-check "src/lib/common/genq list events/mod.nu") 0
}
