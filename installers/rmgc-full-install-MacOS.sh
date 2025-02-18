# Installs rmgc and dependencies as needed (Homebrew, Nushell)

# To download and run this script
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh)"
# To just download script
#   curl -s -o "rmgc-full-install-MacOS.sh" "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh"

# Define color codes



# Install Homebrew if necessary
which -s brew
if [[ $? != 0 ]] ; then
    # Install Homebrew
    echo "Installing Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "${green}Homebrew install complete.${reset}"
    sleep 2s

    # Add Homebrew to Path
    echo "Adding Homebrew to Path, per Guidance Above."
    echo >> $HOME/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo "${green}Homebrew Update to Path complete.${reset}"
    sleep 2s    
else
    brew update
fi

# Install Nushell
if brew ls --versions nushell > /dev/null; then
  # Nushell already installed
  echo "$(brew ls --versions nushell) is already installed."
else
  # The package is not installed
  echo "Installing Nushell."
  brew install nushell
  echo "${green}Nushell install complete.${reset}"
  source ~/.zprofile
  sleep 2s
fi


# Install RMGC
echo "Downloading RMGC installer."
curl -s -o "rmgc-install-MacOS.nu" "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-install-MacOS.nu"
echo "Installing RMGC."
nu rmgc-install-MacOS.nu

echo
