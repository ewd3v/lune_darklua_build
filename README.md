# lune_darklua_build

A [darklua](https://darklua.com/) build tool for [Lune](https://lune-org.github.io/docs).
Also comes as a library for usage within Lune scripts.

## Install

### With pesde

```sh
pesde add pesde/darklua --dev -t lune
pesde add ewdev/darklua_build --dev -t lune
pesde install
```

## Usage (binary)

pesde.toml:

```toml
[dev_dependencies]
darklua = { name = "pesde/darklua", version = "^0.17.2" }
darklua_build = { name = "ewdev/darklua_build", version = "^0.1.0" }
```

```sh
darklua_build # Builds from src, into out
```

CLI options:

```sh
--input / -i [Path]
# Path to what to process (defaults to "src").

--output / -o [Path]
# Path to the output folder (defaults to "out").

--config / -c [Path]
# Path to a build config file. If left empty (or invalid): attempts to find any .darklua.build.json / .darklua.build.toml / .darklua.build.yaml

--silent / -s
# If provided, silences all non error messages.

--watch / -w
# If provided, listens to any changes to any input / build file, and automatically re-runs the build script.
```

.darklua.build.toml (.json / .yaml also supported)

```toml
input = "src" # Path to what to process (defaults to "src").
output = "out" # Path to the output folder (defaults to "out").

[options] # An optional dictionary containing a set of build options.
cwd = "." # Sets the relative path of all other paths, including input and output.
include = [ # List of globs for files to include while building (also copied over to the output)
    "roblox_packages/**/*", ".darklua.json", "*.project.json", "sourcemap.json"
]
ignore = [ "*.d." ] # List of globs for files to ignore (also ignores files for files under the input path)
darklua_config = ".darklua.json" # Custom path to your darklua config file (if left empty: uses default config path)

silent = false # If set to true, silences all non error messages.
watch = false # If set to true, listens to any changes to any input / build file, and automatically re-runs the build script.

temp_dir_keep = false # If true, keeps the temporary build directory that's created after finishing.
temp_dir_location = "." # Path for where to create the temporary build directory (defaults to system temp directory, unless temp_dir_keep is enabled where the current directory is used instead)

[options.scripts] # An optional dictionary containing a list of scripts to run at certain points while building. All commands are ran inside the temporary build directory.
preProcess = "rojo sourcemap default.project.json -o sourcemap.json" # An array / string of scripts to run before processing with darklua
postProcess = [ "command", "another command" ] # An array / string of scripts to run after processing with darklua, and before copying over files to the selected output
```

## Usage (library)

```lua
local darklua_build = require("path/to/package")
darklua_build(
    inputPath, -- Path to what to process.
    outputPath, -- Path to the output folder.
    { -- An optional dictionary containing a set of build options.
        -- For a full list of options, and what they do, refer to the example .darklua.build.toml above.

        include = { "roblox_packages/**/*", ".darklua.json", "*.project.json", "sourcemap.json" },
        ignore = { "*.d." },

        scripts = {
            preProcess = "rojo sourcemap default.project.json -o sourcemap.json",
            postProcess = function(buildDir: string) -- Scripts may also be functions, where the 1st argument being sent is the path to the temporary build directory.
                print("Finished processing inside " .. buildDir)
            end
        }
    }
)
```
