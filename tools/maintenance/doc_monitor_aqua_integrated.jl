#!/usr/bin/env julia

"""
Documentation Monitoring System with Full Aqua.jl Integration
Uses a separate Julia environment to avoid dependency conflicts

This version automatically activates the documentation monitoring environment
and provides full Aqua.jl integration alongside custom documentation analysis.
"""

# Load required packages first
using Pkg
using Dates
using Statistics

# Check if we're in the correct environment and activate if needed
function ensure_doc_monitor_environment()
    current_project = Base.active_project()
    doc_monitor_project = joinpath(@__DIR__, "Project.toml")

    if current_project != doc_monitor_project
        println("🔄 Activating documentation monitoring environment...")
        Pkg.activate(@__DIR__)
        println("✅ Environment activated: $(basename(@__DIR__))")
    end
end

# Activate the environment first
ensure_doc_monitor_environment()

# Now load the project-specific packages
using Aqua
using Test
using YAML
using JSON3
using TOML
using ArgParse

println("✅ All packages loaded successfully")
println("🔬 Aqua.jl version: $(Pkg.dependencies()[Base.UUID("4c88cf16-eb10-579e-8560-4a9242c79595")].version)")

# Include the minimal system functions (they work without dependencies)
include("doc_monitor_minimal.jl")

"""
Enhanced Aqua.jl analysis with full integration
"""
function run_full_aqua_analysis(package_module, config::Dict{String, Any})::Dict{String, Any}
    if package_module === nothing
        return Dict{String, Any}(
            "available" => false,
            "error" => "No package module loaded"
        )
    end
    
    println("  🔬 Running comprehensive Aqua.jl analysis...")
    
    results = Dict{String, Any}(
        "available" => true,
        "package_name" => string(package_module),
        "timestamp" => now(),
        "core_tests" => Dict{String, Any}(),
        "optional_tests" => Dict{String, Any}(),
        "summary" => Dict{String, Any}()
    )
    
    # Get configuration
    core_tests = get(config, "core_tests", Dict())
    optional_tests = get(config, "optional_tests", Dict())
    aqua_options = get(config, "aqua_options", Dict())
    
    # Run core tests
    core_test_specs = [
        ("undefined_exports", () -> Aqua.test_undefined_exports(package_module), get(core_tests, "undefined_exports", true)),
        ("unbound_args", () -> Aqua.test_unbound_args(package_module), get(core_tests, "unbound_args", true)),
        ("ambiguities", () -> begin
            exclude = get(get(aqua_options, "ambiguities", Dict()), "exclude", [])
            broken = get(get(aqua_options, "ambiguities", Dict()), "broken", false)
            Aqua.test_ambiguities(package_module; exclude=exclude, broken=broken)
        end, get(core_tests, "ambiguities", true)),
        ("persistent_tasks", () -> Aqua.test_persistent_tasks(package_module), get(core_tests, "persistent_tasks", true)),
        ("project_extras", () -> Aqua.test_project_extras(package_module), get(core_tests, "project_extras", true))
    ]
    
    for (test_name, test_func, enabled) in core_test_specs
        if enabled
            results["core_tests"][test_name] = run_aqua_test_with_capture(test_func, test_name)
        end
    end
    
    # Run optional tests
    optional_test_specs = [
        ("stale_deps", () -> begin
            ignore = get(get(aqua_options, "stale_deps", Dict()), "ignore", [])
            Aqua.test_stale_deps(package_module; ignore=ignore)
        end, get(optional_tests, "stale_deps", false)),
        ("deps_compat", () -> begin
            ignore = get(get(aqua_options, "deps_compat", Dict()), "ignore", [])
            Aqua.test_deps_compat(package_module; ignore=ignore)
        end, get(optional_tests, "deps_compat", false)),
        ("piracies", () -> begin
            treat_as_own = get(get(aqua_options, "piracies", Dict()), "treat_as_own", [])
            Aqua.test_piracies(package_module; treat_as_own=treat_as_own)
        end, get(optional_tests, "piracies", false))
    ]
    
    for (test_name, test_func, enabled) in optional_test_specs
        if enabled
            results["optional_tests"][test_name] = run_aqua_test_with_capture(test_func, test_name)
        end
    end
    
    # Calculate summary
    results["summary"] = calculate_aqua_summary_enhanced(results)
    
    return results
end

