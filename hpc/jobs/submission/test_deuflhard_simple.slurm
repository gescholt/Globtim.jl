#!/bin/bash
#SBATCH --job-name=deuflhard_simple
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --mem=8G
#SBATCH --output=deuflhard_simple_%j.out
#SBATCH --error=deuflhard_simple_%j.err

echo "=========================================="
echo "SIMPLE DEUFLHARD TEST WITH COMPILED BUNDLE"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Start time: $(date)"
echo ""

# Extract bundle to temp directory
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
echo "Creating work directory: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Extracting bundle..."
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz

# Set environment
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

echo "Environment configured"
echo ""

# Create a simple test script
cat > test_deuflhard.jl << 'EOF'
println("Starting Deuflhard test...")
println("Loading packages...")

using Pkg
using ForwardDiff, StaticArrays, DynamicPolynomials
using TimerOutputs, Parameters
using Printf, Dates

println("Core packages loaded")

# Define precision enum
@enum PrecisionType begin
    Float64Precision
    RationalPrecision
    BigFloatPrecision
    BigIntPrecision
    AdaptivePrecision
end

# Create timer
_TO = TimerOutputs.TimerOutput()

println("Loading GlobTim modules...")

# Load modules with full paths
include("$(ENV["JULIA_PROJECT"])/src/BenchmarkFunctions.jl")
include("$(ENV["JULIA_PROJECT"])/src/LibFunctions.jl")
include("$(ENV["JULIA_PROJECT"])/src/Samples.jl")
include("$(ENV["JULIA_PROJECT"])/src/Structures.jl")
include("$(ENV["JULIA_PROJECT"])/src/Constructor.jl")

println("Modules loaded successfully")

# Test Deuflhard function
println("\nTesting Deuflhard function...")
test_point = [0.5, 0.5]
test_value = Deuflhard(test_point)
println("f([0.5, 0.5]) = $test_value")

# Create test input
println("\nCreating test input...")
TR = test_input(
    Deuflhard,
    dim = 2,
    center = [0.0, 0.0],
    sample_range = 1.2,
    GN = 100,
    tolerance = nothing
)
println("Test input created with $(TR.GN) samples")

# Construct polynomial
println("\nConstructing polynomial...")
degree = 6
start_time = time()
pol = Constructor(TR, degree, precision=Float64Precision, verbose=1)
construction_time = time() - start_time

println("\n=== RESULTS ===")
println("Polynomial degree: $degree")
println("Number of samples: $(TR.GN)")
println("L2 error: $(@sprintf("%.2e", pol.nrm))")
println("Condition number: $(@sprintf("%.2e", pol.cond_vandermonde))")
println("Number of coefficients: $(length(pol.coeffs))")
println("Construction time: $(@sprintf("%.3f", construction_time)) seconds")

println("\n✅ Test completed successfully!")
EOF

echo "Running simple Deuflhard test..."
cd $JULIA_PROJECT
/sw/bin/julia --project=. --startup-file=no test_deuflhard.jl

EXIT_CODE=$?

echo ""
echo "Test completed with exit code: $EXIT_CODE"
echo "End time: $(date)"

# Cleanup
cd /tmp
rm -rf $WORK_DIR

exit $EXIT_CODE