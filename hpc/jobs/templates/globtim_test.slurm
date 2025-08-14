#!/bin/bash
#SBATCH -J globtim_test
#SBATCH -t 00:30:00              # 30 minutes
#SBATCH -n 1                     # 1 task
#SBATCH -c 8                     # 8 CPUs per task
#SBATCH --mem-per-cpu=4000       # 4GB per CPU (32GB total)
#SBATCH -o globtim_test_%j.out
#SBATCH -e globtim_test_%j.err

# Globtim Test Job
# Basic test of Julia and Globtim functionality on HPC cluster

echo "=== Globtim HPC Test Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Set Julia threading and NFS environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/julia_depot_nfs"
export TMPDIR="/stornext/snfs3/home/scholten/tmp_nfs"

# Create NFS temp directory and change to project
mkdir -p "$TMPDIR"
cd ~/globtim_hpc

echo "=== System Information ==="
hostname
uname -a
echo "Available memory: $(free -h | grep '^Mem:' | awk '{print $7}')"
echo "Julia threads: $JULIA_NUM_THREADS"
echo ""

echo "=== Julia Version ==="
/sw/bin/julia --version
echo ""

echo "=== Testing Basic Julia ==="
/sw/bin/julia -e '
println("Julia ", VERSION, " with ", Threads.nthreads(), " threads")
println("Testing basic packages...")
using LinearAlgebra, Statistics, Random
println("✓ LinearAlgebra, Statistics, Random work")

# Test basic math
A = rand(100, 100)
B = A * A
println("✓ Basic matrix operations work")

# Test threading
Threads.@threads for i in 1:Threads.nthreads()
    println("Thread $i running")
end
println("✓ Threading works")
'

echo ""
echo "=== Testing Globtim Source Loading ==="
/sw/bin/julia -e '
println("Loading Globtim source files...")
try
    # Load core modules without package dependencies
    include("src/Structures.jl")
    println("✓ Structures.jl loaded")
    
    include("src/BenchmarkFunctions.jl") 
    println("✓ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl")
    println("✓ LibFunctions.jl loaded")
    
    println("✓ Core Globtim modules loaded successfully!")
catch e
    println("Error loading Globtim: ", e)
end
'

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Job duration: $SECONDS seconds"
