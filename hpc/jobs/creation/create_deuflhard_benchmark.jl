"""
Deuflhard Benchmark Job Creation

Creates comprehensive Deuflhard polynomial construction and critical point finding tests
that integrate with existing HPC job infrastructure.

Follows the pattern of existing job creation scripts in this directory.
"""

using Dates
using Printf

# Test configuration structure
struct DeuflhardTestConfig
    mode::String
    degrees::Vector{Int}
    sample_sizes::Vector{Int}
    sample_ranges::Vector{Float64}
    precision_types::Vector{String}
    enable_benchmarks::Bool
    time_limit::String
    memory::String
    cpus::Int
    description::String
end

# Predefined test configurations
const TEST_CONFIGS = Dict(
    "quick" => DeuflhardTestConfig(
        "quick",
        [4, 6],
        [50, 100],
        [1.2],
        ["Float64Precision"],
        false,
        "00:30:00",
        "32G",
        12,
        "Quick test - basic parameters for fast validation"
    ),
    
    "standard" => DeuflhardTestConfig(
        "standard",
        [4, 6, 8, 10],
        [100, 200],
        [1.2],
        ["Float64Precision", "AdaptivePrecision"],
        true,
        "02:00:00",
        "64G",
        24,
        "Standard test - comprehensive coverage with benchmarking"
    ),
    
    "thorough" => DeuflhardTestConfig(
        "thorough",
        [4, 6, 8, 10, 12],
        [50, 100, 200, 400],
        [1.0, 1.2, 1.5],
        ["Float64Precision", "AdaptivePrecision"],
        true,
        "04:00:00",
        "128G",
        24,
        "Thorough test - all parameter combinations"
    ),
    
    "scaling" => DeuflhardTestConfig(
        "scaling",
        [4, 6, 8, 10, 12, 14],
        [100, 200, 400, 800],
        [1.2],
        ["Float64Precision"],
        true,
        "03:00:00",
        "96G",
        24,
        "Scaling analysis - degree and sample size scaling behavior"
    )
)

