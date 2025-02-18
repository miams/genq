RMGC is an open-source, third-party [RootsMagic](https://rootsmagic.com/) reporting engine for use in the terminal. RMGC is designed to let you quickly and easily pull structured geneaogy data from your RootsMagic SQLite database. RMGC is built on top of [Nushell](https://www.nushell.sh/), a new kind of shell for Windows, MacOS and Linux. 

## Nushell
Unlike traditional shells such as bash, zsh or Powershell; Nushell's foundational philosophy centered on processing structured data.  The NuShell scripting language borrow's UNIX's process piping (the " | " symbol) concept and makes it a core construct used virtually every command. This makes for scripts that are easy to read and debug but still very powerful and effecient at processing data.  Nushell is built using Rust, a modern, fast systems programming language many view as destined to replace C+ as the most commonly used systems language.

## SQL
At its core, RMGC uses SQL (Structured Queried Language) to query RootsMagics SQLite database. In most cases, RMGC removes the need to deal with SQL's complexity.  RMGC leverages its library of internal and third-party SQL queries to extract data. From there, you are able to access a rich set of Nushell commands to personalize your data analysis and tabular reports to your individual needs.

## Read-Only 
**RMGC is not designed for making data updates to the RootsMagic database.**  This approach is based on the belief that nothing is more important the preserving the data integrity of potentially years of genealogy research.  All queries run against a copy of your RootsMagic database.  With one command (syncdb) you call pull a fresh copy of your RootsMagic database.  Although no RMGC queries are designed to write to the tables and fields, some SQL queries may write temporary tables or views.  These are invisible to RootsMagic, but still have a chance of corrupting the database.  So to avoid any possible confusion, and potential loss of data, **never point RootsMagic to open RMGC's copy of the database.**

## Caveats
* Nushell is mature and powerful in the sense that has been under active development by a community of open source developers for over 5 years.  But the language still has not reached stable release phase associated with a 1.0 release.  The Nushell development team still introduces breaking changes to the code as they currently prioritize building a mondern and powerful language over stability.  I'm not aware of a published roadmap, but I suspect they will reach a 1.0 release by late 2025.

* RMGC is not in any way affiliated with RootsMagic Inc.  Additionally, they do not provide technical support for SQL access to the RootsMagic database outside of RootsMagic itself.

* Currently testing is only performed on MacOS and Windows 11, and only with RootsMagic version 10. The RootsMagic database schema has had only minor updates since version 8, so theoretically, almost all queries should work equally well with versions 8 and 9.
