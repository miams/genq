# GenQuery Extension API Documentation

This document describes how to create and structure extensions for GenQuery, a terminal-based RootsMagic reporting engine built on Nushell.

## Overview

GenQuery extensions allow users to add custom functionality while keeping the core system stable and focused. Extensions are organized under `src/lib/ext/` with each extension in its own directory.

## Extension Structure

### Basic Extension Layout
```
src/lib/ext/your-extension-name/
├── mod.nu              # Main module file (required)
├── README.md           # Extension documentation (recommended)
└── additional-files/   # Additional modules as needed
```

### Example Extension Structure
```
src/lib/ext/miams/
├── mod.nu                                    # Main exports
├── README.md                                 # Documentation
├── genq census/mod.nu                        # Census-specific commands
├── genq list findagrave/mod.nu              # FindAGrave functionality
├── genq list obits/mod.nu                   # Obituary processing
└── genq tabulate sources labels/mod.nu      # Source analysis
```

## Extension API Guidelines

### 1. Module Structure

Every extension must have a `mod.nu` file that exports its functionality:

```nu
# src/lib/ext/your-extension/mod.nu
export use "genq your-command/mod.nu" *
export use "another-module/mod.nu" *

# Optional: Extension metadata
export def extension-info [] {
    {
        name: "your-extension-name"
        version: "1.0.0"
        author: "Your Name"
        description: "Brief description of your extension"
        dependencies: ["common"]
        genq_api_version: "1.0"
    }
}
```

### 2. Command Naming Conventions

Extensions should follow GenQuery's hierarchical command structure:

- **Primary commands**: `genq <action>` (e.g., `genq census`)
- **List commands**: `genq list <type>` (e.g., `genq list obits`)
- **Tabulate commands**: `genq tabulate <analysis>` (e.g., `genq tabulate sources`)

### 3. Function Categories

Use the `@category` attribute to organize your functions:

```nu
@category "genq-your-extension"
export def "genq your-command" [] {
    # Your implementation
}
```

Recommended categories:
- `genq-your-extension-name` for extension-specific commands
- `genq-common` only for functions that extend core functionality

### 4. Documentation Standards

All exported functions should include:

```nu
# Brief description of what the function does.
#
# Longer description explaining the purpose, data sources, and output format.
# Include information about any special requirements or limitations.
#
# Examples:
#   genq your-command --option value
#   genq your-command | where condition == "value"

@category "genq-your-extension"
@search-terms "relevant, keywords, for, discovery"
@example 'Description of example' {'genq your-command --example'}
export def "genq your-command" [
    required_param: string          # Description of required parameter
    --optional_flag: int = 1        # Description of optional flag with default
    --help(-h)                      # Show help information
] {
    # Implementation
}
```

### 5. Database Access Patterns

Extensions should follow these patterns for database access:

#### Using Environment Variables
```nu
# Access configured database
let results = open $env.rmdb | query db $your_sql_query

# Access SQL files directory
let sql_path = [$env.genq_sql, "your-query.sql"] | path join
let query = open $sql_path
```

#### SQL Query Patterns
```nu
# Simple query
let results = open $env.rmdb | query db "SELECT * FROM PersonTable LIMIT 10"

# Parameterized query
let results = open $env.rmdb | query db "
    SELECT * FROM PersonTable 
    WHERE PersonID = ? AND BirthYear > ?
" -p [$person_id, $min_year]

# Using named parameters
let results = open $env.rmdb | query db "
    SELECT * FROM PersonTable 
    WHERE PersonID = :person_id AND BirthYear > :min_year
" -p {person_id: $person_id, min_year: $min_year}
```

### 6. Output Formatting

Extensions should provide consistent output formatting:

#### For List Commands
```nu
# Return structured data that can be piped
$results 
| select PersonID Surname Given BirthYear DeathYear
| sort-by Surname Given
```

#### For Reports
```nu
# Use GenQuery's built-in utilities
$results 
| each {|row| $row | upsert ShortName (limit $row.FullName 20)}
| startat1  # Use GenQuery's 1-based indexing utility
```

#### For Dates
```nu
# Use GenQuery's rmdate function for RootsMagic date parsing
use rmdate
$results 
| each {|row| $row | upsert FormattedDate (rmdate $row.RMDate --format 3)}
```

### 7. Error Handling

Provide helpful error messages:

```nu
# Check for required environment
if ($env.rmdb? | is-empty) {
    error make {
        msg: "Database not configured"
        help: "Set the rmdb environment variable to point to your RootsMagic database"
    }
}

# Validate parameters
if $year < 1800 or $year > 2024 {
    error make {
        msg: $"Invalid year: ($year)"
        help: "Year must be between 1800 and 2024"
    }
}
```

### 8. Utility Functions

Extensions can create internal utility functions:

```nu
# Internal helper (not exported)
def parse_census_year [year: int] {
    if $year in [1790, 1800, 1810, 1820, 1830, 1840, 1850, 1860, 1870, 1880, 1900, 1910, 1920, 1930, 1940, 1950] {
        $year
    } else {
        error make {msg: $"($year) is not a valid US Federal Census year"}
    }
}

# Exported command using the helper
@category "genq-your-extension"
export def "genq census" [year: int] {
    let census_year = parse_census_year $year
    # ... rest of implementation
}
```

## Best Practices

### Performance
- Use `SELECT` statements that only return needed columns
- Add appropriate `WHERE` clauses to limit result sets
- Consider using indexes when querying large tables

### Compatibility
- Test with the demo database (`demo/pres2020.ged`)
- Use `COLLATE NOCASE` for text comparisons to ensure compatibility
- Handle missing data gracefully

### User Experience
- Provide helpful command descriptions and examples
- Include progress indicators for long-running operations
- Support common output formats (table, CSV, etc.)

### Code Organization
- Keep functions focused and single-purpose
- Use descriptive parameter names
- Group related functionality in submodules

## Testing Your Extension

### Basic Testing
```nu
# Test loading your extension
use src/lib/ext/your-extension *

# Test individual commands
genq your-command --help
genq your-command test-parameter
```

### Integration Testing
```nu
# Test with demo database
$env.rmdb = "demo/pres2020.rmtree"
$env.genq_sql = "sql/"

# Run your commands
genq your-command | first 5
```

## Extension Examples

See existing extensions for reference:
- `miams/` - Personal genealogy research tools
- `pres2020/` - US Presidents database utilities

## Contributing

When creating extensions:

1. Follow the naming conventions and API patterns
2. Include comprehensive documentation
3. Test with the provided demo database
4. Consider contributing useful extensions back to the community

## API Versioning

Current GenQuery API Version: **1.0**

Extensions should specify their required API version:

```nu
export def check_api_compatibility [] {
    let required_version = "1.0"
    # Implementation to check compatibility
}
```

## Support

For questions about extension development:
- Review existing extensions in `src/lib/ext/`
- Check the core functionality in `src/lib/common/`
- Refer to the main GenQuery documentation in `docs/`