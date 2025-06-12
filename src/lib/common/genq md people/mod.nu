# Export Obsidian markdown person files.
#
# Generates Obsidian-compatible markdown files for genealogy persons from RootsMagic database.
# Creates files with YAML frontmatter containing birth/death events, parents, and children.
@category "genq-common"
@search-terms "Markdown, Obsidian"
@example 'Generate markdown for person' {'genq md people 1575 --gens 2'}
export def main [
    rin?:int                # Person ID (RIN) to generate markdown for
    --gens:int = 1          # Number of generations to include (0-3)
    --out-dir:string = "./vault"  # Output directory for markdown files
] {
    use rmdate
    
    # Show help if no RIN provided
    if ($rin | is-empty) {
        print "Export Obsidian markdown person files."
        print ""
        print "Generates Obsidian-compatible markdown files for genealogy persons from RootsMagic database."
        print "Creates files with YAML frontmatter containing birth/death events, parents, and children."
        print ""
        print $"(ansi green_bold)Usage(ansi reset):"
        print "  > genq md people <rin> {flags}"
        print ""
        print $"(ansi green_bold)Flags(ansi reset):"
        print ""
        print "  --gens: <int> - Number of generations to include (0-3) (default: 1)"
        print "  --out-dir: <string> - Output directory for markdown files (default: ./vault)"
        print "  -h, --help - Display the help message for this command"
        print ""
        print $"(ansi green_bold)Parameters(ansi reset):"
        print ""
        print "  rin: <int> Person ID (RIN) to generate markdown for"
        print ""
        print $"(ansi green_bold)Examples(ansi reset):"
        print "  Generate markdown for person"
        print "  > genq md people 1575 --gens 2"
        return
    }
    
    if $gens < 0 or $gens > 3 {
        error make {msg: "gens must be 0-3"}
    }

    let sql_path = [$env.genq_sql, "person_tree_rm10.sql"] | path join
    let sqlquery = (open $sql_path)
    
    let people = open $env.rmdb | query db $sqlquery -p {starting: $rin, max_depth: $gens}
    | each {|row|
        let fname  = $"($row.Surname), ($row.Given) \(RIN ($row.PersonID)\).md"
        $row
        | upsert FileName $fname
        | upsert WikiLink $"[[$fname|($row.Given) ($row.Surname)]]"
        | upsert Birth (if $row.BirthYear != null { $"($row.BirthYear)" } else { "" })
        | upsert Death (if $row.DeathYear != null { $"($row.DeathYear)" } else { "" })
    }

    let linkmap = ($people | reduce -f {} {|it acc|
        $acc | upsert ($it.PersonID | into string) $it.WikiLink
    })

    # helper to pull relation text per neighbour
    def rel_text [code] {
        match $code {
            'parent'  => 'Parent',
            'child'   => 'Child',
            'spouse'  => 'Spouse',
            _         => 'Relative'
        }
    }

    # Process the focus person (there should be only one "self" record)  
    let me = ($people | where RelCode == "self" | first)
    
    let rels = (
        $people
        | where RelCode != 'self'
        | each {|r|
            $"* **((rel_text $r.RelCode))**: (($linkmap | get ($r.PersonID | into string)))"
        }
        | str join "\n"
    )

        # Get birth and death event details for this person
        let birth_event = open $env.rmdb | query db "
            SELECT e.Date, p.Name as Location, e.Note 
            FROM EventTable e 
            LEFT JOIN PlaceTable p ON p.PlaceID = e.PlaceID 
            WHERE e.OwnerID = ? AND e.EventType = 1
            ORDER BY e.SortDate LIMIT 1
        " -p [$me.PersonID] | get 0?
        
        let death_event = open $env.rmdb | query db "
            SELECT e.Date, p.Name as Location, e.Note 
            FROM EventTable e 
            LEFT JOIN PlaceTable p ON p.PlaceID = e.PlaceID 
            WHERE e.OwnerID = ? AND e.EventType = 2
            ORDER BY e.SortDate LIMIT 1
        " -p [$me.PersonID] | get 0?

        let yaml_block = {
            type: "person"
            rin: $me.PersonID
            status: "confirmed"
            birth: (if ($birth_event | is-empty) { null } else { {
                date: (if ($birth_event.Date? | is-empty) { $me.BirthYear } else { (rmdate $birth_event.Date --format 3).FormattedDate.0 })
                location: ($birth_event.Location? | default "")
                note: ($birth_event.Note? | default "")
            } })
            death: (if ($death_event | is-empty) { null } else { {
                date: (if ($death_event.Date? | is-empty) { $me.DeathYear } else { (rmdate $death_event.Date --format 3).FormattedDate.0 })
                location: ($death_event.Location? | default "")
                note: ($death_event.Note? | default "")
            } })
        }

    # Get parents (father first, then mother)
    let parents = ($people 
    | where RelCode == "parent"
    | each {|p| 
        let person_sex = (open $env.rmdb | query db "SELECT Sex FROM PersonTable WHERE PersonID = ?" -p [$p.PersonID] | get 0?.Sex | default 1)
        {person: $p, sex: $person_sex}
    }
    | sort-by sex  # 0 = male (father), 1 = female (mother)
    | each {|item| $"[[Person - ($item.person.Given) ($item.person.Surname) \(RIN($item.person.PersonID)\)]]"})

    # Get children ordered by birth year
    let children = ($people 
    | where RelCode == "child" 
    | sort-by BirthYear
    | each {|c| $"[[Person - ($c.Given) ($c.Surname) \(RIN($c.PersonID)\)]]"})

    # Add parents and children to yaml_block
    let yaml_block = $yaml_block | upsert parents $parents | upsert children $children

    let body = $"\n# ($me.Given) ($me.Surname)\n\n## Notes\n\n"
    let dest = $"($out_dir)/People/($me.FileName)"
    mkdir ($dest | path dirname)
    (
        $"---\n" + ($yaml_block | to yaml) + $"---\n" + $body
    ) | save --force $dest

    $"Wrote 1 Markdown file to ($out_dir)/People"
}