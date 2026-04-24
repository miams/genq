# Telemetry consent management — opt-in gate and config persistence

# Check whether telemetry is currently enabled.
export def is-enabled [] {
    $env.GENQ_CONFIG?.telemetry?.enabled? | default false
}

# Write the telemetry enabled flag to the config file.
export def set-enabled [enabled: bool] {
    let genq_home = ($env.GENQ_HOME? | default $env.PWD)
    let config_path = ($genq_home | path join "config" "default.toml")

    if not ($config_path | path exists) {
        print $"(ansi red)Error:(ansi reset) Config file not found at ($config_path)"
        return
    }

    try {
        let config = (open $config_path)
        let updated = ($config | upsert telemetry.enabled $enabled)
        $updated | to toml | save --force $config_path

        # Update the live environment so subsequent checks reflect the change
        $env.GENQ_CONFIG = $updated
    } catch {|e|
        print $"(ansi red)Error:(ansi reset) Failed to update telemetry config: ($e.msg)"
    }
}

# On first run, check if [telemetry] is configured. If not, show the opt-in prompt.
# Only prompts in interactive terminals; non-interactive defaults to disabled.
export def first-run-check [] {
    # If telemetry key already exists in config, nothing to do
    if ($env.GENQ_CONFIG?.telemetry? | default null) != null {
        return
    }

    # Non-interactive terminal — silently default to disabled
    if ($env.TERM_PROGRAM? | default "" | is-empty) {
        set-enabled false
        return
    }

    print ""
    print $"(ansi cyan_bold)GenQuery Telemetry(ansi reset)"
    print ""
    print "GenQuery can share anonymous usage data to help improve the tool."
    print "No personal information, database content, or file paths are collected."
    print "Data is used only for: identifying unused features, diagnosing errors,"
    print "and measuring command performance."
    print ""

    let choice = (input "Enable telemetry? [y/N]: " | str trim | str downcase)

    if $choice == "y" or $choice == "yes" {
        set-enabled true
        print $"(ansi green)Telemetry enabled.(ansi reset) You can disable it anytime with: genq telemetry disable"
    } else {
        set-enabled false
        print $"Telemetry disabled. You can enable it later with: genq telemetry enable"
    }
    print ""
}
