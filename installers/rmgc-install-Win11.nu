# Customize Nushell Configuration
'# Tailored Nushell Configuration '               | save $"($env.AppData)/config.nu"
echo '$env.config.buffer_editor = "notepad"'      | save --append $"($env.AppData)/nushell/config.nu" 
print ""                                          | save --append $"($env.AppData)/nushell/config.nu" 
echo '$env.config.history.file_format = "sqlite"' | save --append $"($env.AppData)/nushell/config.nu"
echo '$env.config.history.max_size = 5_000_000'   | save --append $"($env.AppData)/nushell/config.nu"
echo '$env.config.history.sync_on_enter = true"'  | save --append $"($env.AppData)/nushell/config.nu"
echo '$env.config.history.isolation = true'       | save --append $"($env.AppData)/nushell/config.nu"

# Create auto-loading config file
mkdir $"($env.AppData)/nushell/vendor/autoload"

# With fresh install we are defaulting to a demo mode. 
# Create startup config file with values for demo 
print "Configuring to use demo mode with fresh install."

'# Configuration for RMGC'                        | save $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

echo $"\n $env.rmgc-mode = 'demo' \n $env.rmdb = '($nu.home-path)/Apps/rmgc/data/pres2020.rmtree'" 
   | save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

echo $"\n $env.rmgc_sql = '($nu.home-path)/Apps/rmgc/sql/'" 
   | save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" 

echo $"\n alias syncdb = cp ($nu.home-path)/Apps/rmgc/data/originaldb/pres2020.rmtree ($nu.home-path)/Apps/rmgc/data/pres2020.rmtree" 
   | save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

echo $"\n source ($nu.home-path)/Apps/rmgc/src/source-commands.nu" 
   | save --append $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu" 

print "Configuration complete.  These are the configuration settings:"
open $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"

print $"(ansi green_bold)Nushell configuration complete.  These are the configuration settings:"
# open $"($env.AppData)/nushell/vendor/autoload/rmgc-config.nu"
print "config.nu: "
cat $"($nu.default-config-dir)/config.nu"
print "rmgc-config.nu: "
cat $"($nu.default-config-dir)/vendor/autoload/rmgc-config.nu"
print ""

print "Installing RMGC."
# create file structure
# safe to run repeatedly, it does not error if already exists
mkdir $"($nu.home-path)/Apps/rmgc/data"
mkdir $"($nu.home-path)/Apps/rmgc/sql"
mkdir $"($nu.home-path)/Apps/rmgc/src"

# Load rmgc source code
powershell -Command $"Invoke-WebRequest -Uri \"https://raw.githubusercontent.com/miams/rmgc/8d3fab75dab83b157e510b352065f152126cf6fa/src/source-commands.nu\" -OutFile $$"($nu.home-path)/Apps/rmgc/src/source-commands.nu""

# Load a sample RootsMagic database.
print "Installing sample RootsMagic database." 
powershell -Command $"Invoke-WebRequest -Uri \"https://raw.githubusercontent.com/miams/rmgc/8d3fab75dab83b157e510b352065f152126cf6fa/demo/pres2020.rmtree\" -OutFile $$"($nu.home-path)/Apps/rmgc/data/pres2020.rmtree""

# Create a copy of demo RM database so syncdb works end-to-end
mkdir $"($nu.home-path)/Apps/rmgc/data/originaldb"
cp $"($nu.home-path)/Apps/rmgc/data/pres2020.rmtree" $"($nu.home-path)/Apps/rmgc/data/originaldb/pres2020.rmtree"

print ""
print ""
print $"(ansi green_bold)Installation Complete!(ansi reset)"  
print ""
print $"Next, reload settings by closing this terminal session and starting a new Nushell terminal." 
print $"In the new window, begin having fun with RMGC by typing: (ansi default_bold)rmgc [tab key](ansi reset)."