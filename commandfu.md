# Favorite Commands

**Citation Count by Person**
List people by how many citations they have.  
`rmgc list citations | select RIN Givens Surname | uniq-by -c RIN | flatten | move count --after RIN | sort-by count --reverse | startat1`

Browse through citations
`rmgc list citations | reject LinkiD CitID SrcID Uniq Sfx Pfx | explore`

List citations for an individual
`rmgc list citations | reject LinkiD CitID SrcID Uniq Sfx Pfx | where RIN ==2`

List Families where Father has multiple wives.
`rmgc list families | reject index | uniq-by FatherID -d | startat1`

Event/Fact - Frequency of type used.
`rmgc list events | histogram Name`

Footnote
`rmgc list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.0.content.1.content.content.0`

Short Footnote
`rmgc list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.1.content.1.content.content.0`

Source
`rmgc list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.2.content.1.content.content.0`

List frequency of variations of Iams name.
`$env.SurnameGroup | enumerate | par-each { |surname| rmgc list people | where Surname == $surname.item} | flatten | histogram Surname`

List record number 100 and display vertically to see all data
`rmgc list citations | range 100..100 | transpose`
