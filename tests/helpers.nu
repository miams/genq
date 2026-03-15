# GenQuery test helpers — shared utilities for nutest test files
# Not a test file — no @test annotations, so nutest will ignore it

# Return common test configuration scenarios as a record
export def get-test-scenarios [] {
    {
        demo_basic: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2020.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["pres2020"]
            }
            paths: {
                sql_dir: "sql"
                lib_dir: "src/lib"
                ext_dir: "src/lib/ext"
                output_dir: "vault"
            }
            display: {
                date_format: 1
                table_mode: "rounded"
            }
        }

        production_basic: {
            database: {
                active: "production"
                connections: {
                    demo: "./data/pres2020.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["miams", "pres2020"]
            }
            paths: {
                sql_dir: "sql"
                lib_dir: "src/lib"
                ext_dir: "src/lib/ext"
                output_dir: "vault"
            }
            display: {
                date_format: 1
                table_mode: "rounded"
            }
        }

        minimal: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2020.rmtree"
                }
            }
            extensions: {
                enabled: []
            }
        }
    }
}

# Create a temp directory with an isolated GenQuery config for testing.
# Returns the path to the temp config file.
# Caller is responsible for cleanup: rm -rf $temp_dir
export def create-test-config [scenario: record] {
    let temp_dir = (mktemp -d -t "genq-test-XXXXXX")
    let config_dir = ($temp_dir | path join "config")
    mkdir $config_dir
    let config_path = ($config_dir | path join "default.toml")
    $scenario | to toml | save $config_path
    { temp_dir: $temp_dir, config_path: $config_path }
}