function create_julia_test_script(config::DeuflhardTestConfig, job_id::String)
    """Create the Julia script content for the benchmark test"""
    
    return """
# Deuflhard Benchmark Test - Mode: $(config.mode)
# Generated: $(now())
# Job ID: $job_id

println("🚀 DEUFLHARD BENCHMARK TEST - MODE: $(uppercase(config.mode))")
println("=" ^ 60)
println("Job ID: $job_id")
println("Started: \$(now())")
println("Julia version: \$(VERSION)")
println("Threads: \$(Threads.nthreads())")
println()

# Load packages and setup
try
    using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
    using DynamicPolynomials, MultivariatePolynomials, TimerOutputs, TOML
    $(config.enable_benchmarks ? "using BenchmarkTools" : "")
    println("✅ Packages loaded")
    
    # Define PrecisionType enum
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    global _TO = TimerOutputs.TimerOutput()
    
    # Load Globtim modules
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    println("✅ Globtim modules loaded")
    
    # Test configuration
    degrees = $(config.degrees)
    sample_sizes = $(config.sample_sizes)
    sample_ranges = $(config.sample_ranges)
    precision_types = [$(join([p for p in config.precision_types], ", "))]
    
    println("📋 Test Configuration:")
    println("   Degrees: \$degrees")
    println("   Sample sizes: \$sample_sizes")
    println("   Sample ranges: \$sample_ranges")
    println("   Precision types: \$precision_types")
    println("   Benchmarks enabled: $(config.enable_benchmarks)")
    println()
    
    # Results collection
    results = []
    test_count = 0
    total_tests = length(degrees) * length(sample_sizes) * length(sample_ranges) * length(precision_types)
    
    println("🧪 Running \$total_tests tests...")
    println()
    
    for degree in degrees
        for samples in sample_sizes
            for sample_range in sample_ranges
                for precision_type in precision_types
                    test_count += 1
                    
                    println("[\$test_count/\$total_tests] Testing: degree=\$degree, samples=\$samples, range=\$sample_range, precision=\$precision_type")
                    
                    try
                        # Create test input with full parameter tracking
                        TR = test_input(
                            Deuflhard,
                            dim = 2,
                            center = [0.0, 0.0],
                            sample_range = sample_range,
                            GN = samples,
                            tolerance = nothing
                        )
                        
                        # Polynomial construction with timing
                        construction_start = time()
                        $(config.enable_benchmarks ? 
                          "benchmark_construction = @benchmark Constructor(\$TR, \$degree, precision=\$precision_type, verbose=0) samples=3 evals=1" :
                          "")
                        pol = Constructor(TR, degree, precision=precision_type, verbose=0)
                        construction_time = time() - construction_start
                        
                        # Critical point finding
                        @polyvar x[1:2]
                        critical_start = time()
                        $(config.enable_benchmarks ?
                          "benchmark_critical = @benchmark begin
                               solutions = solve_polynomial_system(\$x, 2, \$degree, \$(pol.coeffs))
                               df_critical = process_crit_pts(solutions, Deuflhard, \$TR)
                               df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, \$TR, enable_hessian=false)
                               (nrow(df_critical), nrow(df_min))
                           end samples=2 evals=1" :
                          "")
                        
                        solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
                        df_critical = process_crit_pts(solutions, Deuflhard, TR)
                        df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, TR, enable_hessian=false)
                        critical_time = time() - critical_start
                        
                        # Record results with comprehensive parameter tracking
                        result = Dict(
                            "job_id" => "$job_id",
                            "test_mode" => "$(config.mode)",
                            "timestamp" => string(now()),
                            "function_name" => "Deuflhard",
                            "dimension" => 2,
                            "degree" => degree,
                            "samples" => samples,
                            "sample_range" => sample_range,
                            "center_x" => 0.0,
                            "center_y" => 0.0,
                            "precision_type" => string(precision_type),
                            "construction_time" => construction_time,
                            "l2_error" => pol.nrm,
                            "condition_number" => pol.cond_vandermonde,
                            "n_coefficients" => length(pol.coeffs),
                            "n_critical_points" => nrow(df_critical),
                            "n_local_minima" => nrow(df_min),
                            "critical_point_time" => critical_time,
                            $(config.enable_benchmarks ? 
                              "\"benchmark_construction_min_time\" => minimum(benchmark_construction.times) / 1e9,
                               \"benchmark_construction_memory\" => benchmark_construction.memory,
                               \"benchmark_critical_min_time\" => minimum(benchmark_critical.times) / 1e9,
                               \"benchmark_critical_memory\" => benchmark_critical.memory," : "")
                            "julia_version" => string(VERSION),
                            "threads" => Threads.nthreads(),
                            "hostname" => gethostname()
                        )
                        
                        push!(results, result)
                        
                        println("   ✅ Success: L2=\$(@sprintf("%.2e", pol.nrm)), critical_pts=\$(nrow(df_critical)), minima=\$(nrow(df_min))")
                        $(config.enable_benchmarks ? 
                          "println(\"      Benchmark: construction=\$(@sprintf(\"%.3f\", minimum(benchmark_construction.times) / 1e9))s, critical=\$(@sprintf(\"%.3f\", minimum(benchmark_critical.times) / 1e9))s\")" : "")
                        
                    catch e
                        println("   ❌ Failed: \$e")
                        # Still record the failure for analysis
                        failure_result = Dict(
                            "job_id" => "$job_id",
                            "test_mode" => "$(config.mode)",
                            "timestamp" => string(now()),
                            "degree" => degree,
                            "samples" => samples,
                            "sample_range" => sample_range,
                            "precision_type" => string(precision_type),
                            "error" => string(e),
                            "status" => "FAILED"
                        )
                        push!(results, failure_result)
                    end
                    
                    println()
                end
            end
        end
    end
    
    # Save comprehensive results
    if !isempty(results)
        results_dir = "deuflhard_results_$job_id"
        mkpath(results_dir)
        
        # Convert to DataFrame and save
        df = DataFrame(results)
        CSV.write("\$results_dir/test_results.csv", df)
        
        # Save detailed configuration
        open("\$results_dir/test_config.txt", "w") do f
            println(f, "# Deuflhard Benchmark Test Configuration")
            println(f, "# Generated: \$(now())")
            println(f, "")
            println(f, "job_id: $job_id")
            println(f, "mode: $(config.mode)")
            println(f, "description: $(config.description)")
            println(f, "timestamp: \$(now())")
            println(f, "")
            println(f, "# Test Parameters")
            println(f, "degrees: \$degrees")
            println(f, "sample_sizes: \$sample_sizes")
            println(f, "sample_ranges: \$sample_ranges")
            println(f, "precision_types: \$precision_types")
            println(f, "enable_benchmarks: $(config.enable_benchmarks)")
            println(f, "")
            println(f, "# System Information")
            println(f, "julia_version: \$(VERSION)")
            println(f, "threads: \$(Threads.nthreads())")
            println(f, "hostname: \$(gethostname())")
            println(f, "")
            println(f, "# Resource Allocation")
            println(f, "time_limit: $(config.time_limit)")
            println(f, "memory: $(config.memory)")
            println(f, "cpus: $(config.cpus)")
        end
        
        # Results summary
        successful_tests = filter(r -> !haskey(r, "status") || r["status"] != "FAILED", results)
        
        println("📊 RESULTS SUMMARY:")
        println("   Tests completed: \$(length(successful_tests))/\$total_tests")
        println("   Success rate: \$(@sprintf("%.1f", 100 * length(successful_tests) / total_tests))%")
        println("   Results saved to: \$results_dir/")
        
        if !isempty(successful_tests)
            # Quick analysis
            construction_times = [r["construction_time"] for r in successful_tests if haskey(r, "construction_time")]
            l2_errors = [r["l2_error"] for r in successful_tests if haskey(r, "l2_error")]
            critical_counts = [r["n_critical_points"] for r in successful_tests if haskey(r, "n_critical_points")]
            
            if !isempty(construction_times)
                println("   Construction time: min=\$(@sprintf("%.3f", minimum(construction_times)))s, max=\$(@sprintf("%.3f", maximum(construction_times)))s, mean=\$(@sprintf("%.3f", mean(construction_times)))s")
            end
            if !isempty(l2_errors)
                println("   L2 errors: min=\$(@sprintf("%.2e", minimum(l2_errors))), max=\$(@sprintf("%.2e", maximum(l2_errors))), mean=\$(@sprintf("%.2e", mean(l2_errors)))")
            end
            if !isempty(critical_counts)
                println("   Critical points: min=\$(minimum(critical_counts)), max=\$(maximum(critical_counts)), mean=\$(@sprintf("%.1f", mean(critical_counts)))")
            end
        end
        
        println("\\n🎉 DEUFLHARD BENCHMARK COMPLETED!")
        println("Results available for analysis in: \$results_dir/")
    else
        println("❌ No tests completed successfully")
        exit(1)
    end
    
catch e
    println("❌ Benchmark failed: \$e")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    exit(1)
end
"""
end

