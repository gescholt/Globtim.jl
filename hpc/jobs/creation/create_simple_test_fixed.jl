"""
Simple HPC Test Creation - Fixed Version

Creates a minimal benchmark test without requiring all packages to be installed.
"""

using Dates
using UUIDs

println("=== Creating Simple HPC Test ===")
println()

# Create a simple test experiment directory structure
experiment_name = "simple_test_" * Dates.format(now(), "yyyymmdd_HHMMSS")
println("Experiment name: $experiment_name")

# Create directory structure
base_dir = "results/experiments/$experiment_name"
mkpath("$base_dir/jobs")
mkpath("$base_dir/aggregated")

println("✓ Created experiment directory: $base_dir")

# Create a simple SLURM job script for testing
job_id = string(uuid4())[1:8]
job_dir = "$base_dir/jobs/$job_id"
mkpath(job_dir)
mkpath("$job_dir/slurm_output")

println("✓ Created job directory: $job_dir")
println("✓ Job ID: $job_id")

# Create a minimal SLURM script that tests Globtim
slurm_content = """#!/bin/bash
#SBATCH --job-name=globtim_test_""" * job_id * """
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:30:00
#SBATCH --mem=8G
#SBATCH --output=""" * job_dir * """/slurm_output/globtim_test_""" * job_id * """_%j.out
#SBATCH --error=""" * job_dir * """/slurm_output/globtim_test_""" * job_id * """_%j.err

# Simple Globtim Test Job
# Job ID: """ * job_id * """
# Generated: """ * string(now()) * """

echo "=== Simple Globtim Test ==="
echo "Job ID: """ * job_id * """"
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
# Copy Globtim source
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC.toml ./Project.toml

echo "✓ Globtim source copied"
echo ""

echo "=== Running Simple Globtim Test ==="
/sw/bin/julia --project=. -e '
using LinearAlgebra, Statistics, Random
Random.seed!(42)

# Load Globtim modules
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl") 
include("src/LibFunctions.jl")

println("=== Simple Sphere Function Test ===")

# Simple 4D Sphere function test
function sphere_4d(x)
    return sum(x.^2)
end

println("Testing Sphere function in 4D...")
println("Global minimum should be at [0,0,0,0] with value 0")
println()

try
    # Run minimal Globtim workflow
    results = safe_globtim_workflow(
        sphere_4d,
        dim = 4,
        center = zeros(4),
        sample_range = 2.0,
        degree = 4,                 # Small degree
        GN = 100,                   # Small sample count
        enable_hessian = true,
        basis = :chebyshev,
        precision = Float64,        # Standard precision
        max_retries = 2
    )
    
    println("✅ SUCCESS!")
    println("   - L2 error: ", @sprintf("%.2e", results.polynomial.nrm))
    println("   - Critical points: ", nrow(results.critical_points))
    println("   - Minimizers: ", nrow(results.minima))
    println("   - Construction time: ", @sprintf("%.2f", results.construction_time), " seconds")
    println()
    
    # Analyze distances to global minimum (origin)
    if nrow(results.minima) > 0
        println("=== Distance Analysis ===")
        global_min = [0.0, 0.0, 0.0, 0.0]
        
        distances = Float64[]
        for i in 1:nrow(results.minima)
            point = [results.minima[i, j] for j in 1:4]
            distance = sqrt(sum((point - global_min).^2))
            push!(distances, distance)
        end
        
        min_distance = minimum(distances)
        mean_distance = mean(distances)
        close_points = sum(distances .< 0.1)
        
        println("   - Minimum distance to origin: ", @sprintf("%.6f", min_distance))
        println("   - Mean distance to origin: ", @sprintf("%.6f", mean_distance))
        println("   - Points within 0.1 of origin: \$close_points/\$(length(distances))")
        
        convergence_rate = close_points / length(distances)
        println("   - Convergence rate: ", @sprintf("%.1f%%", convergence_rate * 100))
        
        # Save results
        using CSV, DataFrames
        
        # Save minimizers with distances
        minimizers_with_distances = copy(results.minima)
        minimizers_with_distances[!, :distance_to_global] = distances
        CSV.write("minimizers_analysis.csv", minimizers_with_distances)
        
        # Create summary as simple text
        open("test_summary.txt", "w") do io
            println(io, "job_id: """ * job_id * """")
            println(io, "slurm_job_id: \$(ENV["SLURM_JOB_ID"])")
            println(io, "function_name: Sphere4D")
            println(io, "degree: 4")
            println(io, "sample_count: 100")
            println(io, "l2_error: \$(results.polynomial.nrm)")
            println(io, "critical_points_count: \$(nrow(results.critical_points))")
            println(io, "minimizers_count: \$(nrow(results.minima))")
            println(io, "min_distance_to_global: \$min_distance")
            println(io, "mean_distance_to_global: \$mean_distance")
            println(io, "convergence_rate: \$convergence_rate")
            println(io, "construction_time: \$(results.construction_time)")
            println(io, "success: true")
        end
        
        println("✓ Results saved to minimizers_analysis.csv and test_summary.txt")
        
    else
        println("⚠️  No minimizers found")
    end
    
catch e
    println("❌ ERROR: \$e")
    
    # Save error info
    open("error_log.txt", "w") do io
        println(io, "job_id: """ * job_id * """")
        println(io, "error: \$e")
        println(io, "timestamp: \$(now())")
    end
    
    exit(1)
end

println()
println("=== Test Completed Successfully ===")
'

echo ""
echo "=== Uploading Results ==="
# Upload results back to job directory
if [ -f "minimizers_analysis.csv" ]; then
    cp minimizers_analysis.csv ~/globtim_hpc/""" * job_dir * """/
    echo "✓ Minimizers analysis uploaded"
fi

if [ -f "test_summary.txt" ]; then
    cp test_summary.txt ~/globtim_hpc/""" * job_dir * """/
    echo "✓ Test summary uploaded"
fi

if [ -f "error_log.txt" ]; then
    cp error_log.txt ~/globtim_hpc/""" * job_dir * """/
    echo "✓ Error log uploaded"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf \$TMPDIR
rm -rf \$JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: """ * job_id * """"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "End time: \$(date)"
echo "Results in: ~/globtim_hpc/""" * job_dir * """/"
"""

