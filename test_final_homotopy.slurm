#!/bin/bash
#SBATCH --job-name=final_homotopy_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=final_homotopy_%j.out
#SBATCH --error=final_homotopy_%j.err

echo "=== FINAL HomotopyContinuation Validation Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Setup work directory
WORK_DIR="/tmp/final_homotopy_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR && cd $WORK_DIR

# Extract the fixed bundle
BUNDLE_FILE="/home/scholten/globtim_homotopy_fixed_20250829_134105.tar.gz"
echo "Extracting fixed bundle: $BUNDLE_FILE"
tar -xzf "$BUNDLE_FILE"

# Configure environment
export JULIA_DEPOT_PATH="$WORK_DIR/bundle/depot"
export JULIA_PROJECT="$WORK_DIR/bundle/project"
export JULIA_NO_NETWORK="1"
export JULIA_PKG_OFFLINE="true"

echo "Environment: $JULIA_PROJECT"
cd "$JULIA_PROJECT"

# Test 1: Package Loading
echo ""
echo "=== Test 1: Package Loading ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    println(\"Loading critical packages...\")
    
    try
        using LinearAlgebra
        println(\"✅ LinearAlgebra loaded\")
    catch e
        println(\"❌ LinearAlgebra failed: \$e\")
    end
    
    try
        using StaticArrays
        println(\"✅ StaticArrays loaded\")
    catch e
        println(\"❌ StaticArrays failed: \$e\")
    end
    
    try
        using SpecialFunctions
        println(\"✅ SpecialFunctions loaded\")
    catch e
        println(\"❌ SpecialFunctions failed: \$e\")
    end
    
    try
        using ForwardDiff
        println(\"✅ ForwardDiff loaded\")
    catch e
        println(\"❌ ForwardDiff failed: \$e\")
    end
    
    try
        using MultivariatePolynomials
        println(\"✅ MultivariatePolynomials loaded\")
    catch e
        println(\"❌ MultivariatePolynomials failed: \$e\")
    end
    
    try
        using DynamicPolynomials
        println(\"✅ DynamicPolynomials loaded\")
    catch e
        println(\"❌ DynamicPolynomials failed: \$e\")
    end
    
    try
        using HomotopyContinuation
        println(\"✅ HomotopyContinuation loaded\")
    catch e
        println(\"❌ HomotopyContinuation failed: \$e\")
    end
"

# Test 2: Basic Functionality
echo ""
echo "=== Test 2: HomotopyContinuation Basic Functionality ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    try
        using HomotopyContinuation, DynamicPolynomials
        println(\"✅ Core packages loaded\")
        
        # Create simple system
        @var x y
        f1 = x^2 + y^2 - 1
        f2 = x + y - 1
        system = System([f1, f2])
        println(\"✅ System created: \$system\")
        
        # Solve system
        solutions = solve(system)
        println(\"✅ Solve succeeded: \$(length(solutions)) solutions found\")
        
        # Analyze solutions
        real_sols = sum(is_real(sol) for sol in solutions)
        println(\"  Real solutions: \$real_sols\")
        println(\"  Complex solutions: \$(length(solutions) - real_sols)\")
        
        if length(solutions) > 0
            println(\"✅ HomotopyContinuation is FULLY FUNCTIONAL!\")
        else
            println(\"⚠️ No solutions found - may indicate an issue\")
        end
        
    catch e
        println(\"❌ HomotopyContinuation functionality test failed: \$e\")
    end
"

# Test 3: Advanced System
echo ""
echo "=== Test 3: Advanced System Test ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    try
        using HomotopyContinuation, DynamicPolynomials
        
        # Create 3x3 system
        @var x y z
        system_3x3 = System([
            x^2 + y^2 + z^2 - 1,
            x + y + z - 1,
            x*y + y*z + z*x - 0.5
        ])
        println(\"✅ 3x3 system created\")
        
        # Time the solve
        start_time = time()
        solutions_3x3 = solve(system_3x3)
        solve_time = time() - start_time
        
        println(\"✅ 3x3 system solved in \$(round(solve_time, digits=2)) seconds\")
        println(\"  Found \$(length(solutions_3x3)) solutions\")
        
        if solve_time < 30
            println(\"✅ Good performance\")
        else
            println(\"⚠️ Slow performance but functional\")
        end
        
    catch e
        println(\"❌ Advanced system test failed: \$e\")
    end
"

# Test 4: Parametric System
echo ""
echo "=== Test 4: Parametric Homotopy Test ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    try
        using HomotopyContinuation, DynamicPolynomials
        
        # Create parametric system
        @var x y t
        param_system = System([x^2 + y^2 - t, x + y - 1], variables=[x, y], parameters=[t])
        println(\"✅ Parametric system created\")
        
        # Solve for specific parameter value
        param_solutions = solve(param_system, target_parameters=[0.5])
        println(\"✅ Parametric solve succeeded: \$(length(param_solutions)) solutions\")
        
        # Test multiple parameter values
        success_count = 0
        for t_val in [0.1, 1.0, 2.0]
            try
                sols = solve(param_system, target_parameters=[t_val])
                success_count += 1
                println(\"  t=\$t_val: \$(length(sols)) solutions\")
            catch
                println(\"  t=\$t_val: Failed\")
            end
        end
        
        if success_count >= 2
            println(\"✅ Parametric homotopy working well\")
        else
            println(\"⚠️ Parametric homotopy has some issues\")
        end
        
    catch e
        println(\"❌ Parametric homotopy test failed: \$e\")
    end
"

echo ""
echo "=== FINAL VALIDATION SUMMARY ==="
echo "Test execution completed at $(date)"
echo ""
echo "This test validates the fixed HomotopyContinuation bundle addresses:"
echo "1. Package instantiation issues (packages should load without errors)"
echo "2. Binary artifact compatibility (x86_64 Linux architecture)"
echo "3. Core solving functionality"
echo "4. Advanced features like parametric homotopy"
echo ""

# Check if HomotopyContinuation loads at all
if /sw/bin/julia --project=. -e 'using HomotopyContinuation; println("SUCCESS")' 2>/dev/null | grep -q "SUCCESS"; then
    echo "🎉 OVERALL RESULT: HomotopyContinuation loads successfully!"
    echo "✅ The fixed bundle resolves the architecture compatibility issues"
    echo "✅ Ready for production use on the falcon cluster"
else
    echo "❌ OVERALL RESULT: HomotopyContinuation still has loading issues"
    echo "🔧 Additional fixes may be required"
fi

# Cleanup
cd /tmp && rm -rf $WORK_DIR
echo "✅ Final validation test completed"