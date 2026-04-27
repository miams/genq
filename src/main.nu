# Source this script to add the commands

use std *

# Load common and custom modules
use common *
use ext/miams *
use ext/pres2025 *

# Direct access to telemetry path helpers — used only by telemetry-init below
# so the inline session-start span lands in the same buffer the public
# `genq telemetry view` reads. These are intentionally not re-exported from
# the `genq telemetry` namespace to keep the user-facing surface minimal.
use 'common/genq telemetry/buffer.nu' [append-span, rotate-buffer]
use 'common/genq telemetry/history.nu' [rotate-history]

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

# Auto-renumber displayed tables 1-based at the REPL prompt.
# Producers do not add an explicit `index` column; this hook applies one
# only on final REPL output. Pipeline filters between producer and display
# see plain lists, so auto-renumbering after `where`/`first`/etc. just works.
$env.config.hooks.display_output = {||
    let val = $in
    if (($val | describe) | str starts-with "table") and (not ('index' in ($val | columns))) {
        $val | enumerate | each {|r| $r.item | upsert index ($r.index + 1) } | table
    } else {
        $val | table
    }
}

# Telemetry: initialize session (fire-and-forget, no-op if disabled)
# All telemetry errors are silently caught — telemetry must never break genq.
try {
    telemetry-init
} catch { }

# DB shape profile: heavy structural snapshot of the active RootsMagic
# database (152+ scalar metrics + multi-row histograms). Runs in a
# background thread so the user gets their prompt immediately. The profile
# command itself is fingerprint-cached: on a stable DB it's a sub-50ms
# fingerprint check followed by an early return, so spawning every session
# is cheap. See docs/db-shape-profile.md for the full design.
try {
    job spawn { try { genq telemetry profile-init } catch { } }
} catch { }

def --env telemetry-init [] {
    # Telemetry is mandatory and always-on. Session start: collect resource
    # attributes, generate trace_id, write initial span.
    let ver = (version)
    let host = (sys host)
    let trace_id = (random uuid | str replace -a '-' '')
    let span_id = (random uuid | str replace -a '-' '' | str substring 0..<16)
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

    # Lightweight DB labels for span correlation. Heavy structural metrics
    # (person_count, size_kb, schema fingerprints) are captured by the DB
    # shape profile and uploaded separately to /v1/profiles.
    let db_name = ($env.GENQ_CONFIG?.database?.active? | default "unknown")
    let db_filename = (if (($env.rmdb? | default "") | path exists) {
        $env.rmdb | path basename
    } else { "" })

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
            { key: "genq.db.name",                value: { stringValue: $db_name } }
            { key: "genq.db.filename",            value: { stringValue: $db_filename } }
            { key: "genq.config.table_mode",      value: { stringValue: ($env.GENQ_CONFIG?.display?.table_mode? | default "rounded") } }
            { key: "genq.config.date_format",     value: { intValue: ($env.GENQ_CONFIG?.display?.date_format? | default 1 | into string) } }
            { key: "genq.session.commands_run",   value: { intValue: "0" } }
            { key: "genq.session.error_count",    value: { intValue: "0" } }
        ]
        status: { code: 1 }
        _resource: $resource
    }

    # Store session in env for command-level instrumentation. commands_run /
    # error_count accumulate across hook invocations during this session.
    $env.GENQ_TELEMETRY_SESSION = {
        trace_id: $trace_id
        span_id: $span_id
        start_time: $start
        start_time_unix_nano: $start_nano
        commands_run: 0
        error_count: 0
        resource: $resource
    }

    # Write initial session span to the buffer; rotate retention on the way in.
    # Path resolution lives in the telemetry module (paths.nu) — see there for
    # the macOS / Linux / Windows layout.
    append-span $span

    let retention = ($env.GENQ_CONFIG?.telemetry?.retention_days? | default 30)
    rotate-buffer $retention
    rotate-history $retention

    # Wire command-level hooks. Append to any user-configured hooks.
    # pre_execution captures the commandline + start time at command dispatch.
    # pre_prompt finalizes the previous command (record span + emit session.end).
    $env.config.hooks.pre_execution = (
        ($env.config.hooks.pre_execution? | default [])
        | append {||
            if ($env.GENQ_TELEMETRY_SESSION? | default null) == null { return }
            let cmdline = (try { commandline } catch { "" })
            if ($cmdline | str trim | is-empty) { return }
            $env.GENQ_TELEMETRY_PENDING = { commandline: $cmdline, start_time: (date now) }
        }
    )

    $env.config.hooks.pre_prompt = (
        ($env.config.hooks.pre_prompt? | default [])
        | append {||
            let pending = ($env.GENQ_TELEMETRY_PENDING? | default null)
            if $pending == null { return }
            $env.GENQ_TELEMETRY_PENDING = null
            try { genq telemetry record-from-hook $pending.start_time (date now) $pending.commandline } catch { }
        }
    )
}

let FedCensus = [1790 1800 1810 1820 1830 1840 1850 1860 1870 1880 1900 1910 1920 1930 1940 1950]
$env.SurnameGroup = [Iams, Iames, Iiams, Iiames, Ijams, Ijames, Imes, Eimes]

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
    action?: string,  # action command
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
    'help' => { genq help },
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

# Show GenQuery help and quick-start tips.
@category "genq-common"
def "genq help" [] {
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
