
# Default Terminal is super ugly and hard to read. Suggest modest improvements.
#   Adjust Terminal Font Size to 18 pt
#   make homebrew profile default, but its all green, better available?

# Install Homebrew
print "Installing Homebrew."
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
print "\e[32mHomebrew install complete.\e[0m"
sleep 3

# Add Homebrew to Path
print "Adding Homebrew to Path, per Guidance Above."
echo >> $HOME/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
print "\e[32mHomebrew Update to Path complete.\e[0m"
sleep 3

# Install Nushell
print "Installing Nushell."
brew install nushell
print "\e[32mNushell install complete.\e[0m"
sleep 3

# Install RMGC
print "Downloading RMGC installer."
curl -s -o  rmgc-install-MacOS.nu "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/installers/rmgc-full-install-MacOS.sh"
print
nu rmgc-install-MacOS.nu

