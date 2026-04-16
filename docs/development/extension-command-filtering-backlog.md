# Extension Command Filtering - Backlog Item

## Problem Statement

Extensions are data format specific. When users have different extensions enabled (e.g., `["pres2025"]` vs `["miams"]`), they see commands in tab completion that won't work with their database and will show null results or errors.

**Current Config Example:**
```toml
[extensions]
enabled = ["pres2025"]  # User only has pres2025, but sees miams commands too
```

**User Experience Issue:**
- User types `genq list findagrave` (miams command) but has pres2025 database
- Command fails or shows empty results
- Confusing experience - user doesn't know why command doesn't work

## Solution Options Analyzed

### Option 1: Dynamic Command Filtering
**Goal:** Only show commands for enabled extensions in tab completion and help

#### Option 1A: Dynamic Completer (High Complexity)
```nu
def list_action_completer [] {
    let config = (load-config)  # Read config on every tab press
    let enabled_exts = $config.extensions.enabled
    # Filter commands based on enabled extensions
}
```

**Complexity Issues:**
- ❌ Performance: Reads/parses config file on every tab press
- ❌ Dependency hell: Completer needs access to config loading functions  
- ❌ Error handling: What if config is missing/corrupted during completion?
- ❌ Nushell limitations: Completers have restricted access to modules/functions

#### Option 1B: Pre-computed Completion (Medium Complexity)
Generate completion list once at startup, store in environment variable.

**Issues:**
- ❌ Stale data: Completion doesn't update if config changes
- ❌ Environment pollution: Extra environment variables
- ❌ Bootstrap timing: Config must load before completers are defined

#### Option 1C: Smart Static with Runtime Validation (Low Complexity - Recommended)
Keep static completion, add runtime filtering:

```nu
def list_action_completer [] { 
    ["findagrave", "people", "citations", "events", "families", "newspaper", "obits"]
}

def validate-command-available [command: string] {
    let config = (load-config)
    let cmd_to_ext = {findagrave: "miams", newspaper: "miams", presidents: "pres2025"}
    
    if $command in ($cmd_to_ext | columns) {
        let required_ext = ($cmd_to_ext | get $command)
        if $required_ext not-in $config.extensions.enabled {
            print $"Error: Command '($command)' requires '($required_ext)' extension"
            print $"Enable it in config: extensions.enabled = [..., \"($required_ext)\"]"
            return false
        }
    }
    return true
}
```

**Benefits:**
- ✅ Low complexity: No changes to completion system
- ✅ Good UX: Clear error when invalid command used
- ✅ Maintainable: Simple mapping of commands to extensions
- ✅ Performance: No config reading during tab completion
- ✅ Robust: Works even if config is temporarily broken

**Trade-off:** Users see all commands in tab completion, but get helpful errors for disabled ones.

### Option 2: Static Commands with Warnings
Keep current system, improve error messages.

### Option 3: Graceful Degradation  
Commands work but show "No data" instead of errors.

## Technical Context

**Current Tab Completion System:**
```nu
def list_action_completer [] { ["findagrave", "people", "citations", "events", "families", "newspaper", "obits"]}
```

**Command-to-Extension Mapping:**
- `common` extension: people, citations, events, families, sources, media
- `miams` extension: findagrave, newspaper, obits
- `pres2025` extension: presidents

**Nushell Completion Constraints:**
- Completer functions expected to be pure/stateless
- Limited access to modules/functions during completion
- Performance sensitive (called on every tab press)

## Implementation Plan (When Revisited)

**Recommended: Option 1C - Smart Static with Runtime Validation**

1. **Map commands to extensions** - Create lookup table
2. **Add validation function** - Check if required extension is enabled
3. **Integrate validation** - Call from command routing logic
4. **Provide helpful errors** - Tell user which extension they need

**Files to modify:**
- `src/main.nu` - Add validation function and integration
- Command routing logic - Add validation calls

**Estimated effort:** 1-2 hours

## Decision Context

**Discussed:** During code review of genq list commands
**Priority:** Medium (UX improvement, not critical functionality)
**Blocked by:** None - just prioritization
**Related:** Extension system, command routing, user experience

## Future Considerations

- Monitor user feedback about command confusion
- Consider if dynamic completion becomes easier with Nushell updates
- Evaluate if extension system becomes more complex (more extensions, more commands)
- Consider command grouping/namespacing as alternative approach