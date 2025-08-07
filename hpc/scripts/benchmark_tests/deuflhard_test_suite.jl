"""
Deuflhard Test Suite for HPC Cluster

Comprehensive testing infrastructure for polynomial construction and critical point finding
using the Deuflhard function as a benchmark. Tracks all parameters and provides detailed
output collection for analysis.

Features:
- Parameter tracking for reproducibility
- BenchmarkTools integration for performance measurement
- Systematic degree and sample size testing
- Critical point analysis and validation
- Structured output collection

Usage:
    julia deuflhard_test_suite.jl [--mode MODE] [--degree DEGREE] [--samples SAMPLES]
    
Modes:
    --quick     : Fast test with minimal parameters
    --standard  : Complete test suite (default)
    --thorough  : Exhaustive testing with all parameter combinations
"""

using Printf
using Dates
using BenchmarkTools
using DataFrames
using CSV

# Global configuration
struct TestConfig
    mode::String
    degrees::Vector{Int}
    sample_sizes::Vector{Int}
    sample_ranges::Vector{Float64}
    centers::Vector{Vector{Float64}}
    precision_types::Vector{Any}
    enable_benchmarks::Bool
    enable_critical_points::Bool
    output_dir::String
    test_id::String
end

# Parse command line arguments
function parse_args()
    mode = "standard"
    custom_degree = nothing
    custom_samples = nothing
    
    for arg in ARGS
        if arg == "--quick"
            mode = "quick"
        elseif arg == "--standard"
            mode = "standard"
        elseif arg == "--thorough"
            mode = "thorough"
        elseif startswith(arg, "--degree=")
            custom_degree = parse(Int, split(arg, "=")[2])
        elseif startswith(arg, "--samples=")
            custom_samples = parse(Int, split(arg, "=")[2])
        end
    end
    
    return mode, custom_degree, custom_samples
end

# Create test configuration based on mode
function create_config(mode::String, custom_degree=nothing, custom_samples=nothing)
    test_id = "deuflhard_$(mode)_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS"))"
    output_dir = "results_$test_id"
    
    if mode == "quick"
        degrees = custom_degree !== nothing ? [custom_degree] : [4, 6]
        sample_sizes = custom_samples !== nothing ? [custom_samples] : [50, 100]
        sample_ranges = [1.2]
        centers = [[0.0, 0.0]]
        precision_types = [Float64Precision]
        enable_benchmarks = false
        enable_critical_points = true
    elseif mode == "thorough"
        degrees = custom_degree !== nothing ? [custom_degree] : [4, 6, 8, 10, 12]
        sample_sizes = custom_samples !== nothing ? [custom_samples] : [50, 100, 200, 400]
        sample_ranges = [1.0, 1.2, 1.5]
        centers = [[0.0, 0.0], [0.1, 0.1], [-0.1, 0.1]]
        precision_types = [Float64Precision, AdaptivePrecision]
        enable_benchmarks = true
        enable_critical_points = true
    else # standard
        degrees = custom_degree !== nothing ? [custom_degree] : [4, 6, 8, 10]
        sample_sizes = custom_samples !== nothing ? [custom_samples] : [100, 200]
        sample_ranges = [1.2]
        centers = [[0.0, 0.0]]
        precision_types = [Float64Precision, AdaptivePrecision]
        enable_benchmarks = true
        enable_critical_points = true
    end
    
    return TestConfig(
        mode, degrees, sample_sizes, sample_ranges, centers, precision_types,
        enable_benchmarks, enable_critical_points, output_dir, test_id
    )
end

# Test result structure
struct TestResult
    test_id::String
    timestamp::DateTime
    function_name::String
    dimension::Int
    degree::Int
    samples::Int
    sample_range::Float64
    center::Vector{Float64}
    precision_type::String
    
    # Polynomial construction results
    construction_time::Float64
    l2_error::Float64
    condition_number::Float64
    n_coefficients::Int
    
    # Critical point results
    n_critical_points::Int
    n_local_minima::Int
    critical_point_time::Float64
    
    # Benchmark results (optional)
    benchmark_construction::Union{Nothing, BenchmarkTools.Trial}
    benchmark_critical_points::Union{Nothing, BenchmarkTools.Trial}
    
    # Additional metadata
    julia_version::String
    threads::Int
    hostname::String
