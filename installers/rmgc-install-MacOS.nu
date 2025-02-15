# CONVERT to MACOS

# Easy reference where configs are stored following Macos standards
# echo $nu

print "Installing RMGC."
# create file structure
# safe to run repeatedly, it does not error if already exists

mkdir $"($nu.home-path)/Apps/rmgc/data"
mkdir $"($nu.home-path)/Apps/rmgc/sql"
mkdir $"($nu.home-path)/Apps/rmgc/src"

# Load rmgc source code
curl -s -o  $"($nu.home-path)/Apps/rmgc/src/source-commands.nu" "https://raw.githubusercontent.com/miams/rmgc/refs/heads/main/src/source-commands.nu"

# Create auto-loading config file
mkdir $"($env.AppData)/nushell/vendor/autoload"

# Load a sample RootsMagic database.
print "Installing sample RootsMagic database." 
powershell -Command $"Invoke-WebRequest -Uri \"https://raw.githubusercontent.com/miams/rmgc/8d3fab75dab83b157e510b352065f152126cf6fa/demo/pres2020.rmtree\" -OutFile "$env:USERPROFILE\\Apps\\rmgc\\data\\pres2020.rmtree\""

# With fresh install we are defaulting to a demo mode. 
# Create startup config file with values for demo 
print "Configuring to use demo mode with fresh install."

'# Configuration for RMGC' | save $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

echo $"\n $env.rmgc-mode = 'demo' \n $env.rmdb = '($env.USERPROFILE)/Apps/rmgc/data/pres2020.rmtree'" | tee { save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" }

echo $"\n $env.rmgc_sql = '($env.USERPROFILE)/Apps/rmgc/sql/'" | tee { save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" }

echo $"\n alias syncdb = cp ($env.USERPROFILE)/Apps/rmgc/data/originaldb/pres2020.rmtree ($env.USERPROFILE)/Apps/rmgc/data/pres2020.rmtree" | tee { save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" }

echo $"\n source ($env.USERPROFILE)/Apps/rmgc/src/source-commands.nu" | tee { save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" }

print "Configuration complete.  These are the configuration settings:"
open $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

# Create a copy of demo RM database so syncdb works end-to-end
mkdir $"($env.USERPROFILE)/Apps/rmgc/data/originaldb"
cp $"($env.USERPROFILE)/Apps/rmgc/data/pres2020.rmtree" $"($env.USERPROFILE)/Apps/rmgc/data/originaldb/pres2020.rmtree"

print
print $"(ansi green_bold)Installation Complete!(ansi reset)"  
print "Next, reload settings by closing this terminal session and starting a new Nushell terminal. In the new window, begin having fun with RMGC by typing: (ansi white_bold)rmgc [tab key](ansi reset)" 