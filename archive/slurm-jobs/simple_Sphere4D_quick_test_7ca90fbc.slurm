#!/bin/bash
#SBATCH --job-name=simple_Sphere4D_quick_test
#SBATCH --output=simple_Sphere4D_quick_test_7ca90fbc.out
#SBATCH --error=simple_Sphere4D_quick_test_7ca90fbc.err
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
