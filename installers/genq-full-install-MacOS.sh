# Installs genq and dependencies as needed (Homebrew, Nushell)

# To download and run this script
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-full-install-MacOS.sh)"
# To just download script
#   curl -s -o "genq-full-install-MacOS.sh" "https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-full-install-MacOS.sh"

# Define color codes
green=$(tput setaf 2)
reset=$(tput sgr0)

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
  echo -e "\n"
  echo "${green}Nushell install complete.${reset}"
  source ~/.zprofile
  sleep 2s
fi


# Install GenQuery
echo "Downloading GenQuery installer."
curl -s -o "genq-install-MacOS.nu" "https://raw.githubusercontent.com/miams/genq/refs/heads/main/installers/genq-install-MacOS.nu"
nu genq-install-MacOS.nu

echo
