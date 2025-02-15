> [!NOTE]
> This is tested on Windows 11, version 10.0.26100.0 using Nushell version 0.102. Last test was on 13-Feb-2025.

# Overview of Windows Installation Approach

There are a variety of ways to install Nushell. Many of the methods are targeted toward the needs software developers, using tools they regularly use. The method recommended and described here is targeted toward end users with the objectives of simplicity, and reliability.

> [!NOTE]
> Currently, winget is not an option, even though it is mentioned as one of the options in [Nushell installation documentation](https://www.nushell.sh/book/installation.html). For more information describing why, [see here](https://github.com/nushell/nushell/issues/14786).

1. Using Powershell (running as Administrator), install Chocolatey, an open-source Windows package manager.
2. Continuing with Powershell (running as Administrator), install Nushell using Chocolatey.
3. A few moments after completion of scripts, a new shell option for Nushell will appear.
4. Using Nushell, install RMGC.
5. Configure RMGC to use the installed sample RootsMagic 10 database.
6. Test RMGC and _experience delight_!
7. Reconfigure RMGC to use for real.

# Automated install

```
Set-ExecutionPolicy Unrestricted
powershell -Command Invoke-WebRequest -Uri "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-Win11.ps1" -OutFile "rmgc-full-install-Win11.ps1"
.\rmgc-full-install-Win11.ps1

```

> [!NOTE]
> Terminal will display a warning about pasting multiple lines of code simultaneously. Seletc "Paste Anyway"

# Step-by-Step Install Guide

## 1. Install Chocolatey

For reference, these are the instructions we are following.
https://chocolatey.org/install#individual

> [!NOTE]
> If you are unfamiliar with Terminal, the Terminal Title Bar in Windows 11 refers to the top section of a terminal window that displays information about the session. The plus sign ("+") opens a new default shell window, and the down carat ("⌄") opens a drop-down menu, letting you choose which specific shell to run or change other options. Multiple shell run simultaneously in separate tabs. The black tap on the dark gray title bar background is a little hard to notice initially.

By default, Windows 11 provides the three shells listed. Powershell opens by default. Completing the process outline in this document will create a fourth shell option, Nushell.

- Powershell
- Command Prompt
- Azure Shell

> [!NOTE]
> When Powershell opens, you will frequently see a message about: "Install the latest PowerShell for new features and improvements.." It is fine to ignore this. Powershell updates frequently and with features not related to typical use.

Next open a new PowerShell tab with Administrative Rights. Click on the down carat to open Terminal drop-down menu Hover over the Windows PowerShell item, and help box appears showing "Ctrl+Click" to open as administrator. Doing that opens an option to "Run as Administrator". _Click that._

Windows' User Account Control (UAC) service will ask your permission to allow Terminal to make changes to your Device. Click yes.

> [!TIP]
> You can easily copy text from the code boxes that follow by clicking icon of the top right corner of the box. That adds it to your clipboard. Then you can CTL-v in your Powershell Window to paste it.

Click on the newly opened Terminal Window, that shows a tab displaying "Administrator: Windows Pow.."

```
Get-ExecutionPolicy
```

If you don't use Powershell much, it will likely say Restricted, and we need to open its permissions to allow Administrative actions.

```
Set-ExecutionPolicy AllSigned
```

## 2. Install Nushell

Continuing with the same Powershell terminal windows using Administrative permissions:

```
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Now install Nushell
From the same Administrative Rights

```
choco install nushell
```

It will ask to run and installation script, select: Y

a. Agree to the Source Agreement Terms: Y

## 3. Open a new Terminal window with Nushell.

Wait a few seconds after the Chocolatey finishes install Nushell. Next, we want to open a new Terminal tab, a tab that uses Nushell. On the top Terminal bar, next to the plus sign, clieck the down arrow, and there should be a 4th option now there for Nushell. Click it.

## 4. Open a new Terminal window with Nushell.

## 5. Configure RMGC to use the installed sample RootsMagic 10 database.

## 6. Test RMGC.

## 7. Reconfigure RMGC to use for real.

to sync with your RootsMagic 10 database and only execute queries only of the copied database.

> [!TIP]
> If you find you like RMGC and Nushell, you can easily make it your default Terminal window. Using the Down Cart, select Settings from the drop down menu. Update the Default Profile (the first item under Startup) to use Nushell and click Save. You can still access the other types of shells at anytime, via the drop down menu.
