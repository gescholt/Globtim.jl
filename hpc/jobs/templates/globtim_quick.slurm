#!/bin/bash
#SBATCH --job-name=globtim_quick
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4          # Request fewer CPUs for faster scheduling
#SBATCH --time=00:10:00            # Short 10-minute job
#SBATCH --mem=8G                   # Less memory
#SBATCH --output=globtim_quick_%j.out
#SBATCH --error=globtim_quick_%j.err

# Quick Globtim Test - Minimal resources for faster scheduling

echo "=== Globtim Quick Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Start time: $(date)"
echo ""

# Set Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_${SLURM_JOB_ID}"

# Create temporary working directory
mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

echo "=== Quick Julia Test ==="
/sw/bin/julia -e '
println("=== Quick Globtim Test ===")
println("Julia ", VERSION, " with ", Threads.nthreads(), " threads")

# Test basic functionality
using LinearAlgebra, Statistics, Random
Random.seed!(42)

# Simple computation test
println("Testing basic computation...")
A = rand(100, 100)
B = A * A
eigenvals = eigvals(A)
println("✓ Matrix operations work")

# Test threading
println("Testing threading...")
results = zeros(Threads.nthreads())
Threads.@threads for i in 1:Threads.nthreads()
    results[i] = sum(rand(1000))
end
println("✓ Threading works: ", results)

println("✓ Quick test completed successfully!")
'

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
