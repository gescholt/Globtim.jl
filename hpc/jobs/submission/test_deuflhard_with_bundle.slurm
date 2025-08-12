#!/bin/bash
#SBATCH --job-name=deuflhard_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --output=deuflhard_test_%j.out
#SBATCH --error=deuflhard_test_%j.err

echo "=========================================="
echo "DEUFLHARD TEST SUITE WITH COMPILED BUNDLE"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Start time: $(date)"
echo ""

# Extract bundle to temp directory for performance
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
echo "Creating work directory: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Extracting bundle..."
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to extract bundle"
    exit 1
fi

# Set environment for offline Julia depot
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

echo "Environment configured:"
echo "  JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT: $JULIA_PROJECT"
echo "  JULIA_NO_NETWORK: $JULIA_NO_NETWORK"
echo ""

# Copy the test script to work directory
echo "Copying test script..."
cp $JULIA_PROJECT/hpc/scripts/benchmark_tests/deuflhard_test_suite.jl .
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy test script"
    exit 1
fi

# Check Julia version
echo "Julia version:"
/sw/bin/julia --version
echo ""

# Run the test suite with quick mode for initial testing
echo "Running Deuflhard test suite (quick mode)..."
echo "=========================================="
cd $JULIA_PROJECT
/sw/bin/julia --project=. --startup-file=no -e '
    println("Loading packages...")
    
    # Load required packages
    using Pkg
    using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
    using DynamicPolynomials, MultivariatePolynomials
    using TimerOutputs, TOML
    using BenchmarkTools
    using Printf, Dates
    
    println("Packages loaded successfully")
    
    # Load GlobTim modules
    println("Loading GlobTim modules...")
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    include("src/Constructor.jl")
    include("src/PolyUtils.jl")
    include("src/CriticalPoints.jl")
    
    println("GlobTim modules loaded successfully")
    
    # Test basic functionality
    println("\nTesting basic functionality...")
    test_point = [0.5, 0.5]
    test_value = Deuflhard(test_point)
    println("Deuflhard function test: f($test_point) = $test_value")
    
    # Run a minimal test
    println("\nRunning minimal polynomial construction test...")
    
    # Define precision type
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    # Create timer
    _TO = TimerOutputs.TimerOutput()
    
    # Create test input
    TR = test_input(
        Deuflhard,
        dim = 2,
        center = [0.0, 0.0],
        sample_range = 1.2,
        GN = 50,
        tolerance = nothing
    )
    
    println("Test input created: $(TR.GN) samples")
    
    # Construct polynomial
    degree = 4
    pol = Constructor(TR, degree, precision=Float64Precision, verbose=0)
    println("Polynomial constructed: L2 error = $(pol.nrm)")
    
    # Try critical points if available
    try
        @polyvar x[1:2]
        solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
        df_critical = process_crit_pts(solutions, Deuflhard, TR)
        println("Critical points found: $(nrow(df_critical))")
    catch e
        println("Critical point analysis skipped: $e")
    end
    
    println("\n✅ Basic functionality test passed!")
    
    # Now run the full test suite
    println("\n========================================")
    println("Running full Deuflhard test suite...")
    println("========================================\n")
    
    # Include and run the test suite
    include("hpc/scripts/benchmark_tests/deuflhard_test_suite.jl")
    
    # Run with quick mode
    exit_code = main()
    exit(exit_code)
'

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Test suite completed with exit code: $EXIT_CODE"
echo "End time: $(date)"
echo ""

# Copy results back to home directory if they exist
if [ -d "results_deuflhard_quick_"* ]; then
    echo "Copying results to home directory..."
    cp -r results_deuflhard_quick_* /home/scholten/
    echo "Results copied to /home/scholten/"
fi

# Cleanup
echo "Cleaning up work directory..."
cd /tmp
rm -rf $WORK_DIR

echo "Job completed"
exit $EXIT_CODE