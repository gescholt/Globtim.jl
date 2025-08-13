#!/bin/bash
#SBATCH --job-name=toy_compile
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH --mem=4G
#SBATCH --output=toy_compile_%j.out
#SBATCH --error=toy_compile_%j.err

echo "=== Toy Package Compilation Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Start: $(date)"
echo ""

# PHASE 1: Environment Setup
echo "PHASE 1: Setting up environment"
echo "================================"

WORK_DIR="/tmp/toy_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Work directory: $WORK_DIR"
echo ""

# PHASE 2: Create Toy Package
echo "PHASE 2: Creating toy package"
echo "============================="

mkdir -p ToyPackage/src
cd ToyPackage

# Create Project.toml
cat > Project.toml << 'EOF'
name = "ToyPackage"
uuid = "12345678-1234-5678-1234-567812345678"
version = "0.1.0"

[deps]
# No dependencies for initial test
EOF

# Create simple module
cat > src/ToyPackage.jl << 'EOF'
module ToyPackage
    export greet, compute
    
    greet(name) = "Hello, $name from ToyPackage!"
    
    function compute(x::Float64, y::Float64)
        return x^2 + y^2
    end
    
    # Force some compilation work
    function heavy_compute(n::Int)
        result = 0.0
        for i in 1:n
            result += compute(float(i), float(i+1))
        end
        return result
    end
end
EOF

echo "Created toy package structure:"
ls -la
echo ""

# PHASE 3: Test Direct Loading (No Bundle)
echo "PHASE 3: Testing direct package loading"
echo "======================================="

# Create a minimal depot
export JULIA_DEPOT_PATH="$WORK_DIR/depot"
export JULIA_PROJECT="$WORK_DIR/ToyPackage"
export JULIA_NO_NETWORK="1"

echo "Environment:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT=$JULIA_PROJECT"
echo ""

echo "Attempting to load package directly..."
/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Julia version: ", VERSION)
    println("Active project: ", Base.active_project())
    println("")
    
    # Try to use the package
    try
        # First, try to load it
        include("src/ToyPackage.jl")
        using .ToyPackage
        
        println("✅ Package loaded successfully!")
        println("Testing functions:")
        println("  greet(\"HPC\") = ", ToyPackage.greet("HPC"))
        println("  compute(3.0, 4.0) = ", ToyPackage.compute(3.0, 4.0))
        println("  heavy_compute(100) = ", ToyPackage.heavy_compute(100))
        
    catch e
        println("❌ Failed to load package: ", e)
    end
'

echo ""
echo "Check what was created in depot:"
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "Depot structure:"
    find $JULIA_DEPOT_PATH -type f | head -20
else
    echo "No depot created"
fi
echo ""

# PHASE 4: Test Bundle Extraction and Loading
echo "PHASE 4: Testing bundle approach"
echo "================================="

# Check if bundle exists
if [ -f /home/scholten/globtim_hpc_bundle.tar.gz ]; then
    echo "Found bundle, extracting..."
    
    BUNDLE_DIR="$WORK_DIR/bundle_test"
    mkdir -p $BUNDLE_DIR
    cd $BUNDLE_DIR
    
    # Extract just to see structure (don't load all packages)
    tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz
    
    echo "Bundle structure:"
    ls -la
    echo ""
    
    # Check if packages exist in bundle
    if [ -d "globtim_bundle/depot/packages" ]; then
        echo "Packages in bundle (first 10):"
        ls globtim_bundle/depot/packages | head -10
        echo "Total packages: $(ls globtim_bundle/depot/packages | wc -l)"
    else
        echo "No packages directory found in bundle!"
    fi
    echo ""
    
    # Try to load a simple package from bundle
    export JULIA_DEPOT_PATH="$BUNDLE_DIR/globtim_bundle/depot"
    export JULIA_PROJECT="$BUNDLE_DIR/globtim_bundle/globtim_hpc"
    
    echo "Testing package loading from bundle..."
    /sw/bin/julia --project="$JULIA_PROJECT" -e '
        println("Attempting to load packages from bundle...")
        println("DEPOT_PATH: ", DEPOT_PATH)
        println("")
        
        # Just try to load Pkg first
        try
            using Pkg
            println("✅ Pkg loaded")
            
            # Show what packages are available
            println("\nProject status:")
            Pkg.status(mode=PKGMODE_MANIFEST)
            
        catch e
            println("❌ Failed to load Pkg: ", e)
        end
    '
else
    echo "Bundle not found at /home/scholten/globtim_hpc_bundle.tar.gz"
fi

echo ""

# PHASE 5: Analysis
echo "PHASE 5: Analysis"
echo "================="

echo "Key observations:"
echo "1. Can we create and load a simple package? [Check Phase 3]"
echo "2. Does the depot get created properly? [Check depot structure]"
echo "3. Can we access the bundle? [Check Phase 4]"
echo "4. Are packages in the bundle accessible? [Check bundle loading]"
echo ""

echo "Disk usage:"
du -sh $WORK_DIR/* 2>/dev/null || echo "No significant disk usage"
echo ""

echo "End time: $(date)"
echo ""

# Cleanup
echo "Cleaning up..."
cd /tmp
rm -rf $WORK_DIR

echo "Test complete."