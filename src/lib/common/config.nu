# GenQuery Configuration Management
#
# Handles loading and managing GenQuery configuration from multiple sources
# with proper cross-platform support and backward compatibility

use paths.nu

# Default configuration structure
export def default_config [] {
    {
        database: {
            active: "demo"
            connections: {
                demo: "./data/pres2020.rmtree"
            }
        }
        paths: {
            genq_home: "."
            sql_dir: "./sql"
            lib_dir: "./src/lib"
            ext_dir: "./src/lib/ext"
            output_dir: "./vault"
        }
        display: {
            date_format: 1
            table_mode: "rounded"
        }
        extensions: {
            enabled: ["miams", "pres2020"]
        }
    }
}

# Get configuration file search locations in priority order (later overrides earlier)
def config_locations [] {
    [
        (default_config_path)                           # Built-in defaults
        (paths genq-config-dir | path join "config.toml")  # User global config
        "./genq.toml"                                   # Project-local config
        ($env.GENQ_CONFIG_FILE? | default "")          # Environment override
    ]
    | where $it != ""  # Remove empty paths
}

# Get path to default config file location
def default_config_path [] {
    "./config/default.toml"
}

# Load configuration from all available sources
export def load_config [] {
    mut config = (default_config)
    
    let locations = (config_locations)
    
    # Load configs in order, with later configs overriding earlier ones
    for location in $locations {
        let resolved_path = (paths resolve-path $location)
        
        if ($resolved_path | path exists) {
            try {
                let file_config = (open $resolved_path | from toml)
                $config = (merge_config $config $file_config)
                # print $"✓ Loaded config from: ($resolved_path)"
            } catch {
                print $"⚠ Warning: Could not load config from ($resolved_path): ($in)"
            }
        }
    }
    
    # Resolve all paths in the configuration
    resolve_config_paths $config
}

# Recursively merge two configuration records
def merge_config [base: record, override: record] {
    mut result = $base
    
    for key in ($override | columns) {
        let override_value = ($override | get $key)
        
        if ($result | columns | any {|col| $col == $key}) {
            let base_value = ($result | get $key)
            
            # If both values are records, merge recursively
            if (($base_value | describe) == "record" and ($override_value | describe) == "record") {
                $result = ($result | upsert $key (merge_config $base_value $override_value))
            } else {
                $result = ($result | upsert $key $override_value)
            }
        } else {
            $result = ($result | upsert $key $override_value)
        }
    }
    
    $result
}

# Resolve all paths in configuration to absolute paths
def resolve_config_paths [config: record] {
    mut resolved = $config
    
    # Determine GenQuery home directory
    let genq_home = (paths resolve-path $config.paths.genq_home)
    
    # Resolve paths section
    let resolved_paths = ($config.paths | transpose key path | each {|item|
        let resolved_path = if ($item.key == "genq_home") {
            (paths resolve-path $item.path)
        } else {
            (paths resolve-genq-path $item.path $genq_home)
        }
        {key: $item.key, path: $resolved_path}
    } | transpose key path | into record)
    
    $resolved = ($resolved | upsert paths $resolved_paths)
    
    # Resolve database connection paths
    let resolved_connections = ($config.database.connections | transpose key path | each {|item|
        let resolved_path = (paths resolve-genq-path $item.path $genq_home)
        {key: $item.key, path: $resolved_path}
    } | transpose key path | into record)
    
    $resolved = ($resolved | upsert database.connections $resolved_connections)
    
    $resolved
}

# Set up GenQuery environment variables based on configuration
export def setup_environment [config: record] {
    # Store the full config for other commands to use
    $env.GENQ_CONFIG = $config
    
    # Set database path
    let active_db = $config.database.active
    if ($active_db in ($config.database.connections | columns)) {
        $env.rmdb = ($config.database.connections | get $active_db)
    } else {
        error make {
            msg: $"Active database '($active_db)' not found in connections"
            help: $"Available databases: (($config.database.connections | columns) | str join ', ')"
        }
    }
    
    # Set other environment variables
    $env.genq_sql = $config.paths.sql_dir
    $env.RDMF = $config.display.date_format
    
    # Add to NU_LIB_DIRS if not already present
    let genq_libs = [$config.paths.lib_dir, $config.paths.ext_dir]
    let current_libs = ($env.NU_LIB_DIRS? | default [])
    let new_libs = ($genq_libs | where {|lib| $lib not-in $current_libs})
    
    if ($new_libs | length) > 0 {
        $env.NU_LIB_DIRS = ($current_libs | append $new_libs)
    }
}

# Check if old environment-based configuration exists
export def has_legacy_config [] {
    ($env.rmdb? | is-not-empty) or ($env.genq_sql? | is-not-empty)
}

# Get current active database name from config
export def get_active_database [] {
    if ($env.GENQ_CONFIG? | is-empty) {
        error make {msg: "GenQuery configuration not loaded"}
    }
    
    $env.GENQ_CONFIG.database.active
}

# Get all available database connections
export def get_database_connections [] {
    if ($env.GENQ_CONFIG? | is-empty) {
        error make {msg: "GenQuery configuration not loaded"}
    }
    
    $env.GENQ_CONFIG.database.connections
}

# Initialize GenQuery with configuration
export def init [] {
    let config = (load_config)
    setup_environment $config
    
    # Validate that essential paths exist
    if not ($env.rmdb | path exists) {
        print $"⚠ Warning: Active database not found: ($env.rmdb)"
        print "  You may need to run 'syncdb' or update your configuration"
    }
    
    if not ($env.genq_sql | path exists) {
        print $"⚠ Warning: SQL directory not found: ($env.genq_sql)"
    }
    
    # print $"✓ GenQuery initialized with database: (get_active_database)"
}