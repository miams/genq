This is tested on Windows 11, version 10.0.26100.0 using Nushell version 0.102 on 13-Feb-2025.

Currently, winget is not an option, even though it is mentioned in the docs.

see https://github.com/nushell/nushell/issues/14786 for more info.

https://chocolatey.org/install

https://chocolatey.org/install#individual

From Command Bar, Open "Terminal"

By default, this version of Windows comes with 3 shells,

- Powershell
- Command Prompt
- Azure Shell

We will use Powershell, which opens by default.

But we need to open PowerShell with Administrative Rights

Next to the "+" sign on the Windows Terminal tab, click the down arrow. A menu slides down showing available shells. Hover over the Windows PowerShell item, and help box appears showing "Ctrl+Click" to open as administrator.

Doing that opens an option to "Run as Administrator". Click that.

Terminal may request to make changes to your Device. Click yet.

Click on the newly opened Terminal Window, that shows a tab displaying "Administrator: Windows Pow.."

```
Get-ExecutionPolicy
```

If you don't use Powershell much, it will likely say Restricted, and we need to open its permissions to allow Administrative actions.

```
Set-ExecutionPolicy AllSigned
```

Now we install chocolatey

```
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Now install Newshell
From the same Adminstrative Rights

```
choco install nushell
```

It will ask to run and installation script, select: Y

Now that Nushell is installed, let's make it a little easier to select.

From the Terminal "Drop Down Carat", select Settings

From left menu, at bottom, select "+ a new profile"

Name:

```
Nushell
```

Command Line:

```
C:\ProgramData\chocolatey\bin\nu.exe
```

Starting Directory:

Icon:

```
C:\ProgramData\chocolatey\bin\nu.exe
```

1.  Verify your version of Windows

```
[System.Environment]: :OSVersion.Version
```

2. Winget should be installed by default, so we will proceed directly to installing Nushell

```
winget install nushell
```

a. Agree to the Source Agreement Terms: Y
