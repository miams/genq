# List media items.
@category "genq-common"
@search-terms "pictures photos"
@example "Print percentage of media with no caption." {'let NoCaption = genq list media | where Caption == "" | length; let TotalMedia = genq list media | length; (($NoCaption / $TotalMedia) * 100) | math round --precision 2 | print $"Percent of Media with no caption: ($in)%."'}
export def "main" [
] {
# Find RootsMagic configuration file using cross-platform path construction
let config_filename = match $nu.os-info.name {
    "macos" => ($nu.home-path | path join "RootsMagic" "Version 10" "RootsMagicUser.xml")
    "windows" => ($nu.home-path | path join "AppData" "Roaming" "RootsMagic" "Version 10" "RootsMagicUser.xml")
    _ => ($nu.home-path | path join ".config" "rootmagic" "RootsMagicUser.xml")  # Linux fallback
}

if ($config_filename | path exists) {
    let filepath = open $config_filename | xml xaccess [ preferences Folders Media ] | get content | flatten | get 0.content
    let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
        FROM MultimediaTable;"
    open $env.rmdb | query db $sqlquery 
    | insert fullpath {|row| 
        # Use path join for cross-platform path construction
        let media_subpath = ($row.MediaPath | str substring 2..)
        let full_media_path = ($filepath | path join $media_subpath $row.MediaFile)
        $"\"($full_media_path)\""
    }
    | reject MediaPath MediaFile URL Date SortDate
    | move fullpath --after MediaType
    | startat1
} else {
    # Configuration file not found - fallback to basic query without full paths
    let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
        FROM MultimediaTable;"
    open $env.rmdb | query db $sqlquery 
    | reject URL Date SortDate
    | startat1
}

}
