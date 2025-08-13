#!/bin/bash
#SBATCH --job-name=bottleneck
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:20:00
#SBATCH --mem=8G
#SBATCH --output=bottleneck_%j.out
#SBATCH --error=bottleneck_%j.err

echo "=== Compilation Bottleneck Analysis ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Start: $(date)"
echo ""

# TEST 1: Bundle Path Verification
echo "TEST 1: Verifying Bundle Paths"
echo "==============================="

WORK_DIR="/tmp/bottleneck_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Extracting bundle to identify structure..."
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz

echo "Actual bundle structure:"
find . -maxdepth 3 -type d | sort
echo ""

# Identify the correct paths
if [ -d "globtim_bundle/depot" ]; then
    CORRECT_DEPOT="$WORK_DIR/globtim_bundle/depot"
    CORRECT_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
    echo "✅ Found correct paths:"
elif [ -d "depot" ]; then
    CORRECT_DEPOT="$WORK_DIR/depot"
    CORRECT_PROJECT="$WORK_DIR/globtim_hpc"
    echo "✅ Found alternate paths:"
else
    echo "❌ Cannot determine bundle structure!"
    exit 1
fi

echo "  DEPOT: $CORRECT_DEPOT"
echo "  PROJECT: $CORRECT_PROJECT"
echo ""

# TEST 2: Environment Variable Testing
echo "TEST 2: Testing Environment Variables"
echo "====================================="

export JULIA_DEPOT_PATH="$CORRECT_DEPOT"
export JULIA_PROJECT="$CORRECT_PROJECT"
export JULIA_NO_NETWORK="1"

echo "Set environment:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT=$JULIA_PROJECT"
echo "  JULIA_NO_NETWORK=$JULIA_NO_NETWORK"
echo ""

# TEST 3: Package Detection
echo "TEST 3: Package Detection Test"
echo "=============================="

/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Julia Configuration:")
    println("  VERSION: ", VERSION)
    println("  DEPOT_PATH: ", DEPOT_PATH)
    println("  LOAD_PATH: ", LOAD_PATH)
    println("  Active Project: ", Base.active_project())
    println("")
    
    # Check if we can find packages
    depot = DEPOT_PATH[1]
    pkg_dir = joinpath(depot, "packages")
    
    if isdir(pkg_dir)
        pkgs = readdir(pkg_dir)
        println("✅ Found ", length(pkgs), " packages in depot")
        println("First 5 packages: ", pkgs[1:min(5, end)])
    else
        println("❌ Package directory not found: ", pkg_dir)
    end
    println("")
    
    # Check compiled cache
    compiled_dir = joinpath(depot, "compiled")
    if isdir(compiled_dir)
        println("✅ Compiled cache exists at: ", compiled_dir)
        # List Julia versions
        versions = readdir(compiled_dir)
        println("  Available versions: ", versions)
    else
        println("⚠️  No compiled cache found")
    end
'

echo ""

# TEST 4: Package Loading Bottleneck
echo "TEST 4: Package Loading Bottleneck"
echo "==================================="

echo "Testing individual package loading..."

