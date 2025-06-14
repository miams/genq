# GenQuery Environment Variable Management
#
# Handles environment variable updates and syncdb alias management

# Reload GenQuery environment variables from updated configuration
@category "genq-common"  
export def reload-genq-environment [
    config: record         # Updated configuration data
] {
    try {
        # Update core environment variables that GenQuery uses
        $env.GENQ_CONFIG = $config
        
        # Convert relative database path to absolute path based on GENQ_HOME
        let db_path = ($config.database.connections | get $config.database.active)
        $env.rmdb = if ($db_path | str starts-with "./") {
            let genq_home = ($env.GENQ_HOME? | default $env.PWD)
            ($genq_home | path join ($db_path | str substring 2..))
        } else {
            $db_path | path expand
        }
        
        $env.genq_sql = $config.paths.sql_dir
        $env.RDMF = $config.display.date_format
        
    } catch { |error|
        # Don't fail the config save if environment reload has issues
        # Just silently continue - the config is saved and will work on restart
    }
}

# Update env.nu with syncdb alias
@category "genq-common"
export def update-env-alias [
    alias_cmd: string     # The alias command to add
    sync_source: string   # Source path for verification
] {
    let env_path = ($nu.config-path | path dirname | path join "env.nu")
    
    # Check if env.nu exists
    if not ($env_path | path exists) {
        print $"(ansi red)Error: Could not find env.nu at ($env_path)(ansi reset)"
        print "Please create the file first or add the alias manually:"
        print $alias_cmd
        return
    }
    
    try {
        # Read current env.nu content
        let current_content = (open $env_path --raw)
        
        # Check if syncdb alias already exists
        let has_syncdb = ($current_content | str contains "alias syncdb")
        
        let new_content = if $has_syncdb {
            # Replace existing syncdb alias
            $current_content | str replace --regex "alias syncdb = .*" $alias_cmd
        } else {
            # Add new syncdb alias at the end
            $current_content + "\n\n## GenQuery Database Sync\n" + $alias_cmd + "\n"
        }
        
        # Create backup (overwrite if exists)
        let backup_path = $env_path + ".genq_backup"
        $current_content | save --force $backup_path
        
        # Write updated content
        $new_content | save --force $env_path
        
        if $has_syncdb {
            print $"(ansi green)✓ Updated existing syncdb command in env.nu(ansi reset)"
        } else {
            print $"(ansi green)✓ Added syncdb command to env.nu(ansi reset)"
        }
        
        print $"(ansi blue)ℹ To activate immediately, run: source ($env_path)(ansi reset)"
        
        # Verify the setup by reloading and testing
        verify-syncdb-setup $sync_source
        
    } catch { |error|
        print $"(ansi red)Error: Failed to update env.nu - ($error.msg)(ansi reset)"
        print "Please add this line manually to your env.nu file:"
        print $alias_cmd
    }
}

# Verify syncdb alias is working correctly
@category "genq-common"
export def verify-syncdb-setup [
    expected_source: string   # Expected source path
] {
    try {
        # Check if the syncdb alias is working by testing if it exists in scope
        let aliases = (scope aliases)
        let syncdb_alias = ($aliases | where name == "syncdb")
        
        if ($syncdb_alias | is-empty) {
            print $"(ansi yellow)Note: syncdb command will be available when you start a new shell(ansi reset)"
            let env_path = ($nu.config-path | path dirname | path join "env.nu")
            print $"Or run: source ($env_path)"
        } else {
            let alias_expansion = ($syncdb_alias | get expansion.0)
            if ($alias_expansion | str contains $expected_source) {
                print $"(ansi green)✓ Database sync is ready! Use 'syncdb' to update your data.(ansi reset)"
            } else {
                print $"(ansi yellow)Warning: syncdb command exists but may not be configured correctly(ansi reset)"
            }
        }
    } catch {
        print $"(ansi yellow)Note: syncdb command will be available when you start a new shell(ansi reset)"
        print "Or run: source ~/.config/nushell/env.nu"
    }
}