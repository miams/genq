# List events/facts.
@category "genq-common"
@search-terms "MRIN"
@example "list the 10 most recent facts/events added to the database" {'genq list events | sort-by LastUpdate | last 10'}
@example "list events with resolved place names" {'genq list events --place-name | where Place != ""'}
@example "list person events that have no citations" {'genq list events --unsourced'}
@example "list unproven birth events" {'genq list events --proof | where Event == "Birth" and Proof == ""'}
@example "list private events" {'genq list events --private | where IsPrivate == "Y"'}
export def "main" [
    --ParseDate(-p)  # Include parsed date component columns
    --place-name     # Resolve PlaceID to place name (adds Place column)
    --unsourced (-u) # Only show events that have no citations (LEFT JOIN CitationLinkTable)
    --proof          # Include Proof column (decoded: Proven / Disproven / Disputed / blank)
    --private        # Include IsPrivate column (Y if marked private, blank otherwise)
] {
    use rmdate *
    # Note: Marriage events show here, but they are reporting MRIx, not RIN.
    print "List of events/facts."
    print "Marriages list MRIN in RIN column"

    $env.config.datetime_format = {normal: "%Y-%m-%d %H:%M:%S", table: "%Y-%m-%d"}

    let place_select = if $place_name {
        ", COALESCE(PlaceTable.Name, '') COLLATE NOCASE as Place"
    } else { "" }

    let place_join = if $place_name {
        " LEFT JOIN PlaceTable ON EventTable.PlaceID = PlaceTable.PlaceID"
    } else { "" }

    let unsourced_join = if $unsourced {
        " LEFT JOIN CitationLinkTable ON CitationLinkTable.OwnerID = EventTable.EventID AND CitationLinkTable.OwnerType = 2"
    } else { "" }

    let unsourced_where = if $unsourced {
        " WHERE CitationLinkTable.CitationID IS NULL"
    } else { "" }

    let sqlquery = (["SELECT EventID, EventTable.OwnerID AS RIN, NameTable.Given as Given, NameTable.Surname as Surname, FactTypeTable.Name as Event,
       COALESCE(Details, '') as Description,
       COALESCE(EventTable.Date, '') COLLATE NOCASE as FullDate,
       CASE EventTable.Proof WHEN 1 THEN 'Proven' WHEN 2 THEN 'Disproven' WHEN 3 THEN 'Disputed' ELSE '' END AS Proof,
       CASE WHEN EventTable.IsPrivate = 1 THEN 'Y' ELSE '' END AS IsPrivate,
       COALESCE(STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC"
        $place_select "
    FROM EventTable
    INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
    JOIN NameTable ON NameTable.OwnerID = EventTable.OwnerID AND NameTable.IsPrimary = 1"
        $place_join $unsourced_join $unsourced_where] | str join)

    if $ParseDate {
        open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | insert ParsedDate {|row| parse-rm-date $row.FullDate} | flatten ParsedDate -a
        | each {|row|
            let base = {
                EventID: $row.EventID
                RIN: $row.RIN
                Given: $row.Given
                Surname: $row.Surname
                Event: $row.Event
                Description: $row.Description
                EventDate: $row.FormattedDate
                SortDate: $row.SortableDate
                LastUpdate: $row.LastUpdate
                DateType: $row.DateType
                DateQualifier: $row.DateQualifier
                DateERA: $row.DateERA
                DateYear: $row.DateYear
                MonthShortName: $row.MonthShortName
                MonthLongName: $row.MonthLongName
                DayofMonth: $row.DayofMonth
                CalendarDate: $row.CalendarDate
                DateDescriptor: $row.DateDescriptor
            }
            let with_place = if $place_name { $base | insert Place $row.Place } else { $base }
            let with_proof = if $proof { $with_place | insert Proof $row.Proof } else { $with_place }
            if $private { $with_proof | insert IsPrivate $row.IsPrivate } else { $with_proof }
        }
        | startat1
    } else {
        open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | upsert-rm-date FullDate EventDate SortDate
        | each {|row|
            let base = {
                EventID: $row.EventID
                RIN: $row.RIN
                Given: $row.Given
                Surname: $row.Surname
                Event: $row.Event
                Description: $row.Description
                EventDate: $row.EventDate
                SortDate: $row.SortDate
                LastUpdate: $row.LastUpdate
            }
            let with_place = if $place_name { $base | insert Place $row.Place } else { $base }
            let with_proof = if $proof { $with_place | insert Proof $row.Proof } else { $with_place }
            if $private { $with_proof | insert IsPrivate $row.IsPrivate } else { $with_proof }
        }
        | startat1
    }
}
