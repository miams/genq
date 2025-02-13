<h1 align="center">rmgc</h1>
<h3 align="center">A Terminal-based RootsMagic Reporting Engine</h3>

Execute blocks of Nushell code to query and parse RootsMagic's SQLite database (RootsMagic version 10 only) to generate tabular reports from the command line. This utility leverages Nushell's shell environment to create a quick, flexible and easy to use reporting tool.

In the examples below, all queries are filtered to the first 20 records for demonstration purposes only.

- rmgc list people | first 20 _List all people in your database_
- rmgc list sources | first 20 _List sources_
- rmgc list obits | first 20
- census 1910
- census RIN 2
- census year 1910 | where Surname == 'Iiams'
- census year 1910 | where Surname == 'Iiams' | sort-by Given

![Example of RMGC](https://github.com/miams/rmgc/blob/main/screencast/example1.gif)