end

# Main test execution function
function run_single_test(config::TestConfig, degree::Int, samples::Int, 
                        sample_range::Float64, center::Vector{Float64}, 
                        precision_type)
    
    println("🧪 Testing: degree=$degree, samples=$samples, range=$sample_range, precision=$precision_type")
    
    # Create test input with parameter tracking
    TR = test_input(
        Deuflhard,
        dim = 2,
        center = center,
        sample_range = sample_range,
        GN = samples,
        tolerance = nothing
    )
    
    println("   ✅ test_input created: $(TR.GN) samples, center=$(TR.center), range=$(TR.sample_range)")
    
    # Polynomial construction with timing
    construction_start = time()
    if config.enable_benchmarks
        benchmark_construction = @benchmark Constructor($TR, $degree, precision=$precision_type, verbose=0)
        pol = Constructor(TR, degree, precision=precision_type, verbose=0)
        construction_time = minimum(benchmark_construction.times) / 1e9  # Convert to seconds
    else
        pol = Constructor(TR, degree, precision=precision_type, verbose=0)
        construction_time = time() - construction_start
        benchmark_construction = nothing
    end
    
    println("   ✅ Polynomial constructed: L2 error = $(@sprintf("%.2e", pol.nrm))")
    
    # Critical point finding
    n_critical_points = 0
    n_local_minima = 0
    critical_point_time = 0.0
    benchmark_critical_points = nothing
    
    if config.enable_critical_points
        try
            @polyvar x[1:2]
            
            critical_start = time()
            if config.enable_benchmarks
                benchmark_critical_points = @benchmark begin
                    solutions = solve_polynomial_system($x, 2, $degree, $(pol.coeffs))
                    df_critical = process_crit_pts(solutions, Deuflhard, $TR)
                    df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, $TR, enable_hessian=false)
                    (nrow(df_critical), nrow(df_min))
                end
                
                # Run once more to get actual results
                solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
                df_critical = process_crit_pts(solutions, Deuflhard, TR)
                df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, TR, enable_hessian=false)
                
                n_critical_points = nrow(df_critical)
                n_local_minima = nrow(df_min)
                critical_point_time = minimum(benchmark_critical_points.times) / 1e9
            else
                solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
                df_critical = process_crit_pts(solutions, Deuflhard, TR)
                df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, TR, enable_hessian=false)
                
                n_critical_points = nrow(df_critical)
                n_local_minima = nrow(df_min)
                critical_point_time = time() - critical_start
            end
            
            println("   ✅ Critical points: $n_critical_points total, $n_local_minima local minima")
            
        catch e
            println("   ⚠️  Critical point analysis failed: $e")
        end
    end
    
    # Create test result
    result = TestResult(
        config.test_id,
        now(),
        "Deuflhard",
        2,
        degree,
        samples,
        sample_range,
        center,
        string(precision_type),
        construction_time,
        pol.nrm,
        pol.cond_vandermonde,
        length(pol.coeffs),
        n_critical_points,
        n_local_minima,
        critical_point_time,
        benchmark_construction,
        benchmark_critical_points,
        string(VERSION),
        Threads.nthreads(),
        gethostname()
    )
    
    return result
end

