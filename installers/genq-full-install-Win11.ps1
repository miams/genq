# This script must be run in Powershell as Administrative user.
# Run these three commands prior to running script to enable script execution, download this file, and run this file.

#    Set-ExecutionPolicy Unrestricted
#    powershell -Command Invoke-WebRequest -Uri "https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-full-install-Win11.ps1" -OutFile "genq-full-install-Win11.ps1"
#    genq-full-install-Win11.ps1

# Process Parameters
param (
    [string[]]$d,   # Allows multiple -d parameters
    [switch]$c      # A switch parameter for the -c flag
)

# Define download URLs
$downloadUrls = @{
    "rm8"  = "https://files.rootsmagic.com/RM8/RootsMagic8Setup.exe"
    "rm9"  = "https://files.rootsmagic.com/RM9/RootsMagic9Setup.exe"
    "rm10" = "https://files.rootsmagic.com/RM10/RootsMagic10Setup.exe"
}

# Ensure $downloads is initialized
$downloads = @()

# Handle -d parameters
if ($d -contains "all") {
    Write-Host "Downloading all versions of RootsMagic (Windows 32-bit): RM8, RM9, RM10"
    $downloads = @("rm8", "rm9", "rm10")  # Override selection if -d all is used
} else {
    $downloads = $d  # Store selected downloads
}

# Process selected downloads
if ($downloads.Count -gt 0) {
    Write-Host "Downloads selected: $($downloads -join ', ')"
    
    foreach ($version in $downloads) {
        if ($downloadUrls.ContainsKey($version)) {
            $url = $downloadUrls[$version]
            $fileName = [System.IO.Path]::GetFileName($url)
            $outputPath = "$PSScriptRoot\$fileName"

            Write-Host "Downloading $version from $url..."
            
            try {
                Invoke-WebRequest -Uri $url -OutFile $outputPath
                Write-Host "Download completed: $outputPath"
            } catch {
                Write-Host "Error downloading $version from $url"
            }
        } else {
            Write-Host "Invalid version specified: $version"
        }
    }
} else {
    Write-Host "No downloads selected."
}

# Handle -c flag
if ($c) {
    Write-Host "Option -c is enabled."
    Write-Host "Installation scripts will be cleaned up after installs are completed."

    # Delete the downloaded files
    # POSSIBLE FUTURE FEATURE
    # foreach ($version in $downloads) {
    #     $fileName = [System.IO.Path]::GetFileName($downloadUrls[$version])
    #     $outputPath = "$PSScriptRoot\$fileName"

    #     if (Test-Path $outputPath) {
    #         Remove-Item $outputPath -Force
    #         Write-Host "Deleted: $outputPath"
    #     }
    # }

} else {
    Write-Host "Option -c is not enabled."
    Write-Host "Installation scripts will remain after installs are completed."
}

# Install Choco
Write-Host "Installing Chocolatey Package Manager."
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
Write-Host "Chocolatey install complete." -ForegroundColor Green

# Install Nushell
Write-Host "Installing Nushell."
choco install nushell -y
Write-Host "Nushell install complete." -ForegroundColor Green

# Install GenQuery
Write-Host "Downloading GenQuery installer."
powershell -Command Invoke-WebRequest -Uri "https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-install-Win11.nu" -OutFile "genq-install-Win11.nu"
Write-Host ""

# Create shortcut and save to programs section of menu bar
Write-Host "Creating a shortcut for GenQuery in Start Menu."
$SourceExe = "$env:USERPROFILE\AppData\Local\Programs\nu\bin\nu.exe"
$ArgumentsToSourceExe = ""
$DestinationPath = "$env:AppData\Microsoft\Windows\Start Menu\Programs\genq.lnk"
$WshShell = New-Object -COMObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()

nu genq-install-Win11.nu

Write-Host ""

# Cleanup scripts if requested.
if ($cleanup) {
    rm .\genq-full-install-Win11.ps1
    rm .\genq-install-Win11.nu
    Write-Host "Deletion of installers completed."
} else {
    Write-Host "No cleanup requested."
}
Write-Host "All tasks completed, Exiting..."
Write-Host ""
Write-Host "GenQuery is successfully installed." -ForegroundColor Green



# There are three ways to enter Nushell: 
#   1.  From within Powershell, type: nu <enter>
#   2.  From Terminal, Open the dropdown menu by clicking on the 'down carat' You will see Nushell as an option

Write-Host "Additionally, the next time you open the Terminal program, click on the 'down carat' for the drop-down menu. You will see Nushell is a new option available. If you choose, you can go into Settings from the drop-down menu, and make Nushell your default shell in Terminal." 
Write-Host ""
Write-Host "Type 'nu' at the prompt. Then begin having fun with GenQuery by typing: " -NoNewline
Write-Host "genq [tab key]" -ForegroundColor White


#Reference:

# https://files.rootsmagic.com/RM8/RootsMagic8Setup.exe
# https://files.rootsmagic.com/RM9/RootsMagic9Setup.exe
# https://files.rootsmagic.com/RM10/RootsMagic10Setup.exe

# https://files.rootsmagic.com/RM9/RootsMagic9SetupX64.exe
# https://files.rootsmagic.com/RM10/RootsMagic10SetupX64.exe

# https://files.rootsmagic.com/RM10/RootsMagic10.dmg
# https://files.rootsmagic.com/RM9/RootsMagic9.dmg
# https://files.rootsmagic.com/RM8/RootsMagic8.dmg


