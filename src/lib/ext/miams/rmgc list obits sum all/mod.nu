# List summary of all obituaries.
@category "rmgc-ext-miams"
export def "main" [] {
   print "List summaries of all obituaries."

   $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d %H:%M:%S"}
   let sqlquery = "SELECT EventID, OwnerID as RIN, Details AS Newspaper, Note AS Obituary, STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) AS LastUpdate 
   FROM EventTable 
   JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType 
   WHERE EventTable.EventType = 1000" 
   let my_dataframe = open $env.rmdb | query db $sqlquery 
    | sort-by LastUpdate
    | reject Obituary
    | startat1

   $my_dataframe
}