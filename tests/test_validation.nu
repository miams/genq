# Tests for GenQuery input validation utilities
# Covers: sanitize-file-path, validate-rmtree-file, validate-directory-path,
#         validate-database-mode, validate-extensions
# Label: [fast] — no database required

use std/testing *
use std assert
use "../src/lib/common/genq config/validation.nu" *

# --- sanitize-file-path ---

@test
def "fast sanitize-file-path trims leading and trailing whitespace" [] {
    let result = (sanitize-file-path "  ~/test/path.txt  " "test")
    assert ($result | str contains ("test" | path join "path.txt"))
}

@test
def "fast sanitize-file-path replaces control characters with spaces" [] {
    let result = (sanitize-file-path "test\r\n\tpath" "test")
    assert ($result | str contains "test path")
}

@test
def "fast sanitize-file-path rejects empty input" [] {
    assert error {|| sanitize-file-path "   " "test file"}
}

@test
def "fast sanitize-file-path expands tilde" [] {
    let result = (sanitize-file-path "~/Documents/test.txt" "test")
    assert (not ($result | str contains "~"))
}

# --- validate-rmtree-file ---

@test
def "fast validate-rmtree-file rejects nonexistent file" [] {
    assert error {|| validate-rmtree-file "/nonexistent/path/test.rmtree"}
}

@test
def "fast validate-rmtree-file rejects wrong extension" [] {
    let tmp = (mktemp -t "genq-test-XXXXXX.txt")
    "content" | save --force $tmp
    assert error {|| validate-rmtree-file $tmp}
    rm -f $tmp
}

# --- validate-directory-path ---

@test
def "fast validate-directory-path accepts existing directory" [] {
    let tmp = (mktemp -d -t "genq-test-XXXXXX")
    let result = (validate-directory-path $tmp "temp")
    assert ($result | path exists)
    assert (($result | path type) == "dir")
    rm -rf $tmp
}

@test
def "fast validate-directory-path rejects nonexistent directory" [] {
    assert error {|| validate-directory-path "/nonexistent/dir/that/cannot/exist" "test"}
}

@test
def "fast validate-directory-path rejects empty path" [] {
    assert error {|| validate-directory-path "   " "test"}
}

# --- validate-database-mode ---

@test
def "fast validate-database-mode accepts production" [] {
    assert equal (validate-database-mode "production") "production"
}

@test
def "fast validate-database-mode accepts demo" [] {
    assert equal (validate-database-mode "demo") "demo"
}

@test
def "fast validate-database-mode rejects invalid mode" [] {
    assert error {|| validate-database-mode "invalid"}
}

@test
def "fast validate-database-mode rejects empty string" [] {
    assert error {|| validate-database-mode ""}
}

# --- validate-extensions ---

@test
def "fast validate-extensions returns empty list unchanged" [] {
    assert equal (validate-extensions []) []
}

@test
def "fast validate-extensions returns valid extension list" [] {
    assert equal (validate-extensions ["miams" "pres2025"]) ["miams" "pres2025"]
}

# --- validate-file-path ---

@test
def "fast validate-file-path accepts existing file" [] {
    let tmp = (mktemp -t "genq-test-XXXXXX")
    "content" | save --force $tmp
    let result = (validate-file-path $tmp "test")
    assert ($result | path exists)
    rm -f $tmp
}

@test
def "fast validate-file-path rejects nonexistent file" [] {
    assert error {|| validate-file-path "/nonexistent/path/file.txt" "test"}
}
