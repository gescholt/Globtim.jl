#!/bin/bash
#SBATCH --job-name=test_globtim_examples
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=test_examples_%j.out
#SBATCH --error=test_examples_%j.err

echo "🧪 Testing Globtim HPC Examples"
echo "================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo ""

# Set up Julia environment
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
mkdir -p "$JULIA_DEPOT_PATH"

echo "📦 Julia depot: $JULIA_DEPOT_PATH"
echo ""

# Use system Julia
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo ""

# Stay in current directory (globtim_hpc)
echo "📁 Working directory: $(pwd)"

echo "📁 Working directory: $(pwd)"
echo ""

# Install required packages
echo "📦 Installing required packages..."
julia --project=. -e "
using Pkg
Pkg.instantiate()
Pkg.precompile()
println(\"✅ Package installation complete\")
"

echo ""
echo "🚀 Running test suite..."
echo ""

# Run the test suite
julia --project=. test_hpc_examples.jl

echo ""
echo "✅ Test suite completed"
echo "Finished: $(date)"
