# Source this script to add the commands

use std *

# Load common and custom modules
use common *
use ext/miams *
use ext/pres2025 *

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
        database: { active: "demo", connections: { demo: ($env.GENQ_HOME | path join "data" "pres2025.rmtree") } }
        paths: { sql_dir: ($env.GENQ_HOME | path join "sql"), lib_dir: ($env.GENQ_HOME | path join "src" "lib"), ext_dir: ($env.GENQ_HOME | path join "src" "lib" "ext"), output_dir: ($env.GENQ_HOME | path join "vault") }
        display: { date_format: 1, table_mode: "rounded" }
        extensions: { enabled: ["miams", "pres2025"] }
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

$env.genq_sql = ($env.GENQ_HOME | path join $config.paths.sql_dir)
$env.RDMF = $config.display.date_format

# Telemetry: initialize session (fire-and-forget, no-op if disabled)
# All telemetry errors are silently caught — telemetry must never break genq.
try {
    telemetry-init
} catch { }

def telemetry-init [] {
    # Check if telemetry section exists; if not, skip (first-run prompt is interactive only)
    let enabled = ($env.GENQ_CONFIG?.telemetry?.enabled? | default false)
    if not $enabled { return }

    # Session start: collect resource attributes, generate trace_id, write initial span
    let ver = (version)
    let host = (sys host)
    let trace_id = (random uuid | str replace -a '-' '')
    let span_id = (random uuid | str replace -a '-' '' | str substring 0..16)
    let start = (date now)
    let start_nano = ($start | into int | into string)

    # Resource attributes (static for session lifetime)
    let resource = { attributes: [
        { key: "service.name",            value: { stringValue: "genq" } }
        { key: "service.version",         value: { stringValue: ($env.GENQ_CONFIG?.metadata?.version? | default "unknown") } }
        { key: "telemetry.sdk.language",   value: { stringValue: "nushell" } }
        { key: "host.os.type",            value: { stringValue: $ver.build_os } }
        { key: "host.arch",               value: { stringValue: $ver.build_target } }
        { key: "host.os.version",         value: { stringValue: ($host.os_version? | default "") } }
        { key: "host.os.kernel_version",  value: { stringValue: ($host.kernel_version? | default "") } }
        { key: "process.runtime.version", value: { stringValue: $ver.version } }
        { key: "genq.terminal",           value: { stringValue: ($env.TERM_PROGRAM? | default "unknown") } }
        { key: "genq.locale",             value: { stringValue: ($env.LANG? | default "unknown") } }
    ] }

    # Gather DB metadata (read-only PRAGMAs)
    let db_meta = (try {
        if ($env.rmdb? | default "" | path exists) {
            let person_count = (open $env.rmdb | query db "SELECT COUNT(*) as c FROM PersonTable" | get 0.c)
            let page_info = (open $env.rmdb | query db "PRAGMA page_count" | get 0.page_count)
            let page_size = (open $env.rmdb | query db "PRAGMA page_size" | get 0.page_size)
            let size_kb = (($page_info * $page_size) / 1024 | into int)
            { person_count: $person_count, size_kb: $size_kb, filename: ($env.rmdb | path basename), db_name: ($env.GENQ_CONFIG?.database?.active? | default "unknown") }
        } else {
            { person_count: 0, size_kb: 0, filename: "", db_name: "none" }
        }
    } catch {
        { person_count: 0, size_kb: 0, filename: "", db_name: "error" }
    })

    let cold_start_ms = ((date now) - $start) / 1ms | into int

    let span = {
        traceId: $trace_id
        spanId: $span_id
        parentSpanId: null
        name: "genq.session"
        kind: 1
        startTimeUnixNano: $start_nano
        endTimeUnixNano: $start_nano
        attributes: [
            { key: "genq.session.cold_start_ms",  value: { intValue: ($cold_start_ms | into string) } }
            { key: "genq.db.name",                value: { stringValue: $db_meta.db_name } }
            { key: "genq.db.filename",            value: { stringValue: $db_meta.filename } }
            { key: "genq.db.person_count",        value: { intValue: ($db_meta.person_count | into string) } }
            { key: "genq.db.size_kb",             value: { intValue: ($db_meta.size_kb | into string) } }
            { key: "genq.config.table_mode",      value: { stringValue: ($env.GENQ_CONFIG?.display?.table_mode? | default "rounded") } }
            { key: "genq.config.date_format",     value: { intValue: ($env.GENQ_CONFIG?.display?.date_format? | default 1 | into string) } }
            { key: "genq.session.commands_run",   value: { intValue: "0" } }
            { key: "genq.session.error_count",    value: { intValue: "0" } }
        ]
        status: { code: 1 }
        _resource: $resource
    }

    # Store session in env for command-level instrumentation
    $env.GENQ_TELEMETRY_SESSION = {
        trace_id: $trace_id
        span_id: $span_id
        start_time: $start
        resource: $resource
    }

    # Write initial session span to local NDJSON buffer
    let data_home = ($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share"))
    let dir = ($data_home | path join "genq" "telemetry")
    if not ($dir | path exists) { mkdir $dir }
    let today = (date now | format date "%Y-%m-%d")
    let file = ($dir | path join $"($today).ndjson")
    $span | to json --raw | $in + "\n" | save --append --raw $file

    # Rotate old buffer files
    let retention = ($env.GENQ_CONFIG?.telemetry?.retention_days? | default 30)
    let cutoff = (date now) - ($retention | into duration --unit day)
    let files = (glob ($dir | path join "*.ndjson"))
    $files | each {|f|
        let basename = ($f | path basename | str replace ".ndjson" "")
        try {
            let file_date = ($basename | into datetime)
            if $file_date < $cutoff { rm $f }
        } catch { }
    }
}

let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]
$env.SurnameGroup = [Iams, Iames, Iiams, Iiames, Ijams, Ijames, Imes, Eimes]

