#!/bin/bash
#SBATCH --job-name=globtim_Sphere4D_quick_test
#SBATCH --output=globtim_Sphere4D_quick_test_a7b3a125.out
#SBATCH --error=globtim_Sphere4D_quick_test_a7b3a125.err
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --partition=batch

echo "🎯 Full Globtim Parametric Test"
echo "==============================="
echo "Function: Sphere4D"
echo "Parameter Set: quick_test"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "📦 Setting up minimal Globtim environment..."
# Copy Globtim source and use minimal Project.toml
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC_Minimal.toml ./Project.toml

echo "📦 Installing essential packages..."
julia --project=. -e '
using Pkg
println("Installing core Globtim dependencies...")

# Install essential packages with error handling
essential_packages = [
    "DataFrames", "DynamicPolynomials", "ForwardDiff", 
    "HomotopyContinuation", "Optim", "LinearAlgebra",
    "Statistics", "Distributions", "Parameters"
]

for pkg in essential_packages
    try
        println("Installing $pkg...")
        Pkg.add(pkg)
        println("✓ $pkg installed")
    catch e
        println("⚠️  Failed to install $pkg: $e")
    end
end

println("📦 Package installation complete")
'

echo
echo "🚀 Running full Globtim parametric test..."
julia --project=. full_globtim_parametric_test.jl Sphere4D quick_test

echo
echo "✅ Full Globtim test completed"
echo "Finished: $(date)"
