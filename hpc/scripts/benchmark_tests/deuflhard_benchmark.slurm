#!/bin/bash
#SBATCH --job-name=deuflhard_benchmark
#SBATCH --partition=batch          # Default partition: 24h max, 3120 cores
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24         # Use all cores for Julia threading
#SBATCH --time=02:00:00            # 2 hours for comprehensive testing
#SBATCH --mem=64G                  # 64GB memory for large polynomial computations
#SBATCH --output=deuflhard_benchmark_%j.out
#SBATCH --error=deuflhard_benchmark_%j.err

# Deuflhard Benchmark Test Suite
# Comprehensive testing of polynomial construction and critical point finding

echo "=== Deuflhard Benchmark Test Suite ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"
export TMPDIR="/tmp/deuflhard_benchmark_${SLURM_JOB_ID}"

# Create temporary working directory
mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo "Memory info: $(free -h | grep '^Mem:' | awk '{print $2 " total, " $7 " available"}')"
echo ""

# Copy Globtim source and test suite
echo "=== Setting up Globtim source ==="
if [ -d "$HOME/globtim_hpc/src" ]; then
    echo "Copying Globtim source from home directory..."
    cp -r "$HOME/globtim_hpc/src" .
    cp "$HOME/globtim_hpc/Project.toml" . 2>/dev/null || true
    
    # Copy test suite
    if [ -d "$HOME/globtim_hpc/hpc/scripts/benchmark_tests" ]; then
        cp -r "$HOME/globtim_hpc/hpc/scripts/benchmark_tests" .
        echo "✓ Test suite copied"
    else
        echo "⚠️  Test suite not found, using fallback"
        # Create minimal test if main suite not available
        cat > simple_deuflhard_test.jl << 'EOF'
# Fallback Deuflhard test
println("🧪 Simple Deuflhard Test")

# Load packages
using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
using DynamicPolynomials, MultivariatePolynomials, TimerOutputs, TOML

# Define PrecisionType enum
@enum PrecisionType begin
    Float64Precision
    RationalPrecision
    BigFloatPrecision
    BigIntPrecision
    AdaptivePrecision
end

# Define TimerOutput instance
global _TO = TimerOutputs.TimerOutput()

# Load Globtim modules
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")
include("src/Samples.jl")
include("src/Structures.jl")

# Test Deuflhard function
println("Testing Deuflhard function...")
test_point = [0.5, 0.5]
test_value = Deuflhard(test_point)
println("✅ Deuflhard($test_point) = $test_value")

# Test polynomial construction
println("Testing polynomial construction...")
TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.2, GN=100)
pol = Constructor(TR, 6, precision=Float64Precision, verbose=0)
println("✅ Polynomial constructed: L2 error = $(pol.nrm)")

# Test critical point finding
println("Testing critical point finding...")
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 6, pol.coeffs)
df_critical = process_crit_pts(solutions, Deuflhard, TR)
println("✅ Found $(nrow(df_critical)) critical points")

println("🎉 Simple Deuflhard test completed successfully!")
EOF
    fi
    
    echo "✓ Source setup complete"
else
    echo "❌ Globtim source not found in $HOME/globtim_hpc/"
    echo "Available files in home:"
    ls -la "$HOME/" | head -10
    exit 1
fi

echo ""
echo "Files in working directory:"
ls -la
echo ""

# Determine test mode from job parameters or environment
TEST_MODE="standard"
CUSTOM_DEGREE=""
CUSTOM_SAMPLES=""

# Parse job name for mode
if [[ "$SLURM_JOB_NAME" == *"quick"* ]]; then
    TEST_MODE="quick"
elif [[ "$SLURM_JOB_NAME" == *"thorough"* ]]; then
    TEST_MODE="thorough"
fi

# Check for custom parameters in environment
if [ ! -z "$BENCHMARK_DEGREE" ]; then
    CUSTOM_DEGREE="--degree=$BENCHMARK_DEGREE"
fi

if [ ! -z "$BENCHMARK_SAMPLES" ]; then
    CUSTOM_SAMPLES="--samples=$BENCHMARK_SAMPLES"
fi

echo "=== Running Deuflhard Benchmark Suite ==="
echo "Test mode: $TEST_MODE"
echo "Custom parameters: $CUSTOM_DEGREE $CUSTOM_SAMPLES"
echo ""

# Run the benchmark test suite
if [ -f "benchmark_tests/deuflhard_test_suite.jl" ]; then
    echo "Running comprehensive test suite..."
    /sw/bin/julia --project=. benchmark_tests/deuflhard_test_suite.jl --$TEST_MODE $CUSTOM_DEGREE $CUSTOM_SAMPLES
    TEST_EXIT_CODE=$?
elif [ -f "simple_deuflhard_test.jl" ]; then
    echo "Running fallback simple test..."
    /sw/bin/julia --project=. simple_deuflhard_test.jl
    TEST_EXIT_CODE=$?
else
    echo "❌ No test suite found"
    TEST_EXIT_CODE=1
fi

echo ""
echo "=== Test Results Collection ==="

# Collect all result files
RESULTS_DIR="deuflhard_results_${SLURM_JOB_ID}"
mkdir -p $RESULTS_DIR

# Copy any generated result files
find . -name "results_*" -type d -exec cp -r {} $RESULTS_DIR/ \;
find . -name "*.csv" -exec cp {} $RESULTS_DIR/ \;
find . -name "*.txt" -exec cp {} $RESULTS_DIR/ \;

# Create job summary
cat > $RESULTS_DIR/job_summary.txt << EOF
# Deuflhard Benchmark Job Summary
Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Test Mode: $TEST_MODE
Custom Parameters: $CUSTOM_DEGREE $CUSTOM_SAMPLES
Start Time: $(date)
Exit Code: $TEST_EXIT_CODE
Julia Version: $(/sw/bin/julia --version)
CPUs: $SLURM_CPUS_PER_TASK
Memory: $SLURM_MEM_PER_NODE MB

# Environment
Julia Depot: $JULIA_DEPOT_PATH
Working Directory: $(pwd)
Available Space: $(df -h . | tail -1 | awk '{print $4}')

# Results Generated
$(ls -la $RESULTS_DIR/)
EOF

echo "Results collected in: $RESULTS_DIR"
echo "Files:"
ls -la $RESULTS_DIR/

# Copy results back to home directory if possible
if [ -d "$HOME/globtim_hpc" ]; then
    echo ""
    echo "Copying results to home directory..."
    cp -r $RESULTS_DIR "$HOME/globtim_hpc/benchmark_results_${SLURM_JOB_ID}/"
    echo "✓ Results copied to $HOME/globtim_hpc/benchmark_results_${SLURM_JOB_ID}/"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Job duration: $SECONDS seconds"
echo "Exit code: $TEST_EXIT_CODE"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "🎉 DEUFLHARD BENCHMARK SUCCESSFUL"
else
    echo "❌ DEUFLHARD BENCHMARK FAILED"
fi

exit $TEST_EXIT_CODE
