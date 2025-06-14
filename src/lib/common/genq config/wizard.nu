# GenQuery Configuration Wizard
#
# Interactive configuration wizard for setting up GenQuery database and extensions

use ui.nu [interactive-select]
use persistence.nu [load-config, save-config]
use environment.nu [update-env-alias, reload-genq-environment]
use validation.nu [validate-database-mode, validate-extensions, validate-file-path, check-writable-path, sanitize-file-path, validate-rmtree-file]
use display.nu [list-config]

# Discover available extensions by scanning src/lib/ext/ directory
@category "genq-common"
def discover-extensions [] {
    let genq_home = ($env.GENQ_HOME? | default $env.PWD)
    let ext_dir = ($genq_home | path join "src" "lib" "ext")
    
    if not ($ext_dir | path exists) {
        return []
    }
    
    try {
        # Get all directories in ext/ that have a mod.nu file
        ls $ext_dir 
        | where type == dir 
        | get name 
        | path basename
        | where { |ext_name| 
            ($ext_dir | path join $ext_name "mod.nu" | path exists)
        }
        | each { |ext_name|
            let readme_path = ($ext_dir | path join $ext_name "readme.md")
            let description = try {
                if ($readme_path | path exists) {
                    # Try to extract first line or title from readme
                    let content = (open $readme_path --raw | lines | first)
                    if ($content | str starts-with "**") {
                        $content | str replace --all "**" ""
                    } else if ($content | str starts-with "# ") {
                        $content | str substring 2..
                    } else {
                        $"Extension for ($ext_name)"
                    }
                } else {
                    $"Extension for ($ext_name)"
                }
            } catch {
                $"Extension for ($ext_name)"
            }
            
            {
                name: $ext_name
                description: $description
            }
        }
    } catch {
        return []
    }
}

