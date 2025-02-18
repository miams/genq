
# Default Terminal is super ugly and hard to read. Suggest modest improvements.
#   Adjust Terminal Font Size to 18 pt
#   make homebrew profile default, but its all green, better available?


# download this script via:  curl -s -o rmgc-full-install-MacOS.sh "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh"



# Install Homebrew
echo "Installing Homebrew."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "\e[32mHomebrew install complete.\e[0m"
sleep 3s

# Add Homebrew to Path
echo "Adding Homebrew to Path, per Guidance Above."
echo >> $HOME/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
echo "\e[32mHomebrew Update to Path complete.\e[0m"
sleep 3s

# Install Nushell
echo "Installing Nushell."
brew install nushell
echo "\e[32mNushell install complete.\e[0m"
sleep 3s

# Install RMGC
echo "Downloading RMGC installer."
nu rmgc-install-MacOS.nu

echo "\n"
