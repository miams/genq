# GenQuery Configuration Persistence
#
# Handles saving and loading configuration to/from TOML files


# Load configuration from TOML file
@category "genq-common"
export def load-config [
    config_path: string    # Path to config file
] {
    try {
        open $config_path
    } catch { |error|
        error make {msg: $"Failed to load configuration from ($config_path): ($error.msg)"}
    }
}

# Save configuration changes to TOML file and update environment
@category "genq-common"
export def save-config [
    config_path: string    # Path to config file
    db_mode: string        # Database mode (demo/production)
    extensions: list       # List of enabled extensions  
    sync_source?: string   # RootsMagic database path (for production)
] {
    try {
        let current_config = (load-config $config_path)
        
        # Update configuration values
        let updated_config = ($current_config 
            | upsert database.active $db_mode
            | upsert extensions.enabled $extensions
        )
        
        # Ensure database.connections always point to local target files (not source files)
        let with_connections = if ("sync" in ($current_config | columns)) and ("targets" in ($current_config.sync | columns)) {
            ($updated_config 
                | upsert database.connections.production ($current_config.sync.targets.production? | default "./data/Iiams.rmtree")
                | upsert database.connections.demo ($current_config.sync.targets.demo? | default "./data/pres2025.rmtree")
            )
        } else {
            # Fallback to standard paths if sync.targets not configured
            ($updated_config 
                | upsert database.connections.production "./data/Iiams.rmtree"
                | upsert database.connections.demo "./data/pres2025.rmtree"
            )
        }
        
        # Add sync source for production mode if provided
        let final_config = if $db_mode == "production" and ($sync_source != null) and ($sync_source | str trim | is-not-empty) {
            $with_connections | upsert sync.sources.production $sync_source
        } else {
            $with_connections
        }
        
        # Save to file
        $final_config | to toml | save --force $config_path
        
        # Return the final config for environment reloading by caller
        $final_config
        
    } catch { |error|
        error make {msg: $"Failed to save configuration: ($error.msg)"}
    }
}

# Check if configuration file exists and is readable
@category "genq-common"
export def config-exists [
    config_path: string    # Path to config file
] {
    ($config_path | path exists) and (try { (open $config_path); true } catch { false })
}