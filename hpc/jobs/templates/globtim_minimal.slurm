#!/bin/bash
#SBATCH --job-name=globtim_minimal
#SBATCH --partition=batch          # Default partition: 24h max, 3120 cores, 256GB max
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24         # Max 24 cores per node on batch partition
#SBATCH --time=00:30:00            # 30 minutes (well under 24h limit)
#SBATCH --mem=32G                  # 32GB (well under 256GB limit)
#SBATCH --output=globtim_minimal_%j.out
#SBATCH --error=globtim_minimal_%j.err

# Minimal Globtim Test - Downloads and runs from scratch
# Avoids home directory disk quota issues

echo "=== Globtim Minimal HPC Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Start time: $(date)"
echo ""

# Set Julia environment to use temporary space
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_${SLURM_JOB_ID}"

# Create temporary working directory
mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

echo "=== Downloading Globtim from Fileserver ==="
# Download minimal Globtim files directly from fileserver
scp -r scholten@fileserver-ssh:globtim/src .
scp scholten@fileserver-ssh:globtim/Project_HPC.toml ./Project.toml

echo "✓ Globtim source downloaded"
echo "Files: $(ls -la)"
echo ""

echo "=== Testing Julia ==="
/sw/bin/julia --version
echo ""

echo "=== Testing Basic Functionality ==="
/sw/bin/julia -e '
println("=== Globtim HPC Test ===")
println("Julia ", VERSION, " with ", Threads.nthreads(), " threads")
println()

# Test basic packages
using LinearAlgebra, Statistics, Random
println("✓ Basic packages loaded")

# Load Globtim modules
println("Loading Globtim modules...")
try
    include("src/Structures.jl")
    println("✓ Structures.jl loaded")
    
    include("src/BenchmarkFunctions.jl") 
    println("✓ BenchmarkFunctions.jl loaded")
    
    # Test benchmark functions
    println()
    println("=== Testing Benchmark Functions ===")
    x = [0.5, 0.5]
    result1 = trefethen_3_8(x)
    println("✓ Trefethen 3.8: f($x) = $result1")
    
    x4d = [0.5, 0.5, 0.5, 0.5]
    result2 = trefethen_5_12(x4d)
    println("✓ Trefethen 5.12 (4D): f($x4d) = $result2")
    
    # Performance test
    println()
    println("=== Performance Test ===")
    n = 1000
    A = rand(n, n)
    B = rand(n, n)
    
    start_time = time()
    C = A * B
    end_time = time()
    
    println("Matrix multiplication ($(n)x$(n)): $(end_time - start_time) seconds")
    println("✓ Performance test completed")
    
    println()
    println("=== All Tests Passed! ===")
    
catch e
    println("Error: ", e)
    println("Stacktrace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end
'

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Job duration: $SECONDS seconds"
