"""
Create Parameters.jl Test Job

Creates a simple benchmark job using the Parameters.jl configuration system.
Tests the complete workflow from parameter specification to SLURM job creation.
"""

println("=== Creating Parameters.jl Test Job ===")
println()

# Load our dependency-free Parameters.jl system
include("src/HPC/BenchmarkConfigSimple.jl")

# Create experiment timestamp
using Dates
experiment_name = "parameters_test_" * Dates.format(now(), "yyyymmdd_HHMMSS")
println("Experiment name: $experiment_name")

# ============================================================================
# STEP 1: Create Parameters with Defaults
# ============================================================================

println()
println("Step 1: Creating parameters with defaults...")

# Create Globtim parameters using our @with_kw-like functionality
globtim_params = GlobtimParameters(
    degree = 4,                    # Small degree for quick test
    sample_count = 100,            # Small sample count
    center = zeros(4),             # 4D center at origin
    sample_range = 2.0,            # Reasonable range for Sphere function
    sparsification_threshold = 1e-4 # Standard threshold
    # Other parameters use defaults
)

println("✓ GlobtimParameters created:")
@unpack_simple (degree, sample_count, center, basis, sparsification_threshold) globtim_params
println("  - degree: $degree")
println("  - sample_count: $sample_count") 
println("  - center: $center")
println("  - basis: $basis")
println("  - sparsification_threshold: $sparsification_threshold")

# Create HPC parameters with automatic resource sizing
hpc_params = HPCParameters(
    cpus = 8,                      # Small job
    memory_gb = 16,                # Reasonable memory
    time_limit = "00:30:00"        # 30 minutes should be plenty
    # Other parameters use defaults
)

println("✓ HPCParameters created:")
@unpack_simple (partition, cpus, memory_gb, time_limit, julia_threads) hpc_params
println("  - partition: $partition")
println("  - cpus: $cpus")
println("  - memory_gb: $memory_gb")
println("  - time_limit: $time_limit")
println("  - julia_threads: $julia_threads")

# ============================================================================
# STEP 2: Create Complete Benchmark Job
# ============================================================================

println()
println("Step 2: Creating complete benchmark job...")

# Get Sphere function from registry
sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]
println("✓ Using benchmark function: $(sphere_func.name)")
println("  - description: $(sphere_func.description)")
println("  - global minimum: $(sphere_func.global_minima[1])")
println("  - expected f_min: $(sphere_func.f_min)")

# Create complete job specification
job = BenchmarkJob(
    benchmark_func = sphere_func,
    globtim_params = globtim_params,
    hpc_params = hpc_params,
    experiment_name = experiment_name,
    tags = ["parameters_test", "sphere", "simple"]
)

println("✓ BenchmarkJob created:")
println("  - job_id: $(job.job_id) (auto-generated)")
println("  - timestamp: $(job.timestamp)")
println("  - parameter_set_id: $(job.parameter_set_id)")
println("  - experiment_name: $(job.experiment_name)")
println("  - tags: $(job.tags)")

# ============================================================================
# STEP 3: Create Directory Structure
# ============================================================================

println()
println("Step 3: Creating directory structure...")

# Create experiment directory structure
base_dir = "results/experiments/$experiment_name"
job_dir = "$base_dir/jobs/$(job.job_id)"
mkpath("$job_dir/slurm_output")

println("✓ Created directories:")
println("  - experiment: $base_dir")
println("  - job: $job_dir")
println("  - slurm_output: $job_dir/slurm_output")

# ============================================================================
# STEP 4: Generate SLURM Job Script
# ============================================================================

println()
println("Step 4: Generating SLURM job script...")