function create_slurm_job(config::DeuflhardTestConfig, job_id::String)
    """Create SLURM job script"""
    
    julia_script = create_julia_test_script(config, job_id)
    
    return """#!/bin/bash
#SBATCH --job-name=deuflhard_$(config.mode)
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$(config.cpus)
#SBATCH --mem=$(config.memory)
#SBATCH --time=$(config.time_limit)
#SBATCH --output=deuflhard_$(config.mode)_%j.out
#SBATCH --error=deuflhard_$(config.mode)_%j.err

echo "=== Deuflhard Benchmark Test ==="
echo "Mode: $(config.mode)"
echo "Description: $(config.description)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Test ID: $job_id"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: \$SLURM_CPUS_PER_TASK"
echo "Memory: \$SLURM_MEM_PER_NODE MB"
echo "Start time: \$(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="\$HOME/globtim_hpc/.julia:\$JULIA_DEPOT_PATH"

# Change to working directory
cd \$HOME/globtim_hpc

echo "=== Environment ==="
echo "Julia threads: \$JULIA_NUM_THREADS"
echo "Julia depot: \$JULIA_DEPOT_PATH"
echo "Working directory: \$(pwd)"
echo "Available space: \$(df -h . | tail -1 | awk '{print \$4}')"
echo ""

# Run the benchmark
echo "=== Starting Deuflhard Benchmark ==="
/sw/bin/julia --project=. -e '$julia_script'

JULIA_EXIT_CODE=\$?

echo ""
echo "=== Job Completed ==="
echo "End time: \$(date)"
echo "Duration: \$SECONDS seconds"
echo "Julia exit code: \$JULIA_EXIT_CODE"

# Copy results to permanent location if successful
if [ \$JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Benchmark completed successfully"
    if [ -d "deuflhard_results_$job_id" ]; then
        echo "📁 Results available in: deuflhard_results_$job_id/"
        ls -la deuflhard_results_$job_id/
    fi
else
    echo "❌ Benchmark failed with exit code \$JULIA_EXIT_CODE"
fi

exit \$JULIA_EXIT_CODE
"""
end

