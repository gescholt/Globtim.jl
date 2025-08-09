"""
BenchmarkTools Integration for HPC Performance Tracking

This module provides comprehensive performance tracking capabilities
for Globtim HPC computations using BenchmarkTools.jl.
"""

# Load dependencies with graceful fallback
const BENCHMARKTOOLS_AVAILABLE = try
    using BenchmarkTools
    true
catch
    @warn "BenchmarkTools not available - using basic timing fallback"
    false
end

using JSON3
using Statistics
using Dates
using Printf

# Load polynomial system dependencies
using DynamicPolynomials

# Load JSON I/O infrastructure
include("json_io.jl")

"""
    benchmark_constructor(TR, degree::Int; basis=:chebyshev, precision=Float64, 
                         samples=5, seconds=10) -> Dict

Benchmark polynomial construction with detailed performance metrics.
"""
function benchmark_constructor(TR, degree::Int; basis=:chebyshev, precision=Float64Precision,
                              samples=5, seconds=10)
    if BENCHMARKTOOLS_AVAILABLE
        println("🔧 Benchmarking Constructor with BenchmarkTools...")
        
        # Run benchmark
        benchmark_result = @benchmark Constructor($TR, $degree, basis=$basis, precision=$precision) samples=samples seconds=seconds
        
        # Extract detailed metrics
        times = benchmark_result.times / 1e9  # Convert to seconds
        
        performance_data = Dict(
            "benchmark_type" => "detailed",
            "tool" => "BenchmarkTools",
            "samples" => length(times),
            "timing_stats" => Dict(
                "mean_time" => mean(times),
                "median_time" => median(times),
                "std_time" => std(times),
                "min_time" => minimum(times),
                "max_time" => maximum(times),
                "q25_time" => quantile(times, 0.25),
                "q75_time" => quantile(times, 0.75)
            ),
            "memory_stats" => Dict(
                "allocations" => benchmark_result.allocs,
                "memory_bytes" => benchmark_result.memory
            ),
            "gc_stats" => Dict(
                "gc_time" => benchmark_result.gctimes / 1e9
            )
        )
        
        @printf "  ⏱️  Mean time: %.4f ± %.4f seconds\\n" mean(times) std(times)
        @printf "  💾 Memory: %.2f MB (%d allocations)\\n" (benchmark_result.memory / 1024^2) benchmark_result.allocs
        
    else
        println("🔧 Benchmarking Constructor with basic timing...")
        
        # Fallback to basic timing
        times = Float64[]
        for i in 1:samples
            time_taken = @elapsed Constructor(TR, degree, basis=basis, precision=precision)
            push!(times, time_taken)
        end
        
        performance_data = Dict(
            "benchmark_type" => "basic",
            "tool" => "basic_timing",
            "samples" => length(times),
            "timing_stats" => Dict(
                "mean_time" => mean(times),
                "std_time" => std(times),
                "min_time" => minimum(times),
                "max_time" => maximum(times)
            )
        )
        
        @printf "  ⏱️  Mean time: %.4f ± %.4f seconds\\n" mean(times) std(times)
    end
    
    # Add metadata
    performance_data["metadata"] = Dict(
        "function" => "Constructor",
        "parameters" => Dict(
            "degree" => degree,
            "basis" => string(basis),
            "precision" => string(precision),
            "dimension" => TR.dim
        ),
        "timestamp" => string(now()),
        "julia_version" => string(VERSION),
        "threads" => Threads.nthreads()
    )
    
    return performance_data
end

