# List events/facts.
use rmdate *

@category "genq-common"
@search-terms "MRIN"
@example "list the 10 most recent facts/events added to the database" {'genq list events | sort-by LastUpdate | last 10'}
@example "list events with resolved place names" {'genq list events --place-name | where Place != ""'}
export def "main" [
    --ParseDate(-p)  # Include parsed date component columns
    --place-name     # Resolve PlaceID to place name (adds Place column)
] {
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

    let sqlquery = (["SELECT EventID, EventTable.OwnerID AS RIN, NameTable.Given as Given, NameTable.Surname as Surname, FactTypeTable.Name as Event,
       COALESCE(Details, '') as Description,
       COALESCE(EventTable.Date, '') COLLATE NOCASE as FullDate,
       COALESCE(STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC"
        $place_select "
    FROM EventTable
    INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
    JOIN NameTable ON NameTable.OwnerID = EventTable.OwnerID AND NameTable.IsPrimary = 1"
        $place_join] | str join)

    if $ParseDate {
        open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | insert ParsedDate {|row| parse-rm-date $row.FullDate} | flatten ParsedDate -a
        | each {|row|
            let result = {
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

            if $place_name {
                $result | insert Place $row.Place
            } else {
                $result
            }
        }
        | startat1
    } else {
        open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | upsert-rm-date FullDate EventDate SortDate
        | each {|row|
            let result = {
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

            if $place_name {
                $result | insert Place $row.Place
            } else {
                $result
            }
        }
        | startat1
    }
}
