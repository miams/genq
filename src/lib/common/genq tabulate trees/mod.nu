# Identify connected components (family trees) in the genealogy database.
# Replicates RootsMagic's "Count Trees" report.
# --rin mode adds Ga, Gb, CoR columns per Gramps/RootsMagic convention:
#   Ga  = generations from anchor UP to least common ancestor
#   Gb  = generations from LCA DOWN to the person
#   CoR = coefficient of relationship (Wright, assuming full non-inbred pedigree)
@category "genq-common"
@search-terms "trees components connected subgraph disconnected"
export def "main" [
    --rin(-r): int  # List all people in the tree containing this PersonID
] {
    # Validate database connectivity before proceeding
    if not ($env.rmdb? | default "" | path exists) {
        print $"(ansi red)Error:(ansi reset) Database not found or not accessible"
        print $"Expected location: ($env.rmdb? | default 'not set')"
        print "Make sure your database is configured correctly with 'genq config'."
        return
    }

    let db = $env.rmdb

    # Create a private temp SQLite file for all working tables — never writes to the
    # user's database, so parallel test runs can't cause concurrent DDL corruption.
    # sqlite3 CLI initializes the file with valid SQLite magic bytes (empty file won't work).
    let tmp_db = (mktemp --suffix ".sqlite")
    ^sqlite3 $tmp_db "CREATE TABLE _g(x)"   # SELECT doesn't write; CREATE forces SQLite magic bytes

    # --- Read edges and persons from user's DB (read-only) ---
    let edges = (open $db | query db "
        SELECT FatherID a, MotherID b FROM FamilyTable WHERE FatherID>0 AND MotherID>0
        UNION SELECT MotherID, FatherID FROM FamilyTable WHERE FatherID>0 AND MotherID>0
        UNION SELECT f.FatherID, c.ChildID FROM FamilyTable f JOIN ChildTable c ON f.FamilyID=c.FamilyID WHERE f.FatherID>0
        UNION SELECT c.ChildID, f.FatherID FROM FamilyTable f JOIN ChildTable c ON f.FamilyID=c.FamilyID WHERE f.FatherID>0
        UNION SELECT f.MotherID, c.ChildID FROM FamilyTable f JOIN ChildTable c ON f.FamilyID=c.FamilyID WHERE f.MotherID>0
        UNION SELECT c.ChildID, f.MotherID FROM FamilyTable f JOIN ChildTable c ON f.FamilyID=c.FamilyID WHERE f.MotherID>0
    ")
    let persons = (open $db | query db "SELECT PersonID AS node, PersonID AS root FROM PersonTable")

    # --- Create working tables in temp DB and load data via JSON ---
    open $tmp_db | query db "CREATE TABLE _genq_e (a INTEGER NOT NULL, b INTEGER NOT NULL)"
    open $tmp_db | query db "CREATE TABLE _genq_c (node INTEGER NOT NULL, root INTEGER NOT NULL)"

    if ($edges | length) > 0 {
        let ej = ($edges | to json)
        open $tmp_db | query db ("INSERT INTO _genq_e (a, b) SELECT json_extract(value,'$.a'), json_extract(value,'$.b') FROM json_each('" + $ej + "')")
    }
    if ($persons | length) > 0 {
        let pj = ($persons | to json)
        open $tmp_db | query db ("INSERT INTO _genq_c (node, root) SELECT json_extract(value,'$.node'), json_extract(value,'$.root') FROM json_each('" + $pj + "')")
    }

    open $tmp_db | query db "CREATE INDEX _genq_ea ON _genq_e(a)"
    open $tmp_db | query db "CREATE INDEX _genq_eb ON _genq_e(b)"
    open $tmp_db | query db "CREATE INDEX _genq_cn ON _genq_c(node)"

    # --- Label propagation: iterate until convergence ---
    # (all queries against tiny temp DB — fast open/close overhead)
    let sql_update = "UPDATE _genq_c SET root = (SELECT MIN(c2.root) FROM _genq_c c2 JOIN _genq_e e ON c2.node = e.a WHERE e.b = _genq_c.node AND c2.root < _genq_c.root) WHERE EXISTS (SELECT 1 FROM _genq_c c2 JOIN _genq_e e ON c2.node = e.a WHERE e.b = _genq_c.node AND c2.root < _genq_c.root)"
    let sql_check  = "SELECT COUNT(*) AS n FROM _genq_c c WHERE EXISTS (SELECT 1 FROM _genq_c c2 JOIN _genq_e e ON c2.node = e.a WHERE e.b = c.node AND c2.root < c.root)"
    mut changed = 1
    while $changed > 0 {
        open $tmp_db | query db $sql_update
        $changed = (open $tmp_db | query db $sql_check | get n | first)
    }

    # --- Query results (labels in tmp_db, names/details in user's DB) ---
    let result = if ($rin | is-not-empty) {
        let anchor = ($rin | into string)
        let target_root = (open $tmp_db | query db ("SELECT root FROM _genq_c WHERE node = " + $anchor) | get root | first)
        let target_root_str = ($target_root | into string)
        let member_ids = (open $tmp_db | query db ("SELECT node FROM _genq_c WHERE root = " + $target_root_str) | get node | str join ",")

        # --- Load directed parent-child edges for relationship BFS ---
        # These separate parent↑ and child↓ edges from the undirected/spouse _genq_e table.
        let par_edges = (open $db | query db "
            SELECT c.ChildID AS child, f.FatherID AS parent
            FROM ChildTable c JOIN FamilyTable f ON f.FamilyID = c.FamilyID WHERE f.FatherID > 0
            UNION
            SELECT c.ChildID, f.MotherID
            FROM ChildTable c JOIN FamilyTable f ON f.FamilyID = c.FamilyID WHERE f.MotherID > 0
        ")

        open $tmp_db | query db "CREATE TABLE _genq_par (child INTEGER NOT NULL, parent INTEGER NOT NULL)"
        open $tmp_db | query db "CREATE TABLE _genq_chi (parent INTEGER NOT NULL, child INTEGER NOT NULL)"

        if ($par_edges | length) > 0 {
            let pej = ($par_edges | to json)
            open $tmp_db | query db ("INSERT INTO _genq_par (child, parent) SELECT json_extract(value,'$.child'), json_extract(value,'$.parent') FROM json_each('" + $pej + "')")
            open $tmp_db | query db ("INSERT INTO _genq_chi (parent, child) SELECT json_extract(value,'$.parent'), json_extract(value,'$.child') FROM json_each('" + $pej + "')")
        }

        open $tmp_db | query db "CREATE INDEX _genq_par_c ON _genq_par(child)"
        open $tmp_db | query db "CREATE INDEX _genq_chi_p ON _genq_chi(parent)"

        # --- BFS from anchor: compute (total, gen) for every blood relative ---
        # Tracks two quantities simultaneously:
        #   total = Ga + Gb  (total generation hops — minimized by BFS)
        #   gen   = Ga - Gb  (signed generation offset: positive=older, negative=younger)
        # Up hop (child→parent): total+1, gen+1
        # Down hop (parent→child): total+1, gen-1
        # Recovery: Ga = (total + gen) / 2,  Gb = (total - gen) / 2
        #
        # BFS expands level-by-level (WHERE r.total = $level) so that each node
        # is first reached at the minimum total distance from the anchor.
        # Persons not reached (spouses, married-in) get NULL Ga/Gb, CoR = 0.0.
        open $tmp_db | query db "CREATE TABLE _genq_rel (node INTEGER PRIMARY KEY, total INTEGER NOT NULL, gen INTEGER NOT NULL)"
        open $tmp_db | query db ("INSERT INTO _genq_rel VALUES (" + $anchor + ", 0, 0)")

        mut level = 0
        mut new_nodes = 1
        while $new_nodes > 0 {
            let lv = ($level | into string)
            let nl = ($level + 1 | into string)
            open $tmp_db | query db ("INSERT OR IGNORE INTO _genq_rel (node, total, gen) SELECT p.parent, r.total + 1, r.gen + 1 FROM _genq_rel r JOIN _genq_par p ON p.child = r.node WHERE r.total = " + $lv + " AND NOT EXISTS (SELECT 1 FROM _genq_rel x WHERE x.node = p.parent)")
            open $tmp_db | query db ("INSERT OR IGNORE INTO _genq_rel (node, total, gen) SELECT c.child, r.total + 1, r.gen - 1 FROM _genq_rel r JOIN _genq_chi c ON c.parent = r.node WHERE r.total = " + $lv + " AND NOT EXISTS (SELECT 1 FROM _genq_rel x WHERE x.node = c.child)")
            $new_nodes = (open $tmp_db | query db ("SELECT COUNT(*) AS n FROM _genq_rel WHERE total = " + $nl) | get n | first)
            $level = $level + 1
        }

        # Pull Ga/Gb for all tree members — blood relatives from _genq_rel, spouses get NULL
        let rel_data = (open $tmp_db | query db ("
            SELECT c.node AS RIN,
                CASE WHEN r.node IS NULL THEN NULL ELSE (r.total + r.gen) / 2 END AS Ga,
                CASE WHEN r.node IS NULL THEN NULL ELSE (r.total - r.gen) / 2 END AS Gb
            FROM _genq_c c
            LEFT JOIN _genq_rel r ON r.node = c.node
            WHERE c.root = " + $target_root_str))

        let demo_data = (open $db | query db ("
            SELECT n.OwnerID AS RIN, n.Given COLLATE NOCASE AS Given,
                   n.Surname COLLATE NOCASE AS Surname,
                   CASE WHEN p.Sex = 1 THEN 'F' ELSE 'M' END AS Sex,
                   n.BirthYear, n.DeathYear
            FROM NameTable n JOIN PersonTable p ON n.OwnerID = p.PersonID
            WHERE n.IsPrimary = 1 AND n.OwnerID IN (" + $member_ids + ")
            ORDER BY n.OwnerID"))

        # Degree = civil law degree of consanguinity = Ga + Gb.
        # Null for spouses (no blood path to anchor).
        # Examples: parent/child=1, siblings=2, 1st cousins=4, 12th cousins=26.
        $demo_data | join $rel_data RIN
            | insert Degree {|row| if ($row.Ga | is-empty) { null } else { $row.Ga + $row.Gb } }
            | select RIN Given Surname Sex BirthYear DeathYear Ga Gb Degree
    } else {
        let root_counts = (open $tmp_db | query db "SELECT root AS RIN, COUNT(*) AS Count FROM _genq_c GROUP BY root ORDER BY Count DESC")
        let root_ids = ($root_counts | get RIN | str join ",")
        let root_names = (open $db | query db ("
            SELECT OwnerID AS RIN, Given COLLATE NOCASE AS Given, Surname COLLATE NOCASE AS Surname
            FROM NameTable WHERE IsPrimary = 1 AND OwnerID IN (" + $root_ids + ")
        "))
        $root_counts | join $root_names RIN | select RIN Given Surname Count | sort-by Count --reverse
    }

    try { rm -f $tmp_db }

    $result | startat1
}