"""
    benchmark_solve_polynomial_system(x, n::Int, d::Int, coeffs; basis=:chebyshev,
                                     samples=3, seconds=30) -> Dict

Benchmark polynomial system solving with performance tracking.
"""
function benchmark_solve_polynomial_system(x, n::Int, d::Int, coeffs; basis=:chebyshev,
                                          samples=3, seconds=30)
    if BENCHMARKTOOLS_AVAILABLE
        println("🔧 Benchmarking solve_polynomial_system with BenchmarkTools...")
        
        # Run benchmark (fewer samples due to longer computation time)
        benchmark_result = @benchmark solve_polynomial_system($x, $n, $d, $coeffs, basis=$basis) samples=samples seconds=seconds
        
        times = benchmark_result.times / 1e9
        
        performance_data = Dict(
            "benchmark_type" => "detailed",
            "tool" => "BenchmarkTools",
            "samples" => length(times),
            "timing_stats" => Dict(
                "mean_time" => mean(times),
                "median_time" => median(times),
                "std_time" => std(times),
                "min_time" => minimum(times),
                "max_time" => maximum(times)
            ),
            "memory_stats" => Dict(
                "allocations" => benchmark_result.allocs,
                "memory_bytes" => benchmark_result.memory
            )
        )
        
        @printf "  ⏱️  Mean time: %.4f ± %.4f seconds\\n" mean(times) std(times)
        @printf "  💾 Memory: %.2f MB (%d allocations)\\n" (benchmark_result.memory / 1024^2) benchmark_result.allocs
        
    else
        println("🔧 Benchmarking solve_polynomial_system with basic timing...")
        
        times = Float64[]
        for i in 1:samples
            time_taken = @elapsed solve_polynomial_system(x, n, d, coeffs, basis=basis)
            push!(times, time_taken)
        end
        
        performance_data = Dict(
            "benchmark_type" => "basic",
            "tool" => "basic_timing",
            "samples" => length(times),
            "timing_stats" => Dict(
                "mean_time" => mean(times),
                "std_time" => std(times),
                "min_time" => minimum(times),
                "max_time" => maximum(times)
            )
        )
        
        @printf "  ⏱️  Mean time: %.4f ± %.4f seconds\\n" mean(times) std(times)
    end
    
    performance_data["metadata"] = Dict(
        "function" => "solve_polynomial_system",
        "parameters" => Dict(
            "dimension" => n,
            "degree" => d,
            "basis" => string(basis),
            "n_coefficients" => length(coeffs)
        ),
        "timestamp" => string(now())
    )
    
    return performance_data
end

"""
    benchmark_full_workflow(TR, degree::Int; basis=:chebyshev, precision=Float64) -> Dict

Benchmark complete Globtim workflow with detailed performance breakdown.
"""
function benchmark_full_workflow(TR, degree::Int; basis=:chebyshev, precision=Float64Precision)
    println("🚀 Benchmarking Full Globtim Workflow")
    println("=" ^ 40)
    
    workflow_benchmarks = Dict()
    
    # 1. Benchmark Constructor
    constructor_perf = benchmark_constructor(TR, degree, basis=basis, precision=precision, samples=3)
    workflow_benchmarks["constructor"] = constructor_perf
    
    # 2. Build polynomial for solving benchmark
    println("\\n🔧 Building polynomial for solving benchmark...")
    pol = Constructor(TR, degree, basis=basis, precision=precision)
    
    # 3. Benchmark solve_polynomial_system
    @polyvar x[1:TR.dim]
    
    solving_perf = benchmark_solve_polynomial_system(x, TR.dim, degree, pol.coeffs, basis=basis, samples=2)
    workflow_benchmarks["solving"] = solving_perf
    
    # 4. Benchmark process_crit_pts (if solving works)
    try
        real_pts = solve_polynomial_system(x, TR.dim, degree, pol.coeffs, basis=basis)
        
        if !isempty(real_pts)
            if BENCHMARKTOOLS_AVAILABLE
                processing_benchmark = @benchmark process_crit_pts($real_pts, $TR.objective, $TR) samples=3
                times = processing_benchmark.times / 1e9
                
                processing_perf = Dict(
                    "benchmark_type" => "detailed",
                    "timing_stats" => Dict(
                        "mean_time" => mean(times),
                        "std_time" => std(times)
                    ),
                    "memory_stats" => Dict(
                        "allocations" => processing_benchmark.allocs,
                        "memory_bytes" => processing_benchmark.memory
                    )
                )
            else
                time_taken = @elapsed process_crit_pts(real_pts, TR.objective, TR)
                processing_perf = Dict(
                    "benchmark_type" => "basic",
                    "timing_stats" => Dict("mean_time" => time_taken)
                )
            end
            
            workflow_benchmarks["processing"] = processing_perf
            println("  ✅ Processing benchmark completed")
        end
        
    catch e
        println("  ⚠️  Skipping processing benchmark due to solving issue: $e")
        workflow_benchmarks["processing"] = Dict("error" => string(e))
    end
    
    # 5. Calculate total workflow performance
    total_time = sum([
        get(get(workflow_benchmarks["constructor"], "timing_stats", Dict()), "mean_time", 0.0),
        get(get(workflow_benchmarks["solving"], "timing_stats", Dict()), "mean_time", 0.0),
        get(get(get(workflow_benchmarks, "processing", Dict()), "timing_stats", Dict()), "mean_time", 0.0)
    ])
    
    workflow_benchmarks["summary"] = Dict(
        "total_estimated_time" => total_time,
        "workflow_components" => length(workflow_benchmarks) - 1,
        "benchmark_timestamp" => string(now()),
        "test_parameters" => Dict(
            "function" => TR.objective isa Function ? "$(TR.objective)" : "unknown",
            "dimension" => TR.dim,
            "degree" => degree,
            "basis" => string(basis),
            "precision" => string(precision)
        )
    )
    
    @printf "\\n📊 Total Workflow Time: %.4f seconds\\n" total_time
    
    return workflow_benchmarks