"""
Run Aqua test with proper error capture
"""
function run_aqua_test_with_capture(test_func::Function, test_name::String)::Dict{String, Any}
    result = Dict{String, Any}(
        "test_name" => test_name,
        "timestamp" => now(),
        "status" => "unknown",
        "duration_ms" => 0,
        "details" => nothing,
        "error_message" => nothing
    )
    
    start_time = time()
    
    try
        # Use @testset to capture results properly
        test_results = @testset "$test_name" begin
            test_func()
        end
        
        result["duration_ms"] = round(Int, (time() - start_time) * 1000)
        
        # Analyze test results
        if test_results isa Test.DefaultTestSet
            if test_results.anynonpass == false && test_results.n_passed > 0
                result["status"] = "passed"
                result["details"] = "$(test_results.n_passed) tests passed"
            else
                result["status"] = "failed"
                result["details"] = "$(test_results.anynonpass) tests failed"
                
                # Extract error details
                if !isempty(test_results.results)
                    failures = filter(r -> r isa Test.Fail || r isa Test.Error, test_results.results)
                    if !isempty(failures)
                        result["error_message"] = string(first(failures))
                    end
                end
            end
        else
            result["status"] = "passed"
            result["details"] = "Test completed successfully"
        end
        
    catch e
        result["duration_ms"] = round(Int, (time() - start_time) * 1000)
        result["status"] = "error"
        result["error_message"] = string(e)
        
        if e isa Test.TestSetException
            result["details"] = "Test set failed with errors"
        else
            result["details"] = "Unexpected error during test execution"
        end
    end
    
    return result
end

"""
Calculate enhanced Aqua summary with detailed metrics
"""
function calculate_aqua_summary_enhanced(results::Dict{String, Any})::Dict{String, Any}
    summary = Dict{String, Any}(
        "total_tests" => 0,
        "passed_tests" => 0,
        "failed_tests" => 0,
        "error_tests" => 0,
        "core_tests_passed" => 0,
        "core_tests_total" => 0,
        "optional_tests_passed" => 0,
        "optional_tests_total" => 0,
        "overall_score" => 0.0,
        "status" => "unknown",
        "test_details" => Dict{String, Any}()
    )
    
    # Analyze core tests
    core_tests = get(results, "core_tests", Dict())
    for (test_name, test_result) in core_tests
        summary["core_tests_total"] += 1
        summary["total_tests"] += 1
        
        status = get(test_result, "status", "unknown")
        summary["test_details"][test_name] = Dict{String, Any}(
            "status" => status,
            "duration_ms" => get(test_result, "duration_ms", 0),
            "category" => "core"
        )
        
        if status == "passed"
            summary["core_tests_passed"] += 1
            summary["passed_tests"] += 1
        elseif status == "failed"
            summary["failed_tests"] += 1
        elseif status == "error"
            summary["error_tests"] += 1
        end
    end
    
    # Analyze optional tests
    optional_tests = get(results, "optional_tests", Dict())
    for (test_name, test_result) in optional_tests
        summary["optional_tests_total"] += 1
        summary["total_tests"] += 1
        
        status = get(test_result, "status", "unknown")
        summary["test_details"][test_name] = Dict{String, Any}(
            "status" => status,
            "duration_ms" => get(test_result, "duration_ms", 0),
            "category" => "optional"
        )
        
        if status == "passed"
            summary["optional_tests_passed"] += 1
            summary["passed_tests"] += 1
        elseif status == "failed"
            summary["failed_tests"] += 1
        elseif status == "error"
            summary["error_tests"] += 1
        end
    end
    
    # Calculate overall score (core tests weighted more heavily)
    if summary["total_tests"] > 0
        core_score = summary["core_tests_total"] > 0 ? 
                    summary["core_tests_passed"] / summary["core_tests_total"] : 1.0
        optional_score = summary["optional_tests_total"] > 0 ? 
                        summary["optional_tests_passed"] / summary["optional_tests_total"] : 1.0
        
        # Weight: core 80%, optional 20%
        summary["overall_score"] = core_score * 0.8 + optional_score * 0.2
    else
        summary["overall_score"] = 0.0
    end
    
    # Determine status
    if summary["core_tests_total"] > 0 && summary["core_tests_passed"] == summary["core_tests_total"]
        if summary["failed_tests"] == 0 && summary["error_tests"] == 0
            summary["status"] = "excellent"
        elseif summary["failed_tests"] <= 1
            summary["status"] = "good"
        else
            summary["status"] = "needs_attention"
        end
    elseif summary["core_tests_passed"] > 0
        summary["status"] = "needs_improvement"
    else
        summary["status"] = "critical"
    end
    
    return summary
