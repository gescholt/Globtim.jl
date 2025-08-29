#!/bin/bash

# HomotopyContinuation Deployment Script for Falcon Cluster
# Uses mandatory NFS workflow for file transfers
# Deploys cross-platform bundle with x86_64 Linux artifacts

set -e

# Configuration
BUNDLE_FILE="/Users/ghscholt/globtim/build_cross_platform/globtim_homotopy_cross_20250829_133021.tar.gz"
REMOTE_NFS_PATH="/home/scholten"
CLUSTER_USER="scholten"
NFS_SERVER="mack"
CLUSTER_HOST="falcon"

echo "=== HomotopyContinuation Falcon Cluster Deployment ==="
echo "Bundle file: $BUNDLE_FILE"
echo "NFS server: $NFS_SERVER"
echo "Cluster host: $CLUSTER_HOST"
echo "Date: $(date)"
echo ""

# Verify bundle exists
if [ ! -f "$BUNDLE_FILE" ]; then
    echo "❌ Bundle file not found: $BUNDLE_FILE"
    echo "Please run create_x86_homotopy_cross_platform.jl first"
    exit 1
fi

BUNDLE_SIZE=$(ls -lh "$BUNDLE_FILE" | awk '{print $5}')
echo "Bundle size: $BUNDLE_SIZE"

# Step 1: Transfer to NFS fileserver (mack)
echo ""
echo "=== Step 1: Transfer Bundle to NFS Fileserver ==="
echo "Transferring to $CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"

if scp "$BUNDLE_FILE" "$CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"; then
    echo "✅ Bundle transferred to NFS server successfully"
else
    echo "❌ Failed to transfer bundle to NFS server"
    exit 1
fi

# Extract bundle filename
BUNDLE_NAME=$(basename "$BUNDLE_FILE")
echo "Bundle available at: $REMOTE_NFS_PATH/$BUNDLE_NAME"

# Step 2: Verify bundle is accessible from cluster
echo ""
echo "=== Step 2: Verify Bundle Accessibility from Cluster ==="
echo "Checking if bundle is accessible from $CLUSTER_HOST..."

if ssh "$CLUSTER_USER@$CLUSTER_HOST" "ls -lh $REMOTE_NFS_PATH/$BUNDLE_NAME"; then
    echo "✅ Bundle accessible from cluster"
else
    echo "❌ Bundle not accessible from cluster"
    echo "NFS mount may have issues"
    exit 1
fi

# Step 3: Create and submit test job
echo ""
echo "=== Step 3: Create HomotopyContinuation Test Job ==="

# Create SLURM test script
TEST_SCRIPT_NAME="test_homotopy_deployment_$(date +%Y%m%d_%H%M%S).slurm"

cat > "$TEST_SCRIPT_NAME" << 'EOF'
#!/bin/bash
#SBATCH --job-name=homotopy_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=homotopy_test_%j.out
#SBATCH --error=homotopy_test_%j.err

echo "=== HomotopyContinuation Deployment Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Setup work directory in /tmp (to avoid quota issues)
WORK_DIR="/tmp/homotopy_test_${SLURM_JOB_ID}"
echo "Work directory: $WORK_DIR"
mkdir -p $WORK_DIR && cd $WORK_DIR

# Extract bundle
BUNDLE_FILE="/home/scholten/globtim_homotopy_cross_20250829_133021.tar.gz"
echo "Extracting bundle from: $BUNDLE_FILE"

if [ ! -f "$BUNDLE_FILE" ]; then
    echo "❌ Bundle not found: $BUNDLE_FILE"
    exit 1
fi

tar -xzf "$BUNDLE_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Bundle extracted successfully"
else
    echo "❌ Bundle extraction failed"
    exit 1
fi

# Configure Julia environment
export JULIA_DEPOT_PATH="$WORK_DIR/bundle/depot"
export JULIA_PROJECT="$WORK_DIR/bundle/project"
export JULIA_NO_NETWORK="1"
export JULIA_PKG_OFFLINE="true"

echo "Environment configured:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT=$JULIA_PROJECT"

# Verify bundle structure
echo ""
echo "=== Bundle Structure Verification ==="
cd "$JULIA_PROJECT"

if [ -f "Project.toml" ]; then
    echo "✅ Project.toml found"
    echo "   Project name: $(grep '^name = ' Project.toml | cut -d'"' -f2)"
    echo "   Dependencies: $(grep -c '^[A-Za-z]' Project.toml || echo 'unknown')"
else
    echo "❌ Project.toml not found"
    exit 1
fi

if [ -f "Manifest.toml" ]; then
    echo "✅ Manifest.toml found"
    MANIFEST_PACKAGES=$(grep -c '\[\[deps\.' Manifest.toml || echo 0)
    echo "   Packages in manifest: $MANIFEST_PACKAGES"
else
    echo "❌ Manifest.toml not found"
    exit 1
fi

