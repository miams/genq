# List events/facts.
@category "rmgc-common"
@search-terms "MRIN"
@example "list the 10 most recent facts/events added to the database" {'rmgc list events | sort-by LastUpdate | last 10'} 
@example "another list the 10 most recent facts/events added to the database" {'rmgc list events | sort-by LastUpdate | last 10'} 
export def "main" [
    --ParseDate(-p) # Parse date components (increases query time by 50x)
    --citations(-c) # Include citations
] {
    # Note: Marriage events show here, but they are reporting MRIx, not RIN.
    print "List of events/facts."
    print "Marriages list MRIN in RIN column"

    help modules --find rmdate | get commands | flatten | flatten
    
    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}
    let sqlquery = "SELECT EventID, EventTable.OwnerID AS RIN, Name as Event, 
       Details as Description,Substr(EventTable.Date,4,4) COLLATE NOCASE AS EventDate, 
       EventTable.Date COLLATE NOCASE as FullDate, 
       STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000' AS LastUpdateUTC 
    FROM EventTable 
    INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
    JOIN NameTable ON NameTable.OwnerID = EventTable.OwnerID;"

    if $ParseDate { 
        open $env.rmdb | query db $sqlquery | polars into-df
        # | polars with-column ([5 6] | polars into-df) --name c
        | polars with-column ( LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" | polars into-df) --name LastUpdate

        # insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"} 
        # | insert MoreColumns {|row| rmdate $row.FullDate -f 3} | flatten MoreColumns -a
        # | reject LastUpdateUTC | startat1
        # $my_dataframe } else {

        # let my_dataframe = open $env.rmdb | query db $sqlquery | 
        # insert LastUpdate {|row| $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"} 
        # | reject LastUpdateUTC | startat1
    }
}

