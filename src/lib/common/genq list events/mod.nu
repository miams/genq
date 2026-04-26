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
    --full-name (-f) # Add FullName column (Given + Surname combined)
    --full-date      # Include FullDate column (raw 24-char RM date string for use with `rmdate` accessors)
    --place-name     # Resolve PlaceID to place name (adds Place column)
    --unsourced (-u) # Only show events that have no citations (LEFT JOIN CitationLinkTable)
    --proof          # Include Proof column (decoded: Proven / Disproven / Disputed / blank)
    --private        # Include IsPrivate column (Y if marked private, blank otherwise)
    --family-id      # Include FamilyID column (populated for marriage events, 0 for person events)
] {
    use rmdate *
    print "List of events/facts."

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

    let family_id_select = if $family_id {
        ", CASE WHEN EventTable.OwnerType = 1 THEN EventTable.OwnerID ELSE 0 END AS FamilyID"
    } else { "" }

    let sqlquery = (["SELECT EventID,
       EventTable.PrimaryRIN AS RIN,
       COALESCE(PrimaryName.Given, '') AS Given,
       COALESCE(PrimaryName.Surname, '') AS Surname,
       EventTable.SecondaryRIN AS SpouseRIN,
       COALESCE(SpouseName.Given, '') AS SpouseGiven,
       COALESCE(SpouseName.Surname, '') AS SpouseSurname,
       FactTypeTable.Name as Event,
       COALESCE(Details, '') as Description,
       COALESCE(EventTable.Date, '') COLLATE NOCASE as FullDate,
       CASE EventTable.Proof WHEN 1 THEN 'Proven' WHEN 2 THEN 'Disproven' WHEN 3 THEN 'Disputed' ELSE '' END AS Proof,
       CASE WHEN EventTable.IsPrivate = 1 THEN 'Y' ELSE '' END AS IsPrivate,
       COALESCE(STRFTIME(DATETIME(EventTable.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC"
        $place_select $family_id_select "
    FROM (
        SELECT et.*,
               CASE WHEN et.OwnerType = 1 THEN ft.FatherID ELSE et.OwnerID END AS PrimaryRIN,
               CASE WHEN et.OwnerType = 1 THEN COALESCE(ft.MotherID, 0) ELSE 0 END AS SecondaryRIN
        FROM EventTable et
        LEFT JOIN FamilyTable ft ON et.OwnerType = 1 AND ft.FamilyID = et.OwnerID
    ) EventTable
    INNER JOIN FactTypeTable ON FactTypeTable.FactTypeID = EventTable.EventType
    INNER JOIN NameTable PrimaryName INDEXED BY idxNameOwnerID ON PrimaryName.OwnerID = EventTable.PrimaryRIN AND PrimaryName.IsPrimary = 1
    LEFT JOIN NameTable SpouseName INDEXED BY idxNameOwnerID ON SpouseName.OwnerID = EventTable.SecondaryRIN AND SpouseName.IsPrimary = 1"
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
                SpouseRIN: $row.SpouseRIN
                SpouseGiven: $row.SpouseGiven
                SpouseSurname: $row.SpouseSurname
                Event: $row.Event
                Description: $row.Description
                EventDate: $row.FormattedDate
                SortDate: $row.SortableDate
                LastUpdate: $row.LastUpdate
                DateType: $row.DateType
                DateModifier: $row.DateModifier
                DateERA: $row.DateERA
                DateYear: $row.DateYear
                MonthShortName: $row.MonthShortName
                MonthLongName: $row.MonthLongName
                DayofMonth: $row.DayofMonth
                CalendarDate: $row.CalendarDate
                DateQualifier: $row.DateQualifier
            }
            let with_familyid = if $family_id { $base | insert FamilyID $row.FamilyID } else { $base }
            let with_fullname = if $full_name { $with_familyid | insert FullName ([$row.Given, $row.Surname] | str join " ") } else { $with_familyid }
            let with_fulldate = if $full_date { $with_fullname | insert FullDate $row.FullDate } else { $with_fullname }
            let with_place = if $place_name { $with_fulldate | insert Place $row.Place } else { $with_fulldate }
            let with_proof = if $proof { $with_place | insert Proof $row.Proof } else { $with_place }
            if $private { $with_proof | insert IsPrivate $row.IsPrivate } else { $with_proof }
        }
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
                SpouseRIN: $row.SpouseRIN
                SpouseGiven: $row.SpouseGiven
                SpouseSurname: $row.SpouseSurname
                Event: $row.Event
                Description: $row.Description
                EventDate: $row.EventDate
                SortDate: $row.SortDate
                LastUpdate: $row.LastUpdate
            }
            let with_familyid = if $family_id { $base | insert FamilyID $row.FamilyID } else { $base }
            let with_fullname = if $full_name { $with_familyid | insert FullName ([$row.Given, $row.Surname] | str join " ") } else { $with_familyid }
            let with_fulldate = if $full_date { $with_fullname | insert FullDate $row.FullDate } else { $with_fullname }
            let with_place = if $place_name { $with_fulldate | insert Place $row.Place } else { $with_fulldate }
            let with_proof = if $proof { $with_place | insert Proof $row.Proof } else { $with_place }
            if $private { $with_proof | insert IsPrivate $row.IsPrivate } else { $with_proof }
        }
    }
}
