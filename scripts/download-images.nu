#!/usr/bin/env nu

# Presidential Images Download Script
# Downloads images from DuckDuckGo search results based on person names extracted from filenames

def extract-person-name [filename: string] {
    # Remove file extension and trailing quote
    let base = ($filename | str replace '\.jpg"$' '')
    
    # Try different patterns to extract person name
    let name = if ($base | str contains ' - ') {
        # Pattern: "Source - Person Name.jpg"
        $base | split row ' - ' | last
    } else if ($base | str contains 'Photo_') {
        # Pattern: "Photo_FirstName_LastName_Year.jpg"
        $base | str replace 'Photo_' '' | str replace '_\d+$' '' | str replace '_' ' '
    } else if ($base | str contains 'Portrait_') {
        # Pattern: "Portrait_FirstName_LastName.jpg"
        $base | str replace 'Portrait_' '' | str replace '_' ' '
    } else {
        # Default: assume it's just the name with underscores
        $base | str replace '_' ' '
    }
    
    $name | str trim
}

def search-duckduckgo-images [person_name: string] {
    let search_query = ($person_name + " portrait president")
    let encoded_query = ($search_query | str replace -a ' ' '+')
    let search_url = $"https://duckduckgo.com/?q=($encoded_query)&iax=images&ia=images"
    
    print $"Searching for: ($person_name)"
    print $"URL: ($search_url)"
    
    try {
        let response = (http get $search_url --headers {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"})
        
        # Extract image URLs from the HTML response
        # Look for image URLs in the page source
        let image_urls = ($response | str find-replace -a --regex 'data-src="([^"]+\.jpg[^"]*)"' '$1' | lines | where {|line| $line | str contains "http" and ($line | str contains ".jpg")})
        
        if ($image_urls | length) > 0 {
            $image_urls | first
        } else {
            null
        }
    } catch {
        print $"Error searching for ($person_name): ($in)"
        null
    }
}

def download-image [url: string, filename: string] {
    let clean_filename = ($filename | str replace '"' '')
    let output_path = $"./downloaded_images/($clean_filename)"
    
    print $"Downloading: ($url) -> ($output_path)"
    
    try {
        # Create output directory if it doesn't exist
        mkdir ./downloaded_images
        
        # Download the image
        http get $url | save $output_path
        print $"✓ Downloaded: ($clean_filename)"
        true
    } catch {
        print $"✗ Failed to download ($clean_filename): ($in)"
        false
    }
}

def main [] {
    print "Presidential Images Download Script"
    print "=================================="
    
    # Get first 5 media files
    let media_files = (nu -I '/Users/miams/Code/genq/src/lib' -I '/Users/miams/Code/genq/src/lib/ext' -c 'source src/main.nu; genq list media | get fullpath | path basename | first 5')
    
    for filename in $media_files {
        print $"\nProcessing: ($filename)"
        
        let person_name = (extract-person-name $filename)
        print $"Extracted name: ($person_name)"
        
        let image_url = (search-duckduckgo-images $person_name)
        
        if ($image_url | is-not-empty) {
            download-image $image_url $filename
        } else {
            print $"✗ No image found for: ($person_name)"
        }
        
        # Small delay to be respectful to the search engine
        sleep 2sec
    }
    
    print "\nDownload script completed!"
}