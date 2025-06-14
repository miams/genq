# Nushell Gotchas and Patterns

A reference guide for Nushell-specific quirks and correct patterns. Formatted for easy AI processing and developer reference.

## Variable Scoping

### Problem
Variables created inside blocks are not accessible outside those blocks.

### Incorrect Pattern
```nushell
if $condition {
    let result = "success"
} else {
    let result = "failure"  
}
print $result  # ERROR: variable not found
```

### Correct Pattern
```nushell
let result = if $condition {
    "success"
} else {
    "failure"
}
print $result  # Works!
```

### Rule
Always use expression-style assignments. Think "what value do I want?" not "what variable do I need?"

---

## String Interpolation with Parentheses

### Problem
Parentheses in string interpolation are interpreted as command substitution.

### Incorrect Pattern
```nushell
print $"Options (recommended for beginners)"  # ERROR: Command 'recommended' not found
print $"Database mode (demo or production)"   # ERROR: Command 'demo' not found
```

### Correct Pattern
```nushell
print $"Options [recommended for beginners]"
print $"Database mode [demo or production]"
print $"Options - recommended for beginners"
```

### Rule
Never use parentheses in interpolated strings for descriptive text. Use square brackets or dashes instead.

---

## Dynamic Path Loading

### Problem
Commands like `source` require parse-time constants and cannot use computed paths.

### Incorrect Pattern
```nushell
source ($env.HOME | path join ".config" "script.nu")  # ERROR: parse-time error
```

### Correct Pattern
```nushell
# Set path in environment variable or use static path
source ~/.config/script.nu
# Or use overlay/module system for dynamic loading
```

### Rule
Use static paths with `source` or set paths in environment variables during initialization.

---

## Module Export Naming

### Problem
Module exports must reference actual filenames with extensions.

### Incorrect Pattern
```nushell
export module 'config'  # ERROR: module not found
```

### Correct Pattern
```nushell
export module 'config.nu'
```

### Rule
Always include the .nu extension when exporting modules.

---

## Function Naming Convention

### Problem
Function names should use hyphens, not underscores.

### Incorrect Pattern
```nushell
def resolve_path [] { }  # Works but not idiomatic
```

### Correct Pattern
```nushell
def resolve-path [] { }
```

### Rule
Use hyphens in function names to follow Nushell conventions.

---

## TOML File Loading

### Problem
Attempting to pipe TOML files to `from toml` when `open` already parses them.

### Incorrect Pattern
```nushell
open "config.toml" | from toml  # Redundant
```

### Correct Pattern
```nushell
open "config.toml"  # Automatically parsed
```

### Rule
The `open` command automatically detects and parses TOML files.

---

## Input Command with Defaults

### Problem
Piping `input` to `default` doesn't work reliably in interactive mode.

### Incorrect Pattern
```nushell
let value = (input "Enter value: " | default "default_value")  # Unreliable
```

### Correct Pattern
```nushell
let value = (input "Enter value: " | str trim)
let value = if ($value | is-empty) { "default_value" } else { $value }
```

### Rule
Explicitly check for empty input rather than relying on piped defaults.

---

## ANSI Code Support

### Problem
Not all standard ANSI codes are supported by Nushell's `ansi` command.

### Incorrect Pattern
```nushell
print $"(ansi dim)Muted text(ansi reset)"  # ERROR: Unknown ansi code
```

### Correct Pattern
```nushell
print $"(ansi light_gray)Muted text(ansi reset)"
```

### Rule
Check Nushell's supported ANSI codes. Use `ansi --list` to see available codes.

---

## Break Statement in Loops

### Problem
Nushell's `break` doesn't take arguments like in other languages.

### Incorrect Pattern
```nushell
loop { break "value" }  # ERROR: break doesn't take arguments
```

### Correct Pattern
```nushell
mut result = ""
while true {
    $result = "value"
    break
}
```

### Rule
Use mutable variables with while loops to return values from loops.

---

## Path Operations

### Problem
Need to understand Nushell's path manipulation commands.

### Examples
```nushell
# Extract filename from path
"path/to/file.jpg" | path basename  # Returns: file.jpg

# Add to table column
$table | insert filename {|row| $row.fullpath | path basename}

# Check path type
if ($path | str contains ":\\") { "windows" } else { "unix" }
if ($path | str starts-with "/") { "absolute" } else { "relative" }
```

### Rule
Use Nushell's built-in path commands instead of string manipulation.

---

## Record Key Uniqueness

### Problem
Nushell records cannot have duplicate keys.

### Incorrect Pattern
```nushell
let record = {
    name: "John"
    name: "Jane"  # ERROR: duplicate key
}
```

### Correct Pattern
```nushell
# Use unique keys or create a list
let records = [
    {name: "John"}
    {name: "Jane"}
]
```

### Rule
Ensure all record keys are unique. Use lists for multiple items with same structure.

---

## Working Directory Context

### Problem
Commands run from autoload have different working directory than development.

### Solution
```nushell
# Always use absolute paths or environment variables
let config_path = ($env.GENQ_HOME | path join "config" "file.toml")

# Not relative paths
let config_path = "./config/file.toml"  # Breaks in autoload
```

### Rule
Use environment variables for base paths, never assume working directory.

---

## Tab Completion Requirements

### Problem
Commands need proper exports to appear in tab completion.

### Incorrect Pattern
```nushell
def "genq config" [] { }  # Not visible in tab completion
```

### Correct Pattern
```nushell
# Add descriptive comment and export
# Configure GenQuery settings interactively.
export def "genq config" [] { }
```

### Rule
Export commands and add descriptive comments for tab completion visibility.