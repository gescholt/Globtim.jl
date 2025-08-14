#!/bin/bash
#SBATCH --job-name=bundle_verify
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --output=bundle_verify_%j.out
#SBATCH --error=bundle_verify_%j.err

echo "Bundle Verification Test"
echo "========================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Start time: $(date)"
echo ""

# Step 1: Check bundle exists
echo "Step 1: Checking bundle file..."
if [ -f /home/scholten/globtim_hpc_bundle.tar.gz ]; then
    echo "✅ Bundle found: /home/scholten/globtim_hpc_bundle.tar.gz"
    ls -lh /home/scholten/globtim_hpc_bundle.tar.gz
else
    echo "❌ Bundle not found!"
    exit 1
fi
echo ""

# Step 2: Extract bundle
echo "Step 2: Extracting bundle..."
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz
if [ $? -eq 0 ]; then
    echo "✅ Bundle extracted successfully"
else
    echo "❌ Bundle extraction failed"
    exit 1
fi
echo ""

# Step 3: Verify extracted structure
echo "Step 3: Verifying bundle structure..."
if [ -d "globtim_bundle/depot" ] && [ -d "globtim_bundle/globtim_hpc" ]; then
    echo "✅ Bundle structure correct"
    echo "   - Depot: globtim_bundle/depot"
    echo "   - Project: globtim_bundle/globtim_hpc"
else
    echo "❌ Bundle structure incorrect"
    echo "Contents of $WORK_DIR:"
    ls -la
    exit 1
fi
echo ""

# Step 4: Check depot contents
echo "Step 4: Checking depot contents..."
echo "Depot packages:"
ls globtim_bundle/depot/packages/ | head -10
echo "..."
echo "Total packages: $(ls globtim_bundle/depot/packages/ | wc -l)"
echo ""

# Step 5: Check project files
echo "Step 5: Checking project files..."
if [ -f "globtim_bundle/globtim_hpc/Project.toml" ] && [ -f "globtim_bundle/globtim_hpc/Manifest.toml" ]; then
    echo "✅ Project files found"
    echo "Project.toml dependencies:"
    grep -A 20 "\[deps\]" globtim_bundle/globtim_hpc/Project.toml
else
    echo "❌ Project files missing"
    exit 1
fi
echo ""

# Step 6: Check GlobTim source files
echo "Step 6: Checking GlobTim source files..."
if [ -d "globtim_bundle/globtim_hpc/src" ]; then
    echo "✅ Source directory found"
    echo "Source files:"
    ls globtim_bundle/globtim_hpc/src/*.jl | head -10
else
    echo "❌ Source directory missing"
    exit 1
fi
echo ""

# Step 7: Test Julia with correct environment
echo "Step 7: Testing Julia environment..."
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

echo "Environment variables:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT=$JULIA_PROJECT"
echo "  JULIA_NO_NETWORK=$JULIA_NO_NETWORK"
echo ""

# Step 8: Simple Julia test
echo "Step 8: Running simple Julia test..."
/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Julia version: ", VERSION)
    println("Project: ", Base.active_project())
    println("Depot path: ", DEPOT_PATH)
    
    # Try to load Pkg
    using Pkg
    println("✅ Pkg loaded")
    
    # Show status
    println("\nProject status:")
    Pkg.status()
'

JULIA_EXIT=$?
echo "Julia exit code: $JULIA_EXIT"
echo ""

# Step 9: Test package loading
echo "Step 9: Testing package loading..."
/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Testing package loading...")
    
    try
        using Pkg
        
        # Try to load each dependency
        packages = ["ForwardDiff", "StaticArrays", "DynamicPolynomials", "TimerOutputs"]
        
        for pkg in packages
            print("Loading $pkg... ")
            try
                eval(Meta.parse("using $pkg"))
                println("✅")
            catch e
                println("❌ $e")
            end
        end
        
    catch e
        println("Error: $e")
        exit(1)
    end
'

LOAD_EXIT=$?
echo "Package loading exit code: $LOAD_EXIT"
echo ""

# Step 10: Summary
echo "========== SUMMARY =========="
if [ $JULIA_EXIT -eq 0 ] && [ $LOAD_EXIT -eq 0 ]; then
    echo "✅ Bundle verification PASSED"
    EXIT_CODE=0
else
    echo "❌ Bundle verification FAILED"
    EXIT_CODE=1
fi

echo "End time: $(date)"
echo ""

# Cleanup
cd /tmp
rm -rf $WORK_DIR

exit $EXIT_CODE