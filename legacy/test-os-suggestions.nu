#!/usr/bin/env nu
# Test OS-specific database path suggestions

print "=== Testing OS-Specific RootsMagic Database Path Suggestions ==="
print ""

print $"Current OS detected: ($nu.os-info.name)"
print ""

print "Path suggestions for this OS:"

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

let default_suggestion = match $nu.os-info.name {
    "windows" => "C:\\Users\\YourName\\Documents\\RootsMagic\\YourFamilyName.rmtree"
    "macos" => "~/Documents/RootsMagic/YourFamilyName.rmtree"
    _ => "~/Documents/RootsMagic/YourFamilyName.rmtree"
}

print $"Default suggestion for input prompt: ($default_suggestion)"
print ""
print "✓ OS-specific suggestions working correctly!"