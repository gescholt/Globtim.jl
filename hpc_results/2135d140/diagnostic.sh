#!/bin/bash
#SBATCH --job-name=diagnostic_2135d140#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --output=results/experiments/diagnostic_20250803_154601/jobs/2135d140/slurm_output/diagnostic_%j.out
#SBATCH --error=results/experiments/diagnostic_20250803_154601/jobs/2135d140/slurm_output/diagnostic_%j.err

echo "=== Diagnostic Test ==="
echo "Job ID: 2135d140"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Set environment
export JULIA_NUM_THREADS=4
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/diagnostic_${SLURM_JOB_ID}"

mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment Check ==="
echo "Julia path: $(which julia)"
echo "Julia version:"
/sw/bin/julia --version
echo ""

echo "=== Basic Julia Test ==="
/sw/bin/julia -e 'println("Julia is working!")'
echo ""

echo "=== Package Test ==="
/sw/bin/julia -e '
println("Testing basic packages...")
try
    using LinearAlgebra
    println("✓ LinearAlgebra loaded")
catch e
    println("✗ LinearAlgebra failed: $e")
end

try
    using Statistics
    println("✓ Statistics loaded")
catch e
    println("✗ Statistics failed: $e")
end

try
    using Random
    println("✓ Random loaded")
catch e
    println("✗ Random failed: $e")
end
'
echo ""

echo "=== Globtim Source Test ==="
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC.toml ./Project.toml

echo "Files copied:"
ls -la

echo ""
echo "=== Globtim Loading Test ==="
/sw/bin/julia --project=. -e '
println("Testing Globtim loading...")
try
    include("src/Structures.jl")
    println("✓ Structures.jl loaded")
catch e
    println("✗ Structures.jl failed: $e")
end

try
    include("src/BenchmarkFunctions.jl")
    println("✓ BenchmarkFunctions.jl loaded")
catch e
    println("✗ BenchmarkFunctions.jl failed: $e")
end

try
    include("src/LibFunctions.jl")
    println("✓ LibFunctions.jl loaded")
catch e
    println("✗ LibFunctions.jl failed: $e")
end
'

echo ""
echo "=== Simple Math Test ==="
/sw/bin/julia -e '
using LinearAlgebra
println("Testing basic math...")
A = rand(3,3)
b = rand(3)
x = A \ b
println("✓ Linear solve works: ||Ax - b|| = $(norm(A*x - b))")
'

echo ""
echo "=== Results ==="
echo "Diagnostic completed at: $(date)"
echo "Working directory was: $(pwd)"
echo "Files created:"
ls -la

# Save a simple result
echo "diagnostic_success" > diagnostic_result.txt
cp diagnostic_result.txt ~/globtim_hpc/results/experiments/diagnostic_20250803_154601/jobs/2135d140/

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo "Diagnostic test completed!"
