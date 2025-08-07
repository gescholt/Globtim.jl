#!/bin/bash
#SBATCH --job-name=param_Sphere4D_quick_test
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=param_Sphere4D_quick_test_c942936d_%j.out
#SBATCH --error=param_Sphere4D_quick_test_c942936d_%j.err

echo "🎯 Parametric Benchmark Test"
echo "============================="
echo "Function: Sphere4D"
echo "Parameter Set: quick_test"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo ""

# Set up Julia environment
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

# Activate project and install packages
echo "📦 Installing/updating packages..."
julia --project=. -e "
using Pkg
Pkg.instantiate()
if !haskey(Pkg.project().dependencies, \"JSON3\")
    Pkg.add(\"JSON3\")
end
Pkg.precompile()
println(\"✅ Package setup complete\")
"

echo ""
echo "🚀 Running parametric test..."
echo ""

# Run the parametric test
julia --project=. parametric_test_framework.jl Sphere4D quick_test

echo ""
echo "✅ Parametric test completed"
echo "Finished: $(date)"
