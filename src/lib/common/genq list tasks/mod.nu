# List research tasks with status, priority, and linked records.
@category "genq-common"
@search-terms "task research todo to-do checklist reminder research log"
@example "List all tasks." {'genq list tasks'}
@example "List only incomplete tasks." {'genq list tasks | where Status != "Done"'}
@example "List high-priority tasks." {'genq list tasks | where Priority == "High"'}
@example "List tasks linked to a specific person." {'genq list tasks --rin 42'}
@example "List only research tasks." {'genq list tasks --type research'}
export def "main" [
    --rin (-r): int          # Filter: show only tasks linked to this person RIN
    --type (-t): string      # Filter by type: general, note, research
    --mod-date (-d)          # Include LastUpdate column (TaskTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    print "List of research tasks."

    # Aggregate linked person names (a task can be linked to multiple people)
    let sqlquery = "
        SELECT
            tk.TaskID,
            CASE tk.TaskType
                WHEN 0 THEN 'General'
                WHEN 1 THEN 'Note'
                WHEN 2 THEN 'Research'
                ELSE CAST(tk.TaskType AS TEXT)
            END AS Type,
            COALESCE(tk.Name, '')        AS Name,
            CASE tk.Status
                WHEN 0 THEN 'Todo'
                WHEN 1 THEN 'Todo'
                WHEN 2 THEN 'In Progress'
                WHEN 3 THEN 'Done'
                ELSE CAST(tk.Status AS TEXT)
            END AS Status,
            CASE tk.Priority
                WHEN 0 THEN ''
                WHEN 1 THEN 'Very Low'
                WHEN 2 THEN 'Low'
                WHEN 3 THEN 'Normal'
                WHEN 4 THEN 'High'
                WHEN 5 THEN 'Very High'
                ELSE CAST(tk.Priority AS TEXT)
            END AS Priority,
            SUBSTR(tk.Date1, 4, 4)       AS Year,
            COALESCE(tk.Details, '')     AS Details,
            COALESCE(tk.Results, '')     AS Results,
            GROUP_CONCAT(
                CASE tl.OwnerType
                    WHEN 0 THEN
                        COALESCE(n.Given, '') || ' ' || COALESCE(n.Surname, '')
                    ELSE NULL
                END,
                '; '
            )                            AS LinkedPersons,
            COALESCE(STRFTIME(DATETIME(tk.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
        FROM TaskTable tk
        LEFT JOIN TaskLinkTable tl ON tl.TaskID = tk.TaskID
        LEFT JOIN NameTable n      ON tl.OwnerType = 0
                                   AND n.OwnerID = tl.OwnerID
                                   AND n.IsPrimary = 1
        GROUP BY tk.TaskID
        ORDER BY tk.Status, tk.Priority DESC, tk.TaskID"

    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row|
            if ($row.LastUpdateUTC | is-empty) { "" } else {
                $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S"
            }
        }
        | reject LastUpdateUTC
        | update LinkedPersons {|row| $row.LinkedPersons | default "" }

    # --rin filter: re-query TaskLinkTable to find tasks linked to this person
    let result = if not ($rin | is-empty) {
        let linked_ids = open $env.rmdb
            | query db $"SELECT TaskID FROM TaskLinkTable WHERE OwnerType = 0 AND OwnerID = ($rin)"
            | get TaskID
        $result | where {|r| $r.TaskID in $linked_ids }
    } else { $result }

    # --type filter
    let result = if not ($type | is-empty) {
        let t = $type | str downcase
        $result | where {|r| ($r.Type | str downcase) | str contains $t }
    } else { $result }

    if $mod_date { $result } else { $result | reject LastUpdate }
}