# Save results to files
function save_results(config::TestConfig, results::Vector{TestResult})
    # Create output directory
    mkpath(config.output_dir)
    
    # Convert results to DataFrame for easy analysis
    df = DataFrame(
        test_id = [r.test_id for r in results],
        timestamp = [r.timestamp for r in results],
        function_name = [r.function_name for r in results],
        dimension = [r.dimension for r in results],
        degree = [r.degree for r in results],
        samples = [r.samples for r in results],
        sample_range = [r.sample_range for r in results],
        center_x = [r.center[1] for r in results],
        center_y = [r.center[2] for r in results],
        precision_type = [r.precision_type for r in results],
        construction_time = [r.construction_time for r in results],
        l2_error = [r.l2_error for r in results],
        condition_number = [r.condition_number for r in results],
        n_coefficients = [r.n_coefficients for r in results],
        n_critical_points = [r.n_critical_points for r in results],
        n_local_minima = [r.n_local_minima for r in results],
        critical_point_time = [r.critical_point_time for r in results],
        julia_version = [r.julia_version for r in results],
        threads = [r.threads for r in results],
        hostname = [r.hostname for r in results]
    )
    
    # Save main results
    CSV.write(joinpath(config.output_dir, "test_results.csv"), df)
    
    # Save configuration
    config_file = joinpath(config.output_dir, "test_config.txt")
    open(config_file, "w") do f
        println(f, "# Deuflhard Test Suite Configuration")
        println(f, "# Generated: $(now())")
        println(f, "")
        println(f, "test_id: $(config.test_id)")
        println(f, "mode: $(config.mode)")
        println(f, "degrees: $(config.degrees)")
        println(f, "sample_sizes: $(config.sample_sizes)")
        println(f, "sample_ranges: $(config.sample_ranges)")
        println(f, "centers: $(config.centers)")
        println(f, "precision_types: $(config.precision_types)")
        println(f, "enable_benchmarks: $(config.enable_benchmarks)")
        println(f, "enable_critical_points: $(config.enable_critical_points)")
        println(f, "julia_version: $(VERSION)")
        println(f, "threads: $(Threads.nthreads())")
        println(f, "hostname: $(gethostname())")
    end
    
    # Save benchmark data if available
    if config.enable_benchmarks
        benchmark_file = joinpath(config.output_dir, "benchmark_data.txt")
        open(benchmark_file, "w") do f
            println(f, "# Benchmark Results")
            println(f, "# Generated: $(now())")
            println(f, "")
            
            for (i, result) in enumerate(results)
                println(f, "## Test $i: degree=$(result.degree), samples=$(result.samples)")
                
                if result.benchmark_construction !== nothing
                    println(f, "Construction benchmark:")
                    println(f, "  Min time: $(minimum(result.benchmark_construction.times) / 1e9) seconds")
                    println(f, "  Mean time: $(mean(result.benchmark_construction.times) / 1e9) seconds")
                    println(f, "  Memory: $(result.benchmark_construction.memory) bytes")
                    println(f, "  Allocations: $(result.benchmark_construction.allocs)")
                end
                
                if result.benchmark_critical_points !== nothing
                    println(f, "Critical points benchmark:")
                    println(f, "  Min time: $(minimum(result.benchmark_critical_points.times) / 1e9) seconds")
                    println(f, "  Mean time: $(mean(result.benchmark_critical_points.times) / 1e9) seconds")
                    println(f, "  Memory: $(result.benchmark_critical_points.memory) bytes")
                    println(f, "  Allocations: $(result.benchmark_critical_points.allocs)")
                end
                
                println(f, "")
            end
        end
    end
    
    println("📁 Results saved to: $(config.output_dir)")
    println("   - test_results.csv: Main results table")
    println("   - test_config.txt: Test configuration")
    if config.enable_benchmarks
        println("   - benchmark_data.txt: Detailed benchmark results")
    end
end

