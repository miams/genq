# Source this script to add the commands

use std *

# Load common and custom modules
use common *
use ext/miams *
use ext/pres2020 *

# Initialize GenQuery configuration system (temporary inline approach)
# Load configuration and set environment variables
let config = (if ("./config/default.toml" | path exists) { 
    open "./config/default.toml"
} else { 
    {
        database: { active: "demo", connections: { demo: "./data/pres2020.rmtree" } }
        paths: { genq_home: ".", sql_dir: "./sql", lib_dir: "./src/lib", ext_dir: "./src/lib/ext", output_dir: "./vault" }
        display: { date_format: 1, table_mode: "rounded" }
        extensions: { enabled: ["miams", "pres2020"] }
    }
})

# Set up environment variables from config
$env.GENQ_CONFIG = $config
$env.rmdb = ($config.database.connections | get $config.database.active)
$env.genq_sql = $config.paths.sql_dir  
$env.RDMF = $config.display.date_format

let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]
$env.SurnameGroup = [Iams, Iames, Iiams, Iiames, Ijams, Ijames, Imes, Eimes]

def genq_action_completer [] { ["review-updates", "list", "tabulate", "assess", "config", "help" ] }
def list_action_completer [] { ["findagrave", "people", "citations", "events", "families", "newspaper", "obits"]}
def census_action_completer [] { ["year", "RIN", "quality", "help" ] }
def config_action_completer [] { ["help", "list", "get", "set"] }
# GenQuery generates tabular reports from the RootsMagic database.
@category "genq-common"
export def genq [
    action?: string@genq_action_completer,  # action command [updates, list, quality, help]
    ...objects: string  # additional directives, options vary based on action command
    ] {

if ($action | is-empty) {
        let $action = "help"
    } 
    
 match $action {
    "review-updates" => {
        if ($objects | is-empty) {
            print $'(ansi red_bold)List of recently updated records.(ansi reset)'
            print 'citations, events, findagrave, obits, people, sources'
            print $"(ansi yellow_bold)NO FUNCTIONALITY YET(ansi reset)\n"
        } else {
        }
    },
    "list" => {
        let mylist = "findagrave people citations families events newspaper obits"
        list ($mylist)
        },
    'assess' => {
        print $'(ansi red_bold)Perform variety of data quality checks for consistency and completeness.(ansi reset)'
        print 'genq assess consistency findagrave'
        print 'genq assess consistency sources'
        print 'genq assess citation-breadth'
        print 'genq assess citation-coverage'
        print $"(ansi yellow_bold)NOT FUNCTIONAL YET - EVALUATION PHASE(ansi reset)\n"
    },
    'tabulate' => {
        print $'(ansi red_bold)Generate tabulated reports summarizing data. (ansi reset)'
        print 'genq assess consistency findagrave'
        print 'genq assess consistency sources'
        print 'genq assess citation-breadth'
        print 'genq assess citation-coverage'
        print $"(ansi yellow_bold)NOT FUNCTIONAL YET - EVALUATION PHASE(ansi reset)\n"
    },
    'config' => {
        let subcommand = if ($objects | length) > 0 { $objects.0 } else { "" }
        genq-config $subcommand ...$objects
    },
    'help' => {
       print $"(ansi green_bold)GenQuery - Genealogy Database Reporting(ansi reset)\n"
       let printstr = "GenQuery is an open-source, third-party RootsMagic reporting engine for use in the terminal. GenQuery is designed to let you quickly and easily pull data from your RootsMagic database. GenQuery is built on top of Nushell, a new kind of shell for OS X, Linux, and Windows. Unlike traditional shells such as bash, zsh or Powershell, Nushell uses structured data allowing for powerful but simple pipelines. It enables users to easily analyze and process data using easier more readable commands.\n"
       wrap-text $printstr (term size).columns
       print ""
       print $"(ansi cyan_bold)Quick Start:(ansi reset)"
       print "• Run 'genq config' to set up your database and preferences"
       print "• Try 'genq list people | first 10' to see some family records"
       print "• Use 'genq help' to see all available commands"
       print ""
       let printstr = "At its core, GenQuery uses SQL (Structured Queried Language) to query RootsMagics SQLite database. In most cases, GenQuery removes the need to deal with SQL complexity.  GenQuery leverages its library of internal and third-party SQL queries to extract data. From there, you are able to access a rich set of Nushell commands to personalize your data analysis and reports to your individual needs." 
       wrap-text $printstr (term size).columns},
    _ => {
        print "OVERVIEW" 
        let printstr = "GenQuery is an open-source, third-party RootsMagic reporting engine for use in the terminal. GenQuery is designed to let you quickly and easily pull data from your RootsMagic database. GenQuery is built on top of Nushell, a new kind of shell for OS X, Linux, and Windows. Unlike traditional shells such as bash, zsh or Powershell, Nushell uses structured data allowing for powerful but simple pipelines. It enables users to easily analyze and process data using easier more readable commands.\n"
        wrap-text $printstr (term size).columns
        let printstr = "At its core, GenQuery uses SQL (Structured Queried Language) to query RootsMagics SQLite database. In most cases, GenQuery removes the need to deal with SQL complexity.  GenQuery leverages its library of internal and third-party SQL queries to extract data. From there, you are able to access a rich set of Nushell commands to personalize your data analysis and reports to your individual needs." 
        wrap-text $printstr (term size).columns}
    }
}  

