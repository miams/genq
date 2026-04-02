# Tests for GenQuery cross-platform path utilities
# Covers: resolve-path, genq-data-dir, genq-config-dir,
#         resolve-genq-path, platform-dirs
# Label: [fast] — no database required

use std/testing *
use std assert
use "../src/lib/common/paths.nu" *

# --- resolve-path ---

@test
def "fast resolve-path expands tilde to absolute path" [] {
    let result = (resolve-path "~/Documents/test.txt")
    assert (not ($result | str contains "~"))
    assert ($result | str contains ("Documents" | path join "test.txt"))
}

@test
def "fast resolve-path passes through absolute paths" [] {
    let abs = ($nu.home-dir | path expand)
    let result = (resolve-path $abs)
    assert equal $result $abs
}

# --- genq-data-dir ---

@test
def "fast genq-data-dir returns non-empty string" [] {
    let dir = (genq-data-dir)
    assert (($dir | str length) > 0)
}

@test
def "fast genq-data-dir returns absolute path" [] {
    let dir = (genq-data-dir)
    assert (not ($dir | str starts-with "."))
    assert (not ($dir | str contains "~"))
}

# --- genq-config-dir ---

@test
def "fast genq-config-dir returns non-empty string" [] {
    let dir = (genq-config-dir)
    assert (($dir | str length) > 0)
}

@test
def "fast genq-config-dir returns absolute path" [] {
    let dir = (genq-config-dir)
    assert (not ($dir | str starts-with "."))
    assert (not ($dir | str contains "~"))
}

# --- resolve-genq-path ---

@test
def "fast resolve-genq-path joins relative path to base dir" [] {
    let base = (mktemp -d -t "genq-test-XXXXXX")
    let result = (resolve-genq-path "config/default.toml" $base)
    let expected = ($base | path join "config" | path join "default.toml" | path expand)
    assert equal $result $expected
    rm -rf $base
}

@test
def "fast resolve-genq-path passes through absolute paths" [] {
    let abs = ($nu.home-dir | path expand)
    let result = (resolve-genq-path $abs $nu.home-dir)
    assert equal $result $abs
}

@test
def "fast resolve-genq-path uses pwd when no base provided" [] {
    let result = (resolve-genq-path "config/default.toml")
    let expected_suffix = ("config" | path join "default.toml")
    assert ($result | str ends-with $expected_suffix)
    assert (not ($result | str starts-with "."))
}

# --- platform-dirs ---

@test
def "fast platform-dirs record has config key" [] {
    let dirs = (platform-dirs)
    assert ($dirs | columns | any { |c| $c == "config" })
}

@test
def "fast platform-dirs record has data key" [] {
    let dirs = (platform-dirs)
    assert ($dirs | columns | any { |c| $c == "data" })
}

@test
def "fast platform-dirs config value is non-empty" [] {
    let dirs = (platform-dirs)
    assert (($dirs.config | str length) > 0)
}
