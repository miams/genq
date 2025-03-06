# Favorite Commands

list genq commands

```
help commands | reject signatures | where category =~ genq | sort-by category name
```

**Citation Count by Person**  
List the 20 people with the most citations

```
genq list citations | select RIN Givens Surname | uniq-by -c RIN | flatten | move count --after RIN | sort-by count --reverse | startat1 | first 20
```

Browse through citations

```
genq list citations | reject LinkiD CitID SrcID Uniq Sfx Pfx | explore
```

List citations for an individual

```
genq list citations | reject LinkiD CitID SrcID Uniq Sfx Pfx | where RIN == 2
```

List Families where Father has multiple wives.

```
genq list families | reject index | uniq-by FatherID -d | startat1  # -d is return values that occur more than once
```

Event/Fact - Frequency of type used.

```
genq list events | histogram Event
```

Footnote

```
genq list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.0.content.1.content.content.0
```

Short Footnote

```
genq list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.1.content.1.content.content.0
```

Source

```
genq list sources | where Name =~ 'Book:' | last | $in.Fields | from xml | get content.0.content.2.content.1.content.content.0
```

List frequency of variations of Iams name.

```
$env.SurnameGroup | enumerate | par-each { |surname| genq list people | where Surname == $surname.item} | flatten | histogram Surname

```

List record number 100 and display vertically to see all data

```
genq list citations | range 100..100 | transpose
```

Show the Rootsmagic database schema

```
open .\Apps\genq\data\pres2020.rmtree | schema | get tables | table -e
```

US Presidents

```
genq list events | where Event == Occupation | where Description =~ "US President" | sort-by Description -n
```

- An ordered list of Presidents

```
genq list events | where Event == Occupation | where Description =~ "US President" | sort-by Description -n
```

- 281 people have Occupations/Titles listed.

```
genq list events | where Event == Occupation | startat1
```

- A total of 19 Event/Fact types are use.

```
genq list events | uniq-by Event | sort-by Event | startat1
```

- Event dates range from 1016 to 2018

```
genq list events | reject LastUpdate EventID | sort-by EventDate | startat1 | explore
```

- George Washington and his family comprise 111 people in the database.

```
genq list events | reject LastUpdate EventID | where Event == "Reference No" | where Description =~ "Washington-" | sort-by Description -n | startat1
```