# List a variety of RootsMagic records.
@category "genq-common"
def "genq list" [] {
    print "List a variety of RootsMagic record types."
}

# Generate tabulated reports summarizing data. 
@category "genq-common"
def "genq tabulate" [] {
    print "Generate tabulated reports summarizing data. "
}

# List sources for Federal census records. [wide]
@category "genq-miams"
def "genq list census" [] {
    print "List of sources for Federal census records (1790-1950)."
    # | insert Footnote {|row| $row.Fields | from xml | get content.0.content.0.content.1.content.content} | flatten 
    # | insert ShortFootnote {|row| $row.Fields | from xml | get content.0.content.1.content.1.content.content} | flatten 
    # | insert Bibliography {|row| $row.Fields | from xml | get content.0.content.2.content.1.content.content} | flatten 
    # | reject Fields | startat1
}

# Colorize RTF strings found in RM note files.
@category "genq-platform"    
def colorize [] {
    $in  
    | str replace --all --regex '<b>(.*?)</b>' $"(ansi light_green_bold)$1(ansi reset)"          # Bold
    | str replace --all --regex '<i>(.*?)</i>' $"(ansi light_yellow_italic)$1(ansi reset)"       # Italic
    | str replace --regex '<u>(.*?)</u>' $"(ansi blue_underline)$1(ansi reset)"                  # Underline
}

# Start index at 1 instead of default 0.
@category "genq-platform"  
def startat1 [] {
   enumerate | flatten | each { |row| $row | upsert index ($row.index + 1) }
}

# Word wrap, improving readability of docs.
@category "genq-platform"  
def wrap-text [text: string, width: int] {
    let words = $text | split row ' '
    mut line = ''
    mut result = []


    for word in $words {
        if ($line | str length) + ($word | str length) + 2 <= $width {
            # Append word to current line
            $line = if ($line | is-empty) { $word } else { $"($line) ($word)" }
        } else {
            # Save the current line and start a new one
            $result = ($result | append $line)
            $line = $word
        }
    }

    # Append the last line if it's not empty
    if not ($line | is-empty) {
        $result = ($result | append $line)
    }

    # Print wrapped text
    $result | each { |row| print $row } 
    return
}

# Limit text in column with ellipsis 
@category "genq-platform"  
  export def limit [
    text: string          # string to shorten
    maxlen: int           # max length of string 
    ] {
    if ($text | str length) > $maxlen {
        $text | str substring 0..$maxlen | [$in, "..."] | str join
    } else {
        $text
    }
}

