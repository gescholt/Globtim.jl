#!/bin/bash
#SBATCH --job-name=globtim_compile_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH --mem=8G
#SBATCH --output=globtim_compile_%j.out
#SBATCH --error=globtim_compile_%j.err

echo "GlobTim Compilation Test"
echo "Job ID: $SLURM_JOB_ID"
echo "Start time: $(date)"
echo ""

# Extract bundle
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR && cd $WORK_DIR
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz

# Set environment
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

# Test compilation
echo "Testing GlobTim compilation..."
/sw/bin/julia --project=. -e '
    println("Loading GlobTim packages...")
    using Pkg
    
    # Test core dependencies
    using ForwardDiff
    using StaticArrays
    using DynamicPolynomials
    using TimerOutputs
    println("✅ Core dependencies loaded")
    
    # Load GlobTim modules
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    println("✅ GlobTim modules loaded successfully")
    
    # Test basic functionality
    test_point = [0.5, 0.5]
    result = Deuflhard(test_point)
    println("✅ Function evaluation: Deuflhard($test_point) = $result")
    
    println("✅ Compilation test completed successfully!")
'

EXIT_CODE=$?
echo ""
echo "Exit code: $EXIT_CODE"
echo "End time: $(date)"

# Cleanup
cd /tmp && rm -rf $WORK_DIR
exit $EXIT_CODE
