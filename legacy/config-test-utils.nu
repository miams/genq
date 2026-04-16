# GenQuery Configuration Testing Utilities
#
# Provides isolated testing environment with temporary configurations
# to ensure tests don't interfere with user's actual settings

# Execute a test with an isolated configuration environment
# Creates a temporary directory, config file, and cleans up automatically
export def with-test-config [
    scenario: record        # Configuration data to use for testing
    test_block: closure     # Test code to execute
] {
    # Create temporary directory for isolated testing
    let temp_dir = (mktemp -d -t "genq-test-XXXXXX")
    let temp_config_dir = ($temp_dir | path join "config")
    let temp_config_path = ($temp_config_dir | path join "default.toml")
    
    try {
        # Setup isolated test environment
        mkdir $temp_config_dir
        $scenario | to toml | save $temp_config_path
        
        # Create basic directory structure if needed
        let data_dir = ($temp_dir | path join "data")
        mkdir $data_dir
        
        # Execute test with isolated GENQ_HOME environment  
        # Change to original directory so relative imports work
        let original_pwd = $env.PWD
        let result = (with-env {GENQ_HOME: $temp_dir} {
            cd $original_pwd
            do $test_block $temp_config_path
        })
        
        # Cleanup and return result
        rm -rf $temp_dir
        $result
    } catch { |error|
        # Cleanup on error and re-throw
        rm -rf $temp_dir
        error make {msg: $error.msg}
    }
}

# Common test configuration scenarios
export def get-test-scenarios [] {
    {
        # Basic demo configuration
        demo_basic: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2025.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["pres2025"]
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
        
        # Basic production configuration
        production_basic: {
            database: {
                active: "production"
                connections: {
                    demo: "./data/pres2025.rmtree"
                    production: "./data/Iiams.rmtree"
                }
            }
            extensions: {
                enabled: ["miams", "pres2025"]
            }
            sync: {
                sources: {
                    production: "/test/path/TestFamily.rmtree"
                    demo: "/test/path/pres2025.rmtree"
                }
                targets: {
                    production: "./data/Iiams.rmtree"
                    demo: "./data/pres2025.rmtree"
                }
                options: {
                    backup_before_sync: true
                    verify_after_sync: true
                }
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
        
        # Minimal configuration for edge case testing
        minimal: {
            database: {
                active: "demo"
                connections: {
                    demo: "./data/pres2025.rmtree"
                }
            }
            extensions: {
                enabled: []
            }
        }
        
        # Configuration with custom paths
        custom_paths: {
            database: {
                active: "production"
                connections: {
                    production: "/custom/path/database.rmtree"
                }
            }
            extensions: {
                enabled: ["custom_ext"]
            }
            paths: {
                sql_dir: "/custom/sql"
                output_dir: "/custom/output"
            }
        }
    }
}

# Quick helper to run test with predefined scenario
export def with-test-scenario [
    scenario_name: string   # Name of predefined scenario
    test_block: closure     # Test code to execute
] {
    let scenarios = (get-test-scenarios)
    let scenario = ($scenarios | get $scenario_name)
    with-test-config $scenario $test_block
}

# Helper to verify configuration was saved correctly
export def assert-config-equals [
    config_path: string     # Path to config file
    expected: record        # Expected configuration values
] {
    let actual = (open $config_path)
    
    # Compare each expected field
    for field in ($expected | columns) {
        let expected_value = ($expected | get $field)
        let actual_value = ($actual | get $field)
        
        if $expected_value != $actual_value {
            error make {
                msg: $"Configuration mismatch for field '($field)': expected ($expected_value), got ($actual_value)"
            }
        }
    }
}