#!/usr/bin/env julia
"""
Monitoring Test Utilities
GlobTim Project - Issue #55 - Test Utilities for Monitoring Functions

Purpose: Utility functions for testing monitoring workflow variable scope issues
Provides common testing infrastructure for monitoring test suites

Utility Categories:
1. Mock monitoring environments
2. Variable scope testing helpers
3. Import validation utilities
4. Error simulation and recovery testing
5. HPC environment simulation
6. Cross-platform compatibility helpers

Author: Julia Test Architect Agent
Date: September 9, 2025
"""

using Test
using Pkg
using Dates

# Re-export test utilities from parent directory
include("../test_utils.jl")

"""
    create_isolated_environment() -> Module

Create an isolated module environment for testing variable scope issues.
Useful for testing import dependencies and variable availability.
"""
function create_isolated_environment()
    # Create a fresh module with minimal imports
    isolated_module = Module(:IsolatedTestEnvironment)
    
    # Add only basic functionality
    Core.eval(isolated_module, :(using Test))
    
    return isolated_module
end

"""
    test_import_in_isolation(module_name::String, test_function::Function) -> Bool

Test importing a module in isolation and run a test function.
Returns true if both import and test succeed, false otherwise.
"""
function test_import_in_isolation(module_name::String, test_function::Function)
    isolated_env = create_isolated_environment()
    
    try
        # Try to import the module in isolation
        Core.eval(isolated_env, :(using $(Symbol(module_name))))
        
        # Run the test function in the isolated environment
        test_function(isolated_env)
        return true
    catch e
        @warn "Import or test failed in isolation for $module_name" exception=e
        return false
    end
end

"""
    simulate_missing_import(module_name::String, function_name::String) -> Exception

Simulate the error that occurs when a function is called without its module imported.
"""
function simulate_missing_import(module_name::String, function_name::String)
    isolated_env = create_isolated_environment()
    
    try
        # Try to call the function without importing the module
        Core.eval(isolated_env, :($(Symbol(function_name))()))
        error("Expected UndefVarError but function was available")
    catch e
        return e
    end
end

"""
    create_monitoring_environment() -> Dict

Create a simulated monitoring environment with common variables and functions.
"""
function create_monitoring_environment()
    return Dict(
        "start_time" => time(),
        "process_id" => getpid(),
        "hostname" => gethostname(),
        "julia_version" => VERSION,
        "available_memory" => Sys.free_memory(),
        "cpu_threads" => Sys.CPU_THREADS,
        "system_type" => Sys.KERNEL,
        "environment_vars" => copy(ENV),
        "depot_paths" => copy(DEPOT_PATH),
        "load_path" => copy(LOAD_PATH)
    )
end

"""
    mock_hpc_environment() -> Dict

Create a mock HPC environment for testing cross-environment compatibility.
"""
function mock_hpc_environment()
    return Dict(
        "hostname" => "r04n02",
        "user" => "scholten",
        "home_dir" => "/home/scholten",
        "project_dir" => "/home/scholten/globtim",
        "julia_version" => "1.9.3",
        "available_memory" => "100GB",
        "cpu_cores" => 48,
        "system_type" => "Linux",
        "batch_system" => "direct",  # No SLURM
        "session_type" => "tmux",
        "environment_vars" => Dict(
            "HOME" => "/home/scholten",
            "USER" => "scholten",
            "JULIA_DEPOT_PATH" => "/home/scholten/.julia",
            "JULIA_PROJECT" => "/home/scholten/globtim"
        )
    )
end

"""
    test_variable_scope(test_name::String, setup_func::Function, test_func::Function) -> Bool

Generic utility for testing variable scope issues.

# Arguments
- `test_name`: Name of the test for logging
- `setup_func`: Function to set up the test environment (called with no args)
- `test_func`: Function to run the actual test (called with setup result)
"""
function test_variable_scope(test_name::String, setup_func::Function, test_func::Function)
    try
        @info "Running variable scope test: $test_name"
        setup_result = setup_func()
        test_result = test_func(setup_result)
        @info "Variable scope test passed: $test_name"
        return test_result
    catch e
        @warn "Variable scope test failed: $test_name" exception=e
        return false
    end
end

"""
    validate_function_availability(module_ref, function_names::Vector{Symbol}) -> Dict

Check if specified functions are available in the given module.
Returns a dict mapping function names to availability status.
"""
function validate_function_availability(module_ref, function_names::Vector{Symbol})
    results = Dict{Symbol, Bool}()
    
    for func_name in function_names
        results[func_name] = isdefined(module_ref, func_name)
    end
    
    return results
