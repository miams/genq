# Fast tests for the RootsMagic source template interpreter.
# Label: [fast] — no database required; all inputs are hardcoded strings.

use std/testing *
use std assert
use "../src/lib/common/mod.nu" *

# ── Helpers ──────────────────────────────────────────────────────────────────

# Build a minimal SourceTable.Fields XML blob from a record of {Name: Value} pairs.
def make-fields-xml [pairs: record] {
    let field_nodes = ($pairs | transpose key val | each {|row|
        $"<Field><Name>($row.key)</Name><Value>($row.val)</Value></Field>"
    } | str join "")
    $"<?xml version=\"1.0\" encoding=\"UTF-8\"?><Root><Fields>($field_nodes)</Fields></Root>"
}

# ── Literal passthrough ───────────────────────────────────────────────────────

@test
def "fast render-template literal only" [] {
    let xml = (make-fields-xml {})
    assert equal (render-template "Hello, world." $xml) "Hello, world."
}

@test
def "fast render-template empty format string returns empty" [] {
    assert equal (render-template "" "") ""
}

# ── Field substitution ────────────────────────────────────────────────────────

@test
def "fast render-template simple field substitution" [] {
    let xml = (make-fields-xml {Author: "Smith, John" Title: "A History"})
    assert equal (render-template "[Author], <i>[Title]</i>." $xml) "Smith, John, <i>A History</i>."
}

@test
def "fast render-template unknown field rendered literally" [] {
    let xml = (make-fields-xml {})
    assert equal (render-template "[LDS]" $xml) "[LDS]"
}

@test
def "fast render-template empty field renders as empty string" [] {
    let xml = (make-fields-xml {Author: ""})
    assert equal (render-template "[Author]" $xml) ""
}

# ── Modifiers ─────────────────────────────────────────────────────────────────

@test
def "fast render-template modifier :Year extracts year" [] {
    let xml = (make-fields-xml {PubDate: "2010"})
    assert equal (render-template "[PubDate:Year]" $xml) "2010"
}

@test
def "fast render-template modifier :Year from full date string" [] {
    let xml = (make-fields-xml {AccessDate: "15 April 1942"})
    assert equal (render-template "[AccessDate:Year]" $xml) "1942"
}

@test
def "fast render-template modifier :Abbrev selects short form" [] {
    let xml = (make-fields-xml {Page: "page 23||23"})
    assert equal (render-template "[Page:Abbrev]" $xml) "23"
}

@test
def "fast render-template modifier :Abbrev falls back to full when no double-bar" [] {
    let xml = (make-fields-xml {Page: "page 23"})
    assert equal (render-template "[Page:Abbrev]" $xml) "page 23"
}

@test
def "fast render-template modifier :Caps title-cases value" [] {
    let xml = (make-fields-xml {Format: "digital images"})
    assert equal (render-template "[Format:Caps]" $xml) "Digital Images"
}

@test
def "fast render-template modifier :Lower lowercases value" [] {
    let xml = (make-fields-xml {ItemType: "Database"})
    assert equal (render-template "[ItemType:Lower]" $xml) "database"
}

@test
def "fast render-template modifier :Reverse reverses Last First name" [] {
    let xml = (make-fields-xml {Author: "Weaver, Michael E."})
    assert equal (render-template "[Author:Reverse]" $xml) "Michael E. Weaver"
}

@test
def "fast render-template modifier :Surname extracts surname" [] {
    let xml = (make-fields-xml {Author: "Weaver, Michael E."})
    assert equal (render-template "[Author:Surname]" $xml) "Weaver"
}

@test
def "fast render-template modifier :First extracts given name" [] {
    let xml = (make-fields-xml {Author: "Weaver, Michael E."})
    assert equal (render-template "[Author:First]" $xml) "Michael E."
}

@test
def "fast render-template chained modifiers :Lower:Abbrev" [] {
    let xml = (make-fields-xml {Edition: "Second Edition||2nd ed."})
    assert equal (render-template "[Edition:Lower:Abbrev]" $xml) "2nd ed."
}

@test
def "fast render-template chained modifiers :Abbrev:Caps" [] {
    let xml = (make-fields-xml {ItemType: "database||db"})
    assert equal (render-template "[ItemType:Abbrev:Caps]" $xml) "Db"
}

# ── Simple conditional suppression ───────────────────────────────────────────

@test
def "fast render-template simple conditional rendered when field present" [] {
    let xml = (make-fields-xml {Author: "Smith, John" Role: "compiler"})
    assert equal (render-template "[Author:Reverse]<, [Role]>" $xml) "John Smith, compiler"
}

@test
def "fast render-template simple conditional suppressed when field empty" [] {
    let xml = (make-fields-xml {Author: "Smith, John" Role: ""})
    assert equal (render-template "[Author:Reverse]<, [Role]>" $xml) "John Smith"
}

