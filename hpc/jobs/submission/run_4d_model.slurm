#!/bin/bash
#SBATCH --job-name=globtim_4d_model
#SBATCH --output=slurm_logs/4d_model_%j.out
#SBATCH --error=slurm_logs/4d_model_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --partition=medium

# 4D Model Experiment SLURM Job
# Purpose: Run polynomial approximation experiments with dense/sparse comparison

# Parameters (can be overridden via sbatch --export)
SAMPLES_PER_DIM=${SAMPLES_PER_DIM:-10}  # Default 10 samples per dimension
DEGREE=${DEGREE:-12}  # Default degree 12
BASIS=${BASIS:-chebyshev}  # Default Chebyshev basis

echo "========================================"
echo "GlobTim 4D Model Experiment"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Date: $(date)"
echo "Parameters:"
echo "  Samples per dimension: $SAMPLES_PER_DIM"
echo "  Total grid points: $((SAMPLES_PER_DIM**4))"
echo "  Polynomial degree: $DEGREE"
echo "  Basis: $BASIS"
echo "  CPUs: $SLURM_CPUS_PER_TASK"
echo "  Memory: $SLURM_MEM_PER_NODE MB"
echo "========================================"

# Use the permanent GlobTim repository location
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

# Load Julia module
module load julia/1.11.2
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Create timestamped results directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$GLOBTIM_DIR/hpc_results/4d_exp_${TIMESTAMP}_job${SLURM_JOB_ID}"
mkdir -p $RESULTS_DIR

echo "Results directory: $RESULTS_DIR"

# Save job configuration
cat > $RESULTS_DIR/job_config.txt << EOF
Job ID: $SLURM_JOB_ID
Node: $(hostname)
Start time: $(date)
Samples per dimension: $SAMPLES_PER_DIM
Total grid points: $((SAMPLES_PER_DIM**4))
Degree: $DEGREE
Basis: $BASIS
Julia threads: $JULIA_NUM_THREADS
Memory allocated: $SLURM_MEM_PER_NODE MB
EOF

# Create Julia script for this specific run
cat > $GLOBTIM_DIR/run_4d_experiment_${SLURM_JOB_ID}.jl << 'EOF'
using Pkg
Pkg.activate(@__DIR__)

# Load the 4D model configuration
include("hpc/experiments/config_4d_model.jl")
include("Examples/systems/DynamicalSystems.jl")
using .DynamicalSystems

# Get parameters from environment
samples_per_dim = parse(Int, get(ENV, "SAMPLES_PER_DIM", "10"))
degree = parse(Int, get(ENV, "DEGREE", "12"))
basis_str = get(ENV, "BASIS", "chebyshev")
basis = Symbol(basis_str)
results_dir = ARGS[1]

# Setup 4D model configuration
config_4d = ExperimentConfig(
    4,  # dimension
    (:one_d_for_all, degree),
    samples_per_dim,
    samples_per_dim^4,  # total grid points
    0.1,  # sample range
    [0.25, 0.25, 0.45, 0.55],  # center
    [0.0, 5.0],  # time interval
    15,  # time points
    basis,
    Float64Precision,
    true,  # enable sparsification
    1e-8,  # sparsity tolerance
    true,  # save matrices
    true   # verbose
)

# Define the 4D model and error function
model, params, states, outputs = define_daisy_ex3_model_4D()
p_true = [0.2, 0.3, 0.5, 0.6]
ic = [1.0, 2.0, 1.0, 1.0]

error_func = make_error_distance(
    model,
    outputs,
    ic,
    p_true,
    config_4d.time_interval,
    config_4d.num_time_points,
    L2_norm
)

# Run the experiment
println("\nStarting 4D experiment with configuration:")
println("  Samples: $(config_4d.samples_per_dim) per dimension")
println("  Total points: $(config_4d.GN)")
println("  Degree: $(config_4d.d)")
println("  Basis: $(config_4d.basis)")

results, timing = run_4d_experiment(config_4d, error_func, results_dir)

println("\n✅ Experiment completed successfully!")
println("Results saved to: $results_dir")
EOF

# Run the Julia experiment
echo "\nStarting Julia computation..."
julia --project=$GLOBTIM_DIR $GLOBTIM_DIR/run_4d_experiment_${SLURM_JOB_ID}.jl $RESULTS_DIR

# Clean up temporary Julia script
rm -f $GLOBTIM_DIR/run_4d_experiment_${SLURM_JOB_ID}.jl

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Computation completed successfully"
    
    # Display results summary
    echo "\n=== Results Summary ==="
    if [ -f "$RESULTS_DIR/comparison_4d.txt" ]; then
        tail -n 20 "$RESULTS_DIR/comparison_4d.txt"
    fi
    
    # List all output files
    echo "\n=== Generated Files ==="
    ls -lh $RESULTS_DIR/
    
    # Archive results for long-term storage
    ARCHIVE_DIR="/home/scholten/globtim_results"
    if [ -d "$ARCHIVE_DIR" ]; then
        echo "\nArchiving results to: $ARCHIVE_DIR"
        cp -r $RESULTS_DIR $ARCHIVE_DIR/
    fi
else
    echo "❌ Computation failed with exit code: $EXIT_CODE"
    echo "Check error logs for details"
    exit $EXIT_CODE
fi

# Cleanup (optional - comment out for debugging)
# rm -rf $WORKDIR

echo "\n========================================"
echo "Job completed at: $(date)"
echo "Total runtime: $SECONDS seconds"
echo "========================================"