end

"""
    save_performance_results(performance_data::Dict, output_dir::String, 
                            computation_id::String) -> String

Save performance benchmarking results to JSON file.
"""
function save_performance_results(performance_data::Dict, output_dir::String, 
                                 computation_id::String)
    mkpath(output_dir)
    
    # Add computation tracking
    performance_data["computation_tracking"] = Dict(
        "computation_id" => computation_id,
        "results_directory" => output_dir,
        "performance_file" => "performance_$(computation_id).json"
    )
    
    # Save to file
    performance_file = joinpath(output_dir, "performance_$(computation_id).json")
    open(performance_file, "w") do f
        JSON3.pretty(f, performance_data)
    end
    
    println("✅ Performance results saved: $performance_file")
    return performance_file
end

"""
    create_hpc_performance_report(performance_files::Vector{String}) -> Dict

Create comprehensive performance report from multiple HPC runs.
"""
function create_hpc_performance_report(performance_files::Vector{String})
    report = Dict(
        "report_metadata" => Dict(
            "report_id" => generate_computation_id(),
            "timestamp" => string(now()),
            "total_files_analyzed" => length(performance_files)
        ),
        "aggregate_performance" => Dict(),
        "scaling_analysis" => Dict(),
        "individual_summaries" => []
    )
    
    # Collect data from all performance files
    constructor_times = Float64[]
    solving_times = Float64[]
    degrees = Int[]
    dimensions = Int[]
    
    for perf_file in performance_files
        try
            perf_data = JSON3.read(read(perf_file, String), Dict)
            
            # Extract timing data
            if haskey(perf_data, "constructor")
                push!(constructor_times, perf_data["constructor"]["timing_stats"]["mean_time"])
            end
            
            if haskey(perf_data, "solving")
                push!(solving_times, perf_data["solving"]["timing_stats"]["mean_time"])
            end
            
            # Extract parameters
            if haskey(perf_data, "summary")
                params = perf_data["summary"]["test_parameters"]
                push!(degrees, get(params, "degree", 0))
                push!(dimensions, get(params, "dimension", 0))
            end
            
            # Store individual summary
            push!(report["individual_summaries"], Dict(
                "file" => basename(perf_file),
                "total_time" => get(get(perf_data, "summary", Dict()), "total_estimated_time", 0.0)
            ))
            
        catch e
            @warn "Failed to process performance file: $perf_file" exception=e
        end
    end
    
    # Compute aggregate statistics
    if !isempty(constructor_times)
        report["aggregate_performance"]["constructor"] = Dict(
            "mean_time" => mean(constructor_times),
            "std_time" => std(constructor_times),
            "min_time" => minimum(constructor_times),
            "max_time" => maximum(constructor_times)
        )
    end
    
    if !isempty(solving_times)
        report["aggregate_performance"]["solving"] = Dict(
            "mean_time" => mean(solving_times),
            "std_time" => std(solving_times),
            "min_time" => minimum(solving_times),
            "max_time" => maximum(solving_times)
        )
    end
    
    # Scaling analysis
    if length(unique(degrees)) > 1 && !isempty(constructor_times)
        report["scaling_analysis"]["degree_scaling"] = analyze_scaling_by_parameter(
            degrees, constructor_times, "degree", "constructor_time"
        )
    end
    
    if length(unique(dimensions)) > 1 && !isempty(constructor_times)
        report["scaling_analysis"]["dimension_scaling"] = analyze_scaling_by_parameter(
            dimensions, constructor_times, "dimension", "constructor_time"
        )
    end
    
    return report
end

