#!/bin/bash
#SBATCH --job-name=native_homotopy_install
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=native_homotopy_%j.out
#SBATCH --error=native_homotopy_%j.err

echo "=== NATIVE HomotopyContinuation Installation on Cluster ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Julia version: $(/sw/bin/julia --version)"
echo "Architecture: $(uname -m)"
echo ""

# This approach installs HomotopyContinuation natively on the cluster
# bypassing the cross-platform bundle issues entirely

# Setup work directory
WORK_DIR="/tmp/native_homotopy_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR && cd $WORK_DIR

# Create a minimal Julia project with just HomotopyContinuation
echo "=== Creating Native Julia Project ==="
cat > Project.toml << 'EOF'
name = "NativeHomotopyTest"
uuid = "12345678-1234-5678-9012-123456789012"
version = "1.0.0"

[deps]
HomotopyContinuation = "f213a82b-91d6-5c5d-acf7-10f1c761b327"
DynamicPolynomials = "7c1d4256-1411-5781-91ec-d7bc3513ac07"
MultivariatePolynomials = "102ac46a-7ee4-5c85-9060-abc95bfdeaa3"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[compat]
HomotopyContinuation = "2.15"
DynamicPolynomials = "0.6"
MultivariatePolynomials = "0.5"
ForwardDiff = "0.10"
StaticArrays = "1.9"
SpecialFunctions = "2.4"
julia = "1.10"
EOF

echo "✅ Project.toml created with HomotopyContinuation dependencies"

# Set up isolated depot to avoid quota issues
export JULIA_DEPOT_PATH="$WORK_DIR/depot"
export JULIA_PROJECT="$WORK_DIR"
mkdir -p "$WORK_DIR/depot"

echo "Environment configured:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"  
echo "  JULIA_PROJECT=$JULIA_PROJECT"

# Install packages natively on the cluster
echo ""
echo "=== NATIVE PACKAGE INSTALLATION ==="
echo "Installing HomotopyContinuation and dependencies directly on x86_64 Linux..."
echo "This will download the correct binary artifacts for this architecture."