# Test loading packages one by one to identify which fail
for pkg in "Pkg" "ForwardDiff" "StaticArrays" "TimerOutputs"; do
    echo ""
    echo "Loading $pkg..."
    
    /sw/bin/julia --project="$JULIA_PROJECT" -e "
        println(\"Attempting to load $pkg...\")
        
        start_time = time()
        try
            # First check if package exists
            pkg_path = joinpath(DEPOT_PATH[1], \"packages\", \"$pkg\")
            if isdir(pkg_path)
                println(\"✅ Package source found at: \", pkg_path)
            else
                println(\"❌ Package source NOT found at: \", pkg_path)
            end
            
            # Try to load it
            @eval using $pkg
            elapsed = time() - start_time
            println(\"✅ $pkg loaded successfully in \", round(elapsed, digits=2), \" seconds\")
            
        catch e
            elapsed = time() - start_time
            println(\"❌ $pkg failed after \", round(elapsed, digits=2), \" seconds\")
            println(\"Error: \", e)
            
            # Try to understand why
            if occursin(\"not found in current path\", string(e))
                println(\"  Issue: Package not in path\")
                println(\"  Current LOAD_PATH: \", LOAD_PATH)
            elseif occursin(\"PrecompilationError\", string(e))
                println(\"  Issue: Precompilation failed\")
            else
                println(\"  Issue: Unknown error type\")
            end
        end
    " 2>&1 | head -20  # Limit output
done

echo ""

# TEST 5: Manual Package Path Addition
echo "TEST 5: Manual Package Path Test"
echo "================================="

echo "Trying to manually add package paths..."

/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Manual path manipulation test...")
    
    # Try to manually add paths
    push!(LOAD_PATH, joinpath(DEPOT_PATH[1], "packages"))
    push!(LOAD_PATH, "@stdlib")
    
    println("Modified LOAD_PATH:")
    for (i, path) in enumerate(LOAD_PATH)
        println("  [", i, "] ", path)
    end
    println("")
    
    # Now try loading a package
    try
        using Pkg
        println("✅ Pkg loaded with modified LOAD_PATH")
        
        # Check what Pkg sees
        println("\nPkg environment:")
        Pkg.status()
        
    catch e
        println("❌ Still cannot load Pkg: ", e)
    end
'

echo ""

# TEST 6: Precompilation Cache Analysis
echo "TEST 6: Precompilation Cache Analysis"
echo "====================================="

echo "Checking precompilation cache compatibility..."

if [ -d "$CORRECT_DEPOT/compiled" ]; then
    echo "Compiled cache structure:"
    find $CORRECT_DEPOT/compiled -name "*.ji" | head -5
    echo ""
    
    # Check Julia version compatibility
    JULIA_VERSION=$(/sw/bin/julia --version | cut -d' ' -f3)
    echo "Current Julia version: $JULIA_VERSION"
    
    if [ -d "$CORRECT_DEPOT/compiled/v${JULIA_VERSION%.*}" ]; then
        echo "✅ Compatible compiled cache found for v${JULIA_VERSION%.*}"
    else
        echo "❌ No compiled cache for current Julia version"
        echo "Available versions:"
        ls $CORRECT_DEPOT/compiled/
    fi
else
    echo "No compiled cache in bundle"
fi

echo ""

# TEST 7: Create Fresh Compilation
echo "TEST 7: Fresh Compilation Test"
echo "=============================="

echo "Attempting fresh compilation of a simple package..."

# Create a minimal package that we know exists
if [ -d "$CORRECT_DEPOT/packages/JSON" ]; then
    echo "Testing with JSON package (if available)..."
    
    /sw/bin/julia --project="$JULIA_PROJECT" -e '
        # Set writable compiled path
        empty!(DEPOT_PATH)
        push!(DEPOT_PATH, "'"$CORRECT_DEPOT"'")
        push!(DEPOT_PATH, "'"$WORK_DIR/fresh_depot"'")
        
        println("DEPOT_PATH for compilation:")
        println(DEPOT_PATH)
        println("")
        
        try
            # This should trigger compilation
            Base.compilecache(Base.PkgId("JSON"))
            println("✅ Successfully compiled JSON")
        catch e
            println("❌ Compilation failed: ", e)
        end
    '
fi

echo ""

# SUMMARY
echo "=== BOTTLENECK ANALYSIS SUMMARY ==="
echo "===================================="

echo "Key findings:"
echo "1. Bundle structure: [Check TEST 1]"
echo "2. Package detection: [Check TEST 3]"
echo "3. Loading failures: [Check TEST 4]"
echo "4. Path issues: [Check TEST 5]"
echo "5. Precompilation compatibility: [Check TEST 6]"
echo "6. Fresh compilation capability: [Check TEST 7]"
echo ""

echo "Recommendations:"
echo "- If packages not found: Check JULIA_DEPOT_PATH"
echo "- If loading fails: Check LOAD_PATH and registry"
echo "- If precompilation fails: Version mismatch or permissions"
echo "- If all else fails: Need to rebuild bundle with correct Julia version"
echo ""

echo "End time: $(date)"

# Cleanup
cd /tmp
rm -rf $WORK_DIR

echo "Analysis complete."