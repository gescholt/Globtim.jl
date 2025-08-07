#!/bin/bash
#SBATCH --job-name=quick_test_dc98cad7
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/logs/slurm_%j.out
#SBATCH --error=/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/logs/slurm_%j.err

echo "=== Globtim HPC Job with JSON Tracking ==="
echo "Job Name: quick_test_dc98cad7"
echo "Computation ID: dc98cad7"
echo "Function: Deuflhard"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo "Output directory: /Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

# Verify input configuration exists
INPUT_CONFIG="/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/input_config.json"
if [ ! -f "$INPUT_CONFIG" ]; then
    echo "❌ ERROR: Input configuration file not found: $INPUT_CONFIG"
    exit 1
fi

echo "✅ Input configuration found: $INPUT_CONFIG"
echo ""

# Run the computation with JSON tracking
echo "=== Starting Globtim Computation with JSON Tracking ==="
/sw/bin/julia --project=. -e '
# Load required packages
using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using DataFrames
using JSON3
using Dates
using CSV
using Printf

# Load JSON I/O utilities
include("hpc/infrastructure/json_io.jl")

println("🚀 Starting Globtim computation with JSON tracking")
println("Computation ID: dc98cad7")
println("Julia version: $(VERSION)")
println("Threads: $(Threads.nthreads())")
println()

# Load input configuration
input_config_path = "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/input_config.json"
println("📋 Loading input configuration from: $input_config_path")

