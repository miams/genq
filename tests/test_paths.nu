# Tests for GenQuery cross-platform path utilities
# Covers: resolve-path, genq-data-dir, genq-config-dir,
#         resolve-genq-path, platform-dirs

use std/testing *
use std assert
use "../src/lib/common/paths.nu" *

# --- resolve-path ---

@test
def "resolve-path expands tilde to absolute path" [] {
    let result = (resolve-path "~/Documents/test.txt")
    assert ($result | str starts-with "/")
    assert ($result | str contains "Documents/test.txt")
}

@test
def "resolve-path passes through absolute paths" [] {
    let result = (resolve-path "/tmp")
    assert ($result | str starts-with "/")
    assert ($result | str contains "tmp")
}

# --- genq-data-dir ---

@test
def "genq-data-dir returns non-empty string" [] {
    let dir = (genq-data-dir)
    assert (($dir | str length) > 0)
}

@test
def "genq-data-dir returns absolute path" [] {
    let dir = (genq-data-dir)
    assert ($dir | str starts-with "/")
}

# --- genq-config-dir ---

@test
def "genq-config-dir returns non-empty string" [] {
    let dir = (genq-config-dir)
    assert (($dir | str length) > 0)
}

@test
def "genq-config-dir returns absolute path" [] {
    let dir = (genq-config-dir)
    assert ($dir | str starts-with "/")
}

# --- resolve-genq-path ---

@test
def "resolve-genq-path joins relative path to base dir" [] {
    let result = (resolve-genq-path "config/default.toml" "/tmp")
    assert equal $result "/tmp/config/default.toml"
}

@test
def "resolve-genq-path passes through absolute paths" [] {
    let result = (resolve-genq-path "/absolute/path.txt" "/tmp")
    assert equal $result "/absolute/path.txt"
}

@test
def "resolve-genq-path uses pwd when no base provided" [] {
    let result = (resolve-genq-path "config/default.toml")
    assert ($result | str ends-with "config/default.toml")
    assert ($result | str starts-with "/")
}

# --- platform-dirs ---

@test
def "platform-dirs record has config key" [] {
    let dirs = (platform-dirs)
    assert ($dirs | columns | any { |c| $c == "config" })
}

@test
def "platform-dirs record has data key" [] {
    let dirs = (platform-dirs)
    assert ($dirs | columns | any { |c| $c == "data" })
}

@test
def "platform-dirs config value is non-empty" [] {
    let dirs = (platform-dirs)
    assert (($dirs.config | str length) > 0)
}