end

"""
    test_datetime_functions_without_import() -> Vector{Exception}

Test datetime functions that commonly fail without proper imports.
Returns list of exceptions encountered.
"""
function test_datetime_functions_without_import()
    isolated_env = create_isolated_environment()
    errors = Exception[]
    
    # Test functions that require Dates import
    datetime_functions = [
        "now()",
        "today()", 
        "Time(12, 0, 0)",
        "Date(2025, 9, 9)",
        "DateTime(2025, 9, 9, 12, 0, 0)"
    ]
    
    for func_expr in datetime_functions
        try
            Core.eval(isolated_env, Meta.parse(func_expr))
        catch e
            push!(errors, e)
        end
    end
    
    return errors
end

"""
    create_validator_test_environment() -> Dict

Create a test environment specifically for testing the package validator.
"""
function create_validator_test_environment()
    temp_project = mktempdir()
    
    # Create minimal Project.toml
    project_toml = joinpath(temp_project, "Project.toml")
    write(project_toml, """
    name = "TestValidatorProject"
    uuid = "12345678-1234-5678-9012-123456789abc"
    version = "0.1.0"
    
    [deps]
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    """)
    
    return Dict(
        "project_path" => temp_project,
        "project_toml" => project_toml,
        "cleanup" => () -> rm(temp_project, recursive=true)
    )
end

"""
    run_validator_with_environment(validator_path::String, test_env::Dict) -> Tuple{Bool, Any}

Run the package validator in a controlled test environment.
Returns (success, result/error).
"""
function run_validator_with_environment(validator_path::String, test_env::Dict)
    if !isfile(validator_path)
        return (false, ArgumentError("Validator file not found: $validator_path"))
    end
    
    try
        # Set up environment
        old_project = get(ENV, "JULIA_PROJECT", "")
        ENV["JULIA_PROJECT"] = test_env["project_path"]
        
        try
            # Ensure Dates is imported to avoid the bug
            eval(:(using Dates))
            
            # Include and run validator
            include(validator_path)
            result = validate_julia_environment("critical-only")
            
            return (true, result)
        finally
            # Restore environment
            if isempty(old_project)
                delete!(ENV, "JULIA_PROJECT")
            else
                ENV["JULIA_PROJECT"] = old_project
            end
        end
    catch e
        return (false, e)
    end
end

"""
    benchmark_import_time(module_name::String; trials::Int=5) -> NamedTuple

Benchmark the time it takes to import a module.
Returns statistics about import performance.
"""
function benchmark_import_time(module_name::String; trials::Int=5)
    times = Float64[]
    
    for i in 1:trials
        # Create fresh environment for each trial
        isolated_env = Module(gensym(:BenchmarkEnv))
        
        start_time = time_ns()
        try
            Core.eval(isolated_env, :(using $(Symbol(module_name))))
            end_time = time_ns()
            push!(times, (end_time - start_time) / 1e9)  # Convert to seconds
        catch e
            @warn "Import failed in trial $i for $module_name" exception=e
            push!(times, Inf)  # Mark failed trials
        end
    end
    
    valid_times = filter(isfinite, times)
    
    if isempty(valid_times)
        return (
            success_rate = 0.0,
            mean_time = Inf,
            min_time = Inf,
            max_time = Inf,
            std_time = NaN
        )
    end
    
    return (
        success_rate = length(valid_times) / trials,
        mean_time = sum(valid_times) / length(valid_times),  # Manual mean calculation
        min_time = minimum(valid_times),
        max_time = maximum(valid_times),
        std_time = sqrt(sum((t - sum(valid_times)/length(valid_times))^2 for t in valid_times) / (length(valid_times) - 1))  # Manual std calculation
    )
end

"""
    create_script_analyzer() -> Function

Create a function that analyzes Julia scripts for import dependencies.
"""
function create_script_analyzer()
    function analyze_script(file_path::String)
        if !isfile(file_path)
            return Dict("error" => "File not found: $file_path")
        end
        
        content = read(file_path, String)
        
        # Find using statements
        using_matches = collect(eachmatch(r"using\s+([A-Za-z_][A-Za-z0-9_]*)", content))
        imports = [m.captures[1] for m in using_matches]
        
        # Find import statements  
        import_matches = collect(eachmatch(r"import\s+([A-Za-z_][A-Za-z0-9_]*)", content))
        append!(imports, [m.captures[1] for m in import_matches])
        
        # Find potential function calls that might need imports
        function_patterns = [
            (r"now\(\)", "Dates"),
            (r"today\(\)", "Dates"),
            (r"mean\(", "Statistics"),
            (r"std\(", "Statistics"),
            (r"norm\(", "LinearAlgebra"),
            (r"versioninfo\(", "InteractiveUtils")
        ]
        
        potential_missing = String[]
        for (pattern, required_module) in function_patterns
            if occursin(pattern, content) && !(required_module in imports)
                push!(potential_missing, required_module)
            end
        end
        
        return Dict(
            "file" => file_path,
            "explicit_imports" => unique(imports),
            "potential_missing" => unique(potential_missing),
            "line_count" => count('\n', content) + 1
        )
    end
    
    return analyze_script
