# Commandfu (GenQ + NuShell) Cheatsheet

A grab-bag of handy **GenQ** commands, formatted to be easy to skim in the terminal with **glow**.

> **Tip:** These examples are written as **NuShell pipelines**. Keeping each stage on its own line makes them way easier to read (and still runnable).

---

## Contents

- [Discovery & help](#discovery--help)
- [Citations](#citations)
- [Families](#families)
- [Events & facts](#events--facts)
- [Sources](#sources)
- [People & names](#people--names)
- [Database / schema](#database--schema)

---

## Discovery & help

### List available `genq` commands

```nu
help commands
| reject signatures
| where category =~ genq
| sort-by category name
| explore
```

---

## Citations

### Citation count by person (top 20)

List the **20** people with the most citations.

```nu
genq list citations
| select RIN Givens Surname
| uniq-by -c RIN
| flatten
| move count --after RIN
| sort-by count --reverse
| startat1
| first 20
```

### Browse through citations (interactive)

```nu
genq list citations
| reject LinkiD CitID SrcID Uniq Sfx Pfx
| explore
```

### List citations for an individual (by RIN)

Example: `RIN == 2`

```nu
genq list citations
| reject LinkiD CitID SrcID Uniq Sfx Pfx
| where RIN == 2
```

### Show record number `N` vertically (see all fields)

Example: show record **100**.

```nu
genq list citations
| slice 100..100
| transpose
```

---

## Families

### Families where Father has multiple wives

`-d` returns values that occur more than once.

```nu
genq list families
| reject index
| uniq-by FatherID -d
| startat1
```

---

## Events & facts

### Event/Fact frequency by type

```nu
genq list events
| histogram Event
```

### US Presidents (ordered list)

```nu
genq list events
| where Event == Occupation
| where Description =~ "US President"
| sort-by Description -n
```

### People who have Occupations/Titles listed

```nu
genq list events
| where Event == Occupation
| startat1
```

### Unique Event/Fact types

```nu
genq list events
| uniq-by Event
| sort-by Event
| startat1
```

### Explore event dates (range / extremes)

```nu
genq list events
| reject LastUpdate EventID
| sort-date-by EventDate
| startat1
| explore
```

### Washington family (people count via “Reference No” pattern)

```nu
genq list events
| reject LastUpdate EventID
| where Event == "Reference No"
| where Description =~ "Washington-"
| sort-by Description -n
| startat1
```

---

## Sources

The next few commands pull specific “chunks” out of source XML fields.  
This list all sources of type `Book:`.

### Footnote

```nu
open $env.rmdb | query db "
     SELECT
       SourceID as SrcID,
       Name as SourceName,
       cast(Fields AS TEXT) as Fields
     FROM SourceTable
     WHERE TemplateID = 0
   "
   | where SourceName =~ 'Book:'
   | each {|row|
       {
         SrcID: $row.SrcID
         SourceName: $row.SourceName
         Footnote: ($row.Fields | from xml | get content.0.content.0.content.1.content.content.0)
       }
   } | sort-by Footnote | explore
```

### Short footnote

```nu
open $env.rmdb | query db "
     SELECT
       SourceID as SrcID,
       Name as SourceName,
       cast(Fields AS TEXT) as Fields
     FROM SourceTable
     WHERE TemplateID = 0
   "
   | where SourceName =~ 'Book:'
   | each {|row|
       {
         SrcID: $row.SrcID
         SourceName: $row.SourceName
         ShortFootnote: ($row.Fields | from xml | get content.0.content.1.content.1.content.content.0)
       }
   } | sort-by ShortFootnote | explore
```

### Bibliography

```nu
open $env.rmdb | query db "
     SELECT
       SourceID as SrcID,
       Name as SourceName,
       cast(Fields AS TEXT) as Fields
     FROM SourceTable
     WHERE TemplateID = 0
   "
   | where SourceName =~ 'Book:'
   | each {|row|
       {
         SrcID: $row.SrcID
         SourceName: $row.SourceName
         Bibliography: ($row.Fields | from xml | get content.0.content.2.content.1.content.content.0)
       }
   } | sort-by Bibliography | explore
```

---

## People & names

### Frequency of surname variations (example: Iams)

This assumes you have an env var like `$env.SurnameGroup` containing a list of surnames to check.

```nu
$env.SurnameGroup
| enumerate
| par-each { |surname|
    genq list people
    | where Surname == $surname.item
  }
| flatten
| histogram Surname
```

---

## Database / schema

### Show the Rootsmagic database schema

```nu
open .\Apps\genq\data\pres2025.rmtree
| schema
| get tables
| table -e
```