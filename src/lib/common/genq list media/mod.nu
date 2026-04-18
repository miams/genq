# List media items.
@category "genq-common"
@search-terms "pictures photos"
@example "Print percentage of media with no caption." {'let NoCaption = genq list media | where Caption == "" | length; let TotalMedia = genq list media | length; (($NoCaption / $TotalMedia) * 100) | math round --precision 2 | print $"Percent of Media with no caption: ($in)%."'}
@example "List all media tagged to a specific person." {'genq list media --for 2'}
@example "Show only the primary photo for a person." {'genq list media --for 2 | where IsPrimary == "Y"'}
export def "main" [
    --mod-date (-d)  # Include LastUpdate column (MultimediaTable.UTCModDate)
    --for (-r): int  # Show only media linked to this RIN (via MediaLinkTable); adds IsPrimary, SortOrder, TagComment
] {
# Find RootsMagic configuration file using cross-platform path construction
let config_filename = match $nu.os-info.name {
    "macos" => ($nu.home-dir | path join "RootsMagic" "Version 10" "RootsMagicUser.xml")
    "windows" => ($nu.home-dir | path join "AppData" "Roaming" "RootsMagic" "Version 10" "RootsMagicUser.xml")
    _ => ($nu.home-dir | path join ".config" "rootmagic" "RootsMagicUser.xml")  # Linux fallback
}

# Build SQL — join MediaLinkTable when --for is set to filter by person RIN
let sqlquery = if ($for | is-not-empty) {
    $"SELECT m.MediaID, m.MediaType, m.MediaPath, m.MediaFile, m.Caption, m.Description,
        CASE WHEN ml.IsPrimary = 1 THEN 'Y' ELSE 'N' END AS IsPrimary,
        ml.SortOrder,
        COALESCE\(ml.Comments, ''\) AS TagComment,
        COALESCE\(STRFTIME\(DATETIME\(m.UTCModDate + 2415018.5\)\) || ' +0000', ''\) AS LastUpdateUTC
        FROM MediaLinkTable ml
        JOIN MultimediaTable m ON ml.MediaID = m.MediaID
        WHERE ml.OwnerType = 0 AND ml.OwnerID = ($for)
        ORDER BY ml.IsPrimary DESC, ml.SortOrder"
} else {
    "SELECT MediaID, MediaType, MediaPath, MediaFile, Caption, Description,
        COALESCE(STRFTIME(DATETIME(UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM MultimediaTable"
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
    let result = open $env.rmdb | query db $sqlquery
    | insert fullpath {|row|
        let media_subpath = ($row.MediaPath | str substring 2.. | str replace --all '\' '/')
        $filepath | path join $media_subpath $row.MediaFile
    }
    | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
    | reject MediaPath LastUpdateUTC
    | move fullpath --after MediaType
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
} else {
    # Configuration file not found — return paths without fullpath resolution
    let result = open $env.rmdb | query db $sqlquery
    | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
    | reject LastUpdateUTC
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}

}
