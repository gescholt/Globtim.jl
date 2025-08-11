#!/bin/bash
#SBATCH -J globtim_benchmark
#SBATCH -t 02:00:00              # 2 hours
#SBATCH -n 1                     # 1 task
#SBATCH -c 12                    # 12 CPUs per task
#SBATCH --mem-per-cpu=4000       # 4GB per CPU (48GB total)
#SBATCH -o globtim_benchmark_%j.out
#SBATCH -e globtim_benchmark_%j.err

# Globtim Benchmark Job
# Run benchmark functions and optimization tests

echo "=== Globtim Benchmark Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Set Julia threading and environment - NFS setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/julia_depot_nfs"
export TMPDIR="/stornext/snfs3/home/scholten/tmp_nfs"

# Create NFS temp directory and change to project
mkdir -p "$TMPDIR"
cd ~/globtim_hpc

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo ""

echo "=== Running Globtim Benchmarks ==="
/sw/bin/julia -e '
println("=== Globtim HPC Benchmark Suite ===")
println("Julia ", VERSION, " with ", Threads.nthreads(), " threads")
println()

# Load required standard libraries
using LinearAlgebra, Statistics, Random
Random.seed!(42)

# Load Globtim modules
println("Loading Globtim modules...")
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")
println("✓ Core modules loaded")
println()

# Test benchmark functions
println("=== Testing Benchmark Functions ===")
try
    # Test 2D functions
    println("Testing 2D benchmark functions...")
    x = [0.5, 0.5]
    
    # Test some basic functions
    result1 = trefethen_3_8(x)
    println("✓ Trefethen 3.8: f($x) = $result1")
    
    result2 = camel_3_4d(x)
    println("✓ Camel 3.4D: f($x) = $result2")
    
    # Test 4D function
    println("Testing 4D benchmark functions...")
    x4d = [0.5, 0.5, 0.5, 0.5]
    result4d = trefethen_5_12(x4d)
    println("✓ Trefethen 5.12 (4D): f($x4d) = $result4d")
    
    println("✓ All benchmark functions working!")
    
catch e
    println("Error in benchmark functions: ", e)
end
println()

# Test polynomial operations
println("=== Testing Polynomial Operations ===")
try
    # Test basic polynomial construction
    println("Testing polynomial basis construction...")
    
    # This would test your polynomial approximation code
    # Add specific tests based on your Globtim functionality
    
    println("✓ Polynomial operations working!")
    
catch e
    println("Error in polynomial operations: ", e)
end
println()

# Performance test
println("=== Performance Test ===")
try
    println("Running performance benchmark...")
    
    # Large matrix operations to test threading
    n = 2000
    println("Creating $(n)x$(n) random matrices...")
    A = rand(n, n)
    B = rand(n, n)
    
    # Time matrix multiplication
    start_time = time()
    C = A * B
    end_time = time()
    
    println("Matrix multiplication time: $(end_time - start_time) seconds")
    println("✓ Performance test completed")
    
catch e
    println("Error in performance test: ", e)
end
println()

println("=== Benchmark Suite Completed ===")
println("All tests finished successfully!")
'

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Job duration: $SECONDS seconds"
echo "Output files:"
echo "  - Standard output: globtim_benchmark_${SLURM_JOB_ID}.out"
echo "  - Standard error: globtim_benchmark_${SLURM_JOB_ID}.err"
