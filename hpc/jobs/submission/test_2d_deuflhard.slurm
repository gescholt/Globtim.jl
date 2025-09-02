#!/bin/bash
#SBATCH --job-name=test_2d_deuflhard
#SBATCH --output=slurm_logs/test_2d_%j.out
#SBATCH --error=slurm_logs/test_2d_%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4
#SBATCH --partition=short

# Test SLURM job for 2D Deuflhard example
# Purpose: Validate Julia + GlobTim workflow on r04n02

echo "========================================"
echo "Starting 2D Deuflhard Test Job"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Date: $(date)"
echo "========================================"

# Use the permanent GlobTim repository location
# Update this path to match where you cloned the repository
GLOBTIM_DIR="${GLOBTIM_DIR:-/globtim}"  # Default to /globtim, can be overridden

# Verify the repository exists
if [ ! -d "$GLOBTIM_DIR" ]; then
    echo "ERROR: GlobTim repository not found at $GLOBTIM_DIR"
    echo "Please set GLOBTIM_DIR environment variable to the correct path"
    exit 1
fi

echo "Using GlobTim repository at: $GLOBTIM_DIR"
cd $GLOBTIM_DIR

# Create directories for logs and results if they don't exist
mkdir -p slurm_logs
mkdir -p hpc_results

# Setup Julia environment
module load julia/1.11.2  # Adjust based on available modules
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Create timestamped results directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$GLOBTIM_DIR/hpc_results/test_2d_${TIMESTAMP}_job${SLURM_JOB_ID}"
mkdir -p $RESULTS_DIR

echo "Running 2D Deuflhard test..."
echo "Results will be saved to: $RESULTS_DIR"

# Run the Julia script from the repository directory
julia --project=$GLOBTIM_DIR $GLOBTIM_DIR/hpc/experiments/test_2d_deuflhard.jl $RESULTS_DIR

# Check exit status
if [ $? -eq 0 ]; then
    echo "✅ Test completed successfully"
    echo "Results saved in: $RESULTS_DIR"
    ls -la $RESULTS_DIR/
else
    echo "❌ Test failed with exit code: $?"
    exit 1
fi

echo "========================================"
echo "Job completed at: $(date)"
echo "========================================"