
# Default Terminal is super ugly and hard to read. Suggest modest improvements.
#   Adjust Terminal Font Size to 18 pt
#   make homebrew profile default, but its all green, better available?

# To download and run this script
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh)"


# Define color codes
green=$(tput setaf 2)

# Install Homebrew
echo "Installing Homebrew."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "${green}Homebrew install complete.${reset}"
sleep 3s

# Add Homebrew to Path
echo "Adding Homebrew to Path, per Guidance Above."
echo >> $HOME/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "${green}Homebrew Update to Path complete.${reset}"
sleep 3s

# Install Nushell
echo "Installing Nushell."
brew install nushell
echo "${green}Nushell install complete.${reset}"
source ~/.zprofile
sleep 3s

# Install RMGC
echo "Downloading RMGC installer."
nu rmgc-install-MacOS.nu

echo
