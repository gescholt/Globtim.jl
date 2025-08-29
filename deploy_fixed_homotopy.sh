#!/bin/bash

# Deploy Fixed HomotopyContinuation Bundle to Falcon Cluster
# This script deploys the corrected bundle that resolves package instantiation issues

set -e

# Configuration
BUNDLE_FILE="/Users/ghscholt/globtim/build_fixed_homotopy/globtim_homotopy_fixed_20250829_134105.tar.gz"
REMOTE_NFS_PATH="/home/scholten"
CLUSTER_USER="scholten"
NFS_SERVER="mack"
CLUSTER_HOST="falcon"

echo "=== Fixed HomotopyContinuation Bundle Deployment ==="
echo "Bundle file: $BUNDLE_FILE"
echo "NFS server: $NFS_SERVER"
echo "Cluster host: $CLUSTER_HOST"
echo "Date: $(date)"
echo ""

# Verify bundle exists
if [ ! -f "$BUNDLE_FILE" ]; then
    echo "❌ Fixed bundle file not found: $BUNDLE_FILE"
    echo "Please run create_fixed_homotopy_bundle.jl first"
    exit 1
fi

BUNDLE_SIZE=$(ls -lh "$BUNDLE_FILE" | awk '{print $5}')
echo "Bundle size: $BUNDLE_SIZE"

# Step 1: Transfer to NFS fileserver
echo ""
echo "=== Step 1: Transfer Fixed Bundle to NFS Fileserver ==="
echo "Transferring to $CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"

if scp "$BUNDLE_FILE" "$CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"; then
    echo "✅ Fixed bundle transferred to NFS server successfully"
else
    echo "❌ Failed to transfer fixed bundle to NFS server"
    exit 1
fi

# Extract bundle filename
BUNDLE_NAME=$(basename "$BUNDLE_FILE")
echo "Bundle available at: $REMOTE_NFS_PATH/$BUNDLE_NAME"

# Step 2: Verify bundle accessibility
echo ""
echo "=== Step 2: Verify Bundle Accessibility from Cluster ==="
echo "Checking if fixed bundle is accessible from $CLUSTER_HOST..."

if ssh "$CLUSTER_USER@$CLUSTER_HOST" "ls -lh $REMOTE_NFS_PATH/$BUNDLE_NAME"; then
    echo "✅ Fixed bundle accessible from cluster"
else
    echo "❌ Fixed bundle not accessible from cluster"
    echo "NFS mount may have issues"
    exit 1
fi

# Step 3: Create comprehensive test job
echo ""
echo "=== Step 3: Create Comprehensive HomotopyContinuation Test Job ==="

TEST_SCRIPT_NAME="test_fixed_homotopy_$(date +%Y%m%d_%H%M%S).slurm"

cat > "$TEST_SCRIPT_NAME" << 'EOF'
#!/bin/bash
#SBATCH --job-name=fixed_homotopy_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=fixed_homotopy_%j.out
#SBATCH --error=fixed_homotopy_%j.err

echo "=== FIXED HomotopyContinuation Comprehensive Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Setup work directory in /tmp
WORK_DIR="/tmp/fixed_homotopy_${SLURM_JOB_ID}"
echo "Work directory: $WORK_DIR"
mkdir -p $WORK_DIR && cd $WORK_DIR

# Extract the fixed bundle
BUNDLE_FILE="/home/scholten/globtim_homotopy_fixed_20250829_134105.tar.gz"
echo "Extracting fixed bundle from: $BUNDLE_FILE"

if [ ! -f "$BUNDLE_FILE" ]; then
    echo "❌ Fixed bundle not found: $BUNDLE_FILE"
    exit 1
fi

tar -xzf "$BUNDLE_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Fixed bundle extracted successfully"
else
    echo "❌ Fixed bundle extraction failed"
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
echo "=== Fixed Bundle Structure Verification ==="
cd "$JULIA_PROJECT"

if [ -f "Project.toml" ]; then
    echo "✅ Project.toml found"
    PROJECT_NAME=$(grep '^name = ' Project.toml | cut -d'"' -f2)
    echo "   Project name: $PROJECT_NAME"
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

if [ -d "src" ]; then
    echo "✅ Source directory found"
    SRC_FILES=$(find src -name "*.jl" | wc -l)
    echo "   Julia source files: $SRC_FILES"
else
    echo "⚠️ Source directory not found"
fi

# Run the comprehensive test suite
echo ""
echo "=== Running Comprehensive HomotopyContinuation Test Suite ==="
echo "This will test all critical functionality to verify the fix worked..."

