# GenQuery Configuration Management Module
#
# Main entry point for GenQuery configuration system
# Coordinates the modular configuration subsystems

# Import functions for internal use only (not exported)
use ui.nu [interactive-select]
use persistence.nu [save-config, load-config, config-exists]
use environment.nu [reload-genq-environment, update-env-alias, verify-syncdb-setup]
use validation.nu [validate-file-path, validate-directory-path, validate-database-mode, validate-extensions, check-writable-path]
use display.nu [list-config]
use wizard.nu [config-wizard]

# Configuration management main entry point
@category "genq-common"
def genq-config-impl [
    subcommand?: string   # Subcommand: list or empty for interactive mode
    ...args: string       # Arguments for subcommands (currently unused)
] {
    # Use GENQ_HOME environment variable to find config
    let genq_home = ($env.GENQ_HOME? | default $env.PWD)
    let config_path = ($genq_home | path join "config" "default.toml")
    
    # Validate GENQ_HOME exists and is accessible
    if not ($genq_home | path exists) {
        print $"(ansi red)Error:(ansi reset) GENQ_HOME directory not found: ($genq_home)"
        print "Make sure you're running from the GenQuery directory or GENQ_HOME is set correctly."
        return
    }
    
    # Validate config file exists
    if not ($config_path | path exists) {
        print $"(ansi red)Error:(ansi reset) Configuration file not found at ($config_path)"
        print "This usually means GenQuery is not properly installed or configured."
        print "Expected config structure: <genq_home>/config/default.toml"
        return
    }
    
    # Test config file is readable and valid
    try {
        let test_config = (open $config_path)
    } catch { |error|
        print $"(ansi red)Error:(ansi reset) Configuration file is corrupted or unreadable"
        print $"Location: ($config_path)"
        print $"Reason: ($error.msg)"
        print "You may need to restore from backup or reinstall GenQuery."
        return
    }
    
    # Normalize subcommand input (case-insensitive)
    let normalized_subcommand = ($subcommand | default "" | str downcase)
    
    match $normalized_subcommand {
        "list" => {
            # Show current configuration settings
            list-config $config_path
        }
        "" => {
            # Interactive configuration wizard (default when no subcommand)
            config-wizard $config_path
        }
        _ => {
            # Handle invalid subcommands with helpful error message
            print $"(ansi red)Error:(ansi reset) Unknown config command '($subcommand)'"
            print "Valid commands:"
            print "  genq config          - Interactive setup wizard"
            print "  genq config list     - Show current settings"
            print "  genq config db <name> - Switch active database (e.g. demo, production)"
        }
    }
}

# Show current GenQuery configuration settings.
@category "genq-common"
export def list [] {
    genq-config-impl list
}

# Switch the active database connection (e.g. demo or production).
@category "genq-common"
export def db [
    connection: string   # Connection name defined in config (e.g. demo, production)
] {
    let genq_home = ($env.GENQ_HOME? | default $env.PWD)
    let config_path = ($genq_home | path join "config" "default.toml")
    let cfg = (open $config_path)
    let connections = ($cfg.database.connections | columns)
    if not ($connection in $connections) {
        print $"(ansi red)Error:(ansi reset) Unknown connection '($connection)'. Available: ($connections | str join ', ')"
        return
    }
    let updated = ($cfg | upsert database.active $connection)
    $updated | to toml | save --force $config_path
    let db_file = ($updated.database.connections | get $connection)
    print $"(ansi green)✓ Switched to '($connection)' \(($db_file)\)(ansi reset)"
    print $"(ansi yellow)Note: restart your shell session or re-source main.nu for the change to take effect.(ansi reset)"
}

# Interactive configuration wizard for GenQuery settings.
@category "genq-common"
export def main [] {
    genq-config-impl
}