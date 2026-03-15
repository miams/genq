# Tests for GenQuery configuration file structure and validation
# Uses temporary config environments to avoid touching user config

use std/testing *
use std assert
use helpers.nu *
use "../src/lib/common/genq config/validation.nu" [validate-database-mode]

@before-each
def setup [] {
    let scenarios = (get-test-scenarios)
    let ctx = (create-test-config $scenarios.demo_basic)
    $ctx
}

@after-each
def teardown [] {
    let ctx = $in
    rm -rf $ctx.temp_dir
}

# --- Config file structure ---

@test
def "config TOML has database section" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert ($config | columns | any { |c| $c == "database" })
}

@test
def "config database has active key" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert ($config.database | columns | any { |c| $c == "active" })
}

@test
def "config database active is demo" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert equal $config.database.active "demo"
}

@test
def "config database connections has demo key" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert ($config.database.connections | columns | any { |c| $c == "demo" })
}

@test
def "config extensions section exists" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert ($config | columns | any { |c| $c == "extensions" })
}

# --- Validate that demo_basic scenario is readable ---

@test
def "demo_basic scenario loads without error" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    assert (not ($config | is-empty))
}

# --- Config validation integration ---

@test
def "validate-database-mode demo matches config active" [] {
    let ctx = $in
    let config = (open $ctx.config_path)
    let active = $config.database.active
    let validated = (validate-database-mode $active)
    assert equal $validated "demo"
}
