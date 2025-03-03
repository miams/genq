# List of full obituaries from Newspapers.com
@category "rmgc-ext-miams"
export def "main" [] {
    print "List of obituaries from Newspapers.com with transcriptions."

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
    let sqlquery = "SELECT EventID, OwnerID as RIN, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdate 
    FROM EventTable 
    JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
    WHERE EventTable.EventType = 1000 
    AND Obituary LIKE '%Newspapers.com%' ORDER BY Newspaper ASC"

    let my_dataframe = open $env.rmdb | query db $sqlquery | insert NewObit {|row|   

    # Replace tags <b>, <i>, and <u> with actual ANSI escape codes
    let ansi_text = $row.Obituary 
        | str replace --all --regex '<b>(.*?)</b>' $"(ansi light_green_bold)$1(ansi reset)"          # Bold
        | str replace --all --regex '<i>(.*?)</i>' $"(ansi light_green_italic)$1(ansi reset)"        # Italic
        | str replace --regex '<u>(.*?)</u>' $"(ansi blue_underline)$1(ansi reset)";                 # Underline
        $ansi_text      
        }
        | sort-by LastUpdate
        | reject Obituary Newspaper EventID LastUpdate
        | startat1

    $my_dataframe
}
