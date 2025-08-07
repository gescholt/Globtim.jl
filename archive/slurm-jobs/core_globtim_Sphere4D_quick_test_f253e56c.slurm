#!/bin/bash
#SBATCH --job-name=core_globtim_Sphere4D_quick_test
#SBATCH --output=core_globtim_Sphere4D_quick_test_f253e56c.out
#SBATCH --error=core_globtim_Sphere4D_quick_test_f253e56c.err
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --partition=batch

echo "🎯 Core Globtim Benchmarking Test"
echo "================================="
echo "Function: Sphere4D"
echo "Parameter Set: quick_test"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "📦 Installing essential packages..."
julia -e '
using Pkg
println("Installing core dependencies...")

# Install essential packages with error handling
essential_packages = [
    "DataFrames", "DynamicPolynomials", "ForwardDiff", 
    "HomotopyContinuation", "Optim", "Parameters", "Distributions"
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
echo "🧪 Testing core dependencies..."
julia -e '
println("Testing package loading...")
try
    using DataFrames, DynamicPolynomials, ForwardDiff
    using HomotopyContinuation, Optim, Parameters, Distributions
    using LinearAlgebra, Statistics, Dates, Printf
    println("✅ All core dependencies loaded successfully")
catch e
    println("❌ Dependency loading failed: $e")
    exit(1)
end
'

echo
echo "🚀 Running core Globtim benchmarking test..."
julia core_globtim_benchmarking.jl Sphere4D quick_test

echo
echo "✅ Core Globtim benchmarking test completed"
echo "Finished: $(date)"