# GenQuery configuration management
@category "genq-common"
def genq-config [
    subcommand?: string@config_action_completer   # Subcommand: help, list, get, set, or empty for interactive mode
    ...args: string       # Arguments for subcommands
] {
    let config_path = "./config/default.toml"
    
    match $subcommand {
        "help" => {
            print $"(ansi green_bold)GenQuery Configuration Help(ansi reset)\n"
            print "GenQuery configuration lets you manage your database settings, sync options,"
            print "and extensions. Think of it like setting up your preferences.\n"
            
            print $"(ansi cyan_bold)Available Commands:(ansi reset)"
            print $"  (ansi green)genq config(ansi reset)              - Interactive setup wizard (recommended for beginners)"
            print $"  (ansi green)genq config list(ansi reset)         - Show your current settings"
            print $"  (ansi green)genq config get <setting>(ansi reset) - Get a specific setting value"
            print $"  (ansi green)genq config help(ansi reset)         - Show this help message\n"
            
            print $"(ansi cyan_bold)Common Settings:(ansi reset)"
            print $"  (ansi yellow)database.active(ansi reset)           - Which database to use (demo or production)"
            print $"  (ansi yellow)extensions.enabled(ansi reset)        - Which features to load"
            print $"  (ansi yellow)sync.sources.production(ansi reset)   - Where your RootsMagic database is stored\n"
            
            print $"(ansi cyan_bold)Examples:(ansi reset)"
            print $"  (ansi dim)genq config(ansi reset)                          - Set up GenQuery interactively"
            print $"  (ansi dim)genq config list(ansi reset)                     - See what database you're using"
            print $"  (ansi dim)genq config get database.active(ansi reset)      - Check if using demo or production data\n"
            
            print $"(ansi blue)💡 Tip: Start with 'genq config' if you're new to GenQuery!(ansi reset)"
        }
        "get" => {
            if ($args | length) == 0 {
                print $"(ansi red)Missing setting name!(ansi reset)"
                print "You need to tell GenQuery which setting you want to see.\n"
                print $"(ansi green)Usage:(ansi reset) genq config get <setting-name>"
                print $"(ansi green)Example:(ansi reset) genq config get database.active\n"
                print "Run 'genq config help' to see available settings."
                return
            }
            let key = $args.0
            try {
                let config = open $config_path
                let value = ($config | get $key)
                print $"(ansi cyan)($key):(ansi reset) ($value)"
            } catch {
                print $"(ansi red)Setting '($key)' not found!(ansi reset)"
                print "Run 'genq config list' to see available settings."
                print "Or run 'genq config help' for examples."
            }
        }
        "set" => {
            if ($args | length) < 2 {
                print $"(ansi red)Missing setting name or value!(ansi reset)"
                print "You need to specify both what setting to change and its new value.\n"
                print $"(ansi green)Usage:(ansi reset) genq config set <setting-name> <new-value>"
                print $"(ansi green)Example:(ansi reset) genq config set database.active production\n"
                print "Run 'genq config help' to see available settings."
                print $"(ansi blue)💡 Tip: Use 'genq config' for the interactive wizard instead!(ansi reset)"
                return
            }
            let key = $args.0
            let value = $args.1
            print $"(ansi yellow)Setting ($key) = ($value)(ansi reset)"
            print $"(ansi yellow)Note: Direct setting changes not yet implemented(ansi reset)"
            print "Use 'genq config' for the interactive setup wizard instead."
        }
        "list" => {
            print $"(ansi green_bold)Your GenQuery Settings:(ansi reset)\n"
            try {
                let config = open $config_path
                print $"(ansi cyan)Database you're using:(ansi reset) ($config.database.active)"
                let db_path = ($config.database.connections | get $config.database.active)
                print $"(ansi cyan)Database file:(ansi reset) ($db_path)"
                print $"(ansi cyan)Extensions (features) loaded:(ansi reset) ($config.extensions.enabled | str join ', ')"
                print $"(ansi cyan)Reports saved to:(ansi reset) ($config.paths.output_dir)"
                
                if ($config.sync? | default false) {
                    print ""
                    print $"(ansi cyan_bold)Database Sync Settings:(ansi reset)"
                    if ($config.database.active == "production") {
                        print $"(ansi cyan)Your RootsMagic database:(ansi reset) ($config.sync.sources.production)"
                        print $"(ansi cyan)GenQuery working copy:(ansi reset) ($config.sync.targets.production)"
                    } else {
                        print $"(ansi dim)Sync settings available when using production database(ansi reset)"
                    }
                }
                
                print ""
                print $"(ansi blue)💡 Run 'genq config' to change these settings(ansi reset)"
                print $"(ansi blue)💡 Run 'genq config help' for more options(ansi reset)"
            } catch {
                print $"(ansi red)Could not read configuration file!(ansi reset)"
                print "Run 'genq config' to set up GenQuery."
            }
        }
        _ => {
            # Interactive configuration wizard
            print $"(ansi green_bold)GenQuery Setup Wizard(ansi reset)"
            print "This will help you configure GenQuery for your genealogy research."
            print "You can press Enter to keep current settings or type 'help' for more info.\n"
            
            try {
                let config = open $config_path
                
                # Database mode selection with explanation
                print $"(ansi yellow_bold)Step 1: Choose Your Database(ansi reset)"
                print "GenQuery can work with demo data (U.S. Presidents) or your personal genealogy data."
                print $"Current database: (ansi cyan)($config.database.active)(ansi reset)"
                print ""
                print "Options:"
                print "  • demo - Practice with U.S. Presidents data (safe for learning)"
                print "  • production - Use your actual RootsMagic genealogy database"
                print ""
                
                let db_mode = loop {
                    let input_val = (input "Which database would you like to use? (demo/production) [demo]: " | str trim)
                    if $input_val == "" or $input_val == "demo" {
                        break "demo"
                    } else if $input_val == "production" {
                        break "production"
                    } else if $input_val == "help" {
                        print ""
                        print "• Choose 'demo' to practice with sample data first"
                        print "• Choose 'production' when ready to work with your real genealogy data"
                        print ""
                        continue
                    } else {
                        print $"(ansi red)Please enter 'demo' or 'production'(ansi reset)"
                        continue
                    }
                }
                
                # Extensions selection with explanation
                print $"\n(ansi yellow_bold)Step 2: Choose Features to Load(ansi reset)"
                print "Extensions add extra commands for specific types of genealogy research."
                print $"Currently loaded: (ansi cyan)($config.extensions.enabled | str join ', ')(ansi reset)"
                print ""
                print "Available extensions:"
                print "  • miams - Personal genealogy tools (obituaries, FindAGrave, census records)"
                print "  • pres2020 - Tools for the Presidents demo database"
                print ""
                
                let extensions_input = (input "Which extensions to load? [miams,pres2020]: " | default "miams,pres2020")
                let extensions = ($extensions_input | split row "," | each { |ext| $ext | str trim })
            
                # Sync configuration for production mode
                if $db_mode == "production" {
                    print $"\n(ansi yellow_bold)Step 3: Set Up Database Sync(ansi reset)"
                    print "GenQuery needs to know where your RootsMagic database file is located"
                    print "so it can copy it to a safe working location for analysis."
                    print $"Current location: (ansi cyan)($config.sync.sources.production)(ansi reset)"
                    print ""
                    print "This is typically something like:"
                    print "  • ~/Genealogy/RootsMagic/Database/YourName.rmtree"
                    print "  • ~/Documents/RootsMagic/YourFamilyName.rmtree"
                    print ""
                    
                    let sync_source = (input "Where is your RootsMagic database file? [~/Genealogy/RootsMagic/Database/Iiams.rmtree]: " | default "~/Genealogy/RootsMagic/Database/Iiams.rmtree")
                    
                    print $"\n(ansi green_bold)Configuration Summary:(ansi reset)"
                    print $"Database mode: (ansi cyan)($db_mode)(ansi reset) - Using your personal genealogy data"
                    print $"Extensions: (ansi cyan)($extensions | str join ', ')(ansi reset) - Features you'll have available"
                    print $"RootsMagic database: (ansi cyan)($sync_source)(ansi reset) - Where your data comes from"
                    print ""
                    
                    let confirm = (input "Does this look correct? (Y/n): " | default "y")
                    if $confirm == "y" or $confirm == "Y" or $confirm == "" {
                        print $"(ansi green)✓ Applying your configuration...(ansi reset)"
                        print $"(ansi yellow)Note: Configuration file updating will be added in a future update(ansi reset)"
                        
                        # Generate syncdb alias
                        let alias_cmd = $"alias syncdb = cp ($sync_source) ./data/Iiams.rmtree"
                        
                        # Explain what we're doing in simple terms
                        print $"\n(ansi blue_bold)Setting up database sync:(ansi reset)"
                        print "GenQuery needs a way to copy your latest genealogy data from RootsMagic"
                        print "to GenQuery's working folder. This creates a 'syncdb' command that will"
                        print "safely copy your database whenever you want to update GenQuery with"
                        print "your latest research."
                        
                        let env_confirm = (input "\nWould you like GenQuery to set this up automatically? (Y/n): " | default "y")
                        if $env_confirm == "y" or $env_confirm == "Y" or $env_confirm == "" {
                            update-env-alias $alias_cmd $sync_source
                        } else {
                            print $"\n(ansi blue)Manual setup required:(ansi reset)"
                            print $"Add this line to your shell configuration:"
                            print $alias_cmd
                        }
                    } else {
                        print $"(ansi yellow)Setup cancelled - run 'genq config' again to try different settings(ansi reset)"
                    }
                } else {
                    print $"\n(ansi green_bold)Configuration Summary:(ansi reset)"
                    print $"Database mode: (ansi cyan)($db_mode)(ansi reset) - Using demo data (U.S. Presidents)"
                    print $"Extensions: (ansi cyan)($extensions | str join ', ')(ansi reset) - Features you'll have available"
                    print ""
                    print "With demo mode, you can practice GenQuery commands safely!"
                    print "When ready for your real data, run 'genq config' again and choose production."
                    print ""
                    
                    let confirm = (input "Apply these settings? (Y/n): " | default "y")
                    if $confirm == "y" or $confirm == "Y" or $confirm == "" {
                        print $"(ansi green)✓ Demo configuration applied!(ansi reset)"
                        print $"(ansi yellow)Note: Configuration file updating will be added in a future update(ansi reset)"
                        print ""
                        print $"(ansi blue)💡 Try these commands to get started:(ansi reset)"
                        print "  • genq list people | first 10"
                        print "  • genq list sources"  
                    } else {
                        print $"(ansi yellow)Setup cancelled - run 'genq config' again to try different settings(ansi reset)"
                    }
                }
            } catch {
                print $"(ansi red)Error reading configuration file!(ansi reset)"
                print "GenQuery may not be properly installed. Please check the installation."
                print "Run 'genq config help' for troubleshooting options."
            }
        }
    }
}