# Main execution function
function main()
    println("🚀 DEUFLHARD TEST SUITE FOR HPC CLUSTER")
    println("=" ^ 50)
    println("Started: $(now())")
    println("Julia version: $(VERSION)")
    println("Threads: $(Threads.nthreads())")
    println("Hostname: $(gethostname())")
    println()

    # Parse arguments and create configuration
    mode, custom_degree, custom_samples = parse_args()
    config = create_config(mode, custom_degree, custom_samples)

    println("📋 Test Configuration:")
    println("   Mode: $(config.mode)")
    println("   Degrees: $(config.degrees)")
    println("   Sample sizes: $(config.sample_sizes)")
    println("   Sample ranges: $(config.sample_ranges)")
    println("   Centers: $(config.centers)")
    println("   Precision types: $(config.precision_types)")
    println("   Benchmarks enabled: $(config.enable_benchmarks)")
    println("   Critical points enabled: $(config.enable_critical_points)")
    println("   Output directory: $(config.output_dir)")
    println()

    # Load required packages and modules
    println("📦 Loading required packages...")
    try
        # Load essential packages
        using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
        using DynamicPolynomials, MultivariatePolynomials
        using TimerOutputs, TOML
        println("   ✅ Essential packages loaded")

        # Define PrecisionType enum
        @enum PrecisionType begin
            Float64Precision
            RationalPrecision
            BigFloatPrecision
            BigIntPrecision
            AdaptivePrecision
        end
        println("   ✅ PrecisionType enum defined")

        # Define TimerOutput instance
        global _TO = TimerOutputs.TimerOutput()
        println("   ✅ TimerOutput instance created")

        # Load Globtim modules
        include("../../../src/BenchmarkFunctions.jl")
        include("../../../src/LibFunctions.jl")
        include("../../../src/Samples.jl")
        include("../../../src/Structures.jl")
        println("   ✅ Globtim modules loaded")

        # Test Deuflhard function
        test_point = [0.5, 0.5]
        test_value = Deuflhard(test_point)
        println("   ✅ Deuflhard function test: f($test_point) = $test_value")

    catch e
        println("   ❌ Package loading failed: $e")
        println("   This may indicate missing dependencies or module issues.")
        return 1
    end

    println()

    # Calculate total number of tests
    total_tests = length(config.degrees) * length(config.sample_sizes) *
                  length(config.sample_ranges) * length(config.centers) *
                  length(config.precision_types)

    println("🧪 Executing $total_tests tests...")
    println()

    # Run all test combinations
    results = TestResult[]
    test_count = 0
    start_time = time()

    for degree in config.degrees
        for samples in config.sample_sizes
            for sample_range in config.sample_ranges
                for center in config.centers
                    for precision_type in config.precision_types
                        test_count += 1

                        println("[$test_count/$total_tests] Testing combination:")
                        println("   Degree: $degree, Samples: $samples, Range: $sample_range")
                        println("   Center: $center, Precision: $precision_type")

                        try
                            result = run_single_test(config, degree, samples, sample_range, center, precision_type)
                            push!(results, result)

                            println("   ✅ Test completed successfully")
                            println("      Construction time: $(@sprintf("%.3f", result.construction_time))s")
                            println("      L2 error: $(@sprintf("%.2e", result.l2_error))")
                            println("      Critical points: $(result.n_critical_points) ($(result.n_local_minima) minima)")

                        catch e
                            println("   ❌ Test failed: $e")
                            println("      Continuing with next test...")
                        end

                        println()
                    end
                end
            end
        end
    end

    total_time = time() - start_time

    # Summary
    println("📊 TEST SUITE SUMMARY")
    println("=" ^ 30)
    println("Total tests planned: $total_tests")
    println("Tests completed: $(length(results))")
    println("Success rate: $(@sprintf("%.1f", 100 * length(results) / total_tests))%")
    println("Total execution time: $(@sprintf("%.2f", total_time)) seconds")
    println("Average time per test: $(@sprintf("%.2f", total_time / max(1, length(results)))) seconds")
    println()

    if !isempty(results)
        # Quick analysis
        construction_times = [r.construction_time for r in results]
        l2_errors = [r.l2_error for r in results]
        critical_counts = [r.n_critical_points for r in results]

        println("📈 QUICK ANALYSIS")
        println("Construction times: min=$(@sprintf("%.3f", minimum(construction_times)))s, max=$(@sprintf("%.3f", maximum(construction_times)))s, mean=$(@sprintf("%.3f", mean(construction_times)))s")
        println("L2 errors: min=$(@sprintf("%.2e", minimum(l2_errors))), max=$(@sprintf("%.2e", maximum(l2_errors))), mean=$(@sprintf("%.2e", mean(l2_errors)))")
        println("Critical points: min=$(minimum(critical_counts)), max=$(maximum(critical_counts)), mean=$(@sprintf("%.1f", mean(critical_counts)))")
        println()

        # Save results
        save_results(config, results)

        println("🎉 TEST SUITE COMPLETED SUCCESSFULLY!")
        println("Results available in: $(config.output_dir)")

        return 0
    else
        println("❌ NO TESTS COMPLETED SUCCESSFULLY")
        println("Check error messages above for debugging information.")
        return 1
    end
end

# Execute main function if script is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