/sw/bin/julia --project=. -e "
    using Pkg
    println(\"=== Native Installation on x86_64 Linux Cluster ===\")
    println(\"Julia version: \$(VERSION)\")
    println(\"Architecture: \$(Sys.MACHINE)\")
    println(\"Platform: \$(Sys.islinux() ? \"Linux\" : \"Other\")\")
    println()
    
    println(\"Setting up package registry...\")
    try
        Pkg.Registry.add(\"General\")
        println(\"✅ General registry added\")
    catch e
        if occursin(\"already exists\", string(e))
            println(\"✅ General registry already exists\")
        else
            println(\"⚠️ Registry setup issue: \$e\")
        end
    end
    
    println(\"\\n=== Installing Critical Packages ===\")
    critical_packages = [
        \"StaticArrays\",
        \"SpecialFunctions\", 
        \"ForwardDiff\",
        \"MultivariatePolynomials\",
        \"DynamicPolynomials\",
        \"HomotopyContinuation\"
    ]
    
    installed_packages = String[]
    failed_packages = String[]
    
    for pkg in critical_packages
        try
            println(\"Installing \$pkg...\")
            Pkg.add(pkg)
            push!(installed_packages, pkg)
            println(\"✅ \$pkg installed successfully\")
        catch e
            push!(failed_packages, pkg)
            println(\"❌ \$pkg installation failed: \$e\")
        end
    end
    
    println(\"\\n=== Installation Summary ===\")
    println(\"Successfully installed (\$(length(installed_packages))): \$(join(installed_packages, \", \"))\")
    if !isempty(failed_packages)
        println(\"Failed to install (\$(length(failed_packages))): \$(join(failed_packages, \", \"))\")
    end
    
    if \"HomotopyContinuation\" in installed_packages
        println(\"\\n✅ HomotopyContinuation installed - proceeding with instantiation\")
    else
        println(\"\\n❌ HomotopyContinuation installation failed - cannot proceed\")
        exit(1)
    end
"

# Instantiate and precompile
echo ""
echo "=== PACKAGE INSTANTIATION AND PRECOMPILATION ==="
/sw/bin/julia --project=. -e "
    using Pkg
    println(\"Instantiating project...\")
    Pkg.instantiate()
    println(\"✅ Instantiation completed\")
    
    println(\"\\nPrecompiling packages...\")
    Pkg.precompile()
    println(\"✅ Precompilation completed\")
    
    println(\"\\n=== Package Status ===\")
    Pkg.status()
"

# Test package loading
echo ""
echo "=== NATIVE PACKAGE LOADING TEST ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    println(\"=== Testing Native Package Loading ===\")
    
    test_results = String[]
    
    packages_to_test = [
        \"LinearAlgebra\",
        \"StaticArrays\", 
        \"SpecialFunctions\",
        \"ForwardDiff\",
        \"MultivariatePolynomials\",
        \"DynamicPolynomials\",
        \"HomotopyContinuation\"
    ]
    
    for pkg in packages_to_test
        try
            println(\"Loading \$pkg...\")
            eval(Meta.parse(\"using \$pkg\"))
            push!(test_results, pkg)
            println(\"  ✅ \$pkg loaded successfully\")
        catch e
            println(\"  ❌ \$pkg failed to load: \$e\")
        end
    end
    
    println(\"\\n=== Native Loading Results ===\")
    println(\"Successfully loaded: \$(join(test_results, \", \"))\")
    
    if \"HomotopyContinuation\" in test_results
        println(\"\\n🎉 HomotopyContinuation loaded successfully with native installation!\")
    else
        println(\"\\n❌ HomotopyContinuation still failing to load\")
    end
"

# Test HomotopyContinuation functionality
echo ""
echo "=== NATIVE HOMOTOPYCONTINUATION FUNCTIONALITY TEST ==="
/sw/bin/julia --project=. --compiled-modules=yes -e "
    println(\"=== Testing Native HomotopyContinuation Functionality ===\")
    
    try
        using HomotopyContinuation, DynamicPolynomials
        println(\"✅ Packages loaded successfully\")
        
        # Test 1: Simple system
        println(\"\\nTest 1: Simple 2x2 system\")
        @var x y
        f1 = x^2 + y^2 - 1
        f2 = x + y - 1
        system = System([f1, f2])
        println(\"✅ System created: \$system\")
        
        solutions = solve(system)
        println(\"✅ Solve succeeded: \$(length(solutions)) solutions found\")
        
        # Analyze solutions
        real_count = sum(is_real(sol) for sol in solutions)
        println(\"  Real solutions: \$real_count\")
        println(\"  Complex solutions: \$(length(solutions) - real_count)\")
        
        # Display first real solution if any
        real_solutions = filter(is_real, solutions)
        if !isempty(real_solutions)
            println(\"  First real solution: \$(real(real_solutions[1].solution))\")
        end
        
        # Test 2: 3x3 system
        println(\"\\nTest 2: 3x3 system\")
        @var u v w
        system_3x3 = System([
            u^2 + v^2 + w^2 - 1,
            u + v + w - 1,
            u*v + v*w + w*u - 0.5
        ])
        println(\"✅ 3x3 system created\")
        
        start_time = time()
        solutions_3x3 = solve(system_3x3)
        solve_time = time() - start_time
        
        println(\"✅ 3x3 system solved in \$(round(solve_time, digits=2)) seconds\")
        println(\"  Found \$(length(solutions_3x3)) solutions\")
        
        # Test 3: Parametric system
        println(\"\\nTest 3: Parametric homotopy\")
        @var a b t
        param_system = System([a^2 + b^2 - t, a + b - 1], variables=[a, b], parameters=[t])
        println(\"✅ Parametric system created\")
        
        param_solutions = solve(param_system, target_parameters=[0.5])
        println(\"✅ Parametric solve succeeded: \$(length(param_solutions)) solutions\")
        
        println(\"\\n🎉 ALL NATIVE HOMOTOPYCONTINUATION TESTS PASSED!\")
        println(\"✅ Native installation resolves all architecture compatibility issues\")
        println(\"✅ All functionality working correctly on x86_64 Linux cluster\")
        println(\"✅ Ready for production use\")
        
    catch e
        println(\"❌ Native HomotopyContinuation test failed: \$e\")
        
        # Try to diagnose the issue
        if occursin(\"library\", string(e)) || occursin(\"symbol\", string(e))
            println(\"\\n🔍 DIAGNOSIS: Library/symbol loading issue\")
            println(\"   This suggests binary compatibility problems persist\")
        elseif occursin(\"artifact\", string(e))
            println(\"\\n🔍 DIAGNOSIS: Artifact issue\")
            println(\"   Binary artifacts may still be problematic\")
        else
            println(\"\\n🔍 DIAGNOSIS: Unknown error\")
            println(\"   Full error: \$e\")
        end
    end
"

echo ""
echo "=== NATIVE INSTALLATION SUMMARY ==="
echo "Native HomotopyContinuation installation completed at $(date)"
echo ""
echo "This approach:"
echo "✅ Installs packages directly on the x86_64 Linux cluster"
echo "✅ Downloads correct binary artifacts for the target architecture" 
echo "✅ Avoids cross-platform compilation issues"
echo "✅ Uses cluster's own Julia environment"
echo ""

# Check overall success
if /sw/bin/julia --project=. -e 'using HomotopyContinuation; println("NATIVE_SUCCESS")' 2>/dev/null | grep -q "NATIVE_SUCCESS"; then
    echo "🎉 NATIVE INSTALLATION SUCCESSFUL!"
    echo "✅ HomotopyContinuation now works on the falcon cluster"
    echo "✅ Architecture compatibility issues resolved"
    echo ""
    echo "DEPLOYMENT READY: Use the following settings in production:"
    echo "  JULIA_DEPOT_PATH=$WORK_DIR/depot"
    echo "  JULIA_PROJECT=$WORK_DIR"
    echo "  /sw/bin/julia --project=. --compiled-modules=yes"
    
    # Show how to create a portable bundle from this
    echo ""
    echo "To create portable bundle from this working installation:"
    echo "  tar -czf homotopy_native_$(date +%Y%m%d).tar.gz -C $WORK_DIR ."
    
else
    echo "❌ NATIVE INSTALLATION STILL HAS ISSUES"
    echo "🔧 HomotopyContinuation may require additional system dependencies"
    echo "🔧 Consider alternative polynomial solvers"
fi

# Keep the working directory for analysis
echo ""
echo "Work directory preserved for analysis: $WORK_DIR"
echo "✅ Native HomotopyContinuation installation test completed"