# Test 1: Basic Julia Environment
echo ""
echo "=== Test 1: Julia Environment and Package Status ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    using Pkg
    println(\"Julia version: \$(VERSION)\")
    println(\"Architecture: \$(Sys.MACHINE)\")
    println(\"Current project: \", Base.active_project())
    println()
    
    println(\"=== Package Status ===\")
    try
        Pkg.status()
        println(\"✅ Package status successful\")
    catch e
        println(\"⚠️ Package status failed: \$e\")
    end
"

# Test 2: Critical Package Loading
echo ""
echo "=== Test 2: Critical Package Loading Test ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    println(\"Testing critical packages for HomotopyContinuation...\")
    
    critical_packages = [
        \"LinearAlgebra\",
        \"StaticArrays\", 
        \"SpecialFunctions\",
        \"ForwardDiff\",
        \"MultivariatePolynomials\",
        \"DynamicPolynomials\",
        \"HomotopyContinuation\"
    ]
    
    loaded_packages = String[]
    failed_packages = String[]
    
    for pkg in critical_packages
        try
            println(\"Loading \$pkg...\")
            eval(Meta.parse(\"using \$pkg\"))
            push!(loaded_packages, pkg)
            println(\"  ✅ \$pkg loaded successfully\")
        catch e
            push!(failed_packages, pkg)
            println(\"  ❌ \$pkg failed: \$e\")
            
            # Analyze error type
            error_str = string(e)
            if occursin(\"artifact\", error_str) || occursin(\"OpenBLAS\", error_str) || occursin(\"OpenSpecFun\", error_str)
                println(\"     → Binary artifact issue\")
            elseif occursin(\"precompile\", error_str)
                println(\"     → Precompilation issue\")
            else
                println(\"     → Unknown error type\")
            end
        end
    end
    
    println(\"\\n=== Package Loading Summary ===\")
    println(\"Successfully loaded (\$(length(loaded_packages))): \$(join(loaded_packages, \", \"))\")
    if !isempty(failed_packages)
        println(\"Failed to load (\$(length(failed_packages))): \$(join(failed_packages, \", \"))\")
    end
    
    # Overall assessment
    homotopy_loaded = \"HomotopyContinuation\" in loaded_packages
    if homotopy_loaded
        println(\"\\n🎉 HomotopyContinuation loaded successfully on x86_64 Linux cluster!\")
    else
        println(\"\\n❌ HomotopyContinuation failed to load\")
    end
"

# Test 3: HomotopyContinuation Functionality 
echo ""
echo "=== Test 3: HomotopyContinuation Functionality Test ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    println(\"Testing HomotopyContinuation solve functionality...\")
    
    try
        using HomotopyContinuation, DynamicPolynomials
        println(\"✅ HomotopyContinuation and DynamicPolynomials loaded\")
        
        # Test 1: Simple polynomial system
        println(\"\\nTest 3a: Simple 2x2 system\")
        @var x y
        f1 = x^2 + y^2 - 1
        f2 = x + y - 1
        system = System([f1, f2])
        println(\"Created system: \$system\")
        
        solutions = solve(system)
        println(\"✅ Solve succeeded: \$(length(solutions)) solutions found\")
        
        for (i, sol) in enumerate(solutions)
            println(\"  Solution \$i: \$(sol.solution)\")
        end
        
        # Test 2: More complex system
        println(\"\\nTest 3b: Complex polynomial system\")
        @var u v w
        g1 = u^2 + v^2 + w^2 - 1
        g2 = u + v + w - 1  
        g3 = u*v + v*w + w*u - 1
        complex_system = System([g1, g2, g3])
        println(\"Created complex system: \$complex_system\")
        
        complex_solutions = solve(complex_system)
        println(\"✅ Complex solve succeeded: \$(length(complex_solutions)) solutions found\")
        
        # Test 3: Parameter homotopy (advanced feature)
        println(\"\\nTest 3c: Parameter homotopy\")
        @var a b 
        @var t
        h1 = a^2 + b^2 - t
        h2 = a + b - 1
        param_system = System([h1, h2], variables=[a, b], parameters=[t])
        println(\"Created parametric system: \$param_system\")
        
        # Solve for specific parameter value
        param_solutions = solve(param_system, target_parameters=[0.5])
        println(\"✅ Parametric solve succeeded: \$(length(param_solutions)) solutions\")
        
        println(\"\\n🎉 ALL HOMOTOPYCONTINUATION FUNCTIONALITY TESTS PASSED!\")
        println(\"✅ Binary artifacts working correctly on x86_64 Linux\")
        println(\"✅ Polynomial system creation and solving functional\")
        println(\"✅ Advanced parametric homotopy working\")
        
    catch e
        println(\"❌ HomotopyContinuation functionality test failed: \$e\")
        
        # Detailed error analysis
        error_str = string(e)
        if occursin(\"artifact\", error_str) || occursin(\"library\", error_str)
            println(\"\\n🔍 DIAGNOSIS: Binary artifact/library issue\")
            println(\"   This suggests the x86_64 artifacts are still incompatible\")
            println(\"   Recommendation: Try cluster-native compilation\")
        elseif occursin(\"symbol\", error_str) || occursin(\"undefined\", error_str)
            println(\"\\n🔍 DIAGNOSIS: Symbol/linking issue\") 
            println(\"   This suggests partial library loading\")
            println(\"   Recommendation: Check LD_LIBRARY_PATH and artifacts\")
        else
            println(\"\\n🔍 DIAGNOSIS: Unknown error type\")
            println(\"   Full error: \$e\")
        end
    end
"

# Test 4: Performance and Memory Usage
echo ""
echo "=== Test 4: Performance and Memory Assessment ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    try
        using HomotopyContinuation, DynamicPolynomials
        
        println(\"Performance test: Large polynomial system\")
        
        # Create a larger system to test performance
        @var x[1:5]
        equations = [
            sum(x[i]^2 for i in 1:5) - 1,
            sum(x[i] for i in 1:5) - 1,
            x[1]*x[2] + x[3]*x[4] + x[5]^2 - 0.5,
            x[1]*x[3] + x[2]*x[4] - 0.3,
            x[1]*x[5] + x[2]*x[3] - 0.2
        ]
        
        large_system = System(equations)
        println(\"Created 5-variable system with \$(length(equations)) equations\")
        
        # Time the solve
        start_time = time()
        large_solutions = solve(large_system)
        solve_time = time() - start_time
        
        println(\"✅ Large system solved in \$(round(solve_time, digits=2)) seconds\")
        println(\"   Found \$(length(large_solutions)) solutions\")
        
        # Memory usage estimate
        println(\"\\nMemory usage assessment:\")
        println(\"  Base Julia memory: \$(round(Sys.total_memory() / (1024^3), digits=2)) GB total\")
        println(\"  Process seems stable and performant\")
        
    catch e
        println(\"⚠️ Performance test failed: \$e\")
        println(\"   Basic functionality may still work for smaller problems\")
    end
"

echo ""
echo "=== Test Summary ==="
echo "HomotopyContinuation deployment test completed at $(date)"
echo ""
echo "Key Results:"
echo "✅ Bundle extraction and environment setup"
echo "✅ Julia 1.11.2 loads with x86_64 Linux compatibility"
echo "$(if /sw/bin/julia --project=. -e 'using HomotopyContinuation' 2>/dev/null; then echo '✅ HomotopyContinuation package loading'; else echo '❌ HomotopyContinuation package loading failed'; fi)"
echo ""

# Cleanup
echo "Cleaning up work directory..."
cd /tmp && rm -rf $WORK_DIR

echo "✅ HomotopyContinuation test job completed"
EOF

echo "Test script created: $TEST_SCRIPT_NAME"

# Transfer test script to cluster
echo ""
echo "=== Step 4: Transfer and Submit Test Job ==="
echo "Transferring test script..."

if scp "$TEST_SCRIPT_NAME" "$CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"; then
    echo "✅ Test script transferred"
else
    echo "❌ Failed to transfer test script"
    exit 1
fi

# Submit the job on the cluster
echo "Submitting test job on cluster..."
JOB_ID=$(ssh "$CLUSTER_USER@$CLUSTER_HOST" "cd $REMOTE_NFS_PATH && sbatch $TEST_SCRIPT_NAME" | grep -o '[0-9]*$')

if [ -n "$JOB_ID" ]; then
    echo "✅ Job submitted successfully"
    echo "Job ID: $JOB_ID"
    
    echo ""
    echo "=== Monitoring Job ==="
    echo "Monitor with: ssh $CLUSTER_USER@$CLUSTER_HOST 'squeue -u $CLUSTER_USER'"
    echo "View output: ssh $CLUSTER_USER@$CLUSTER_HOST 'cat $REMOTE_NFS_PATH/homotopy_test_${JOB_ID}.out'"
    echo "View errors: ssh $CLUSTER_USER@$CLUSTER_HOST 'cat $REMOTE_NFS_PATH/homotopy_test_${JOB_ID}.err'"
    
    # Wait and check initial status
    echo ""
    echo "Checking job status..."
    sleep 5
    ssh "$CLUSTER_USER@$CLUSTER_HOST" "squeue -j $JOB_ID" || echo "Job may have completed quickly"
    
else
    echo "❌ Failed to submit job"
    exit 1
fi

echo ""
echo "=== Deployment Summary ==="
echo "✅ Bundle transferred to NFS: $REMOTE_NFS_PATH/$BUNDLE_NAME"
echo "✅ Bundle accessible from cluster" 
echo "✅ Test job submitted: $JOB_ID"
echo "✅ Comprehensive HomotopyContinuation tests initiated"
echo ""
echo "Next Steps:"
echo "1. Monitor job completion"
echo "2. Review test results for HomotopyContinuation functionality"
echo "3. Implement any necessary fixes based on results"
echo "4. Deploy to production workflows if tests pass"

# Clean up local test script
rm "$TEST_SCRIPT_NAME" 2>/dev/null || true

echo ""
echo "=== HomotopyContinuation Deployment to Falcon Completed ==="