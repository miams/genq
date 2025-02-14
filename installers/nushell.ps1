# This script must be run in Powershell as Administrative user.
# Run these three commands first to enable script execution, download this file, and run this file.

# Set-ExecutionPolicy Unrestricted
# powershell -Command Invoke-WebRequest -Uri "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/nushell.ps1" -OutFile "rmgc-full-install-Win11.ps1"
# rmgc-full-install-Win11.ps1


# Permit Powershell to software.
Set-ExecutionPolicy AllSigned

# Install Choco
Write-Host "Installing Chocolatey Package Manager."
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
Write-Host "Chocolatey install complete." -ForegroundColor Green

# Install Nushell
Write-Host "Installing Nushell."
choco install nushell -y
Write-Host "Nushell install complete." -ForegroundColor Green

# Install RMGC
Write-Host "Downloading RMGC installer."
powershell -Command Invoke-WebRequest -Uri "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/windows.nu" -OutFile "rmgc-install-Win11.nu"
Write-Host "Installing RMGC"
nu rmgc-install-Win11.nu

Write-Host "Okay to clean up by deleting install scripts?."

# This is erroring
# Set-ExecutionPolicy Restricted

