**About the US Presidents database.**

Credit for the featured US Presidents genealogy database goes to Paul E. Stobbe. Thank you for this public resource.

The pres2020.rmtree database is an import of a [public GEDCOM](https://github.com/arbre-app/public-gedcoms) originally published by Paul Stobbe. I'm unable to locate a website by Mr. Stobbe about the gedcom file he created. [Reportedly](https://uniquelyyourshosting.net/genealogy/getperson.php?personID=I2184&tree=demotree&sitever=standard), this gedcom has a history of updates by various people, dating as far back as 1994.

**Observations about the data structure.**

- President families are grouped using the "Reference No" event/fact.

**GenQuery tips and tricks**

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
