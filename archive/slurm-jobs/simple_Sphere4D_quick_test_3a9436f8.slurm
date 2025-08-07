#!/bin/bash
#SBATCH --job-name=simple_Sphere4D_quick_test
#SBATCH --output=simple_Sphere4D_quick_test_3a9436f8.out
#SBATCH --error=simple_Sphere4D_quick_test_3a9436f8.err
#SBATCH --time=00:05:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --partition=batch

echo "🎯 Simple Parametric Test"
echo "========================="
echo "Function: Sphere4D"
echo "Parameter Set: quick_test"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment with temporary depot to avoid quota issues
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
export PATH="/sw/bin:$PATH"

echo "🔧 Julia environment setup:"
echo "   JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"
mkdir -p "$JULIA_DEPOT_PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "🚀 Running simple test..."
julia simple_parametric_test.jl Sphere4D quick_test

echo
echo "✅ Simple test completed"
echo "Finished: $(date)"
