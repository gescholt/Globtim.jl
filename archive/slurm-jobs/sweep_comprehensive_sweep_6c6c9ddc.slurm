#!/bin/bash
#SBATCH --job-name=sweep_comprehensive_sweep_6c6c9ddc
#SBATCH --output=sweep_comprehensive_sweep_6c6c9ddc.out
#SBATCH --error=sweep_comprehensive_sweep_6c6c9ddc.err
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --partition=batch

echo "🎯 Parameter Sweep: comprehensive_sweep"
echo "================================="
echo "Description: Full parameter space exploration"
echo "Estimated jobs: 36"
echo "Estimated time: 90 minutes"
echo "Batch ID: 6c6c9ddc"
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
mkdir -p sweep_results_6c6c9ddc

# Run parameter combinations
job_count=0

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 3 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 3 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 3 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=3 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 3 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 5 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 5 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 5 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=5 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 5 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=7 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 7 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=7 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 7 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=7 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Sphere4D 7 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Sphere4D deg=7 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Sphere4D 7 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=3 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 3 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=3 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 3 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=3 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 3 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=3 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 3 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=5 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 5 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=5 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 5 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=5 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 5 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=5 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 5 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=7 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 7 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=7 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 7 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=7 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rosenbrock4D 7 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rosenbrock4D deg=7 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rosenbrock4D 7 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=3 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 3 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=3 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 3 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=3 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 3 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=3 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 3 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=5 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 5 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=5 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 5 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=5 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 5 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=5 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 5 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=7 samples=100 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 7 100 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=7 samples=100 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 7 100 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=7 samples=300 domain=1.5"
julia parameter_sweep_runner.jl Rastrigin4D 7 300 1.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "📊 Job $((++job_count)): Rastrigin4D deg=7 samples=300 domain=2.5"
julia parameter_sweep_runner.jl Rastrigin4D 7 300 2.5 sweep_results_6c6c9ddc
echo "✅ Job $job_count completed"
echo

echo "🎯 Parameter sweep completed!"
echo "Total jobs: $job_count"
echo "Results directory: sweep_results_6c6c9ddc"
echo "Finished: $(date)"
