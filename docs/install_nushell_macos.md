> [!NOTE]
> This is tested on MacOS Sequoia, version 15.3.1 using Nushell version 0.102. Last test was on 18-Feb-2025.

# Overview of MacOS Installation Approach

Installation is automated, requiring only running a single script from the MacOS terminal. Detailed instructions follow describing exactly how to do that, even if you've never used the terminal. For transparency, this is summary of the software installed via the script (genq-full-install-MacOS.sh).

- Homebrew. This package management software widely used by Mac user community. If you already have it, the script will use it, instead of downloading a new copy.
- Nushell. Installed via Homebrew.
- GenQuery. This software runs in your home directory under ~/Apps/genq. This location was chosen because the scripts are designed to be edited and tailored by you, to meet your own genealogy research goals.

# Step-by-Step Install Guide

From the Launchpad, open Terminal

> [!TIP]
> If you find the text in Terminal hard to read, here is a way to improve it.
>
> 1.  In the Terminal menu bar, select Terminal | Settings | Profiles
> 2.  Select Pro profile
> 3.  At the bottom of the list of profiles, click "Default" button.
> 4.  Change font size to 18 (don't change font style)
> 5.  Close the Terminal application and restart to use the new default settings.

Next: Copy and paste the text below into the terminal window.

> [!TIP]
> You can easily copy text from the code boxes that follow by clicking icon of the top right corner of the box. That adds it to your clipboard. Then you can CTL-v in your Powershell Window to paste it.

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-full-install-MacOS.sh)"

```

## Allow the script to run

The script will pause with "Checking for `sudo` access (which may request your password).." Enter your password of the username you use to log into MacOS.

As the script prepares to install Homebrew, there will be a pause as it asks you to press RETURN/ENTER to continue or any other key to abort.

## Get a cup of coffee..

From there, the script will run through till completion without interruptions. If you don't already have Homebrew, the entire script will take about 2 minutes to run.

- Homebrew (package manager)
- Nushell (installed via Homebrew)
- GenQuery
  - GenQuery main program
  - a custom user extension
  - RootsMagic US Presidents database
  - Initial configuration using demo mode

## After Install

1. Close out your terminal session.
2. Open a new terminal session.
3. Run: nu
4. Run your favorite genq commands.
   - help genq <font color="green"># a great place to start</font>
   - genq list people <font color="green"># a fun first command</font>
   - genq list events <font color="green"># show your RootsMagic friends what you can do</font>

```
help genq <font color="green"># a great place to start</font>
genq list people <font color="green"># a fun first command</font>
genq list events <font color="green"># show your RootsMagic friends what you can do</font>
```

# FAQ

1. Why are "sudo" admin privileges required to run the install script if GenQuery is installed only in my home directory?  
   Answer: "sudo" is required to install Homebrew.

2. How do I configure GenQuery to use my RootsMagic database?  
   Answer:

3. This is great. What are all the out-of-the-box commands I can run?  
   Answer:

4. This is awesome. What else you use recommend to improve the GenQuery user experience?  
   Answer: [Ghostty](https://ghostty.org/) is a wonderful replacement for Apple's default Terminal program.