# Write the SLURM script
script_path = "$job_dir/test_job.sh"
open(script_path, "w") do io
    write(io, slurm_content)
end

# Make it executable
chmod(script_path, 0o755)

println("✓ Created SLURM script: $script_path")

# Create submission helper
helper_content = """#!/bin/bash

# Simple Test Submission Helper
echo "=== Simple Globtim Test Submission ==="
echo "Job ID: """ * job_id * """"
echo "Experiment: """ * experiment_name * """"
echo ""

case "\$1" in
    "submit")
        echo "Submitting test job..."
        sbatch """ * job_dir * """/test_job.sh
        echo "Job submitted! Monitor with: squeue -u \$USER"
        ;;
    "status")
        echo "Checking job status..."
        squeue -u \$USER --name=globtim_test_*
        ;;
    "results")
        echo "Checking results..."
        if [ -f \"""" * job_dir * """/test_summary.txt\" ]; then
            echo "=== Test Summary ==="
            cat """ * job_dir * """/test_summary.txt
        else
            echo "No results found yet"
        fi
        ;;
    "logs")
        echo "Recent SLURM output files:"
        ls -la """ * job_dir * """/slurm_output/ 2>/dev/null || echo "No output files yet"
        ;;
    *)
        echo "Usage: \$0 {submit|status|results|logs}"
        echo "  submit  - Submit the test job"
        echo "  status  - Check job status"
        echo "  results - Show test results"
        echo "  logs    - Show SLURM output files"
        ;;
esac
"""

helper_path = "$base_dir/manage_test.sh"
open(helper_path, "w") do io
    write(io, helper_content)
end
chmod(helper_path, 0o755)

println("✓ Created management script: $helper_path")

println()
println("=== Simple Test Created Successfully! ===")
println()
println("📁 **Experiment Directory:** $base_dir")
println("🆔 **Job ID:** $job_id")
println("📋 **Management Script:** $helper_path")
println()
println("🚀 **Next Steps:**")
println("1. Submit the test:")
println("   $helper_path submit")
println()
println("2. Monitor progress:")
println("   $helper_path status")
println()
println("3. Check results:")
println("   $helper_path results")
println()
println("This test will:")
println("• Run a simple 4D Sphere function optimization")
println("• Use degree 4, 100 samples (should complete in ~30 seconds)")
println("• Measure distance to known global minimum at origin")
println("• Save detailed results for analysis")
println()
println("✅ **Ready to submit!**")