try
    input_config = load_input_config(input_config_path)
    println("✅ Input configuration loaded successfully")
    
    # Validate configuration
    if !validate_input_config(input_config)
        error("Invalid input configuration")
    end
    println("✅ Input configuration validated")
    
    # Extract parameters
    test_params = input_config["test_input"]
    poly_params = input_config["polynomial_construction"]
    analysis_params = get(input_config, "critical_point_analysis", Dict())
    
    println("\n📊 Configuration Summary:")
    println("   Function: $(test_params["function_name"])")
    println("   Dimension: $(test_params["dimension"])")
    println("   Degree: $(poly_params["degree"])")
    println("   Basis: $(poly_params["basis"])")
    println("   Samples: $(test_params["GN"])")
    println("   Hessian analysis: $(get(analysis_params, "enable_hessian", true))")
    println()
    
    # Record start time
    start_time = now()
    timings = Dict{String, Float64}()
    
    # Step 1: Create test input
    println("🔧 Step 1: Creating test input...")
    step1_start = time()
    
    # Get the function (this is a simplified approach - in practice you might need a function registry)
    objective_func = eval(Symbol(test_params["function_name"]))
    
    TR = test_input(
        objective_func,
        dim = test_params["dimension"],
        center = test_params["center"],
        sample_range = test_params["sample_range"],
        GN = test_params["GN"],
        tolerance = test_params["tolerance"]
    )
    
    println("✅ Test input created ($(time() - step1_start) seconds)")
    
    # Step 2: Polynomial construction
    println("\n🏗️  Step 2: Polynomial construction...")
    step2_start = time()
    
    degree = poly_params["degree"]
    basis = Symbol(poly_params["basis"])
    precision_type = eval(Symbol(poly_params["precision_type"]))
    
    pol = Constructor(TR, degree, 
                     basis=basis, 
                     precision=precision_type,
                     normalized=get(poly_params, "normalized", false),
                     verbose=get(poly_params, "verbose", 0))
    
    construction_time = time() - step2_start
    timings["construction_time"] = construction_time
    
    println("✅ Polynomial constructed ($(construction_time) seconds)")
    println("   L2 error: $(@sprintf("%.2e", pol.nrm))")
    println("   Coefficients: $(length(pol.coeffs))")
    
    # Step 3: Critical point finding
    println("\n🔍 Step 3: Critical point finding...")
    step3_start = time()
    
    @polyvar x[1:test_params["dimension"]]
    solutions = solve_polynomial_system(x, test_params["dimension"], degree, pol.coeffs,
                                      basis=basis,
                                      precision=get(pol, :precision, precision_type),
                                      normalized=get(poly_params, "normalized", false))
    
    df_critical = process_crit_pts(solutions, objective_func, TR)
    solving_time = time() - step3_start
    timings["solving_time"] = solving_time
    timings["n_raw_solutions"] = length(solutions)
    
    println("✅ Critical points found ($(solving_time) seconds)")
    println("   Raw solutions: $(length(solutions))")
    println("   Valid critical points: $(nrow(df_critical))")
    
    # Step 4: Critical point analysis
    println("\n🔬 Step 4: Critical point analysis...")
    step4_start = time()
    
    df_enhanced, df_min = analyze_critical_points(
        objective_func, df_critical, TR,
        tol_dist = get(analysis_params, "tol_dist", 0.025),
        enable_hessian = get(analysis_params, "enable_hessian", true),
        max_iters_in_optim = get(analysis_params, "max_iters_in_optim", 100),
        verbose = get(analysis_params, "verbose", true)
    )
    
    analysis_time = time() - step4_start
    timings["analysis_time"] = analysis_time
    
    println("✅ Critical point analysis completed ($(analysis_time) seconds)")
    println("   Enhanced critical points: $(nrow(df_enhanced))")
    println("   Local minima found: $(nrow(df_min))")
    
    # Record end time
    end_time = now()
    total_runtime = (end_time - start_time).value / 1000.0
    
    println("\n📊 Computation Summary:")
    println("   Total runtime: $(@sprintf("%.2f", total_runtime)) seconds")
    println("   Polynomial construction: $(@sprintf("%.2f", construction_time)) seconds")
    println("   Critical point solving: $(@sprintf("%.2f", solving_time)) seconds")
    println("   Critical point analysis: $(@sprintf("%.2f", analysis_time)) seconds")
    
    # Step 5: Save results with JSON tracking
    println("\n💾 Step 5: Saving results...")
    
    computation_id = input_config["metadata"]["computation_id"]
    output_dir = "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7"
    
    # Create output results
    output_results = create_output_results(
        computation_id, start_time, end_time,
        pol, df_enhanced, df_min, timings
    )
    
    # Save output results JSON
    output_results_path = joinpath(output_dir, "output_results.json")
    save_output_results(output_results, output_results_path)
    
    # Save detailed outputs
    detailed_dir = joinpath(output_dir, "detailed_outputs")
    save_detailed_outputs(df_enhanced, df_min, pol, detailed_dir)
    
    println("✅ All results saved successfully!")
    println("   Output directory: $output_dir")
    println("   Input config: $(joinpath(output_dir, "input_config.json"))")
    println("   Output results: $output_results_path")
    println("   Detailed outputs: $detailed_dir")
    
    println("\n🎉 COMPUTATION COMPLETED SUCCESSFULLY!")
    
catch e
    println("❌ COMPUTATION FAILED: $e")
    
    # Save error information
    error_info = Dict(
        "computation_id" => "dc98cad7",
        "timestamp" => string(now()),
        "error_message" => string(e),
        "status" => "FAILED"
    )
    
    error_path = "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/error_info.json"
    open(error_path, "w") do f
        JSON3.pretty(f, error_info, indent=2)
    end
    
    println("Error information saved to: $error_path")
    
    # Print stack trace for debugging
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    
    exit(1)
end
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Summary of results
if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Computation completed successfully"
    echo "📁 Results available in: /Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7"
    
    # List key output files
    if [ -f "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/output_results.json" ]; then
        echo "   📄 Output results: /Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/output_results.json"
    fi
    if [ -d "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/detailed_outputs" ]; then
        echo "   📁 Detailed outputs: /Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/detailed_outputs/"
        ls -la "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/detailed_outputs/"
    fi
else
    echo "❌ Computation failed with exit code $JULIA_EXIT_CODE"
    if [ -f "/Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/error_info.json" ]; then
        echo "   📄 Error info: /Users/ghscholt/globtim/hpc/jobs/creation/../../../hpc/results/by_function/Deuflhard/2025-08/single_tests/deg8_chebyshev_quick_20250807_102224_dc98cad7/error_info.json"
    fi
fi

exit $JULIA_EXIT_CODE
