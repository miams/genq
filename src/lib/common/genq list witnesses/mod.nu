# List shared event witnesses across all event types.
@category "genq-common"
@search-terms "shared event witness role participant"
@example "list all witnesses" {'genq list witnesses'}
@example "list witnesses for a specific person" {'genq list witnesses --rin 42'}
@example "list witnesses for census events only" {'genq list witnesses | where EventType == "Census"'}
export def "main" [
    --rin (-r): int          # Filter: show only records where this RIN is the witness
    --event-rin (-e): int    # Filter: show only witnesses for events owned by this RIN
    --event-type (-t): string  # Filter by event type name (case-insensitive substring match)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of shared event witnesses."

    let sqlquery = "SELECT
        w.WitnessID,
        w.EventID,
        ft.Name COLLATE NOCASE as EventType,
        SUBSTR(e.Date, 4, 4) as EventYear,
        e.OwnerID as EventOwnerRIN,
        primary_person.Given COLLATE NOCASE as EventOwnerGiven,
        primary_person.Surname COLLATE NOCASE as EventOwnerSurname,
        w.PersonID as WitnessRIN,
        witness_name.Given COLLATE NOCASE as WitnessGiven,
        witness_name.Surname COLLATE NOCASE as WitnessSurname,
        r.RoleName COLLATE NOCASE as Role
    FROM WitnessTable w
    JOIN EventTable e ON w.EventID = e.EventID
    JOIN FactTypeTable ft ON e.EventType = ft.FactTypeID
    LEFT JOIN RoleTable r ON w.Role = r.RoleID
    LEFT JOIN NameTable primary_person ON e.OwnerID = primary_person.OwnerID AND primary_person.IsPrimary = 1
    LEFT JOIN NameTable witness_name ON w.PersonID = witness_name.OwnerID AND witness_name.IsPrimary = 1
    WHERE w.PersonID > 0
    ORDER BY e.OwnerID, w.EventID"

    let result = open $env.rmdb | query db $sqlquery

    let result = if not ($rin | is-empty) {
        $result | where WitnessRIN == $rin
    } else { $result }

    let result = if not ($event_rin | is-empty) {
        $result | where EventOwnerRIN == $event_rin
    } else { $result }

    let result = if not ($event_type | is-empty) {
        let t = $event_type | str downcase
        $result | where {|r| ($r.EventType | str downcase) | str contains $t}
    } else { $result }

    $result | startat1
}
