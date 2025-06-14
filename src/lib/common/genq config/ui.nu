# GenQuery Configuration UI Utilities
#
# Provides reusable interactive UI components for configuration wizards

# Reusable interactive navigation UI function using Nushell's input list
@category "genq-common"
export def interactive-select [
    prompt: string              # The prompt message to display
    options: list<record>       # List of {value: string, label: string, description?: string}
    default_index?: int         # Index of default option (0-based)
] {
    let default_idx = ($default_index | default 0)
    
    # Validate inputs
    if ($options | length) == 0 {
        error make {msg: "Options list cannot be empty"}
    }
    
    if $default_idx >= ($options | length) or $default_idx < 0 {
        error make {msg: $"Default index ($default_idx) out of range for ($options | length) options"}
    }
    
    # Create list of display strings with descriptions
    let display_options = ($options | each { |opt|
        if "description" in ($opt | columns) {
            $"($opt.label) - ($opt.description)"
        } else {
            $opt.label
        }
    })
    
    # Use Nushell's input list for interactive selection
    let selected_display = try {
        ($display_options | input list $prompt)
    } catch {
        # Handle interruption gracefully - return default option
        return ($options | get $default_idx | get value)
    }
    
    # Find the corresponding value based on the selected display string
    let selected_option = ($options | enumerate | where { |item|
        let display = if "description" in ($item.item | columns) {
            $"($item.item.label) - ($item.item.description)"
        } else {
            $item.item.label
        }
        $display == $selected_display
    })
    
    if ($selected_option | length) > 0 {
        return ($selected_option | first | get item.value)
    }
    
    # Fallback - shouldn't happen with input list
    return ($options | get $default_idx | get value)
}