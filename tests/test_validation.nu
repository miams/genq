# Tests for GenQuery input validation utilities
# Covers: sanitize-file-path, validate-rmtree-file, validate-directory-path,
#         validate-database-mode, validate-extensions

use std/testing *
use std assert
use "../src/lib/common/genq config/validation.nu" *

# --- sanitize-file-path ---

@test
def "sanitize-file-path trims leading and trailing whitespace" [] {
    let result = (sanitize-file-path "  ~/test/path.txt  " "test")
    assert ($result | str contains "test/path.txt")
}

@test
def "sanitize-file-path replaces control characters with spaces" [] {
    let result = (sanitize-file-path "test\r\n\tpath" "test")
    assert ($result | str contains "test path")
}

@test
def "sanitize-file-path rejects empty input" [] {
    assert error {|| sanitize-file-path "   " "test file"}
}

@test
def "sanitize-file-path expands tilde" [] {
    let result = (sanitize-file-path "~/Documents/test.txt" "test")
    assert ($result | str starts-with "/")
}

# --- validate-rmtree-file ---

@test
def "validate-rmtree-file rejects nonexistent file" [] {
    assert error {|| validate-rmtree-file "/nonexistent/path/test.rmtree"}
}

@test
def "validate-rmtree-file rejects wrong extension" [] {
    let tmp = (mktemp -t "genq-test-XXXXXX.txt")
    "content" | save --force $tmp
    assert error {|| validate-rmtree-file $tmp}
    rm -f $tmp
}

# --- validate-directory-path ---

@test
def "validate-directory-path accepts existing directory" [] {
    let result = (validate-directory-path "/tmp" "temp")
    assert ($result | path exists)
    assert (($result | path type) == "dir")
}

@test
def "validate-directory-path rejects nonexistent directory" [] {
    assert error {|| validate-directory-path "/nonexistent/dir/that/cannot/exist" "test"}
}

@test
def "validate-directory-path rejects empty path" [] {
    assert error {|| validate-directory-path "   " "test"}
}

# --- validate-database-mode ---

@test
def "validate-database-mode accepts production" [] {
    assert equal (validate-database-mode "production") "production"
}

@test
def "validate-database-mode accepts demo" [] {
    assert equal (validate-database-mode "demo") "demo"
}

@test
def "validate-database-mode rejects invalid mode" [] {
    assert error {|| validate-database-mode "invalid"}
}

@test
def "validate-database-mode rejects empty string" [] {
    assert error {|| validate-database-mode ""}
}

# --- validate-extensions ---

@test
def "validate-extensions returns empty list unchanged" [] {
    assert equal (validate-extensions []) []
}

@test
def "validate-extensions returns valid extension list" [] {
    assert equal (validate-extensions ["miams" "pres2020"]) ["miams" "pres2020"]
}

# --- validate-file-path ---

@test
def "validate-file-path accepts existing file" [] {
    let tmp = (mktemp -t "genq-test-XXXXXX")
    "content" | save --force $tmp
    let result = (validate-file-path $tmp "test")
    assert ($result | path exists)
    rm -f $tmp
}

@test
def "validate-file-path rejects nonexistent file" [] {
    assert error {|| validate-file-path "/nonexistent/path/file.txt" "test"}
}