# Interactive configuration wizard implementation
@category "genq-common"
export def config-wizard [
    config_path: string    # Path to configuration file
] {
    print $"(ansi green_bold)GenQuery Setup Wizard(ansi reset)"
    print "This will help you configure GenQuery for your genealogy research."
    print "You can press Enter to keep current settings or type 'help' for more info.\n"
    
    let config = try {
        load-config $config_path
    } catch { |error|
        if ($error.msg | str contains "Failed to load configuration") {
            if ($error.msg | str contains "No such file") {
                print $"(ansi red)Error: Configuration file not found(ansi reset)"
                print $"Expected location: ($config_path)"
                print "Please ensure GenQuery is properly installed and GENQ_HOME is set correctly."
            } else if ($error.msg | str contains "Permission denied") {
                print $"(ansi red)Error: Cannot read configuration file(ansi reset)"
                print $"Location: ($config_path)"
                print "Please check file permissions and try again."
            } else {
                print $"(ansi red)Error: Configuration file is corrupted or invalid(ansi reset)"
                print $"Location: ($config_path)"
                print "The file may have invalid TOML syntax or structure."
            }
        } else {
            print $"(ansi red)Error: Could not read configuration file(ansi reset)"
            print $"Location: ($config_path)"
            print $"Reason: ($error.msg)"
        }
        print "Run 'genq config --help' for setup information."
        return
    }
    
    # Pre-wizard confirmation with Y/N/List options
    print $"(ansi yellow_bold)Ready to configure GenQuery?(ansi reset)"
    print "This wizard will guide you through setting up your database and extensions."
    print ""
    
    let proceed_options = [
        {value: "yes", label: "Yes", description: "Continue with configuration wizard"},
        {value: "no", label: "No", description: "Cancel and return to command line"},
        {value: "list", label: "List", description: "Show current settings first"}
    ]
    
    let proceed_choice = try {
        (interactive-select "What would you like to do?" $proceed_options 0)
    } catch {
        # Handle interruption/cancellation
        print $"\n(ansi yellow)Configuration cancelled.(ansi reset)"
        return
    }
    
    match $proceed_choice {
        "no" => {
            print $"(ansi yellow)Configuration cancelled.(ansi reset)"
            print "Run 'genq config' again when you're ready to configure GenQuery."
            return
        }
        "list" => {
            # Show current settings using display module
            list-config $config_path
            print ""
            
            # Ask again after showing current settings
            let continue_options = [
                {value: "yes", label: "Yes", description: "Continue with configuration wizard"},
                {value: "no", label: "No", description: "Keep current settings and exit"}
            ]
            
            let continue_choice = try {
                (interactive-select "Continue with configuration wizard?" $continue_options 0)
            } catch {
                # Handle interruption - default to no
                "no"
            }
            
            if $continue_choice == "no" {
                print $"(ansi green)Keeping current settings.(ansi reset)"
                return
            }
        }
        _ => {
            # Continue with "yes" or any other input
        }
    }
    
    print $"(ansi green)Starting configuration wizard...(ansi reset)\n"
    
    # Database mode selection with explanation
    print $"(ansi yellow_bold)Step 1: Choose Your Database(ansi reset)"
    print "GenQuery can work with demo data \\(U.S. Presidents\\) or your personal genealogy data."
    print $"Current database: (ansi cyan)($config.database.active)(ansi reset)"
    print ""
    
    # Sort database options to put current setting first
    let all_db_options = [
        {value: "demo", label: "Demo", description: "Practice with U.S. Presidents data \\(safe for learning\\)"},
        {value: "production", label: "Production", description: "Use a copy of your actual RootsMagic genealogy database"}
    ]
    
    let db_options = if $config.database.active == "production" {
        # Put production first when it's current setting
        [$all_db_options.1, $all_db_options.0]
    } else {
        # Keep demo first when it's current setting  
        $all_db_options
    }
    
    let db_mode = try {
        validate-database-mode (interactive-select "Which database would you like to use?" $db_options 0)
    } catch {
        # Handle interruption - use current config
        $config.database.active
    }
    
    # Extensions selection with explanation
    print $"\n(ansi yellow_bold)Step 2: Choose Features to Load(ansi reset)"
    print "Extensions add extra commands for specific types of genealogy research."
    print $"Currently loaded: (ansi cyan)($config.extensions.enabled | str join ', ')(ansi reset)"
    print ""
    
    let available_extensions = try {
        (discover-extensions)
    } catch { |error|
        print $"(ansi yellow)Warning: Could not scan for extensions(ansi reset)"
        print $"Error: ($error.msg)"
        print "Continuing with current extension settings..."
        []
    }
    
    let extensions = if ($available_extensions | length) > 0 {
        # Create list of extension display strings with descriptions
        let extension_options = ($available_extensions | each { |ext|
            $"($ext.name) - ($ext.description)"
        })
        
        let selected_extensions = try {
            ($extension_options | input list --multi "Which extensions would you like to load?")
        } catch {
            # Handle interruption - use current config
            ($config.extensions.enabled | each { |ext_name|
                let ext_info = ($available_extensions | where name == $ext_name | first)
                $"($ext_info.name) - ($ext_info.description)"
            })
        }
        
        # Extract extension names from selected display strings
        validate-extensions ($selected_extensions | each { |selected|
            ($selected | split row " - " | first)
        }) $available_extensions
    } else {
        print $"(ansi yellow)No extensions found in src/lib/ext/ directory(ansi reset)"
        []
    }

    # Get RootsMagic database location for production mode with validation
    let sync_source = if $db_mode == "production" {
        print $"\n(ansi yellow_bold)RootsMagic Database Location:(ansi reset)"
        print "GenQuery needs to know where your RootsMagic database file is located."
        let current_source = if ("sync" in ($config | columns)) and ("sources" in ($config.sync | columns)) {
            ($config.sync.sources.production? | default "Not configured")
        } else {
            "Not configured"
        }
        print $"Current location: (ansi cyan)($current_source)(ansi reset)"
        print ""
        print "This is typically something like:"
        
        # Show OS-appropriate path examples
        match $nu.os-info.name {
            "windows" => {
                print "  • C:\\Users\\YourName\\Documents\\RootsMagic\\YourFamilyName.rmtree"
                print "  • C:\\Users\\YourName\\Genealogy\\RootsMagic\\Database\\YourName.rmtree"
                print "  • D:\\Genealogy\\RootsMagic\\YourFamilyName.rmtree"
            }
            "macos" => {
                print "  • ~/Documents/RootsMagic/YourFamilyName.rmtree"
                print "  • ~/Genealogy/RootsMagic/Database/YourName.rmtree"
                print "  • /Users/YourName/Desktop/Genealogy/YourFamilyName.rmtree"
            }
            _ => {
                # Linux and other Unix-like systems
                print "  • ~/Documents/RootsMagic/YourFamilyName.rmtree"
                print "  • ~/Genealogy/RootsMagic/Database/YourName.rmtree"
                print "  • /home/yourname/genealogy/YourFamilyName.rmtree"
            }
        }
        print ""
        
        # Get validated RootsMagic database path with retry logic
        let validated_path = (1..3 | reduce --fold null { |attempt, acc|
            if $acc != null {
                $acc  # Already have a valid path
            } else {
                # Create OS-appropriate default suggestion
                let default_suggestion = match $nu.os-info.name {
                    "windows" => "C:\\Users\\YourName\\Documents\\RootsMagic\\YourFamilyName.rmtree"
                    "macos" => "~/Documents/RootsMagic/YourFamilyName.rmtree"
                    _ => "~/Documents/RootsMagic/YourFamilyName.rmtree"
                }
                
                let sync_source_input = try {
                    (input $"Where is your RootsMagic database file? [($default_suggestion)]: ")
                } catch {
                    print $"\n(ansi yellow)Input cancelled, using current configuration(ansi reset)"
                    return $config.sync.sources.production
                }
                
                let path_to_validate = if ($sync_source_input | str trim | is-empty) { 
                    $default_suggestion
                } else { 
                    $sync_source_input | str trim 
                }
                
                # Validate the path
                try {
                    let result = (validate-rmtree-file $path_to_validate)
                    print $"(ansi green)✓ Valid RootsMagic database file found(ansi reset)"
                    $result
                } catch { |error|
                    print $"(ansi red)✗ ($error.msg)(ansi reset)"
                    
                    if $attempt < 3 {
                        print $"(ansi yellow)Please try again. Attempts remaining: (3 - $attempt)(ansi reset)"
                        print ""
                        null
                    } else {
                        print $"(ansi yellow)Maximum attempts reached. Using current configuration: ($config.sync.sources.production)(ansi reset)"
                        $config.sync.sources.production
                    }
                }
            }
        })
        
        $validated_path
    } else {
        null
    }
    
    # Check if any changes were made
    let db_changed = ($db_mode != $config.database.active)
    let ext_changed = ($extensions != $config.extensions.enabled)
    let sync_changed = if $db_mode == "production" { 
        ($sync_source != $config.sync.sources.production) 
    } else { 
        false 
    }
    let any_changes = ($db_changed or $ext_changed or $sync_changed)
    
    # Show new configuration summary
    print $"\n(ansi green_bold)New Configuration Summary:(ansi reset)"
    print $"Database mode: (ansi cyan)($db_mode)(ansi reset)"
    print $"Extensions: (ansi cyan)($extensions | str join ', ')(ansi reset)"
    if $db_mode == "production" {
        print $"RootsMagic database: (ansi cyan)($sync_source)(ansi reset)"
        print ""
        print $"(ansi blue_bold)Database Safety:(ansi reset)"
        print "GenQuery always uses a copy of your production database as a safety precaution."
        print "Your original RootsMagic database is never modified or accessed directly."
        print $"You can run (ansi cyan_bold)syncdb(ansi reset) at any time to refresh GenQuery's data."
    }
    print ""
    
    # Single confirmation prompt with change detection
    let confirm_prompt = if $any_changes {
        "Apply these settings? (Y/n): "
    } else {
        "No changes detected. Keep current settings? (Y/n): "
    }
    
    let confirm = try {
        (input $confirm_prompt | default "y")
    } catch {
        print $"\n(ansi yellow)Input cancelled, keeping current settings(ansi reset)"
        "n"
    }
    
    if $confirm == "y" or $confirm == "Y" or $confirm == "" {
        if $any_changes {
            # Validate config file is writable before attempting save
            try {
                check-writable-path $config_path
            } catch { |error|
                print $"(ansi red)Error: Cannot write to configuration file(ansi reset)"
                print $"Error details: ($error.msg)"
                print "Please check file permissions and try again."
                return
            }
            
            # Actually save the configuration
            try {
                let saved_config = (save-config $config_path $db_mode $extensions $sync_source)
                reload-genq-environment $saved_config
                print $"(ansi green)✓ Configuration saved successfully!(ansi reset)"
                
                # Set up syncdb alias for production mode
                if $db_mode == "production" {
                    let target_path = ($config.sync.targets.production | default "./data/Iiams.rmtree")
                    let alias_cmd = $"alias syncdb = cp ($sync_source) ($target_path)"
                    try {
                        update-env-alias $alias_cmd $sync_source
                    } catch { |error|
                        print $"(ansi yellow)Warning: Could not set up syncdb alias automatically(ansi reset)"
                        if ($error.msg | str contains "not found") {
                            print "Reason: Could not locate your Nushell env.nu file"
                            print "This is normal for some Nushell installations."
                        } else if ($error.msg | str contains "Permission denied") {
                            print "Reason: Insufficient permissions to modify env.nu file"
                        } else {
                            print $"Reason: ($error.msg)"
                        }
                        let env_path = ($nu.config-path | path dirname | path join "env.nu")
                        print $"You can add this manually to your ($env_path) file:"
                        print $"    ($alias_cmd)"
                    }
                }
            } catch { |error|
                if ($error.msg | str contains "Failed to save configuration") {
                    print $"(ansi red)Error: Could not save configuration file(ansi reset)"
                    if ($error.msg | str contains "Permission denied") {
                        print "Reason: Insufficient permissions to write configuration file"
                        print "Try running with appropriate permissions or check file ownership."
                    } else if ($error.msg | str contains "No such file") {
                        print "Reason: Configuration directory may not exist"
                        print "Please ensure the config directory structure is set up correctly."
                    } else {
                        print $"Reason: ($error.msg)"
                    }
                } else if ($error.msg | str contains "Failed to load configuration") {
                    print $"(ansi red)Error: Could not read current configuration(ansi reset)"
                    print "The configuration file may be corrupted or have invalid format."
                    print $"Reason: ($error.msg)"
                } else {
                    print $"(ansi red)Error: Configuration save failed(ansi reset)"
                    print $"Reason: ($error.msg)"
                }
                print "Your settings were not saved. Please address the issue and try again."
            }
        } else {
            print $"(ansi green)✓ Keeping current settings.(ansi reset)"
        }
    } else {
        print $"(ansi yellow)Configuration cancelled.(ansi reset)"
    }
}