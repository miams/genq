## How does RMGC work?

RMGC is a collection of scripts written in the Nushell language. These scripts reside in a common directory under ($nu.home-path)/Apps/rmgc[^1]. For a code to be part of RMGC, it must be included or loaded by the main.nu file residing in ($nu.home-path)/Apps/rmgc[^1].

RMGC is loaded automatically by Nushell when a new instance of the shell is launched. This was defined
during software installation. That directive resides at ($nu.default-config-dir)/env.nu[^1]. Importantly all RMGC code is loaded at this time. No code is loaded dynamically when your run a command.

The command to load RMGC into the Nushell environment is called "source", which is different than running a program (requires immediate execution under a new process id) Sourcing loads all the RMGC software, validating the static code does not have syntax errors. At this point, the software is loaded and ready-to-run.

The benefit of loading the RMGC commands into the environment and how Nushell is architected, is the RMGC commands operate and behave in the exact same manner as native Nushell commands. In fact, the RMGC commands leverage Nushell's help and documentation system. You can see this in action by viewing the list of commands[^2]. This provides the user

## Another way to extend Nushell

Depending on the way Nushell was initially installed and configured, users may see plugins listed in the help commands. Currently, RMGC's installation software does not include plugins for simplicity's sake.

Plugins take the concept of commands loaded in the Nushell environment to the next level. Plugins are pre-compiled commands (usually written in Rust). Plugins extend the capabilities of Nushell, as they are written in a full-featured language, where as RMGC's shell environment are limited by Nushell's native capability. Of particular interest is [Polars](https://www.nushell.sh/commands/docs/polars.html), an implementation of a [widely used data-science library](https://docs.pola.rs/). Polars efficient design supports analysis of millions of records.

[^1]:

```
print $"($nu.home-path)/Apps/rmgc"
print $"($nu.default-config-dir)"
```

[^2]:

```
help commands | where command_type == custom
help commands | sort-by command_type
```