"""
    analyze_scaling_by_parameter(param_values::Vector, times::Vector, 
                                param_name::String, metric_name::String) -> Dict

Analyze performance scaling with respect to a parameter.
"""
function analyze_scaling_by_parameter(param_values::Vector, times::Vector, 
                                     param_name::String, metric_name::String)
    # Group by parameter value
    param_groups = Dict()
    for (param, time) in zip(param_values, times)
        if !haskey(param_groups, param)
            param_groups[param] = Float64[]
        end
        push!(param_groups[param], time)
    end
    
    # Compute statistics for each parameter value
    scaling_data = Dict(
        "parameter_name" => param_name,
        "metric_name" => metric_name,
        "parameter_values" => sort(collect(keys(param_groups))),
        "scaling_points" => []
    )
    
    for param_val in sort(collect(keys(param_groups)))
        group_times = param_groups[param_val]
        
        push!(scaling_data["scaling_points"], Dict(
            "parameter_value" => param_val,
            "mean_time" => mean(group_times),
            "std_time" => std(group_times),
            "sample_count" => length(group_times)
        ))
    end
    
    # Estimate scaling relationship (simple linear fit in log space)
    if length(scaling_data["parameter_values"]) >= 2
        param_vals = Float64.(scaling_data["parameter_values"])
        mean_times = [point["mean_time"] for point in scaling_data["scaling_points"]]
        
        # Simple log-log fit: log(time) = a + b*log(param)
        log_params = log.(param_vals)
        log_times = log.(mean_times)
        
        # Linear regression in log space
        n = length(log_params)
        sum_x = sum(log_params)
        sum_y = sum(log_times)
        sum_xy = sum(log_params .* log_times)
        sum_x2 = sum(log_params .^ 2)
        
        b = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x^2)
        a = (sum_y - b * sum_x) / n
        
        scaling_data["scaling_analysis"] = Dict(
            "log_intercept" => a,
            "scaling_exponent" => b,
            "interpretation" => b < 1.5 ? "sublinear" : b < 2.5 ? "quadratic" : "superquadratic"
        )
        
        println("    📈 Scaling exponent: $(round(b, digits=2)) ($(scaling_data["scaling_analysis"]["interpretation"]))")
    end
    
    return scaling_data
end

"""
    benchmark_hpc_job_components(config_file::String) -> Dict

Benchmark all components of an HPC job based on configuration file.
"""
function benchmark_hpc_job_components(config_file::String)
    println("🚀 Comprehensive HPC Job Component Benchmarking")
    println("=" ^ 50)
    
    # Load configuration
    config = load_input_config(config_file)
    
    # Extract parameters
    test_input_config = config["test_input"]
    poly_config = config["polynomial_construction"]
    
    # Create test_input (simplified for benchmarking)
    function_name = test_input_config["function_name"]
    f = eval(Symbol(function_name))  # Get function by name
    
    TR = test_input(f, 
                   dim=test_input_config["dimension"],
                   center=test_input_config["center"],
                   sample_range=test_input_config["sample_range"])
    
    # Benchmark each component
    all_benchmarks = Dict(
        "configuration" => config,
        "benchmarks" => Dict()
    )
    
    # Get precision type safely
    precision_str = poly_config["precision_type"]
    precision_type = if precision_str == "Float64"
        Float64Precision
    elseif precision_str == "AdaptivePrecision"
        AdaptivePrecision
    elseif precision_str == "RationalPrecision"
        RationalPrecision
    elseif precision_str == "BigFloatPrecision"
        BigFloatPrecision
    else
        Float64Precision  # Safe fallback
    end

    # Constructor benchmark
    constructor_bench = benchmark_constructor(
        TR, poly_config["degree"],
        basis=Symbol(poly_config["basis"]),
        precision=precision_type
    )
    all_benchmarks["benchmarks"]["constructor"] = constructor_bench

    # Full workflow benchmark
    workflow_bench = benchmark_full_workflow(
        TR, poly_config["degree"],
        basis=Symbol(poly_config["basis"]),
        precision=precision_type
    )
    all_benchmarks["benchmarks"]["full_workflow"] = workflow_bench
    
    # Save results
    output_dir = "hpc_results/performance_tracking"
    comp_id = config["metadata"]["computation_id"]
    perf_file = save_performance_results(all_benchmarks, output_dir, comp_id)
    
    println("\\n✅ HPC job component benchmarking complete")
    return all_benchmarks, perf_file
end

# Export performance tracking functions
export benchmark_constructor, benchmark_solve_polynomial_system, benchmark_full_workflow
export save_performance_results, create_hpc_performance_report, analyze_scaling_by_parameter
export benchmark_hpc_job_components