@test
def "fast render-template simple conditional suppressed when field absent" [] {
    let xml = (make-fields-xml {Author: "Smith, John"})
    assert equal (render-template "[Author:Reverse]<, [Role]>" $xml) "John Smith"
}

# ── Default-value conditional ─────────────────────────────────────────────────

@test
def "fast render-template defval uses field when present" [] {
    let xml = (make-fields-xml {PubPlace: "Baltimore"})
    assert equal (render-template "<[PubPlace]|N.p.>" $xml) "Baltimore"
}

@test
def "fast render-template defval uses fallback when field empty" [] {
    let xml = (make-fields-xml {PubPlace: ""})
    assert equal (render-template "<[PubPlace]|N.p.>" $xml) "N.p."
}

@test
def "fast render-template defval uses fallback when field absent" [] {
    let xml = (make-fields-xml {})
    assert equal (render-template "<[Publisher]|n.p.>" $xml) "n.p."
}

# ── Ternary conditional ────────────────────────────────────────────────────────

@test
def "fast render-template ternary takes present branch when field set" [] {
    let xml = (make-fields-xml {Title: "Guard Wars"})
    assert equal (render-template "<?[Title]|\"[Title],\"  |>" $xml --plain-text) '"Guard Wars,"'
}

@test
def "fast render-template ternary takes absent branch when field empty" [] {
    let xml = (make-fields-xml {Title: ""})
    assert equal (render-template "<?[Title]|\"[Title],\" |no title>" $xml) "no title"
}

@test
def "fast render-template ternary with no absent branch renders empty when field absent" [] {
    let xml = (make-fields-xml {})
    assert equal (render-template "<?[CreditLine]|; [CreditLine]>" $xml) ""
}

# ── Compound template (book) ──────────────────────────────────────────────────

@test
def "fast render-template book general template" [] {
    let xml = (make-fields-xml {
        Author: "Weaver, Michael E."
        Title: "Guard Wars"
        SubTitle: "the 28th Infantry Division in World War II"
        PubPlace: "Bloomington"
        Publisher: "Indiana University Press"
        PubDate: "2010"
        Page: "42"
    })
    let fmt = "[Author]<, [Role]>, <i>[Title]<: [SubTitle]></i><, [Edition:Lower:Abbrev]> (<[PubPlace]|N.p.>: <[Publisher]|n.p.>, <[PubDate]|n.d.>), [Page]."
    let result = (render-template $fmt $xml)
    assert ($result | str contains "Weaver, Michael E.")
    assert ($result | str contains "Guard Wars")
    assert ($result | str contains "Bloomington")
    assert ($result | str contains "Indiana University Press")
    assert ($result | str contains "2010")
    assert ($result | str contains "42")
    # Role is absent — no double comma
    assert not ($result | str contains ",,")
}

# ── HTML tag handling ──────────────────────────────────────────────────────────

@test
def "fast render-template html tags preserved by default" [] {
    let xml = (make-fields-xml {Title: "My Journal"})
    assert equal (render-template "<i>[Title]</i>" $xml) "<i>My Journal</i>"
}

@test
def "fast render-template html tags stripped with --plain-text" [] {
    let xml = (make-fields-xml {Title: "My Journal"})
    assert equal (render-template "<i>[Title]</i>" $xml --plain-text) "My Journal"
}

@test
def "fast render-template sc tags stripped with --plain-text" [] {
    let xml = (make-fields-xml {Name: "Some Name"})
    assert equal (render-template "<sc>[Name]</sc>" $xml --plain-text) "Some Name"
}

# ── Punctuation cleanup ────────────────────────────────────────────────────────

@test
def "fast render-template cleanup removes double comma from suppressed block" [] {
    # Role absent: "[Author], <, [Role]>" → "Smith, John," with trailing comma
    # The simple conditional ", [Role]" is suppressed when Role is empty
    let xml = (make-fields-xml {Author: "Smith, John"})
    let result = (render-template "[Author]<, [Role]>, <i>[Title]</i>." $xml)
    assert not ($result | str contains ",,")
    assert not ($result | str starts-with ",")
}

# ── DB integration smoke test ─────────────────────────────────────────────────

@test
def "db-iiams render-template book source from live db returns non-empty footnote" [] {
    let rows = (open $env.rmdb | query db "
        SELECT cast(s.Fields AS TEXT) as Fields, t.Footnote as TmplFootnote
        FROM SourceTable s
        JOIN SourceTemplateTable t ON s.TemplateID = t.TemplateID
        WHERE s.TemplateID = 14
        LIMIT 1
    ")
    if ($rows | is-empty) { return }
    let row = ($rows | first)
    let result = (render-template $row.TmplFootnote $row.Fields --plain-text)
    assert ($result | is-not-empty)
    assert not ($result | str contains ",,")
}
