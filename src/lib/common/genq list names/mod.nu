# List all name records — primary and alternate — from NameTable.
@category "genq-common"
@search-terms "AKA maiden married nickname alias spelling alternate"
@example "list only alternate (non-primary) names" {'genq list names --alternate'}
@example "list all AKA names" {'genq list names --type aka'}
@example "list all name records for RIN 42" {'genq list names --rin 42'}
export def "main" [
    --type (-t): string  # Filter by NameType: aka birth immigrant maiden married nickname other
    --alternate (-a)     # Show only alternate (non-primary) names
    --rin (-r): int      # Filter by person RIN
    --mod-date (-d)      # Include LastUpdate column (NameTable.UTCModDate)
] {
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    # Validate --type before building query
    if not ($type | is-empty) {
        let t = $type | str downcase
        let valid = ["aka", "birth", "immigrant", "maiden", "married", "nickname", "other"]
        if not ($valid | any {|v| $v == $t}) {
            print $"(ansi red)Error:(ansi reset) Unknown name type '($t)'."
            print "Valid types: aka birth immigrant maiden married nickname other"
            return
        }
    }

    let type_where = if not ($type | is-empty) {
        let t = $type | str downcase
        let num = match $t {
            "aka"       => "0"
            "birth"     => "1"
            "immigrant" => "2"
            "maiden"    => "3"
            "married"   => "4"
            "nickname"  => "5"
            "other"     => "6"
            _           => "0"
        }
        [$"n.NameType = ($num)"]
    } else { [] }

    let alt_where  = if $alternate { ["n.IsPrimary = 0"] } else { [] }
    let rin_where  = if not ($rin | is-empty) { [$"n.OwnerID = ($rin)"] } else { [] }

    let where_clause = (["1=1"] | append $type_where | append $alt_where | append $rin_where | str join " AND ")

    let base_sql = "SELECT
        n.NameID,
        n.OwnerID as RIN,
        n.Surname COLLATE NOCASE as Surname,
        n.Given COLLATE NOCASE as Given,
        CASE n.NameType
            WHEN 0 THEN 'AKA'
            WHEN 1 THEN 'Birth'
            WHEN 2 THEN 'Immigrant'
            WHEN 3 THEN 'Maiden'
            WHEN 4 THEN 'Married'
            WHEN 5 THEN 'Nickname'
            WHEN 6 THEN 'Other'
            ELSE 'Unknown'
        END as NameType,
        n.IsPrimary,
        n.BirthYear,
        n.DeathYear,
        COALESCE(STRFTIME(DATETIME(n.UTCModDate + 2415018.5)) || ' +0000', '') AS LastUpdateUTC
    FROM NameTable n"

    let sqlquery = [$base_sql " WHERE " $where_clause " ORDER BY n.OwnerID, n.IsPrimary DESC, n.NameType"] | str join

    print "List of name records."
    let result = open $env.rmdb | query db $sqlquery
        | insert LastUpdate {|row| if ($row.LastUpdateUTC | is-empty) { "" } else { $row.LastUpdateUTC | date to-timezone local | format date "%Y-%m-%d %H:%M:%S" } }
        | reject LastUpdateUTC
    if $mod_date { $result | startat1 } else { $result | reject LastUpdate | startat1 }
}
