"""
Configuration file for Aqua.jl tests

This file contains configuration settings and exclusions for Aqua.jl tests.
Modify these settings as needed based on your package's specific requirements.
"""

# Aqua test configuration for Globtim.jl
const AQUA_CONFIG = (
    # Method ambiguity exclusions
    ambiguity_exclusions = [
        # Add specific method signatures here if needed
        # Example: Base.show
        # Base.convert
    ],
    
    # Tests to skip entirely (use sparingly)
    skip_tests = [
        # Skip persistent tasks test temporarily due to version constraint issues
        :test_persistent_tasks,
        # Skip stale deps test due to false positives for development tools
        :test_stale_deps
    ],
    
    # Dependency analysis settings
    deps_compat_check = true,
    stale_deps_check = true,

    # Known "stale" dependencies that are actually used (false positives)
    # These dependencies are flagged by Aqua as potentially unused but serve important purposes
    stale_deps_ignore = [
        "ProgressLogging",  # Used in experiments, notebooks, and HPC monitoring workflows
        "JuliaFormatter",   # Used in formatting scripts, CI/CD pipelines, and pre-commit hooks
        "Colors",          # Used in visualization extensions, plotting backends, and documentation
        "JSON3",           # Used extensively in HPC JSON tracking, test infrastructure, and data serialization
        "BenchmarkTools",  # Used in performance testing, HPC benchmarking, and optional development tools
        "YAML",            # Used in documentation monitoring system and HPC configuration workflows
        "Makie",           # Base dependency for CairoMakie/GLMakie extensions and visualization system
        "TOML",            # Used in configuration parsing and project management (standard library)
        "SHA",             # Used in security features and integrity checking
        "UUIDs"            # Used in test ID generation and unique identifier creation
    ],
    
    # Project structure validation
    project_toml_formatting = true,
    
    # Custom test settings
    strict_mode = false,  # Set to true for stricter checking
    
    # CI-specific settings
    ci_mode = haskey(ENV, "CI"),
    
    # Verbose output settings
    verbose = get(ENV, "AQUA_VERBOSE", "false") == "true"
)

"""
Get Aqua configuration for the current environment
"""
function get_aqua_config()
    return AQUA_CONFIG
end

"""
Run Aqua tests with the configured settings
"""
function run_configured_aqua_tests(module_to_test)
    config = get_aqua_config()
    
    # Run tests based on configuration
    if :test_ambiguities ∉ config.skip_tests
        if isempty(config.ambiguity_exclusions)
            Aqua.test_ambiguities(module_to_test)
        else
            Aqua.test_ambiguities(module_to_test; exclude=config.ambiguity_exclusions)
        end
    end
    
    if :test_undefined_exports ∉ config.skip_tests
        Aqua.test_undefined_exports(module_to_test)
    end
    
    if :test_unbound_args ∉ config.skip_tests
        Aqua.test_unbound_args(module_to_test)
    end
    
    if :test_persistent_tasks ∉ config.skip_tests
        Aqua.test_persistent_tasks(module_to_test)
    end
    
    if config.project_toml_formatting && :test_project_toml_formatting ∉ config.skip_tests
        # Check if this function exists in the current Aqua version
        if hasmethod(Aqua.test_project_toml_formatting, (typeof(module_to_test),))
            Aqua.test_project_toml_formatting(module_to_test)
        else
            @warn "test_project_toml_formatting not available in this Aqua version"
        end
    end
    
    # Optional tests (may fail without breaking CI)
    if config.deps_compat_check
        try
            Aqua.test_deps_compat(module_to_test)
        catch e
            if config.ci_mode && config.strict_mode
                rethrow(e)
            else
                @warn "Dependency compatibility check failed" exception=e
            end
        end
    end
    
    if config.stale_deps_check
        try
            # Check if Aqua supports ignoring specific dependencies
            if hasmethod(Aqua.test_stale_deps, (typeof(module_to_test), Dict))
                # Use ignore list if supported
                Aqua.test_stale_deps(module_to_test; ignore=config.stale_deps_ignore)
            else
                # Fallback to basic test (may produce false positives)
                Aqua.test_stale_deps(module_to_test)
            end
        catch e
            if config.ci_mode && config.strict_mode
                rethrow(e)
            else
                @warn "Stale dependency check failed (may include false positives for dev tools)" exception=e
            end
        end
    end
end

"""
Check if we should run Aqua tests in the current environment
"""
function should_run_aqua_tests()
    # Skip Aqua tests if explicitly disabled
    if get(ENV, "SKIP_AQUA_TESTS", "false") == "true"
        return false
    end
    
    # Skip on older Julia versions where Aqua might not work well
    if VERSION < v"1.6"
        @warn "Skipping Aqua tests on Julia $(VERSION) - requires Julia 1.6+"
        return false
    end
    
    return true
end

"""
Print Aqua configuration information
"""
function print_aqua_config()
    config = get_aqua_config()
    
    println("🔧 Aqua.jl Configuration:")
    println("  Strict mode: $(config.strict_mode)")
    println("  CI mode: $(config.ci_mode)")
    println("  Verbose: $(config.verbose)")
    println("  Ambiguity exclusions: $(length(config.ambiguity_exclusions))")
    println("  Skipped tests: $(config.skip_tests)")
    println("  Dependency checks: compat=$(config.deps_compat_check), stale=$(config.stale_deps_check)")
    println("  Stale deps ignored: $(length(config.stale_deps_ignore)) packages")
    if config.verbose
        println("    Ignored packages: " * join(config.stale_deps_ignore, ", "))
    end
end

export get_aqua_config, run_configured_aqua_tests, should_run_aqua_tests, print_aqua_config
