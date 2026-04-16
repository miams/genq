# List media items.
@category "genq-common"
@search-terms "pictures photos"
@example "Print percentage of media with no caption." {'let NoCaption = genq list media | where Caption == "" | length; let TotalMedia = genq list media | length; (($NoCaption / $TotalMedia) * 100) | math round --precision 2 | print $"Percent of Media with no caption: ($in)%."'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (MultimediaTable.UTCModDate)
] {
# Find RootsMagic configuration file using cross-platform path construction
let config_filename = match $nu.os-info.name {
    "macos" => ($nu.home-dir | path join "RootsMagic" "Version 10" "RootsMagicUser.xml")
    "windows" => ($nu.home-dir | path join "AppData" "Roaming" "RootsMagic" "Version 10" "RootsMagicUser.xml")
    _ => ($nu.home-dir | path join ".config" "rootmagic" "RootsMagicUser.xml")  # Linux fallback
}

if ($config_filename | path exists) {
    let filepath = open $config_filename
        | get content
        | where tag == "Folders"
        | first
        | get content
        | where tag == "Media"
        | first
        | get content
        | get 0.content
    let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate,
        COALESCE(STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM MultimediaTable;"
    let result = open $env.rmdb | query db $sqlquery
    | insert fullpath {|row|
        # Use path join for cross-platform path construction
        let media_subpath = ($row.MediaPath | str substring 2.. | str replace --all '\' '/')
        let full_media_path = ($filepath | path join $media_subpath $row.MediaFile)
        $full_media_path
    }
    | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
    | reject MediaPath MediaFile URL Date SortDate LastUpdateUTC
    | move fullpath --after MediaType
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
} else {
    # Configuration file not found - fallback to basic query without full paths
    let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate,
        COALESCE(STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM MultimediaTable;"
    let result = open $env.rmdb | query db $sqlquery
    | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
    | reject URL Date SortDate LastUpdateUTC
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}

}
