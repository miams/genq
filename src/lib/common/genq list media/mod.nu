# List media items.
@category "genq-common"
@search-terms "pictures photos"
@example "Print percentage of media with no caption." {'let NoCaption = genq list media | where Caption == "" | length; let TotalMedia = genq list media | length; (($NoCaption / $TotalMedia) * 100) | math round --precision 2 | print $"Percent of Media with no caption: ($in)%."'}
export def "main" [
] {
# Find RootsMagic configuration file.
if $nu.os-info.name == 'macos' { 
    # Happy-Path: Default app location form RM10 on MacOS
    let filename = [$nu.home-path, '/RootsMagic/Version 10/RootsMagicUser.xml'] | str join 
    if ($filename | path exists) {
        let filepath = open $filename | xml xaccess [ preferences Folders Media ] | get content | flatten | get 0.content
        # print $"The RM10 for ($nu.os-info.name) filepath is: ($filepath)."
        # print 
        let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
            FROM MultimediaTable;"
        open $env.rmdb | query db $sqlquery 
        | insert fullpath {|row| $filepath; ['"', $filepath, "/", ($row.MediaPath | str substring 2..100), "/", $row.MediaFile, '"'] | str join | str replace -a "\\" "/"}
        | reject MediaPath MediaFile URL Date SortDate
        | move fullpath --after MediaType
        | startat1
        } else {
        # print $"The RootsMagic version 10 for ($nu.os-info.name) configuration file: ($filename) not found. Degrading to not have full parsed path."
        # Degrade to not have full parsed path.
        let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
            FROM MultimediaTable;"
        open $env.rmdb | query db $sqlquery 
        | reject URL Date SortDate
        | startat1
        }} else {
    # print "Windows."
    # Happy-Path: Default app location form RM10 on Windows 10
    let filename = [$nu.home-path, '\AppData\Roaming\RootsMagic\Version 10\RootsMagicUser.xml'] | str join 
    if ($filename | path exists) {
        let filepath = open $filename | xml xaccess [ preferences Folders Media ] | get content | flatten | get 0.content
        # print $"The RM10 for ($nu.os-info.name) filepath is: ($filepath)."
        # print 
        let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
            FROM MultimediaTable;"
        open $env.rmdb | query db $sqlquery 
        | insert fullpath {|row| $filepath; ['"', $filepath, '\', ($row.MediaPath | str substring 2..100), '\', $row.MediaFile, '"'] | str join | str replace -a '/' '\'}
        | reject MediaPath MediaFile URL Date SortDate
        | move fullpath --after MediaType
        | startat1
        } else {
        # print $"The RootsMagic version 10 for ($nu.os-info.name) configuration file: ($filename) not found. Degrading to not have full parsed path."
        # Degrade to not have full parsed path.
        let sqlquery = "SELECT MediaID, MediaType, MediaPath, MediaFile, URL, Caption, Description, Date, SortDate 
            FROM MultimediaTable;"
        open $env.rmdb | query db $sqlquery 
        | reject URL Date SortDate
        | startat1
        }
}

}