def genq-actions [] { ["list", "tabulate", "config", "version", "help"] }

# Report the current GenQuery version.
@category "genq-common"
export def "genq version" [] {
    # 1. Config metadata.version (set by genquery-start from bundle VERSION file)
    let config_version = ($env.GENQ_CONFIG? | get --optional metadata.version | default "")
    if ($config_version | is-not-empty) {
        print $config_version
        return
    }

    # 2. VERSION file in GENQ_HOME (written by CI into app bundle)
    let version_file = ($env.GENQ_HOME | path join "VERSION")
    if ($version_file | path exists) {
        let file_version = (open $version_file | str trim)
        if ($file_version | is-not-empty) {
            print $file_version
            return
        }
    }

    # 3. Git describe (dev environments only — no git on end-user machines)
    let git_version = (try {
        ^git -C $env.GENQ_HOME describe --tags --always 2>/dev/null | str trim
    } catch { "" })
    if ($git_version | is-not-empty) {
        print $git_version
        return
    }

    print "unknown"
}

# GenQuery generates tabular reports from the RootsMagic database.
@category "genq-common"
export def genq [
    action?: string@genq-actions,  # action command
    ...objects: string  # additional directives, options vary based on action command
    ] {

let $action = if ($action | is-empty) {
        "help"
    } else {
        $action | str downcase
    } 
    
    match $action {
    "version" => {
        genq version
    },
    "review-updates" => {
        print $"(ansi red)Error:(ansi reset) The 'review-updates' command has been removed from GenQuery"
        print "This command was never fully implemented and has been cleaned up."
        print "Available commands: list, tabulate, config, help"
        print "Use 'genq help' to see all available functionality."
    },
    "list" => {
        # List subcommands are handled by the module system
        # Tab completion shows available subcommands automatically
        print "List command - use 'genq list <type>' where type is: people, citations, events, families, etc."
        print "Available list types:"
        print "  people, citations, events, families, findagrave, newspaper, obits"
        print "Example: genq list people | first 10"
        },
    "assess" => {
        print $"(ansi red)Error:(ansi reset) The 'assess' command has been removed from GenQuery"
        print "This command was never fully implemented and has been cleaned up."
        print "Available commands: list, tabulate, config, help"
        print "Use 'genq help' to see all available functionality."
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
       wrap-text $printstr (term size).columns
    },
    _ => {
        print "OVERVIEW" 
        let printstr = "GenQuery is an open-source, third-party RootsMagic reporting engine for use in the terminal. GenQuery is designed to let you quickly and easily pull data from your RootsMagic database. GenQuery is built on top of Nushell, a new kind of shell for OS X, Linux, and Windows. Unlike traditional shells such as bash, zsh or Powershell, Nushell uses structured data allowing for powerful but simple pipelines. It enables users to easily analyze and process data using easier more readable commands.\n"
        wrap-text $printstr (term size).columns
        let printstr = "At its core, GenQuery uses SQL (Structured Queried Language) to query RootsMagics SQLite database. In most cases, GenQuery removes the need to deal with SQL complexity.  GenQuery leverages its library of internal and third-party SQL queries to extract data. From there, you are able to access a rich set of Nushell commands to personalize your data analysis and reports to your individual needs." 
        wrap-text $printstr (term size).columns
    }
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
def "genq list census" [
    --short-footnote (-s)  # Show short footnote instead of footnote
    --bibliography (-b)    # Show bibliography instead of footnote
] {
    if $short_footnote and $bibliography {
        print $"(ansi red)Error:(ansi reset) Use only one of --short-footnote or --bibliography."
        return
    }

    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of sources for Federal census records (1790-1950)."

    let field_name = if $bibliography {
        "Bibliography"
    } else if $short_footnote {
        "ShortFootnote"
    } else {
        "Footnote"
    }

    def source-field [fields: string, field_name: string] {
        if ($fields | is-empty) {
            return ""
        }

        try {
            let source_fields = ($fields | from xml | get content.0.content)
            let matching_field = (
                $source_fields
                | where {|field| (($field | get --optional content.0.content.0.content | default "") == $field_name) }
                | first
            )

            $matching_field | get --optional content.1.content.0.content | default ""
        } catch {
            ""
        }
    }

    let sqlquery = "SELECT
        Name COLLATE NOCASE as SourceName,
        cast(Fields AS TEXT) as Fields
    FROM SourceTable
    WHERE TemplateID = 0
      AND (
          Name LIKE 'Fed Census:%' COLLATE NOCASE
          OR Name LIKE 'Fed Census %' COLLATE NOCASE
          OR Name LIKE 'Federal Census:%' COLLATE NOCASE
          OR Name LIKE 'Federal Census %' COLLATE NOCASE
      )
    ORDER BY Name COLLATE NOCASE"

    open $env.rmdb | query db $sqlquery
    | insert $field_name {|row| source-field $row.Fields $field_name}
    | reject Fields
    | startat1
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
   $in | enumerate | each { |row| $row.item | upsert index ($row.index + 1) }
}

@category "genq-platform"
def "sort-date-by" [
   column: string
   --reverse(-r)
   --no-empty
   --only-empty
] {
    let rows = $in
    if ($rows | is-empty) {
        return $rows
    }

    let sort_column = if $column == "EventDate" and (($rows | columns) | any {|c| $c == "SortDate" }) {
        "SortDate"
    } else {
        $column
    }

    let with_dates = ($rows | where {|row| (($row | get --optional $sort_column | default "") | is-not-empty) })
    let without_dates = ($rows | where {|row| (($row | get --optional $sort_column | default "") | is-empty) })

    if $only_empty {
        return $without_dates
    }

    let sorted = if $reverse {
        $with_dates | sort-by {|row| $row | get $sort_column } --reverse
    } else {
        $with_dates | sort-by {|row| $row | get $sort_column }
    }

    if $no_empty {
        $sorted
    } else {
        [$sorted, $without_dates] | flatten
    }
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

# Main entry point - route to appropriate genq command
def main [...args: string] {
    if ($args | length) == 0 {
        genq
    } else if ($args | length) == 1 {
        # Single argument - try module command first, then main genq function
        let action = $args.0
        match $action {
            "census" => { genq census }
            _ => { genq $action }
        }
    } else {
        # Multiple arguments - try module command first
        let action = $args.0
        let subcommand = $args.1
        let rest_args = if ($args | length) > 2 { $args | skip 2 } else { [] }
        
        match $action {
            "census" => { genq census $subcommand ...$rest_args }
            _ => { genq $action $subcommand ...$rest_args }
        }
    }
}
