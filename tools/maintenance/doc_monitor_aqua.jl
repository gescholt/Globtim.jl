"""
Aqua.jl Integration Module for Documentation Monitoring

This module integrates Aqua.jl quality assurance into the documentation monitoring system,
replacing custom quality checks with proven community tools.
"""

using Test
using Dates

"""
Run comprehensive Aqua.jl quality analysis
"""
function run_aqua_analysis(monitor::DocumentationMonitor)::Dict{String, Any}
    if !AQUA_AVAILABLE
        return Dict{String, Any}(
            "error" => "Aqua.jl not available",
            "available" => false,
            "timestamp" => now()
        )
    end
    
    if monitor.package_module === nothing
        return Dict{String, Any}(
            "error" => "No package module loaded",
            "available" => true,
            "package_loaded" => false,
            "timestamp" => now()
        )
    end
    
    config = get(monitor.config, "aqua_quality", Dict())
    core_tests = get(config, "core_tests", Dict())
    optional_tests = get(config, "optional_tests", Dict())
    aqua_options = get(config, "aqua_options", Dict())
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "package_name" => string(monitor.package_module),
        "available" => true,
        "package_loaded" => true,
        "core_tests" => Dict{String, Any}(),
        "optional_tests" => Dict{String, Any}(),
        "summary" => Dict{String, Any}()
    )
    
    # Run core tests (always enabled)
    if get(core_tests, "undefined_exports", true)
        results["core_tests"]["undefined_exports"] = run_aqua_test(
            () -> Aqua.test_undefined_exports(monitor.package_module),
            "Undefined Exports"
        )
    end
    
    if get(core_tests, "unbound_args", true)
        results["core_tests"]["unbound_args"] = run_aqua_test(
            () -> Aqua.test_unbound_args(monitor.package_module),
            "Unbound Arguments"
        )
    end
    
    if get(core_tests, "ambiguities", true)
        ambiguity_options = get(aqua_options, "ambiguities", Dict())
        exclude = get(ambiguity_options, "exclude", [])
        broken = get(ambiguity_options, "broken", false)
        
        results["core_tests"]["ambiguities"] = run_aqua_test(
            () -> Aqua.test_ambiguities(monitor.package_module; exclude=exclude, broken=broken),
            "Method Ambiguities"
        )
    end
    
    if get(core_tests, "persistent_tasks", true)
        results["core_tests"]["persistent_tasks"] = run_aqua_test(
            () -> Aqua.test_persistent_tasks(monitor.package_module),
            "Persistent Tasks"
        )
    end
    
    if get(core_tests, "project_extras", true)
        results["core_tests"]["project_extras"] = run_aqua_test(
            () -> Aqua.test_project_extras(monitor.package_module),
            "Project Extras"
        )
    end
    
    # Run optional tests (can be disabled)
    if get(optional_tests, "stale_deps", false)
        stale_options = get(aqua_options, "stale_deps", Dict())
        ignore = get(stale_options, "ignore", [])
        
        results["optional_tests"]["stale_deps"] = run_aqua_test(
            () -> Aqua.test_stale_deps(monitor.package_module; ignore=ignore),
            "Stale Dependencies"
        )
    end
    
    if get(optional_tests, "deps_compat", false)
        compat_options = get(aqua_options, "deps_compat", Dict())
        ignore = get(compat_options, "ignore", [])
        
        results["optional_tests"]["deps_compat"] = run_aqua_test(
            () -> Aqua.test_deps_compat(monitor.package_module; ignore=ignore),
            "Dependency Compatibility"
        )
    end
    
    if get(optional_tests, "piracies", false)
        piracy_options = get(aqua_options, "piracies", Dict())
        treat_as_own = get(piracy_options, "treat_as_own", [])
        
        results["optional_tests"]["piracies"] = run_aqua_test(
            () -> Aqua.test_piracies(monitor.package_module; treat_as_own=treat_as_own),
            "Type Piracies"
        )
    end
    
    # Calculate summary statistics
    results["summary"] = calculate_aqua_summary(results)
    
    return results
end

"""
Run a single Aqua.jl test and capture the result
"""
function run_aqua_test(test_func::Function, test_name::String)::Dict{String, Any}
    result = Dict{String, Any}(
        "test_name" => test_name,
        "timestamp" => now(),
        "status" => "unknown",
        "duration_ms" => 0,
        "error_message" => nothing,
        "details" => nothing
    )
    
    start_time = time()
    
    try
        # Capture test output using Test.jl
        test_result = @testset "$test_name" begin
            test_func()
        end
        
        result["duration_ms"] = round(Int, (time() - start_time) * 1000)
        
        # Parse test result
        if test_result isa Test.DefaultTestSet
            if test_result.n_passed > 0 && test_result.anynonpass == false
                result["status"] = "passed"
                result["details"] = "$(test_result.n_passed) tests passed"
            else
                result["status"] = "failed"
                result["details"] = "$(test_result.anynonpass) tests failed"
                
                # Try to extract error details
                if !isempty(test_result.results)
                    errors = filter(r -> r isa Test.Fail || r isa Test.Error, test_result.results)
                    if !isempty(errors)
                        result["error_message"] = string(first(errors))
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
        
        # Try to extract meaningful error information
        if e isa Test.TestSetException
            result["details"] = "Test set failed with $(length(e.errors)) errors"
        elseif e isa MethodError
            result["details"] = "Method error - possibly unsupported Aqua.jl version"
        else
            result["details"] = "Unexpected error during test execution"
        end
    end
    
    return result
