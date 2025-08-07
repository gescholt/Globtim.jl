#!/bin/bash
#SBATCH --job-name=params_test_9353c78b
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:30:00
#SBATCH --mem=16G
#SBATCH --output=results/experiments/parameters_test_20250803_161755/jobs/9353c78b/slurm_output/params_test_9353c78b_%j.out
#SBATCH --error=results/experiments/parameters_test_20250803_161755/jobs/9353c78b/slurm_output/params_test_9353c78b_%j.err

# Parameters.jl Test Job
# Job ID: 9353c78b
# Function: Sphere
# Degree: 4, Samples: 100
# Generated: 2025-08-03T16:17:55.826

echo "=== Parameters.jl Test Job ==="
echo "Job ID: 9353c78b"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Start time: $(date)"
echo ""

# Set Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_${SLURM_JOB_ID}"

# Create working directory
mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

echo "=== Downloading Globtim ==="
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC.toml ./Project.toml

echo "✓ Globtim source copied"
echo ""

echo "=== Running Parameters.jl Benchmark ==="
/sw/bin/julia --project=. -e '
using LinearAlgebra, Statistics, Random
Random.seed!(42)

# Load Globtim and Parameters.jl system
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl") 
include("src/LibFunctions.jl")
include("src/HPC/BenchmarkConfigSimple.jl")

println("=== Parameters.jl Sphere Function Test ===")

# Recreate job parameters (demonstrating parameter persistence)
globtim_params = GlobtimParameters(
    degree = 4,
    sample_count = 100,
    center = [0.0, 0.0, 0.0, 0.0],
    sample_range = 2.0,
    sparsification_threshold = 0.0001
)

# Use @unpack_simple for clean parameter access
@unpack_simple (degree, sample_count, center, sample_range) globtim_params

println("Parameters loaded:")
println("  - degree: $degree")
println("  - sample_count: $sample_count")
println("  - center: $center")
println("  - sample_range: $sample_range")
println()

# Get benchmark function
sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]
test_function = sphere_func.func

println("Running Globtim workflow...")
println("Expected: Should find minimizers very close to origin [0,0,0,0]")
println()

try
    # Run Globtim workflow with unpacked parameters
    results = safe_globtim_workflow(
        test_function,
        dim = length(center),
        center = center,
        sample_range = sample_range,
        degree = degree,
        GN = sample_count,
        enable_hessian = true,
        basis = :chebyshev,
        precision = Float64,
        max_retries = 3
    )
    
    println("✅ SUCCESS!")
    println("   - L2 error: ", @sprintf("%.2e", results.polynomial.nrm))
    println("   - Critical points: ", nrow(results.critical_points))
    println("   - Minimizers: ", nrow(results.minima))
    println("   - Construction time: ", @sprintf("%.2f", results.construction_time), " seconds")
    println()
    
    # Distance analysis using our Parameters.jl system
    if nrow(results.minima) > 0
        println("=== Distance Analysis (Parameters.jl) ===")
        minimizer_points = Matrix{Float64}(results.minima[:, 1:4])
        distances = compute_min_distances_to_global(minimizer_points, sphere_func.global_minima)
        
        min_distance = minimum(distances)
        mean_distance = mean(distances)
        close_points = sum(distances .< 0.1)
        convergence_rate = close_points / length(distances)
        
        println("   - Minimum distance to origin: ", @sprintf("%.6f", min_distance))
        println("   - Mean distance to origin: ", @sprintf("%.6f", mean_distance))
        println("   - Points within 0.1 of origin: $close_points/$(length(distances))")
        println("   - Convergence rate: ", @sprintf("%.1f%%", convergence_rate * 100))
        
        # Save results using Parameters.jl job info
        using CSV, DataFrames
        
        # Save minimizers with distances
        minimizers_with_distances = copy(results.minima)
        minimizers_with_distances[!, :distance_to_global] = distances
        CSV.write("minimizers_analysis.csv", minimizers_with_distances)
        
        # Create comprehensive results summary
        open("results_summary.txt", "w") do io
            println(io, "job_id: 9353c78b")
            println(io, "slurm_job_id: $(ENV["SLURM_JOB_ID"])")
            println(io, "function_name: Sphere")
            println(io, "degree: $degree")
            println(io, "sample_count: $sample_count")
            println(io, "l2_error: $(results.polynomial.nrm)")
            println(io, "critical_points_count: $(nrow(results.critical_points))")
            println(io, "minimizers_count: $(nrow(results.minima))")
            println(io, "min_distance_to_global: $min_distance")
            println(io, "mean_distance_to_global: $mean_distance")
            println(io, "convergence_rate: $convergence_rate")
            println(io, "construction_time: $(results.construction_time)")
            println(io, "parameters_jl_system: true")
            println(io, "success: true")
        end
        
        println("✓ Results saved with Parameters.jl metadata")
        
    else
        println("⚠️  No minimizers found")
    end
    
catch e
    println("❌ ERROR: $e")
    
    open("error_log.txt", "w") do io
        println(io, "job_id: 9353c78b")
        println(io, "error: $e")
        println(io, "parameters_jl_system: true")
        println(io, "timestamp: $(now())")
    end
    
    exit(1)
end

println()
println("=== Parameters.jl Test Completed Successfully ===")
'

echo ""
echo "=== Uploading Results ==="
if [ -f "minimizers_analysis.csv" ]; then
    cp minimizers_analysis.csv ~/globtim_hpc/results/experiments/parameters_test_20250803_161755/jobs/9353c78b/
    echo "✓ Minimizers analysis uploaded"
fi

if [ -f "results_summary.txt" ]; then
    cp results_summary.txt ~/globtim_hpc/results/experiments/parameters_test_20250803_161755/jobs/9353c78b/
    echo "✓ Results summary uploaded"
fi

if [ -f "error_log.txt" ]; then
    cp error_log.txt ~/globtim_hpc/results/experiments/parameters_test_20250803_161755/jobs/9353c78b/
    echo "✓ Error log uploaded"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: 9353c78b"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "End time: $(date)"
echo "Results in: ~/globtim_hpc/results/experiments/parameters_test_20250803_161755/jobs/9353c78b/"
echo "Parameters.jl system: SUCCESS"