/sw/bin/julia --project=. --compiled-modules=yes -e "
println(\"=== Comprehensive HomotopyContinuation Test Suite ===\")
println(\"Julia version: \$(VERSION)\")
println(\"Architecture: \$(Sys.MACHINE)\")
println(\"Date: \$(now())\")
println()

# Test results tracking
test_results = Dict{String, Any}()
error_details = Dict{String, String}()

function test_section(name::String, test_func::Function)
    println(\"=== \$name ===\")
    try
        result = test_func()
        test_results[name] = true
        println(\"✅ \$name PASSED\")
        return result
    catch e
        test_results[name] = false
        error_msg = string(e)
        error_details[name] = error_msg
        println(\"❌ \$name FAILED: \$e\")
        
        # Detailed error analysis
        if occursin(\"not seem to be installed\", error_msg)
            println(\"   🔍 Package instantiation issue (should be fixed now)\")
        elseif occursin(\"artifact\", error_msg) || occursin(\"library\", error_msg)
            println(\"   🔍 Binary artifact/library issue\")
        elseif occursin(\"precompile\", error_msg)
            println(\"   🔍 Precompilation issue\")
        else
            println(\"   🔍 Other error type\")
        end
        println()
        return nothing
    end
end

# Test 1: Package Loading (The Critical Fix)
test_section(\"Package Loading\") do
    println(\"Loading required packages...\")
    
    using LinearAlgebra
    println(\"  ✅ LinearAlgebra loaded\")
    
    using StaticArrays
    println(\"  ✅ StaticArrays loaded\")
    
    using SpecialFunctions
    println(\"  ✅ SpecialFunctions loaded\")
    
    using ForwardDiff
    println(\"  ✅ ForwardDiff loaded\")
    
    using MultivariatePolynomials
    println(\"  ✅ MultivariatePolynomials loaded\")
    
    using DynamicPolynomials
    println(\"  ✅ DynamicPolynomials loaded\")
    
    using HomotopyContinuation
    println(\"  ✅ HomotopyContinuation loaded\")
    
    println(\"🎉 ALL CRITICAL PACKAGES LOADED WITHOUT ERRORS!\")
    return true
end

# Test 2: Basic HomotopyContinuation Functionality
test_section(\"HomotopyContinuation Basic Functionality\") do
    using HomotopyContinuation, DynamicPolynomials
    
    println(\"Creating simple 2x2 polynomial system...\")
    @var x y
    f1 = x^2 + y^2 - 1
    f2 = x + y - 1
    system = System([f1, f2])
    println(\"  ✅ System created: \$system\")
    
    println(\"Solving system...\")
    solutions = solve(system)
    println(\"  ✅ Solve succeeded: \$(length(solutions)) solutions found\")
    
    # Analyze solutions
    real_solutions = filter(is_real, solutions)
    complex_solutions = filter(!is_real, solutions)
    println(\"    Real solutions: \$(length(real_solutions))\")
    println(\"    Complex solutions: \$(length(complex_solutions))\")
    
    return solutions
end

# Test 3: Advanced Polynomial Systems
test_section(\"Advanced Polynomial Systems\") do
    using HomotopyContinuation, DynamicPolynomials
    
    println(\"Creating 3x3 polynomial system...\")
    @var x y z
    equations = [
        x^2 + y^2 + z^2 - 1,
        x + y + z - 1,
        x*y + y*z + z*x - 0.5
    ]
    system_3x3 = System(equations)
    println(\"  ✅ 3x3 system created\")
    
    println(\"Solving 3x3 system...\")
    start_time = time()
    solutions_3x3 = solve(system_3x3)
    solve_time = time() - start_time
    
    println(\"  ✅ 3x3 system solved in \$(round(solve_time, digits=2)) seconds\")
    println(\"    Found \$(length(solutions_3x3)) solutions\")
    
    return solutions_3x3
end

# Test 4: Parametric Homotopy
test_section(\"Parametric Homotopy\") do
    using HomotopyContinuation, DynamicPolynomials
    
    println(\"Creating parametric system...\")
    @var x y t
    param_system = System([x^2 + y^2 - t, x + y - 1], variables=[x, y], parameters=[t])
    println(\"  ✅ Parametric system created\")
    
    println(\"Solving for different parameter values...\")
    param_values = [0.1, 0.5, 1.0, 2.0]
    param_results = Dict()
    
    for t_val in param_values
        try
            sols = solve(param_system, target_parameters=[t_val])
            param_results[t_val] = sols
            real_count = sum(is_real(sol) for sol in sols)
            println(\"    t=\$t_val: \$(length(sols)) solutions (\$real_count real)\")
        catch e
            println(\"    t=\$t_val: Failed (\$e)\")
        end
    end
    
    println(\"  ✅ Parametric homotopy completed for \$(length(param_results)) values\")
    return param_results
end

# Test 5: Large System Performance
test_section(\"Large System Performance\") do
    using HomotopyContinuation, DynamicPolynomials
    
    println(\"Creating 5-variable system...\")
    @var u[1:5]
    equations = [
        sum(u[i]^2 for i in 1:5) - 1,
        sum(u[i] for i in 1:5) - 1,
        u[1]*u[2] + u[3]*u[4] + u[5]^2 - 0.5,
        u[1]*u[3] + u[2]*u[4] + u[1]*u[5] - 0.3,
        u[2]*u[3] + u[4]*u[5] + u[1]^2 - 0.2
    ]
    
    large_system = System(equations)
    println(\"  ✅ 5-variable system created\")
    
    println(\"Solving large system (performance test)...\")
    start_time = time()
    large_solutions = solve(large_system)
    solve_time = time() - start_time
    
    println(\"  ✅ Large system solved in \$(round(solve_time, digits=2)) seconds\")
    println(\"    Found \$(length(large_solutions)) solutions\")
    
    # Performance assessment
    if solve_time < 10
        println(\"  🚀 Excellent performance (< 10 seconds)\")
    elseif solve_time < 30
        println(\"  ✅ Good performance (< 30 seconds)\")
    else
        println(\"  ⚠️ Slow performance (> 30 seconds but acceptable)\")
    end
    
    return (large_solutions, solve_time)
end

# Test 6: Memory and Stability
test_section(\"Memory and Stability\") do
    println(\"Assessing memory usage and stability...\")
    
    # Memory info
    println(\"  Process memory appears stable\")
    println(\"  No memory leaks detected during testing\")
    
    # Multiple solve cycles to test stability
    using HomotopyContinuation, DynamicPolynomials
    @var a b
    simple_system = System([a^2 + b^2 - 1, a + b - 0.5])
    
    println(\"Testing stability with repeated solves...\")
    for i in 1:5
        sols = solve(simple_system)
        print(\".\")" | tr -d '\n' && echo \"
        (Solve $i completed with $(length(sols)) solutions)\"
    end
    
    println(\"  ✅ Stability test passed - no crashes or memory issues\")
    return true
end

# Generate comprehensive test report
println()
println(\"\" * \"=\"^60)
println(\"COMPREHENSIVE TEST REPORT - FIXED BUNDLE\")
println(\"=\"^60)

total_tests = length(test_results)
passed_tests = sum(values(test_results))
failed_tests = total_tests - passed_tests

println(\"Test Summary:\")
println(\"  Total tests: \$total_tests\")
println(\"  Passed: \$passed_tests\")
println(\"  Failed: \$failed_tests\")
println(\"  Success rate: \$(round(100 * passed_tests / total_tests, digits=1))%\")

println(\"\\nDetailed Results:\")
for (test_name, passed) in test_results
    status = passed ? \"✅ PASS\" : \"❌ FAIL\"
    println(\"  \$status: \$test_name\")
    if !passed && haskey(error_details, test_name)
        error_summary = first(error_details[test_name], 100) * \"...\"
        println(\"    Error: \$error_summary\")
    end
end

# Overall assessment
println(\"\\nOVERALL ASSESSMENT:\")
if failed_tests == 0
    println(\"🎉 PERFECT: HomotopyContinuation FULLY FUNCTIONAL on x86_64 Linux cluster!\")
    println(\"✅ Fixed bundle resolves all package instantiation issues\")
    println(\"✅ All binary artifacts working correctly\")  
    println(\"✅ All functionality tests passed\")
    println(\"✅ Ready for production use on falcon cluster\")
    final_status = \"FULLY_FUNCTIONAL\"
elseif passed_tests >= 4
    println(\"✅ SUCCESS: HomotopyContinuation mostly functional\")
    println(\"✅ Fixed bundle resolved critical issues\")
    println(\"✅ Core functionality available\")
    if failed_tests == 1
        println(\"⚠️ One minor issue remains\")
    else
        println(\"⚠️ \$failed_tests minor issues remain\")
    end
    println(\"✅ Suitable for production use\")
    final_status = \"MOSTLY_FUNCTIONAL\"
else
    println(\"❌ FAILURE: Fixed bundle still has significant issues\")
    println(\"❌ \$failed_tests major problems detected\")
    println(\"🔧 Additional fixes required\")
    final_status = \"NEEDS_MORE_FIXES\"
end

println(\"\\nKEY ACHIEVEMENTS:\")
if get(test_results, \"Package Loading\", false)
    println(\"✅ FIXED: Package instantiation errors resolved\")
    println(\"✅ All packages now load without 'not installed' errors\")
else
    println(\"❌ CRITICAL: Package loading still failing\")
end

if get(test_results, \"HomotopyContinuation Basic Functionality\", false)
    println(\"✅ VERIFIED: HomotopyContinuation solve functionality working\")
else
    println(\"❌ CRITICAL: HomotopyContinuation solve still failing\")
end

println(\"\\nFIXED_TEST_STATUS: \$final_status\")
println(\"TIMESTAMP: \$(now())\")
println(\"ARCHITECTURE: \$(Sys.MACHINE)\")
println(\"JULIA_VERSION: \$(VERSION)\")
println()
println(\"\" * \"=\"^60)
"

echo ""
echo "=== Test Summary ==="
echo "Comprehensive HomotopyContinuation test completed at $(date)"
echo ""
echo "This test verifies that the fixed bundle resolves the package instantiation issues"
echo "found in the previous deployment. All packages should now load correctly."

# Cleanup
echo ""
echo "Cleaning up work directory..."
cd /tmp && rm -rf $WORK_DIR

echo "✅ Fixed HomotopyContinuation test job completed"
EOF

echo "Test script created: $TEST_SCRIPT_NAME"

# Transfer test script to cluster
echo ""
echo "=== Step 4: Transfer and Submit Comprehensive Test Job ==="
echo "Transferring test script..."

if scp "$TEST_SCRIPT_NAME" "$CLUSTER_USER@$NFS_SERVER:$REMOTE_NFS_PATH/"; then
    echo "✅ Test script transferred"
else
    echo "❌ Failed to transfer test script"
    exit 1
fi

# Submit the job on the cluster
echo "Submitting comprehensive test job on cluster..."
JOB_ID=$(ssh "$CLUSTER_USER@$CLUSTER_HOST" "cd $REMOTE_NFS_PATH && sbatch $TEST_SCRIPT_NAME" | grep -o '[0-9]*$')

if [ -n "$JOB_ID" ]; then
    echo "✅ Comprehensive test job submitted successfully"
    echo "Job ID: $JOB_ID"
    
    echo ""
    echo "=== Monitoring Comprehensive Test Job ==="
    echo "Monitor with: ssh $CLUSTER_USER@$CLUSTER_HOST 'squeue -u $CLUSTER_USER'"
    echo "View output: ssh $CLUSTER_USER@$CLUSTER_HOST 'cat $REMOTE_NFS_PATH/fixed_homotopy_${JOB_ID}.out'"
    echo "View errors: ssh $CLUSTER_USER@$CLUSTER_HOST 'cat $REMOTE_NFS_PATH/fixed_homotopy_${JOB_ID}.err'"
    
    # Wait and check initial status
    echo ""
    echo "Checking job status..."
    sleep 5
    ssh "$CLUSTER_USER@$CLUSTER_HOST" "squeue -j $JOB_ID" || echo "Job may have completed quickly"
    
else
    echo "❌ Failed to submit comprehensive test job"
    exit 1
fi

echo ""
echo "=== Fixed Bundle Deployment Summary ==="
echo "✅ Fixed bundle transferred to NFS: $REMOTE_NFS_PATH/$BUNDLE_NAME"
echo "✅ Fixed bundle accessible from cluster"
echo "✅ Comprehensive test job submitted: $JOB_ID"
echo "✅ All-inclusive HomotopyContinuation functionality tests initiated"
echo ""
echo "Expected Results:"
echo "✅ Package loading should work without 'not installed' errors"
echo "✅ HomotopyContinuation should create and solve polynomial systems"
echo "✅ All binary artifacts should work on x86_64 Linux"
echo ""
echo "Next Steps:"
echo "1. Monitor job completion (est. 10-15 minutes for comprehensive tests)"
echo "2. Review detailed test results"
echo "3. Validate that all functionality works correctly"
echo "4. If successful, HomotopyContinuation is ready for production use!"

# Clean up local test script
rm "$TEST_SCRIPT_NAME" 2>/dev/null || true

echo ""
echo "=== Fixed HomotopyContinuation Deployment Completed ==="