function create_deuflhard_benchmark_job(mode::String = "standard")
    """Main function to create Deuflhard benchmark job"""
    
    if !haskey(TEST_CONFIGS, mode)
        println("❌ Unknown test mode: $mode")
        println("Available modes: $(join(keys(TEST_CONFIGS), ", "))")
        return nothing
    end
    
    config = TEST_CONFIGS[mode]
    job_id = string(uuid4())[1:8]  # Short UUID for job identification
    
    println("🚀 Creating Deuflhard Benchmark Job")
    println("=" ^ 40)
    println("Mode: $mode")
    println("Description: $(config.description)")
    println("Job ID: $job_id")
    println()
    
    # Create job script
    slurm_script = create_slurm_job(config, job_id)
    
    # Write to file
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    filename = "deuflhard_$(mode)_$(timestamp)_$(job_id).slurm"
    
    open(filename, "w") do f
        write(f, slurm_script)
    end
    
    println("📄 Job script created: $filename")
    println()
    println("📋 Test Configuration:")
    println("   Degrees: $(config.degrees)")
    println("   Sample sizes: $(config.sample_sizes)")
    println("   Sample ranges: $(config.sample_ranges)")
    println("   Precision types: $(config.precision_types)")
    println("   Benchmarks: $(config.enable_benchmarks)")
    println("   Time limit: $(config.time_limit)")
    println("   Memory: $(config.memory)")
    println("   CPUs: $(config.cpus)")
    println()
    
    total_tests = length(config.degrees) * length(config.sample_sizes) * 
                  length(config.sample_ranges) * length(config.precision_types)
    println("🧪 Total tests to run: $total_tests")
    println()
    
    println("🚀 To submit this job:")
    println("   scp $filename scholten@falcon:~/globtim_hpc/")
    println("   ssh scholten@falcon 'cd ~/globtim_hpc && sbatch $filename'")
    println()
    println("📊 Monitor with existing tools:")
    println("   python hpc/monitoring/python/slurm_monitor.py --job [JOB_ID]")
    println()
    
    return filename, job_id
end

# Command line interface
function main()
    if length(ARGS) == 0
        mode = "standard"
    else
        mode = ARGS[1]
    end
    
    if mode == "--help" || mode == "-h"
        println("Deuflhard Benchmark Job Creator")
        println()
        println("Usage: julia create_deuflhard_benchmark.jl [MODE]")
        println()
        println("Available modes:")
        for (name, config) in TEST_CONFIGS
            println("  $name: $(config.description)")
            println("    Time: $(config.time_limit), Memory: $(config.memory), CPUs: $(config.cpus)")
            println("    Tests: $(length(config.degrees) * length(config.sample_sizes) * length(config.sample_ranges) * length(config.precision_types))")
            println()
        end
        return
    end
    
    create_deuflhard_benchmark_job(mode)
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
