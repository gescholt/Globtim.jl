#!/usr/bin/env julia
"""
Performance regression detection for Globtim.jl CI/CD pipeline
Compares current performance against baseline and detects regressions.
"""

using Pkg
Pkg.activate(".")
using Globtim, DynamicPolynomials, JSON, Statistics, TimerOutputs

# Configuration
const BASELINE_FILE = "performance_baseline.json"
const RESULTS_FILE = "performance_results.json"
const REGRESSION_THRESHOLD = 0.15  # 15% slowdown threshold
const MIN_SAMPLES = 3

"""
Run standardized performance benchmarks
"""
function run_benchmarks()
    println("🚀 Running performance benchmarks...")
    
    benchmarks = Dict()
    
    # Benchmark 1: 2D Deuflhard optimization
    println("  📊 Benchmark 1: 2D Deuflhard")
    f = Deuflhard
    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
    
    times = Float64[]
    for i in 1:MIN_SAMPLES
        time_taken = @elapsed begin
            pol = Constructor(TR, 8)
            @polyvar x[1:2]
            solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
            df = process_crit_pts(solutions, f, TR)
        end
        push!(times, time_taken)
    end
    
    benchmarks["deuflhard_2d"] = Dict(
        "mean_time" => mean(times),
        "std_time" => std(times),
        "min_time" => minimum(times),
        "max_time" => maximum(times),
        "samples" => length(times)
    )
    
    # Benchmark 2: 3D optimization with higher degree
    println("  📊 Benchmark 2: 3D Higher Degree")
    TR3 = test_input(f, dim=3, center=zeros(3), sample_range=1.2)
    
    times = Float64[]
    for i in 1:MIN_SAMPLES
        time_taken = @elapsed begin
            pol = Constructor(TR3, 6)  # Lower degree for 3D
            @polyvar x[1:3]
            solutions = solve_polynomial_system(x, 3, 6, pol.coeffs)
        end
        push!(times, time_taken)
    end
    
    benchmarks["optimization_3d"] = Dict(
        "mean_time" => mean(times),
        "std_time" => std(times),
        "min_time" => minimum(times),
        "max_time" => maximum(times),
        "samples" => length(times)
    )
    
    # Benchmark 3: Polynomial construction only
    println("  📊 Benchmark 3: Polynomial Construction")
    times = Float64[]
    for i in 1:MIN_SAMPLES
        time_taken = @elapsed pol = Constructor(TR, 10)
        push!(times, time_taken)
    end
    
    benchmarks["polynomial_construction"] = Dict(
        "mean_time" => mean(times),
        "std_time" => std(times),
        "min_time" => minimum(times),
        "max_time" => maximum(times),
        "samples" => length(times)
    )
    
    # Add system information
    benchmarks["system_info"] = Dict(
        "julia_version" => string(VERSION),
        "num_threads" => Threads.nthreads(),
        "timestamp" => string(now()),
        "commit_sha" => get(ENV, "CI_COMMIT_SHA", "unknown"),
        "branch" => get(ENV, "CI_COMMIT_BRANCH", "unknown")
    )
    
    return benchmarks
end

"""
Load baseline performance data
"""
function load_baseline()
    if !isfile(BASELINE_FILE)
        println("⚠️  No baseline file found at $BASELINE_FILE")
        return nothing
    end
    
    try
        return JSON.parsefile(BASELINE_FILE)
    catch e
        println("❌ Error loading baseline: $e")
        return nothing
    end
end

"""
Compare current results against baseline
"""
function check_regression(current, baseline)
    if baseline === nothing
        println("📝 No baseline available - saving current results as baseline")
        return false, Dict()
    end
    
    regressions = Dict()
    has_regression = false
    
    println("\n🔍 Checking for performance regressions...")
    
    for (benchmark_name, current_data) in current
        if benchmark_name == "system_info"
            continue
        end
        
        if !haskey(baseline, benchmark_name)
            println("  ⚠️  New benchmark: $benchmark_name")
            continue
        end
        
        baseline_time = baseline[benchmark_name]["mean_time"]
        current_time = current_data["mean_time"]
        
        # Calculate relative change
        relative_change = (current_time - baseline_time) / baseline_time
        
        status = if relative_change > REGRESSION_THRESHOLD
            has_regression = true
            regressions[benchmark_name] = relative_change
            "❌ REGRESSION"
        elseif relative_change > 0.05  # 5% warning threshold
            "⚠️  SLOWER"
        elseif relative_change < -0.05  # 5% improvement
            "✅ FASTER"
        else
            "✅ STABLE"
        end
        
        println("  $status $benchmark_name: $(round(baseline_time, digits=3))s → $(round(current_time, digits=3))s ($(round(relative_change*100, digits=1))%)")
    end
    
    return has_regression, regressions
end

"""
Generate performance report
"""
function generate_report(current, baseline, has_regression, regressions)
    report = Dict(
        "timestamp" => string(now()),
        "commit_sha" => get(ENV, "CI_COMMIT_SHA", "unknown"),
        "branch" => get(ENV, "CI_COMMIT_BRANCH", "unknown"),
        "has_regression" => has_regression,
        "regressions" => regressions,
        "current_results" => current,
        "baseline_results" => baseline
    )
    
    # Save detailed report
    open("performance_report.json", "w") do f
        JSON.print(f, report, 2)
    end
    
    # Generate summary for GitLab
    if has_regression
        println("\n❌ PERFORMANCE REGRESSION DETECTED!")
        println("The following benchmarks show significant slowdowns:")
        for (name, change) in regressions
            println("  - $name: $(round(change*100, digits=1))% slower")
        end
        println("\nSee performance_report.json for detailed analysis.")
        return 1  # Exit code 1 for regression
    else
        println("\n✅ No performance regressions detected")
        return 0  # Exit code 0 for success
    end
end

"""
Update baseline if this is a main branch build
"""
function update_baseline_if_needed(current)
    branch = get(ENV, "CI_COMMIT_BRANCH", "")
    if branch == "main" && get(ENV, "UPDATE_BASELINE", "false") == "true"
        println("📝 Updating performance baseline...")
        open(BASELINE_FILE, "w") do f
            JSON.print(f, current, 2)
        end
        println("✅ Baseline updated")
    end
end

# Main execution
function main()
    println("🎯 Globtim.jl Performance Regression Check")
    println("=" ^ 50)
    
    # Run benchmarks
    current_results = run_benchmarks()
    
    # Save current results
    open(RESULTS_FILE, "w") do f
        JSON.print(f, current_results, 2)
    end
    
    # Load baseline and check for regressions
    baseline = load_baseline()
    has_regression, regressions = check_regression(current_results, baseline)
    
    # Generate report
    exit_code = generate_report(current_results, baseline, has_regression, regressions)
    
    # Update baseline if needed
    update_baseline_if_needed(current_results)
    
    exit(exit_code)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
