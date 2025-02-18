> [!NOTE]
> This is tested on MacOS Sequoia, version 15.3.1 using Nushell version 0.102. Last test was on 18-Feb-2025.

# Overview of MacOS Installation Approach

This installer script (rmgc-full-install-MacOS.sh) uses the Homebrew package manager to install Nushell. If Homebrew is not present, it will install it.

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
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh)"

```

Allow script to run

The script will pause with "Checking for `sudo` access (which may request your password).." Enter your password of the username you use to log into MacOS.

script will list Homebrew programs and directories it will install.

script will pause with
Press RETURN/ENTER to continue or any other key to abort:

Get a cup of coffee..

```
./rmgc-full-install-MacOS.sh
```

Add it to the path

```
eval "$(/opt/homebrew/bin/brew shellenv)"
```
