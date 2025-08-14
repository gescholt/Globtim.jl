#!/bin/bash
#SBATCH -J globtim_quick
#SBATCH -t 00:10:00                # 10 minutes
#SBATCH -n 1                       # 1 task
#SBATCH -c 2                       # 2 CPUs per task (faster scheduling)
#SBATCH --mem-per-cpu=2000         # 2GB per CPU (4GB total)
#SBATCH -o globtim_quick_%j.out
#SBATCH -e globtim_quick_%j.err

# Quick Globtim Test - Minimal resources for faster scheduling

echo "=== Globtim Quick Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Start time: $(date)"
echo ""

# ⚠️ WARNING: /tmp usage is forbidden on this cluster!
# Using NFS workspace instead
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/julia_depot_nfs"
export TMPDIR="/stornext/snfs3/home/scholten/tmp_nfs"

# Create NFS working directory
mkdir -p $TMPDIR
cd ~/globtim_hpc

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