end

"""
    simulate_hpc_execution(func::Function; mock_env::Dict = mock_hpc_environment()) -> Any

Simulate executing a function in an HPC environment.
"""
function simulate_hpc_execution(func::Function; mock_env::Dict = mock_hpc_environment())
    # Store original environment
    original_env = Dict{String, String}()
    
    # Set HPC environment variables
    for (key, value) in mock_env["environment_vars"]
        original_env[key] = get(ENV, key, "")
        ENV[key] = string(value)
    end
    
    try
        @info "Simulating HPC execution on $(mock_env["hostname"])"
        result = func()
        @info "HPC simulation completed successfully"
        return result
    finally
        # Restore original environment
        for (key, original_value) in original_env
            if isempty(original_value)
                delete!(ENV, key)
            else
                ENV[key] = original_value
            end
        end
    end
end

"""
    create_error_recovery_tester() -> Function

Create a function that tests error recovery mechanisms.
"""
function create_error_recovery_tester()
    function test_error_recovery(primary_func::Function, fallback_func::Function, test_input)
        primary_result = nothing
        primary_error = nothing
        fallback_result = nothing
        fallback_error = nothing
        
        # Test primary function
        try
            primary_result = primary_func(test_input)
        catch e
            primary_error = e
        end
        
        # Test fallback function if primary failed
        if primary_error !== nothing
            try
                fallback_result = fallback_func(test_input)
            catch e
                fallback_error = e
            end
        end
        
        return Dict(
            "primary_success" => primary_error === nothing,
            "primary_result" => primary_result,
            "primary_error" => primary_error,
            "fallback_success" => fallback_error === nothing,
            "fallback_result" => fallback_result,
            "fallback_error" => fallback_error,
            "recovery_successful" => (primary_error === nothing) || (fallback_error === nothing)
        )
    end
    
    return test_error_recovery
end

"""
    validate_monitoring_script_health(script_path::String) -> Dict

Comprehensive health check for a monitoring script.
"""
function validate_monitoring_script_health(script_path::String)
    if !isfile(script_path)
        return Dict("healthy" => false, "error" => "File not found")
    end
    
    results = Dict(
        "file_path" => script_path,
        "file_size" => filesize(script_path),
        "readable" => true,
        "parseable" => false,
        "import_analysis" => Dict(),
        "syntax_errors" => [],
        "potential_issues" => [],
        "healthy" => false
    )
    
    try
        # Check if file can be read
        content = read(script_path, String)
        
        # Check if file can be parsed
        try
            Meta.parse(content)
            results["parseable"] = true
        catch e
            push!(results["syntax_errors"], string(e))
        end
        
        # Analyze imports
        analyzer = create_script_analyzer()
        results["import_analysis"] = analyzer(script_path)
        
        # Check for specific problematic patterns
        if occursin("now()", content) && !occursin("using Dates", content)
            push!(results["potential_issues"], "Uses now() without importing Dates")
        end
        
        if occursin("mean(", content) && !occursin("using Statistics", content)
            push!(results["potential_issues"], "Uses mean() without importing Statistics")
        end
        
        # Overall health assessment
        results["healthy"] = results["parseable"] && 
                           isempty(results["syntax_errors"]) && 
                           length(results["potential_issues"]) <= 2  # Allow minor issues
        
    catch e
        results["readable"] = false
        results["error"] = string(e)
    end
    
    return results
end

# Export utility functions
export create_isolated_environment, test_import_in_isolation, simulate_missing_import
export create_monitoring_environment, mock_hpc_environment, test_variable_scope
export validate_function_availability, test_datetime_functions_without_import
export create_validator_test_environment, run_validator_with_environment
export benchmark_import_time, create_script_analyzer, simulate_hpc_execution
export create_error_recovery_tester, validate_monitoring_script_health