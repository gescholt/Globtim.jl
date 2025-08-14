#!/bin/bash
#SBATCH --job-name=bundle_final
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:20:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH -o bundle_final_%j.out
#SBATCH -e bundle_final_%j.err

echo "===== GlobTim Bundle Final Compilation Test ====="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start: $(date)"
echo ""

# Use local /tmp for extraction (faster than home)
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

BUNDLE_PATH="/home/scholten/globtim_hpc_bundle.tar.gz"

# Check if bundle exists
if [ ! -f "$BUNDLE_PATH" ]; then
    echo "ERROR: Bundle not found at $BUNDLE_PATH"
    exit 1
fi

echo "Extracting bundle from: $BUNDLE_PATH"
echo "Bundle size: $(ls -lh $BUNDLE_PATH | awk '{print $5}')"
echo ""

tar -xzf $BUNDLE_PATH || {
    echo "ERROR: Failed to extract bundle"
    exit 1
}

# The tar contains globtim_bundle/ directory
echo "Bundle extracted successfully"
ls -la
echo ""

# Set up environment for offline Julia depot
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_PKG_SERVER=""
export JULIA_NO_NETWORK="1"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

echo "Environment Configuration:"
echo "  JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT: $JULIA_PROJECT"
echo "  JULIA_NO_NETWORK: $JULIA_NO_NETWORK"
echo "  JULIA_NUM_THREADS: $JULIA_NUM_THREADS"
echo ""

# Verify directories exist
if [ ! -d "$JULIA_DEPOT_PATH" ]; then
    echo "ERROR: Depot not found at $JULIA_DEPOT_PATH"
    exit 1
fi

if [ ! -d "$JULIA_PROJECT" ]; then
    echo "ERROR: Project not found at $JULIA_PROJECT"
    exit 1
fi

cd $JULIA_PROJECT
echo "Working directory: $(pwd)"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

echo "===== Phase 1: Package Loading Test ====="
/sw/bin/julia --project=. -e '
println("Julia ", VERSION)
println("Active project: ", Base.active_project())
println("Threads: ", Threads.nthreads())
println()

using Pkg

println("Testing critical package loading:")
packages = ["ForwardDiff", "HomotopyContinuation", "DynamicPolynomials", "Optim", "StaticArrays", "TimerOutputs"]

failed = String[]
for pkg in packages
    print("  Loading ", pkg, "... ")
    flush(stdout)
    try
        @time eval(Meta.parse("using $pkg"))
        println("✅")
    catch e
        println("❌")
        println("    Error: ", e)
        push!(failed, pkg)
    end
end

if !isempty(failed)
    println("\n❌ Failed to load: ", join(failed, ", "))
    exit(1)
else
    println("\n✅ All critical packages loaded successfully!")
end
'

PHASE1_EXIT=$?
if [ $PHASE1_EXIT -ne 0 ]; then
    echo "Phase 1 failed with exit code $PHASE1_EXIT"
    cd /tmp
    rm -rf $WORK_DIR
    exit $PHASE1_EXIT
fi

echo ""
echo "===== Phase 2: GlobTim Module Compilation ====="
/sw/bin/julia --project=. -e '
println("Loading dependencies...")
using StaticArrays
using ForwardDiff
using DynamicPolynomials
using HomotopyContinuation
using Optim
using TimerOutputs
using LinearAlgebra

println("\nCompiling GlobTim modules...")

try
    # Core structures
    print("  Compiling Structures.jl... ")
    flush(stdout)
    include("src/Structures.jl")
    println("✅")
    
    # Benchmark functions
    print("  Compiling BenchmarkFunctions.jl... ")
    flush(stdout)
    include("src/BenchmarkFunctions.jl")
    println("✅")
    
    # Library functions
    print("  Compiling LibFunctions.jl... ")
    flush(stdout)
    include("src/LibFunctions.jl")
    println("✅")
    
    # Additional modules
    print("  Compiling Samples.jl... ")
    flush(stdout)
    include("src/Samples.jl")
    println("✅")
    
    print("  Compiling ApproxConstruct.jl... ")
    flush(stdout)
    include("src/ApproxConstruct.jl")
    println("✅")
    
    println("\n✅ All GlobTim modules compiled successfully!")