# Update env.nu with syncdb alias
@category "genq-common"
def update-env-alias [
    alias_cmd: string     # The alias command to add
    sync_source: string   # Source path for verification
] {
    let env_path = ($env.HOME | path join ".config" "nushell" "env.nu")
    
    # Check if env.nu exists
    if not ($env_path | path exists) {
        print $"(ansi red)Error: Could not find env.nu at ($env_path)(ansi reset)"
        print "Please create the file first or add the alias manually."
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
        
        # Create backup
        let backup_path = $env_path + ".genq_backup"
        $current_content | save $backup_path
        
        # Write updated content
        $new_content | save $env_path
        
        if $has_syncdb {
            print $"(ansi green)✓ Updated existing syncdb command in env.nu(ansi reset)"
        } else {
            print $"(ansi green)✓ Added syncdb command to env.nu(ansi reset)"
        }
        
        # Verify the setup by reloading and testing
        verify-syncdb-setup $sync_source
        
    } catch {
        print $"(ansi red)Error: Failed to update env.nu(ansi reset)"
        print "Please add this line manually to your env.nu file:"
        print $alias_cmd
    }
}

# Verify syncdb alias is working correctly
@category "genq-common"
def verify-syncdb-setup [
    expected_source: string   # Expected source path
] {
    try {
        # Source the updated env.nu to reload aliases
        source ($env.HOME | path join ".config" "nushell" "env.nu")
        
        # Get the current syncdb alias definition
        let aliases = (scope aliases)
        let syncdb_alias = ($aliases | where name == "syncdb")
        
        if ($syncdb_alias | is-empty) {
            print $"(ansi yellow)Warning: syncdb command may not be available until you restart your shell(ansi reset)"
            print "You can run 'source ~/.config/nushell/env.nu' to reload it now."
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
