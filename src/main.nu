# Source this script to add the commands

use std *

# Load common and custom modules
use common *
use ext/miams *
use ext/pres2020 *

# Initialize GenQuery configuration system
# Set GenQuery home directory from environment or use current directory as fallback
if not ($env.GENQ_HOME? | default null | is-not-empty) {
    $env.GENQ_HOME = $env.PWD
}

# Load configuration and set environment variables
let config_path = ($env.GENQ_HOME | path join "config" "default.toml")
let config = (if ($config_path | path exists) { 
    open $config_path
} else { 
    {
        database: { active: "demo", connections: { demo: ($env.GENQ_HOME | path join "data" "pres2020.rmtree") } }
        paths: { sql_dir: ($env.GENQ_HOME | path join "sql"), lib_dir: ($env.GENQ_HOME | path join "src" "lib"), ext_dir: ($env.GENQ_HOME | path join "src" "lib" "ext"), output_dir: ($env.GENQ_HOME | path join "vault") }
        display: { date_format: 1, table_mode: "rounded" }
        extensions: { enabled: ["miams", "pres2020"] }
    }
})

# Set up environment variables from config
$env.GENQ_CONFIG = $config

# Convert relative database path to absolute path based on GENQ_HOME
let db_path = ($config.database.connections | get $config.database.active)
$env.rmdb = if ($db_path | str starts-with "./") {
    ($env.GENQ_HOME | path join ($db_path | str substring 2..))
} else {
    $db_path | path expand
}

$env.genq_sql = $config.paths.sql_dir  
$env.RDMF = $config.display.date_format

let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]
$env.SurnameGroup = [Iams, Iames, Iiams, Iiames, Ijams, Ijames, Imes, Eimes]

def genq_action_completer [] { ["review-updates", "list", "tabulate", "assess", "config", "help" ] }
def list_action_completer [] { ["findagrave", "people", "citations", "events", "families", "newspaper", "obits"]}
def census_action_completer [] { ["year", "RIN", "quality", "help" ] }
def config_action_completer [] { ["list"] }
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
        if $subcommand == "list" {
            genq config list  
        } else {
            genq config
        }
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


