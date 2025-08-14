#!/usr/bin/env julia

"""
Simple Aqua.jl Integration for Documentation Monitoring
Works in the dedicated environment with full Aqua.jl integration
"""

# Activate the documentation monitoring environment
using Pkg
Pkg.activate(@__DIR__)

# Load all required packages
using Aqua
using Test
using YAML
using JSON3
using TOML
using Dates
using Statistics

println("✅ All packages loaded successfully")
println("🔬 Aqua.jl version: $(Pkg.dependencies()[Base.UUID("4c88cf16-eb10-579e-8560-4a9242c79595")].version)")

# Include the minimal system functions for reuse
include("doc_monitor_minimal.jl")

"""
Run comprehensive Aqua.jl analysis
"""
function run_aqua_comprehensive(package_module)::Dict{String, Any}
    if package_module === nothing
        return Dict{String, Any}("available" => false, "error" => "No package module")
    end
    
    println("  🔬 Running comprehensive Aqua.jl analysis...")
    
    results = Dict{String, Any}(
        "available" => true,
        "package_name" => string(package_module),
        "timestamp" => now(),
        "tests" => Dict{String, Any}(),
        "summary" => Dict{String, Any}()
    )
    
    # Define tests to run
    test_specs = [
        ("undefined_exports", () -> Aqua.test_undefined_exports(package_module)),
        ("unbound_args", () -> Aqua.test_unbound_args(package_module)),
        ("ambiguities", () -> Aqua.test_ambiguities(package_module)),
        ("persistent_tasks", () -> Aqua.test_persistent_tasks(package_module)),
        ("project_extras", () -> Aqua.test_project_extras(package_module)),
        ("stale_deps", () -> Aqua.test_stale_deps(package_module; ignore=[
            :ProgressLogging, :JSON3, :BenchmarkTools, :JuliaFormatter,
            :Makie, :YAML, :Colors, :ProfileView
        ])),
        ("deps_compat", () -> Aqua.test_deps_compat(package_module))
    ]
    
    # Run each test
    for (test_name, test_func) in test_specs
        try
            start_time = time()
            
            # Capture test results using @testset
            test_result = @testset "$test_name" begin
                test_func()
            end
            
            duration = round(Int, (time() - start_time) * 1000)
            
            # Analyze results
            if test_result isa Test.DefaultTestSet
                if test_result.anynonpass == false && test_result.n_passed > 0
                    status = "passed"
                    details = "$(test_result.n_passed) tests passed"
                else
                    status = "failed"
                    details = "$(test_result.anynonpass) tests failed"
                end
            else
                status = "passed"
                details = "Test completed"
            end
            
            results["tests"][test_name] = Dict{String, Any}(
                "status" => status,
                "duration_ms" => duration,
                "details" => details
            )
            
        catch e
            results["tests"][test_name] = Dict{String, Any}(
                "status" => "error",
                "error" => string(e),
                "details" => "Test failed with error"
            )
        end
    end
    
    # Calculate summary
    total_tests = length(results["tests"])
    passed_tests = count(t -> get(t, "status", "") == "passed", values(results["tests"]))
    failed_tests = count(t -> get(t, "status", "") == "failed", values(results["tests"]))
    error_tests = count(t -> get(t, "status", "") == "error", values(results["tests"]))
    
    overall_score = total_tests > 0 ? passed_tests / total_tests : 0.0
    
    status = if passed_tests == total_tests
        "excellent"
    elseif passed_tests >= total_tests * 0.8
        "good"
    elseif passed_tests >= total_tests * 0.5
        "needs_attention"
    else
        "critical"
    end
    
    results["summary"] = Dict{String, Any}(
        "total_tests" => total_tests,
        "passed_tests" => passed_tests,
        "failed_tests" => failed_tests,
        "error_tests" => error_tests,
        "overall_score" => overall_score,
        "status" => status
    )
    
    return results
end