end

"""
Load configuration from YAML file
"""
function load_config(config_path::String)::Dict{String, Any}
    if isfile(config_path)
        return YAML.load_file(config_path)
    else
        # Return default configuration
        return Dict{String, Any}(
            "aqua_quality" => Dict{String, Any}(
                "enabled" => true,
                "core_tests" => Dict{String, Any}(
                    "undefined_exports" => true,
                    "unbound_args" => true,
                    "ambiguities" => true,
                    "persistent_tasks" => true,
                    "project_extras" => true
                ),
                "optional_tests" => Dict{String, Any}(
                    "stale_deps" => false,
                    "deps_compat" => false,
                    "piracies" => false
                ),
                "aqua_options" => Dict{String, Any}()
            )
        )
    end
end

"""
Main function with full Aqua.jl integration
"""
function run_integrated_monitoring(root_dir::String=".", config_path::String="doc_monitor_config.yaml")
    println("🔍 Globtim Documentation Monitor v2.0 (Full Aqua.jl Integration)")
    println("Repository: $(abspath(root_dir))")
    println("Environment: $(basename(@__DIR__))")
    println("Timestamp: $(now())")
    println()
    
    # Load configuration
    config = load_config(joinpath(root_dir, "tools", "maintenance", config_path))
    
    # Load package module (from the main project, not our environment)
    original_project = joinpath(root_dir, "Project.toml")
    package_module = nothing
    
    if isfile(original_project)
        try
            # Temporarily switch back to main project to load the package
            Pkg.activate(root_dir)
            
            # Parse Project.toml to get package name
            project_data = TOML.parsefile(original_project)
            package_name = get(project_data, "name", nothing)
            
            if package_name !== nothing
                package_module = Base.require(Main, Symbol(package_name))
                println("✅ Package module loaded: $package_name")
            end
            
            # Switch back to our environment
            Pkg.activate(@__DIR__)
        catch e
            println("⚠️  Could not load package module: $e")
        end
    end
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "repository_root" => abspath(root_dir),
        "environment" => basename(@__DIR__),
        "package_module_loaded" => package_module !== nothing
    )
    
    # Run full Aqua.jl analysis
    aqua_config = get(config, "aqua_quality", Dict())
    if get(aqua_config, "enabled", true)
        aqua_results = run_full_aqua_analysis(package_module, aqua_config)
        results["aqua_analysis"] = aqua_results
        print_aqua_results_detailed(aqua_results)
    end
    
    # Run custom analyses (reuse from minimal system)
    println("\n📋 Running Enhanced Task Analysis...")
    task_results = analyze_tasks(root_dir)
    results["task_analysis"] = task_results
    print_task_results_detailed(task_results)
    
    println("\n📚 Running Documentation Coverage Analysis...")
    doc_results = analyze_documentation_coverage(root_dir)
    results["documentation_analysis"] = doc_results
    print_doc_results_detailed(doc_results)
    
    # Calculate enhanced health score
    results["overall_health_score"] = calculate_enhanced_health_score(results)
    
    # Print final summary
    print_integrated_summary(results)
    
    return results
end

# Essential printing functions
function print_aqua_results_detailed(aqua_results::Dict{String, Any})
    if !get(aqua_results, "available", false)
        println("  ❌ Aqua.jl analysis not available")
        return
    end

    println("  🔬 Comprehensive Aqua.jl Quality Analysis:")
    println("     Package: $(get(aqua_results, "package_name", "unknown"))")

    summary = get(aqua_results, "summary", Dict())
    total_tests = get(summary, "total_tests", 0)
    passed_tests = get(summary, "passed_tests", 0)
    overall_score = get(summary, "overall_score", 0.0)
    status = get(summary, "status", "unknown")

    status_emoji = status == "excellent" ? "🟢" : status == "good" ? "🟡" : "🔴"

    println("     Tests run: $total_tests")
    println("     ✅ Passed: $passed_tests")
    println("     $status_emoji Overall score: $(round(overall_score * 100, digits=1))%")
    println("     Status: $(titlecase(replace(status, "_" => " ")))")
