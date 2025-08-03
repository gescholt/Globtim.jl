"""
Test Julia Depot Path Fix

Tests the proper setup of JULIA_DEPOT_PATH to avoid permission issues.
The key is to ensure Julia only uses directories we have write access to.
"""

println("=== Testing Julia Depot Path Fix ===")
println()

# Test on HPC cluster with proper depot setup
test_script = """
# Set Julia depot to only use accessible directories
export JULIA_DEPOT_PATH="/tmp/julia_depot_\${USER}_test"
mkdir -p \$JULIA_DEPOT_PATH

echo "Julia depot path: \$JULIA_DEPOT_PATH"
echo "Testing Julia with controlled depot..."

/sw/bin/julia -e '
println("Julia depot paths:")
for (i, path) in enumerate(DEPOT_PATH)
    println("  \$i: \$path")
    if isdir(path)
        println("     ✓ exists and accessible")
    else
        println("     ❌ not accessible")
    end
end

println()
println("Testing package installation...")

using Pkg

# Test installing a simple package
try
    println("Installing StaticArrays...")
    Pkg.add("StaticArrays")
    println("✓ StaticArrays installed successfully")
    
    using StaticArrays
    println("✓ StaticArrays loaded successfully")
    
    # Test basic functionality
    v = @SVector [1.0, 2.0, 3.0]
    println("✓ StaticArrays working: \$v")
    
catch e
    println("❌ StaticArrays test failed: \$e")
end

println()
println("Testing Parameters.jl...")
try
    Pkg.add("Parameters")
    println("✓ Parameters.jl installed")
    
    using Parameters
    println("✓ Parameters.jl loaded")
    
    # Test @with_kw
    @with_kw struct TestStruct
        x::Int = 5
        y::Float64 = 2.0
    end
    
    test_obj = TestStruct(x=10)
    println("✓ @with_kw working: x=\$(test_obj.x), y=\$(test_obj.y)")
    
catch e
    println("❌ Parameters.jl test failed: \$e")
end
'

# Cleanup
rm -rf \$JULIA_DEPOT_PATH
echo "✓ Cleanup completed"
"""

println("Test script created. Upload and run on HPC cluster:")
println()
println("# Upload and run:")
println("echo '$test_script' > test_depot_fix.sh")
println("chmod +x test_depot_fix.sh")
println("./test_depot_fix.sh")
println()
println("This should resolve the /Users permission issue by using only /tmp directories.")