"""
Print Aqua.jl results
"""
function print_aqua_comprehensive(aqua_results::Dict{String, Any})
    if !get(aqua_results, "available", false)
        println("  ❌ Aqua.jl analysis not available")
        return
    end
    
    println("  🔬 Comprehensive Aqua.jl Quality Analysis:")
    println("     Package: $(get(aqua_results, "package_name", "unknown"))")
    
    summary = get(aqua_results, "summary", Dict())
    total_tests = get(summary, "total_tests", 0)
    passed_tests = get(summary, "passed_tests", 0)
    failed_tests = get(summary, "failed_tests", 0)
    error_tests = get(summary, "error_tests", 0)
    overall_score = get(summary, "overall_score", 0.0)
    status = get(summary, "status", "unknown")
    
    status_emoji = if status == "excellent"
        "🟢"
    elseif status == "good"
        "🟡"
    elseif status == "needs_attention"
        "🟠"
    else
        "🔴"
    end
    
    println("     Tests run: $total_tests")
    println("     ✅ Passed: $passed_tests")
    if failed_tests > 0
        println("     ❌ Failed: $failed_tests")
    end
    if error_tests > 0
        println("     ⚠️  Errors: $error_tests")
    end
    println("     $status_emoji Overall score: $(round(overall_score * 100, digits=1))%")
    println("     Status: $(titlecase(replace(status, "_" => " ")))")
    
    # Show individual test results
    tests = get(aqua_results, "tests", Dict())
    if !isempty(tests)
        println("     Individual test results:")
        for (test_name, test_result) in tests
            test_status = get(test_result, "status", "unknown")
            duration = get(test_result, "duration_ms", 0)
            emoji = test_status == "passed" ? "✅" : test_status == "failed" ? "❌" : "⚠️"
            display_name = titlecase(replace(test_name, "_" => " "))
            println("       $emoji $display_name: $test_status ($(duration)ms)")
        end
    end
end

"""
Main function with full Aqua.jl integration
"""
function run_simple_aqua_integration(root_dir::String=".")
    println("🔍 Globtim Documentation Monitor with Aqua.jl Integration")
    println("Repository: $(abspath(root_dir))")
    println("Environment: $(basename(@__DIR__))")
    println("Timestamp: $(now())")
    println()
    
    # Load package module from main project
    original_project = joinpath(root_dir, "Project.toml")
    package_module = nothing
    
    if isfile(original_project)
        try
            # Temporarily switch to main project
            Pkg.activate(root_dir)
            
            # Get package name
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
        "package_module_loaded" => package_module !== nothing
    )
    
    # Run Aqua.jl analysis
    aqua_results = run_aqua_comprehensive(package_module)
    results["aqua_analysis"] = aqua_results
    print_aqua_comprehensive(aqua_results)
    
    # Run custom analyses (reuse from minimal system)
    println("\n📋 Running Task Analysis...")
    task_results = analyze_tasks(root_dir)
    results["task_analysis"] = task_results
    
    total_todos = get(task_results, "total_todos", 0)
    total_tasks = get(task_results, "total_markdown_tasks", 0)
    completion_rate = get(task_results, "completion_rate", 0.0)
    
    println("  💭 TODO comments: $total_todos")
    println("  📝 Markdown tasks: $total_tasks")
    if total_tasks > 0
        println("  ✅ Task completion: $(round(completion_rate * 100, digits=1))%")
    end
    
    println("\n📚 Running Documentation Coverage Analysis...")
    doc_results = analyze_documentation_coverage(root_dir)
    results["documentation_analysis"] = doc_results
    
    total_functions = get(doc_results, "total_functions", 0)
    documented_functions = get(doc_results, "documented_functions", 0)
    coverage_rate = get(doc_results, "coverage_rate", 0.0)
    
    println("  Functions analyzed: $total_functions")
    println("  ✅ Documented: $documented_functions")
    println("  📊 Coverage rate: $(round(coverage_rate * 100, digits=1))%")
    
    # Calculate enhanced health score
    aqua_score = if get(aqua_results, "available", false)
        get(get(aqua_results, "summary", Dict()), "overall_score", 0.0)
    else
        0.5
    end
    
    task_density = get(task_results, "task_density", 0.0)
    task_score = max(0.0, 1.0 - min(1.0, task_density / 5.0))
    
    # Weighted health score: Aqua 40%, docs 30%, tasks 20%, completion 10%
    overall_health = aqua_score * 0.4 + coverage_rate * 0.3 + task_score * 0.2 + completion_rate * 0.1
    results["overall_health_score"] = overall_health
    
    # Final summary
    println("\n📊 Final Summary:")
    println("=" ^ 40)
    
    health_emoji = if overall_health >= 0.8
        "🟢"
    elseif overall_health >= 0.6
        "🟡"
    elseif overall_health >= 0.4
        "🟠"
    else
        "🔴"
    end
    
    println("$health_emoji Overall Health: $(round(overall_health * 100, digits=1))%")
    println("  🔬 Aqua.jl Score: $(round(aqua_score * 100, digits=1))%")
    println("  📚 Documentation Coverage: $(round(coverage_rate * 100, digits=1))%")
    println("  📋 Task Management: $(round(task_score * 100, digits=1))%")
    if total_tasks > 0
        println("  ✅ Task Completion: $(round(completion_rate * 100, digits=1))%")
    end
    
    return results
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    try
        results = run_simple_aqua_integration(".")
        
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
        println("Stack trace:")
        showerror(stdout, e, catch_backtrace())
        exit(3)
    end
end
