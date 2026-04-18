# GenQuery Cookbook

A practical guide to getting useful genealogy data out of your RootsMagic database using GenQuery. Each recipe shows the command, explains what it does, and describes when you'd use it.

> **How to read the examples**  
> The `|` symbol is a *pipe* — it passes the output of one step into the next.  
> Breaking a pipeline across multiple lines makes it easier to read; it runs the same as one long line.  
> `--flag` options modify what a command returns. Run any command with `--help` to see all options.

---

## Contents

1. [Discovering What You Have](#1-discovering-what-you-have)
2. [People](#2-people)
3. [Events & Facts](#3-events--facts)
4. [Citations & Evidence Quality](#4-citations--evidence-quality)
5. [Sources](#5-sources)
6. [Families & Children](#6-families--children)
7. [Places & Geography](#7-places--geography)
8. [Media](#8-media)
9. [Trees & Relationships](#9-trees--relationships)
10. [Research Workflows](#10-research-workflows)
11. [Nushell Patterns for Genealogists](#11-nushell-patterns-for-genealogists)

---

## 1. Discovering What You Have

### List all GenQuery commands

Shows every available command, grouped by category. Start here when you want to know what GenQuery can do.

```nu
help commands
| reject signatures
| where category =~ genq
| sort-by category name
```

### Show help for a specific command

```nu
genq list events --help
```

### Count records in each main table

A quick census of your database — how many people, events, sources, etc.

```nu
[
    {Table: "People"       Count: (genq list people | length)}
    {Table: "Events"       Count: (genq list events | length)}
    {Table: "Families"     Count: (genq list families | length)}
    {Table: "Citations"    Count: (genq list citations | length)}
    {Table: "Sources"      Count: (genq list sources | length)}
    {Table: "Places"       Count: (genq list places | length)}
    {Table: "Media"        Count: (genq list media | length)}
]
```

### Show the RootsMagic database schema

See every table and column in your `.rmtree` file.

```nu
open $env.rmdb
| schema
| get tables
| table -e
```

---

## 2. People

### List everyone in the database

```nu
genq list people
```

### Find people by surname

```nu
genq list people
| where Surname == "Iams"
```

### Search for a surname by partial match (case-insensitive)

The `=~` operator matches anywhere in the string.

```nu
genq list people
| where Surname =~ "iam"
```

### Find people by first name

```nu
genq list people
| where Given =~ "Franklin"
```

### Find a specific person by name

```nu
genq list people
| where Surname == "Iams" and Given =~ "Franklin"
```

### Look up a person by their RIN (Record Identification Number)

Every person in RootsMagic has a unique RIN. This is the fastest lookup.

```nu
genq list people
| where RIN == 2
```

### List people with birth years in a range

```nu
genq list people
| where BirthYear >= 1850 and BirthYear <= 1900
```

### List people with no recorded birth year

```nu
genq list people
| where BirthYear == 0
```

### Count people by birth decade

Useful for understanding the time span of your research.

```nu
genq list people
| where BirthYear > 0
| insert Decade {|r| ($r.BirthYear // 10) * 10}
| group-by Decade
| transpose Decade rows
| insert Count {|r| $r.rows | length}
| reject rows
| sort-by Decade
```

### List all names including alternate and maiden names

Returns one row per name fact, so a person appears multiple times if they have alternate names.

```nu
genq list names
```

### Find a maiden name

```nu
genq list names
| where Surname == "Smith"
```

### Show how recently each person was edited

The `--mod-date` flag adds a `LastUpdate` column showing when the record was last changed in RootsMagic.

```nu
genq list people --mod-date
| sort-by LastUpdate --reverse
| first 20
```

### View all fields for a single person (vertical layout)

`transpose` flips the table so field names are on the left — useful when a row has many columns.

```nu
genq list people
| where RIN == 2
| transpose
```

---

## 3. Events & Facts

### List all events/facts

```nu
genq list events
```

### See what fact types are in your database

```nu
genq list events
| select Event
| uniq
| sort-by Event
```

### Count how often each fact type is used

```nu
genq list events
| histogram Event
```

### List all events of a specific type

```nu
genq list events
| where Event == "Birth"
```

### List events for a specific person

```nu
genq list events
| where RIN == 2
| sort-by EventDate
```

### See a person's full timeline (all facts in date order)

```nu
genq list events
| where RIN == 2
| sort-by SortDate
| select Event EventDate Description
```

### Find events that mention a keyword in the description

```nu
genq list events
| where Description =~ "Pennsylvania"
```

### List all birth events with their place names

`--place-name` joins the PlaceTable so you get the place name instead of just a numeric ID.

```nu
genq list events --place-name
| where Event == "Birth"
| where Place != ""
| sort-by Surname
| explore
```

### Browse events interactively

-  **g:** Move to the first line. 
-  **(Shift + g):** Move to the last line. 
-  **(fn + ⬇):** Page down.
-  **(fn + ⬆):** Page up.
- **:try** Filter mode
- **/** Search mode

Press `q` to quit.

```nu
genq list events
| sort-by SortDate
| explore
```

### List events sorted oldest to newest (using RM date format)

`sort-date-by` understands RootsMagic's encoded date format, including ranges and qualifiers like "about 1880".

```nu
genq list events
| sort-date-by EventDate
| select Given Surname Event EventDate
```

### Find events with no date recorded

```nu
genq list events
| where EventDate == ""
| select RIN Given Surname Event
```

### Find events recently added or changed

```nu
genq list events
| sort-by LastUpdate --reverse
| first 20
```

### Find events that have no citations (research gaps)

This is one of the most useful research tools: find facts that you haven't sourced yet.

```nu
genq list events --unsourced
| where Event == "Birth"
| sort-by Surname
```

### Count unsourced facts by type

Shows where the biggest citation gaps are in your database.

```nu
genq list events --unsourced
| histogram Event
| sort-by count --reverse
```

### List people who have an unsourced Birth event

```nu
genq list events --unsourced
| where Event == "Birth"
| select RIN Given Surname EventDate
| sort-by Surname
```

### Find people whose Death is unsourced but Birth is recorded

```nu
let sourced_births = genq list events | where Event == "Birth" | select RIN | uniq
genq list events --unsourced
| where Event == "Death"
| where RIN in $sourced_births.RIN
| select RIN Given Surname
```

---

## 4. Citations & Evidence Quality

Citations connect your facts to the sources that prove them. GenQuery exposes the full GPS (Genealogical Proof Standard) quality rating system.

**Citation quality** uses three dimensions:
| Field | Values | Meaning |
|-------|--------|---------|
| `Source` | Primary / Secondary | Was the informant present at the event? |
| `Information` | Direct / Indirect / Negative | Does the record directly state the fact? |
| `Evidence` | Original / Derivative | Is this the original record or a copy/index? |

### List all citations

```nu
genq list citations
```

### Browse citations interactively

```nu
genq list citations
| reject LinkiD CitID SrcID Uniq Sfx Pfx
| explore
```

### List citations for a specific person

```nu
genq list citations
| where RIN == 2
| select Citer SourceName Source Information Evidence
```

### Count citations per person (top 20 best-documented)

```nu
genq list citations
| select RIN Given Surname
| uniq-by -c RIN
| flatten
| move count --after RIN
| sort-by count --reverse
| first 20
```

### Count citations per person (bottom 20 least-documented)

Find the people who need more research attention.

```nu
genq list citations
| select RIN Given Surname
| uniq-by -c RIN
| flatten
| move count --after RIN
| sort-by count
| first 20
```

### List citations with GPS quality fields

The `--quality` flag decodes the 3-character quality code into readable labels. The existing `Source` column (source name) is renamed to `SourceName` to avoid confusion.

```nu
genq list citations --quality
| where RIN == 2
| select Citer SourceName Source Information Evidence
```

### List all citations with their evidence quality

```nu
genq list citations --quality
| select RIN Given Surname Citer Source Information Evidence
| sort-by Evidence Source
```

### Find citations with the highest quality evidence (Original Primary Direct)

```nu
genq list citations --quality
| where Source == "Primary" and Information == "Direct" and Evidence == "Original"
| select RIN Given Surname Citer SourceName
```

### Find citations backed only by derivative sources (indexes, transcriptions)

Derivative evidence is weaker — these facts deserve verification against original records.

```nu
genq list citations --quality
| where Evidence == "Derivative"
| select RIN Given Surname Citer SourceName
| sort-by Surname
```

### List citations for a specific event (by EventID)

First find the EventID from `genq list events`, then look up its citations.

```nu
# Step 1: find the EventID
genq list events
| where RIN == 2 and Event == "Birth"
| select EventID Event EventDate

# Step 2: look up citations for that event
genq list citations --event-id
| where EventID == 5
| select Citer SourceName
```

### See quality ratings for every event of a person

Combines EventID with quality to give a full evidence picture for one person.

```nu
genq list citations --event-id --quality
| where RIN == 2
| select EventID Citer SourceName Source Information Evidence
| sort-by EventID
```

### Audit evidence quality across a surname group

How well is the Iams family documented?

```nu
genq list citations --quality
| where Surname == "Iams"
| group-by Evidence
| transpose Evidence rows
| insert Count {|r| $r.rows | length}
| reject rows
| sort-by Count --reverse
```

### Count citations by fact type

Which fact types have the most evidence overall?

```nu
genq list citations
| histogram Citer
| sort-by count --reverse
```

---

## 5. Sources

### List all sources

```nu
genq list sources
```

### List all sources including template-based ones (with rendered citation text)

RootsMagic supports hundreds of citation templates. `--all` renders the Footnote, ShortFootnote, and Bibliography text for each.

```nu
genq list sources --all
```

### Search for sources by name

```nu
genq list sources
| where Name =~ "Census"
```

### List all census sources

```nu
genq list sources
| where Name =~ "Fed Census"
| sort-by Name
```

### Count sources by type prefix

```nu
genq list sources
| insert Type {|r|
    if ($r.Name | str starts-with "Book:") { "Book" }
    else if ($r.Name | str starts-with "Fed Census:") { "Federal Census" }
    else if ($r.Name | str starts-with "Find a Grave:") { "Find a Grave" }
    else if ($r.Name | str starts-with "Newspapers:") { "Newspaper" }
    else { "Other" }
}
| histogram Type
| sort-by count --reverse
```

### Show the most recently added sources

```nu
genq list sources --mod-date
| sort-by LastUpdate --reverse
| first 20
```

---

## 6. Families & Children

### List all families (couples)

Each row is one couple. FatherID and MotherID are their RINs.

```nu
genq list families
```

### Find families where the father appears more than once (multiple marriages)

`uniq-by -d` returns only the values that appear *more than once*.

```nu
genq list families
| reject index
| uniq-by FatherID -d
| sort-by FatherID
```

### Find families where the mother appears more than once

```nu
genq list families
| reject index
| uniq-by MotherID -d
| sort-by MotherID
```

### List children for a specific family (by MRIN)

```nu
genq list children
| where MRIN == 1
| sort-by ChildOrder
| select ChildOrder Given Surname RelFather RelMother
```

### List all children and their relationship types

`RelFather` and `RelMother` show Birth, Adopted, Step, Foster, etc.

```nu
genq list children
| where RelFather != "Birth" or RelMother != "Birth"
| select Given Surname RelFather RelMother
```

### Count children per family

```nu
genq list children
| group-by MRIN
| transpose MRIN rows
| insert ChildCount {|r| $r.rows | length}
| reject rows
| sort-by ChildCount --reverse
| first 20
```

### Find families with the most children

```nu
genq list children
| group-by MRIN
| transpose MRIN rows
| insert ChildCount {|r| $r.rows | length}
| reject rows
| sort-by ChildCount --reverse
| first 10
```

---

## 7. Places & Geography

### List all places

```nu
genq list places
```

### Search for places by name

```nu
genq list places
| where Name =~ "Pennsylvania"
```

### List places that have GPS coordinates

Geocoded places can be used for mapping and distance queries.

```nu
genq list places --coordinates
| where Latitude != 0
| select Name Latitude Longitude
```

### Find what percentage of places are geocoded

```nu
let total = genq list places | length
let geocoded = genq list places --coordinates | where Latitude != 0 | length
($geocoded / $total * 100) | math round --precision 1
| print $"($in)% of places have GPS coordinates"
```

### Calculate distances from a reference place (by PlaceID)

`genq distance-from` pipes into any table that has Latitude and Longitude columns. This shows how far each place is from a reference point.

```nu
genq list places --coordinates
| genq distance-from --place-id 1
| where Distance != null
| sort-by Distance
| first 20
| select Name Distance
```

### Find all places within 50 km of a named location

```nu
genq list places --coordinates
| genq distance-from --place-name "Pittsburgh, Allegheny, Pennsylvania, USA"
| where Distance != null and Distance <= 50
| sort-by Distance
| select Name Distance
```

### Find places within 100 miles (using miles instead of km)

```nu
genq list places --coordinates
| genq distance-from --place-name "Pittsburgh, Allegheny, Pennsylvania, USA" --unit mi
| where Distance != null and Distance <= 100
| sort-by Distance
| select Name Distance
```

### Find events that took place within 50 km of a location

Combine place distances with events for geographic research clustering.

```nu
let nearby = genq list places --coordinates
    | genq distance-from --place-name "Pittsburgh, Allegheny, Pennsylvania, USA"
    | where Distance != null and Distance <= 50
    | select PlaceID Name Distance

genq list events --place-name
| where Place != ""
| join $nearby --on Place Name
| select Given Surname Event EventDate Place Distance
| sort-by Distance
```

---

## 8. Media

### List all media files

```nu
genq list media
```

### List photos only

MediaType 0 = Image.

```nu
genq list media
| where MediaType == 0
```

### Find media with no caption

```nu
genq list media
| where Caption == ""
| select MediaID fullpath
```

### Show what percentage of media has no caption

```nu
let no_caption = genq list media | where Caption == "" | length
let total = genq list media | length
($no_caption / $total * 100) | math round --precision 1
| print $"($in)% of media has no caption"
```

### Find recently added media

```nu
genq list media --mod-date
| sort-by LastUpdate --reverse
| first 20
```

---

## 9. Trees & Relationships

### Count family trees and find the largest one

RootsMagic databases sometimes contain disconnected groups of people. This shows each distinct tree with a people count and the most-connected person (the anchor).

```nu
genq tabulate trees
```

### List all people in the same tree as a specific person

Shows every relative with their generational distance from the anchor person. `Ga` = generations up to the nearest shared ancestor; `Gb` = generations back down; `Degree` = total distance.

```nu
genq tabulate trees --rin 1
```

### Find the most distantly related people in a tree

```nu
genq tabulate trees --rin 1
| where Degree != null
| sort-by Degree --reverse
| first 10
| select Given Surname Degree
```

### List FAN club associations (Friends, Associates, Neighbors)

```nu
genq list associations
```

### Find all associations for a specific person

```nu
genq list associations
| where ID1 == 2 or ID2 == 2
| select AssocType Role1 Role2 Given1 Surname1 Given2 Surname2 Date
```

### List shared events (witnesses)

People who appear on the same document or event.

```nu
genq list witnesses
| where PersonID == 2
| select EventID RoleName Given Surname
```

---

## 10. Research Workflows

These multi-step examples combine commands to answer real research questions.

### Find all unsourced Birth events for a surname

The core research gap finder: who in your Iams line is missing a sourced birth?

```nu
genq list events --unsourced
| where Event == "Birth" and Surname == "Iams"
| select RIN Given Surname EventDate
| sort-by EventDate
```

### Evidence quality audit for a person

See every fact for a person with its citation quality, so you can identify weak evidence.

```nu
genq list citations --event-id --quality
| where RIN == 2
| select EventID Citer SourceName Source Information Evidence
| sort-by Evidence Source
```

### Find facts supported only by derivative sources

These are the most fragile entries in your database — worth checking against originals.

```nu
genq list citations --quality
| where Evidence == "Derivative"
| select RIN Given Surname Citer SourceName
| sort-by Surname Given
```

### Find people with citations but unsourced Birth events

These people have some research done, but the birth specifically lacks a source.

```nu
let cited_rins = genq list citations | select RIN | uniq
genq list events --unsourced
| where Event == "Birth"
| where RIN in $cited_rins.RIN
| select RIN Given Surname EventDate
| sort-by Surname
```

### Summary report: sourced vs unsourced births by surname prefix

```nu
let all_births = genq list events | where Event == "Birth" | select RIN Surname
let unsourced = genq list events --unsourced | where Event == "Birth" | select RIN

$all_births
| insert Unsourced {|r| ($r.RIN in $unsourced.RIN)}
| group-by Unsourced
| transpose Unsourced rows
| insert Count {|r| $r.rows | length}
| reject rows
```

### Find the top 10 most-cited sources

Which sources are you relying on the most?

```nu
genq list citations
| group-by Source
| transpose Source rows
| insert Count {|r| $r.rows | length}
| reject rows
| sort-by Count --reverse
| first 10
```

### Find people who share a census year with a specific person

Look up everyone who appears in the same census events as RIN 2.

```nu
let my_census_events = genq list events
    | where RIN == 2 and Event == "Census"
    | select EventDate Description

genq list events
| where Event == "Census"
| join $my_census_events --on EventDate
| where RIN != 2
| select RIN Given Surname EventDate
| uniq-by RIN
```

### List all people in a geographic cluster

Find everyone who has birth events within 50 km of Pittsburgh.

```nu
let nearby_places = genq list places --coordinates
    | genq distance-from --place-name "Pittsburgh, Allegheny, Pennsylvania, USA"
    | where Distance != null and Distance <= 50
    | select Name

genq list events --place-name
| where Event == "Birth" and Place != ""
| where Place in $nearby_places.Name
| select RIN Given Surname EventDate Place
| sort-by Surname
```

### Compare citation counts between two people

```nu
let rin_a = 1
let rin_b = 2

let count_a = genq list citations | where RIN == $rin_a | length
let count_b = genq list citations | where RIN == $rin_b | length

[
    {RIN: $rin_a, Citations: $count_a}
    {RIN: $rin_b, Citations: $count_b}
]
```

---

## 11. Nushell Patterns for Genealogists

These are general Nushell techniques that come up constantly when working with GenQuery data.

### Filter rows: `where`

```nu
genq list people | where Surname == "Iams"
genq list people | where BirthYear > 1850
genq list events | where Event == "Birth" and Surname == "Iams"
```

### Sort rows: `sort-by`

```nu
genq list people | sort-by Surname Given
genq list citations | sort-by count --reverse   # largest first
```

### Keep only certain columns: `select`

```nu
genq list events | select RIN Given Surname Event EventDate
```

### Remove columns you don't need: `reject`

```nu
genq list citations | reject LinkiD CitID SrcID Uniq Sfx Pfx
```

### Count rows

```nu
genq list people | length
```

### See just the first or last N rows

```nu
genq list people | first 10
genq list events | sort-by LastUpdate --reverse | last 5
```

### See all fields for one row (vertical layout)

```nu
genq list events | where EventID == 5 | transpose
```

### Count occurrences of values in a column: `histogram`

```nu
genq list events | histogram Event
genq list people | histogram BirthYear
```

### Count distinct values in a column: `uniq-by -c`

```nu
genq list citations
| uniq-by -c RIN
| sort-by count --reverse
```

### Group and count: `group-by` + `transpose`

A flexible way to count things when `histogram` isn't quite right.

```nu
genq list events
| group-by Event
| transpose Event rows
| insert Count {|r| $r.rows | length}
| reject rows
| sort-by Count --reverse
```

### Browse results interactively: `explore`

Opens a scrollable, filterable viewer. Arrow keys to navigate, `q` to quit.

```nu
genq list events | explore
```

### Save results to a variable

```nu
let my_people = genq list people | where Surname == "Iams"
$my_people | length
$my_people | where BirthYear > 1850
```

### Export results to CSV

```nu
genq list people | to csv | save people.csv
genq list citations --quality | to csv | save citations.csv
```

### Export results to JSON

```nu
genq list events | to json | save events.json
```

### Renumber rows from 1 (instead of 0)

GenQuery's `startat1` command renumbers the index column starting at 1, which matches how genealogists count.

```nu
genq list people | startat1
```