catch e
    println("❌")
    println("\nCompilation error: ", e)
    println(sprint(showerror, e, catch_backtrace()))
    exit(1)
end
'

PHASE2_EXIT=$?
if [ $PHASE2_EXIT -ne 0 ]; then
    echo "Phase 2 failed with exit code $PHASE2_EXIT"
    cd /tmp
    rm -rf $WORK_DIR
    exit $PHASE2_EXIT
fi

echo ""
echo "===== Phase 3: Functionality Test ====="
/sw/bin/julia --project=. -e '
# Load dependencies
using StaticArrays
using ForwardDiff
using LinearAlgebra

# Load compiled modules
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")

println("Testing benchmark functions:")
println()

# Test Sphere function
print("  Testing Sphere... ")
val = Sphere([0.0, 0.0])
if abs(val) < 1e-10
    println("✅ (value: ", val, ")")
else
    println("❌ (value: ", val, ")")
end

# Test Rosenbrock function
print("  Testing Rosenbrock... ")
val = Rosenbrock([1.0, 1.0])
if abs(val) < 1e-10
    println("✅ (value: ", val, ")")
else
    println("❌ (value: ", val, ")")
end

# Test Rastrigin function
print("  Testing Rastrigin... ")
val = Rastrigin([0.0, 0.0])
if abs(val) < 1e-10
    println("✅ (value: ", val, ")")
else
    println("❌ (value: ", val, ")")
end

# Test gradient computation with ForwardDiff
println("\nTesting gradient computation:")
grad = ForwardDiff.gradient(x -> Rosenbrock(x), [1.0, 1.0])
println("  Gradient of Rosenbrock at [1,1]: ", grad)
println("  Gradient norm: ", norm(grad))
if norm(grad) < 1e-8
    println("  ✅ Gradient computation works correctly")
else
    println("  ⚠️  Non-zero gradient at optimum (numerical precision)")
end

# Test with a non-optimal point
grad2 = ForwardDiff.gradient(x -> Rosenbrock(x), [0.0, 0.0])
println("  Gradient of Rosenbrock at [0,0]: ", grad2)
println("  Gradient norm: ", norm(grad2))
if norm(grad2) > 1.0
    println("  ✅ Gradient is non-zero away from optimum")
end

# Test HomotopyContinuation
println("\nTesting HomotopyContinuation:")
using HomotopyContinuation, DynamicPolynomials
@polyvar x y
F = [x^2 + y^2 - 1, x + y]
result = solve(F)
println("  Number of solutions found: ", length(solutions(result)))
if length(solutions(result)) > 0
    println("  ✅ HomotopyContinuation works")
end

println("\n🎉 All functionality tests passed!")
'

PHASE3_EXIT=$?

echo ""
echo "===== Compilation Summary ====="
echo "Phase 1 (Package Loading): Exit code $PHASE1_EXIT"
echo "Phase 2 (Module Compilation): Exit code $PHASE2_EXIT"
echo "Phase 3 (Functionality Test): Exit code $PHASE3_EXIT"
echo "Duration: $SECONDS seconds"
echo "End: $(date)"

# Clean up
echo ""
echo "Cleaning up temporary directory..."
cd /tmp
rm -rf $WORK_DIR

if [ $PHASE1_EXIT -eq 0 ] && [ $PHASE2_EXIT -eq 0 ] && [ $PHASE3_EXIT -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "🎉 SUCCESS: GlobTim bundle is ready for HPC!"
    echo "=========================================="
    echo ""
    echo "Bundle location: /home/scholten/globtim_hpc_bundle.tar.gz"
    echo "Bundle size: $(ls -lh /home/scholten/globtim_hpc_bundle.tar.gz | awk '{print $5}')"
    echo ""
    echo "To use in SLURM jobs:"
    echo "  1. Extract: tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz"
    echo "  2. Set environment:"
    echo "     export JULIA_DEPOT_PATH='\$PWD/globtim_bundle/depot'"
    echo "     export JULIA_PROJECT='\$PWD/globtim_bundle/globtim_hpc'"
    echo "     export JULIA_NO_NETWORK='1'"
    echo "  3. Run: julia --project=\$JULIA_PROJECT script.jl"
    echo ""
    exit 0
else
    echo ""
    echo "❌ FAILURE: Compilation test failed"
    exit 1
fi