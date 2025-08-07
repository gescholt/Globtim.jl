#!/bin/bash
#SBATCH --job-name=test_focused_examples
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=test_focused_%j.out
#SBATCH --error=test_focused_%j.err

echo "🧪 Testing Focused Globtim Examples"
echo "===================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo ""

# Set up Julia environment (use existing depot from previous job)
export JULIA_DEPOT_PATH="/tmp/julia_depot_59771288"
if [ ! -d "$JULIA_DEPOT_PATH" ]; then
    export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
    mkdir -p "$JULIA_DEPOT_PATH"
fi

echo "📦 Julia depot: $JULIA_DEPOT_PATH"

# Use system Julia
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo ""

echo "📁 Working directory: $(pwd)"
echo ""

# Activate project
echo "📦 Activating project..."
julia --project=. -e "using Pkg; Pkg.instantiate()" || echo "⚠️  Project activation had issues"
echo ""

# Test 1: Parameters.jl Demo
echo "🧪 TEST 1: Parameters.jl Demo"
echo "=============================="
julia --project=. test_parameters_demo.jl
echo ""

# Test 2: Simple Benchmark
echo "🧪 TEST 2: Simple Benchmark"
echo "============================"
julia --project=. test_simple_benchmark.jl
echo ""

# Test 3: 4D Framework
echo "🧪 TEST 3: 4D Framework"
echo "========================"
julia --project=. test_4d_framework.jl
echo ""

echo "✅ All focused tests completed"
echo "Finished: $(date)"
