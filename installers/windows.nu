
# create file structure
# safe to run repeatedly, it does not error if already exists
mkdir $"($env.USERPROFILE)/Apps/rmgc/data"
mkdir $"($env.USERPROFILE)/Apps/rmgc/sql"
mkdir $"($env.USERPROFILE)/Apps/rmgc/src"

# Load a sample RootsMagic database.
powershell -Command $"Invoke-WebRequest -Uri \"https://github.com/miams/rmgc/blob/8d3fab75dab83b157e510b352065f152126cf6fa/demo/pres2020.rmtree\" -OutFile "$env:USERPROFILE\\Apps\\rmgc\\data\\pres2020.rmtree\""

# Load rmgc source
powershell -Command $"Invoke-WebRequest -Uri \"https://github.com/miams/rmgc/blob/8d3fab75dab83b157e510b352065f152126cf6fa/src/source-commands.nu\" -OutFile "$env:USERPROFILE\\Apps\\rmgc\\src\\source-commands.nu\""

