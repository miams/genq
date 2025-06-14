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
    subcommand?: string   # Subcommand: help, list, get, set, or empty for interactive mode
    ...args: string       # Arguments for subcommands
] {
    # Use GENQ_HOME environment variable to find config
    let genq_home = ($env.GENQ_HOME? | default $env.PWD)
    let config_path = ($genq_home | path join "config" "default.toml")
    
    match $subcommand {
        "list" => {
            list-config $config_path
        }
        _ => {
            # Interactive configuration wizard
            config-wizard $config_path
        }
    }
}

# Show current GenQuery configuration settings.
@category "genq-common" 
export def list [] {
    genq-config-impl list
}

# Interactive configuration wizard for GenQuery settings.
@category "genq-common"
export def main [] {
    genq-config-impl
}