end

function print_task_results_detailed(task_results::Dict{String, Any})
    println("  📋 Enhanced Task Progress Analysis:")

    total_todos = get(task_results, "total_todos", 0)
    total_tasks = get(task_results, "total_markdown_tasks", 0)
    completion_rate = get(task_results, "completion_rate", 0.0)

    println("     💭 TODO comments: $total_todos")
    println("     📝 Markdown tasks: $total_tasks")

    if total_tasks > 0
        completion_emoji = completion_rate >= 0.7 ? "🟢" : completion_rate >= 0.4 ? "🟡" : "🔴"
        println("     $completion_emoji Task completion: $(round(completion_rate * 100, digits=1))%")
    end
end

function print_doc_results_detailed(doc_results::Dict{String, Any})
    println("  📚 Enhanced Documentation Coverage Analysis:")

    total_functions = get(doc_results, "total_functions", 0)
    documented_functions = get(doc_results, "documented_functions", 0)
    coverage_rate = get(doc_results, "coverage_rate", 0.0)

    println("     Functions analyzed: $total_functions")
    println("     ✅ Documented: $documented_functions")

    coverage_emoji = coverage_rate >= 0.8 ? "🟢" : coverage_rate >= 0.6 ? "🟡" : "🔴"
    println("     $coverage_emoji Coverage rate: $(round(coverage_rate * 100, digits=1))%")
end

function calculate_enhanced_health_score(results::Dict{String, Any})::Float64
    scores = Float64[]
    weights = Float64[]

    # Aqua.jl score
    if haskey(results, "aqua_analysis")
        aqua_data = results["aqua_analysis"]
        if get(aqua_data, "available", false)
            aqua_summary = get(aqua_data, "summary", Dict())
            aqua_score = get(aqua_summary, "overall_score", 0.0)
            push!(scores, aqua_score)
            push!(weights, 0.4)
        end
    end

    # Documentation coverage
    if haskey(results, "documentation_analysis")
        doc_data = results["documentation_analysis"]
        coverage_rate = get(doc_data, "coverage_rate", 0.0)
        push!(scores, coverage_rate)
        push!(weights, 0.3)
    end

    # Task management
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        task_density = get(task_data, "task_density", 0.0)
        task_score = max(0.0, 1.0 - min(1.0, task_density / 5.0))
        push!(scores, task_score)
        push!(weights, 0.2)
    end

    # Task completion
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        completion_rate = get(task_data, "completion_rate", 0.0)
        push!(scores, completion_rate)
        push!(weights, 0.1)
    end

    return isempty(scores) ? 0.5 : sum(scores .* weights) / sum(weights)
end

function print_integrated_summary(results::Dict{String, Any})
    println("\n📊 Final Integrated Summary:")
    println("=" ^ 50)

    health_score = get(results, "overall_health_score", 0.0)
    health_emoji = health_score >= 0.8 ? "🟢" : health_score >= 0.6 ? "🟡" : "🔴"

    println("$health_emoji Overall Documentation Health: $(round(health_score * 100, digits=1))%")

    # Show component scores
    if haskey(results, "aqua_analysis")
        aqua_data = results["aqua_analysis"]
        if get(aqua_data, "available", false)
            aqua_summary = get(aqua_data, "summary", Dict())
            aqua_score = get(aqua_summary, "overall_score", 0.0)
            println("  🔬 Aqua.jl Quality: $(round(aqua_score * 100, digits=1))%")
        end
    end

    if haskey(results, "documentation_analysis")
        doc_data = results["documentation_analysis"]
        coverage_rate = get(doc_data, "coverage_rate", 0.0)
        println("  📚 Documentation Coverage: $(round(coverage_rate * 100, digits=1))%")
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    args = parse_simple_args(ARGS)
    
    if args["help"]
        show_help()
        exit(0)
    end
    
    try
        results = run_integrated_monitoring(args["root_dir"])
        
        # Exit with appropriate code
        health_score = get(results, "overall_health_score", 0.0)
        if health_score < 0.4
            exit(2)  # Critical
        elseif health_score < 0.6
            exit(1)  # Warning
        else
            exit(0)  # Success
        end
    catch e
        println("❌ Error: $e")
        if args["verbose"]
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
        end
        exit(3)
    end
end
