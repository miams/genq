<h1 align="center">genq</h1>
<h3 align="center">A Terminal-based RootsMagic Reporting Engine</h3>

Execute blocks of Nushell code to query and parse RootsMagic's SQLite database (RootsMagic version 10 only) to generate tabular reports from the command line. This utility leverages Nushell's shell environment to create a quick, flexible and easy to use reporting tool.

In the examples below, all queries are filtered to the first 20 records for demonstration purposes only.

<h3 align="left">Screencast Example Queries:</h3>

Queries in screencast are filtered to the first 20 records for demonstration purposes only.

- genq list people | first 20 _List all people in your database_
- genq list sources | first 20 _List sources_
- genq list obits | first 20
- census 1910
- census RIN 2
- census year 1910 | where Surname == 'Iiams'
- census year 1910 | where Surname == 'Iiams' | sort-by Given

<h2 align="left">Example of GenQuery:</h2>

Example

<video autoplay loop style="width:250%; height: auto; position:absolute; z-index: -1;">
  <source src="https://genq.s3.us-east-1.amazonaws.com/example1.mp4" type="video/mp4" />
  <img src="https://genq.s3.us-east-1.amazonaws.com/example1.png"">
</video>

[![Example Video](https://genq.s3.us-east-1.amazonaws.com/example1.png)](https://genq.s3.us-east-1.amazonaws.com/example1.mp4)

Example

<video autoplay loop style="width:250%; height: auto; position:absolute; z-index: -1;">
  <source src="https://rmgc.s3.us-east-1.amazonaws.com/example1.mp4" type="video/mp4" />
  <img src="https://rmgc.s3.us-east-1.amazonaws.com/example1.png"">
</video>


<h2 align="left">Quick Start Guide:</h2>

<h3 align="left">Requirements:</h3>

- Modern Windows (Win10 or Win11)
- Modern MacOS (Intel and M processors)
- NuShell (genq install this if not present)
- RootsMagic 10 (RM10, RM8 and RM9 should also work well)

<h3 align="left">Installation:</h3>

Installation is performed via installation scripts via command-line. Guides are available for [Windows](https://github.com/miams/genq/blob/main/docs/install_nushell_win11.md) and [MacOS](https://github.com/miams/genq/blob/main/docs/install_nushell_macos.md). For Windows, the installation script installs the Chocolatey package management software if not already present and uses it to install Nushell. Similarly for MacOS, the installation script installs the Homebrew package management software (if not already present) and uses it to install Nushell.

> [!CAUTION]
> Currently, there is minimal testing on the various platforms. If you are operating within the requirements above and encounter a problem, please open an [issue](https://github.com/miams/genq/issues).

<h3 align="left">Getting Started:</h3>

A sample RootsMagic database of the U.S. Presidents is included with installation. After installation, GenQuery starts in a "demo" mode configuration where GenQuery queries this database. When you are comfortable using it, you can edit the "genq-config.nu" file to use your RootsMagic database. A "genq configure" command is under development to simplify updating configurations.

> [!NOTE]
> GenQuery comes with a syncdb command. This command pulls a current copy of your production RootsMagic database to an GenQuery query location. GenQuery is designed to never touch your production database.

<h2 align="left">More About GenQuery:</h2>

Here is a full description of [genq](https://github.com/miams/genq/blob/main/docs/what_is_genq.md).

<h2 align="left">Updating Nushell and GenQuery:</h2>

Documentation for updating Nushell and GenQuery going forward is pending.
