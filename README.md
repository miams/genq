<h1 align="center">rmgc</h1>
<h3 align="center">A Terminal-based RootsMagic Reporting Engine</h3>

Execute blocks of Nushell code to query and parse RootsMagic's SQLite database (RootsMagic version 10 only) to generate tabular reports from the command line. This utility leverages Nushell's shell environment to create a quick, flexible and easy to use reporting tool.

In the examples below, all queries are filtered to the first 20 records for demonstration purposes only.

<h3 align="left">Screencast Example Queries:</h3>

Queries in screencast are filtered to the first 20 records for demonstration purposes only.

- rmgc list people | first 20 _List all people in your database_
- rmgc list sources | first 20 _List sources_
- rmgc list obits | first 20
- census 1910
- census RIN 2
- census year 1910 | where Surname == 'Iiams'
- census year 1910 | where Surname == 'Iiams' | sort-by Given

![Example of RMGC](https://github.com/miams/rmgc/blob/main/screencast/example1.mp4)

<h2 align="left">Quick Start Guide:</h2>

<h3 align="left">Requirements:</h3>

- Modern Windows (Win10 or Win11)
- Modern MacOS (Intel and M processors)
- NuShell (rmgc install this if not present)
- RootsMagic 10 (RM10, RM8 and RM9 should also work well)

<h3 align="left">Installation:</h3>

Installation is performed via installation scripts via command-line. Guides are available for [Windows](https://github.com/miams/rmgc/blob/main/docs/install_nushell_win11.md) and [MacOS](https://github.com/miams/rmgc/blob/main/docs/install_nushell_macos.md). For Windows, the installation script installs the Chocolatey package management software if not already present and uses it to install Nushell. Similarly for MacOS, the installation script installs the Homebrew package management software (if not already present) and uses it to install Nushell.

> [!CAUTION]
> Currently, there is minimal testing on the various platforms. If you are operating within the requirements above and encounter a problem, please open an [issue](https://github.com/miams/rmgc/issues).

<h3 align="left">Getting Started:</h3>

A sample RootsMagic database of the U.S. Presidents is included with installation. After installation, RMGC starts in a "demo" mode configuration where RMGC queries this database. When you are comfortable using it, you can edit the "rmgc-config.nu" file to use your RootsMagic database. A "rmgc configure" command is under development to simplify updating configurations.

> [!NOTE]
> RMGC comes with a syncdb command. This command pulls a current copy of your production RootsMagic database to an RMGC query location. RMGC is designed to never touch your production database.

<h2 align="left">More About RMGC:</h2>

Here is a full description of [rmgc](https://github.com/miams/rmgc/blob/main/docs/what_is_rmgc.md).

<h2 align="left">Updating Nushell and RMGC:</h2>

Documentation for updating Nushell and RMGC going forward is pending.
