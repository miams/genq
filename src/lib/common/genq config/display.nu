# GenQuery Configuration Display
#
# Handles displaying current configuration settings to users

use persistence.nu [load-config, config-exists]

# Display current GenQuery configuration settings
@category "genq-common"
export def list-config [
    config_path: string    # Path to configuration file
] {
    # Check if config file exists
    if not (config-exists $config_path) {
        print $"(ansi red)Error: Configuration file not found(ansi reset)"
        print $"Expected location: ($config_path)"
        let genq_home = ($config_path | path dirname | path dirname)
        print $"Current GENQ_HOME: ($genq_home)"
        print "Please ensure GenQuery is properly installed and GENQ_HOME is set correctly."
        print "Run 'genq config' to set up GenQuery."
        return
    }
    
    print $"(ansi green_bold)Your GenQuery Settings:(ansi reset)\n"
    
    let config = try {
        load-config $config_path
    } catch { |error|
        if ($error.msg | str contains "Failed to load configuration") {
            if ($error.msg | str contains "Permission denied") {
                print $"(ansi red)Error: Cannot read configuration file(ansi reset)"
                print $"Location: ($config_path)"
                print "Please check file permissions and try again."
            } else {
                print $"(ansi red)Error: Configuration file is corrupted or invalid(ansi reset)"
                print $"Location: ($config_path)"
                print "The file may have invalid TOML syntax or structure."
            }
        } else {
            print $"(ansi red)Could not read configuration file(ansi reset)"
            print $"Reason: ($error.msg)"
        }
        print "Run 'genq config' to reconfigure GenQuery."
        return
    }
    
    # Display database information
    print $"(ansi cyan)Database you're using:(ansi reset) ($config.database.active)"
    let active_db = $config.database.active
    let db_path = if $active_db == "production" { 
        $config.database.connections.production 
    } else { 
        $config.database.connections.demo 
    }
    print $"(ansi cyan)Database file:(ansi reset) ($db_path)"
    
    # Display extension information
    let extension_list = ($config.extensions.enabled | str join ', ')
    print $"(ansi cyan)Extensions loaded:(ansi reset) ($extension_list)"
    
    # Display output directory
    print $"(ansi cyan)Reports saved to:(ansi reset) ($config.paths.output_dir)"
    
    # Display sync settings if available
    if ("sync" in ($config | columns)) {
        print ""
        print $"(ansi cyan_bold)Database Sync Settings:(ansi reset)"
        if ($config.database.active == "production") {
            let source_path = if ("sources" in ($config.sync | columns)) {
                ($config.sync.sources.production? | default "Not configured")
            } else {
                "Not configured"
            }
            let target_path = if ("targets" in ($config.sync | columns)) {
                ($config.sync.targets.production? | default "./data/Iiams.rmtree")
            } else {
                "./data/Iiams.rmtree"
            }
            print $"(ansi cyan)Your RootsMagic database:(ansi reset) ($source_path)"
            print $"(ansi cyan)GenQuery working copy:(ansi reset) ($target_path)"
        } else {
            print $"(ansi light_gray)Sync settings available when using production database(ansi reset)"
        }
    }
    
    print ""
    print $"(ansi blue)💡 Run 'genq config' to change these settings(ansi reset)"
    print $"(ansi blue)💡 Run 'genq config --help' for more options(ansi reset)"
}