end

"""
Calculate summary statistics from Aqua.jl test results
"""
function calculate_aqua_summary(results::Dict{String, Any})::Dict{String, Any}
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
        "status" => "unknown"
    )
    
    # Count core tests
    core_tests = get(results, "core_tests", Dict())
    for (test_name, test_result) in core_tests
        summary["core_tests_total"] += 1
        summary["total_tests"] += 1
        
        status = get(test_result, "status", "unknown")
        if status == "passed"
            summary["core_tests_passed"] += 1
            summary["passed_tests"] += 1
        elseif status == "failed"
            summary["failed_tests"] += 1
        elseif status == "error"
            summary["error_tests"] += 1
        end
    end
    
    # Count optional tests
    optional_tests = get(results, "optional_tests", Dict())
    for (test_name, test_result) in optional_tests
        summary["optional_tests_total"] += 1
        summary["total_tests"] += 1
        
        status = get(test_result, "status", "unknown")
        if status == "passed"
            summary["optional_tests_passed"] += 1
            summary["passed_tests"] += 1
        elseif status == "failed"
            summary["failed_tests"] += 1
        elseif status == "error"
            summary["error_tests"] += 1
        end
    end
    
    # Calculate overall score
    if summary["total_tests"] > 0
        # Core tests are weighted more heavily
        core_score = summary["core_tests_total"] > 0 ? 
                    summary["core_tests_passed"] / summary["core_tests_total"] : 1.0
        optional_score = summary["optional_tests_total"] > 0 ? 
                        summary["optional_tests_passed"] / summary["optional_tests_total"] : 1.0
        
        # Weight core tests at 80%, optional at 20%
        summary["overall_score"] = core_score * 0.8 + optional_score * 0.2
    else
        summary["overall_score"] = 0.0
    end
    
    # Determine overall status
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
Print Aqua.jl analysis summary to console
"""
function print_aqua_summary(results::Dict{String, Any}, verbose::Bool)
    println("  🔬 Aqua.jl Quality Analysis Results:")
    
    if !get(results, "available", false)
        println("     ❌ Aqua.jl not available")
        return
    end
    
    if !get(results, "package_loaded", false)
        println("     ❌ Package module not loaded")
        return
    end
    
    summary = get(results, "summary", Dict())
    total_tests = get(summary, "total_tests", 0)
    passed_tests = get(summary, "passed_tests", 0)
    failed_tests = get(summary, "failed_tests", 0)
    error_tests = get(summary, "error_tests", 0)
    overall_score = get(summary, "overall_score", 0.0)
    status = get(summary, "status", "unknown")
    
    # Status emoji
    status_emoji = if status == "excellent"
        "🟢"
    elseif status == "good"
        "🟡"
    elseif status in ["needs_attention", "needs_improvement"]
        "🟠"
    else
        "🔴"
    end
    
    println("     Package: $(get(results, "package_name", "unknown"))")
    println("     Total tests: $total_tests")
    println("     ✅ Passed: $passed_tests")
    
    if failed_tests > 0
        println("     ❌ Failed: $failed_tests")
    end
    
    if error_tests > 0
        println("     ⚠️  Errors: $error_tests")
    end
    
    println("     $status_emoji Overall score: $(round(overall_score * 100, digits=1))%")
    println("     Status: $(titlecase(replace(status, "_" => " ")))")
    
    # Show core vs optional breakdown
    core_passed = get(summary, "core_tests_passed", 0)
    core_total = get(summary, "core_tests_total", 0)
    optional_passed = get(summary, "optional_tests_passed", 0)
    optional_total = get(summary, "optional_tests_total", 0)
    
    if core_total > 0
        println("     📋 Core tests: $core_passed/$core_total passed")
    end
    
    if optional_total > 0
        println("     📋 Optional tests: $optional_passed/$optional_total passed")
    end
    
    # Show individual test results if verbose
    if verbose
        println("     Detailed results:")
        
        core_tests = get(results, "core_tests", Dict())
        for (test_name, test_result) in core_tests
            status = get(test_result, "status", "unknown")
            duration = get(test_result, "duration_ms", 0)
            emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
            println("       $emoji $(get(test_result, "test_name", test_name)): $status ($(duration)ms)")
            
            if status != "passed" && haskey(test_result, "error_message")
                error_msg = test_result["error_message"]
                if length(error_msg) > 100
                    error_msg = error_msg[1:97] * "..."
                end
                println("         Error: $error_msg")
            end
        end
        
        optional_tests = get(results, "optional_tests", Dict())
        if !isempty(optional_tests)
            println("       Optional tests:")
            for (test_name, test_result) in optional_tests
                status = get(test_result, "status", "unknown")
                duration = get(test_result, "duration_ms", 0)
                emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
                println("       $emoji $(get(test_result, "test_name", test_name)): $status ($(duration)ms)")
            end
        end
    end
end