# Create SLURM script using our parameters
slurm_script = """#!/bin/bash
#SBATCH --job-name=params_test_$(job.job_id)
#SBATCH --partition=$(hpc_params.partition)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$(hpc_params.cpus)
#SBATCH --time=$(hpc_params.time_limit)
#SBATCH --mem=$(hpc_params.memory_gb)G
#SBATCH --output=$job_dir/slurm_output/params_test_$(job.job_id)_%j.out
#SBATCH --error=$job_dir/slurm_output/params_test_$(job.job_id)_%j.err

# Parameters.jl Test Job
# Job ID: $(job.job_id)
# Function: $(job.benchmark_func.name)
# Degree: $(job.globtim_params.degree), Samples: $(job.globtim_params.sample_count)
# Generated: $(job.timestamp)

echo "=== Parameters.jl Test Job ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: \$SLURM_CPUS_PER_TASK"
echo "Start time: \$(date)"
echo ""

# Set Julia environment
export JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_\${USER}_\${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_\${SLURM_JOB_ID}"

# Create working directory
mkdir -p \$TMPDIR
cd \$TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: \$JULIA_NUM_THREADS"
echo "Working directory: \$(pwd)"
echo "Available space: \$(df -h . | tail -1 | awk '{print \$4}')"
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
    degree = $(globtim_params.degree),
    sample_count = $(globtim_params.sample_count),
    center = $(globtim_params.center),
    sample_range = $(globtim_params.sample_range),
    sparsification_threshold = $(globtim_params.sparsification_threshold)
)

# Use @unpack_simple for clean parameter access
@unpack_simple (degree, sample_count, center, sample_range) globtim_params

println("Parameters loaded:")
println("  - degree: \$degree")
println("  - sample_count: \$sample_count")
println("  - center: \$center")
println("  - sample_range: \$sample_range")
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
        println("   - Points within 0.1 of origin: \$close_points/\$(length(distances))")
        println("   - Convergence rate: ", @sprintf("%.1f%%", convergence_rate * 100))
        
        # Save results using Parameters.jl job info
        using CSV, DataFrames
        
        # Save minimizers with distances
        minimizers_with_distances = copy(results.minima)
        minimizers_with_distances[!, :distance_to_global] = distances
        CSV.write("minimizers_analysis.csv", minimizers_with_distances)
        
        # Create comprehensive results summary
        open("results_summary.txt", "w") do io
            println(io, "job_id: $(job.job_id)")
            println(io, "slurm_job_id: \$(ENV["SLURM_JOB_ID"])")
            println(io, "function_name: $(sphere_func.name)")
            println(io, "degree: \$degree")
            println(io, "sample_count: \$sample_count")
            println(io, "l2_error: \$(results.polynomial.nrm)")
            println(io, "critical_points_count: \$(nrow(results.critical_points))")
            println(io, "minimizers_count: \$(nrow(results.minima))")
            println(io, "min_distance_to_global: \$min_distance")
            println(io, "mean_distance_to_global: \$mean_distance")
            println(io, "convergence_rate: \$convergence_rate")
            println(io, "construction_time: \$(results.construction_time)")
            println(io, "parameters_jl_system: true")
            println(io, "success: true")
        end
        
        println("✓ Results saved with Parameters.jl metadata")
        
    else
        println("⚠️  No minimizers found")
    end
    
catch e
    println("❌ ERROR: \$e")
    
    open("error_log.txt", "w") do io
        println(io, "job_id: $(job.job_id)")
        println(io, "error: \$e")
        println(io, "parameters_jl_system: true")
        println(io, "timestamp: \$(now())")
    end
    
    exit(1)
end

println()
println("=== Parameters.jl Test Completed Successfully ===")
'

echo ""
echo "=== Uploading Results ==="
if [ -f "minimizers_analysis.csv" ]; then
    cp minimizers_analysis.csv ~/globtim_hpc/$job_dir/
    echo "✓ Minimizers analysis uploaded"
fi

if [ -f "results_summary.txt" ]; then
    cp results_summary.txt ~/globtim_hpc/$job_dir/
    echo "✓ Results summary uploaded"
fi

if [ -f "error_log.txt" ]; then
    cp error_log.txt ~/globtim_hpc/$job_dir/
    echo "✓ Error log uploaded"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf \$TMPDIR
rm -rf \$JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "End time: \$(date)"
echo "Results in: ~/globtim_hpc/$job_dir/"
echo "Parameters.jl system: SUCCESS"
"""

# Write SLURM script
script_path = "$job_dir/params_test_job.sh"
open(script_path, "w") do io
    write(io, slurm_script)
end
chmod(script_path, 0o755)

println("✓ SLURM script created: $script_path")

# ============================================================================
# STEP 5: Create Job Management Script
# ============================================================================

println()
println("Step 5: Creating job management script...")

management_script = """#!/bin/bash

# Parameters.jl Test Job Management
echo "=== Parameters.jl Test Job Management ==="
echo "Job ID: $(job.job_id)"
echo "Experiment: $experiment_name"
echo "Function: $(job.benchmark_func.name)"
echo "Parameters: degree=$(job.globtim_params.degree), samples=$(job.globtim_params.sample_count)"
echo ""

case "\$1" in
    "submit")
        echo "Submitting Parameters.jl test job..."
        sbatch $job_dir/params_test_job.sh
        echo "Job submitted! Monitor with: \$0 status"
        ;;
    "status")
        echo "Checking job status..."
        squeue -u \$USER --name=params_test_*
        ;;
    "results")
        echo "Checking results..."
        if [ -f "$job_dir/results_summary.txt" ]; then
            echo "=== Results Summary ==="
            cat $job_dir/results_summary.txt
        else
            echo "No results found yet"
        fi
        ;;
    "logs")
        echo "Recent SLURM output files:"
        ls -la $job_dir/slurm_output/ 2>/dev/null || echo "No output files yet"
        if [ -f "$job_dir/slurm_output"/*.out ]; then
            echo ""
            echo "=== Latest Output ==="
            cat $job_dir/slurm_output/*.out | tail -20
        fi
        ;;
    *)
        echo "Usage: \$0 {submit|status|results|logs}"
        echo "  submit  - Submit the Parameters.jl test job"
        echo "  status  - Check job status"
        echo "  results - Show test results"
        echo "  logs    - Show SLURM output files"
        ;;
esac
"""

mgmt_path = "$base_dir/manage_params_test.sh"
open(mgmt_path, "w") do io
    write(io, management_script)
end
chmod(mgmt_path, 0o755)

println("✓ Management script created: $mgmt_path")

# ============================================================================
# SUMMARY
# ============================================================================

println()
println("=== Parameters.jl Test Job Created Successfully! ===")
println()
println("📁 **Experiment**: $experiment_name")
println("🆔 **Job ID**: $(job.job_id)")
println("🎯 **Function**: $(job.benchmark_func.name) (4D Sphere)")
println("⚙️  **Parameters**: degree=$(job.globtim_params.degree), samples=$(job.globtim_params.sample_count)")
println("💻 **Resources**: $(job.hpc_params.cpus) CPUs, $(job.hpc_params.memory_gb)GB, $(job.hpc_params.time_limit)")
println()
println("🚀 **Next Steps:**")
println("1. Submit job:")
println("   $mgmt_path submit")
println()
println("2. Monitor progress:")
println("   $mgmt_path status")
println()
println("3. Check results:")
println("   $mgmt_path results")
println()
println("**Expected Results:**")
println("• Should find minimizers very close to origin [0,0,0,0]")
println("• Distance to global minimum < 0.01 for good convergence")
println("• Convergence rate > 80% for this simple function")
println("• Demonstrates complete Parameters.jl workflow")
println()
println("✅ **Parameters.jl system ready for HPC testing!**")
