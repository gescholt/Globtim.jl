#!/bin/bash
#SBATCH --job-name=sweep_basic_sweep_43946012
#SBATCH --output=sweep_basic_sweep_43946012.out
#SBATCH --error=sweep_basic_sweep_43946012.err
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --partition=batch

echo "🎯 Parameter Sweep: basic_sweep"
echo "================================="
echo "Description: Basic parameter exploration"
echo "Estimated jobs: 18"
echo "Estimated time: 30 minutes"
echo "Batch ID: 43946012"
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

echo "🚀 Running parameter sweep..."

# Create results directory
mkdir -p sweep_results_43946012

# Run parameter combinations
job_count=0

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=50 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 3 50 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=50 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 3 50 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=50 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 3 50 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=100 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 3 100 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 3 100 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=100 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 3 100 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=50 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 4 50 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=50 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 4 50 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=50 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 4 50 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=100 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 4 100 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 4 100 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=4 samples=100 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 4 100 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=50 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 5 50 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=50 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 5 50 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=50 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 5 50 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=100 domain=1.0"
julia parameter_sweep_runner.jl Sphere4D 5 100 1.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 5 100 1.5 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=100 domain=2.0"
julia parameter_sweep_runner.jl Sphere4D 5 100 2.0 sweep_results_43946012
echo "✅ Job $job_count completed"
echo

echo "🎯 Parameter sweep completed!"
echo "Total jobs: $job_count"
echo "Results directory: sweep_results_43946012"
echo "Finished: $(date)"
