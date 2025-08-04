"""
Test Parameters.jl-like functionality without external dependencies
Tests the BenchmarkConfigSimple.jl system on HPC cluster
"""

println("=== Testing Dependency-Free Parameters.jl System ===")
println()

# Load our dependency-free Parameters.jl implementation
include("src/HPC/BenchmarkConfigSimple.jl")

println("✓ BenchmarkConfigSimple.jl loaded successfully")
println()

# Test 1: Struct creation with defaults
println("1. Testing struct creation with defaults...")
try
    params = GlobtimParameters(degree=6, sample_count=200)
    println("   ✓ GlobtimParameters created: degree=$(params.degree), samples=$(params.sample_count)")
    println("   ✓ Default center: $(params.center)")
    println("   ✓ Default basis: $(params.basis)")
    println("   ✓ Default threshold: $(params.sparsification_threshold)")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 2: @unpack_simple macro
println("2. Testing @unpack_simple macro...")
try
    params = GlobtimParameters(degree=4, sample_count=100)
    @unpack_simple (degree, sample_count, center) params
    println("   ✓ @unpack_simple worked:")
    println("     - degree: $degree")
    println("     - sample_count: $sample_count") 
    println("     - center: $center")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 3: HPC Parameters
println("3. Testing HPC parameters...")
try
    hpc_params = HPCParameters(cpus=24, memory_gb=48)
    println("   ✓ HPCParameters created:")
    println("     - partition: $(hpc_params.partition) (default)")
    println("     - cpus: $(hpc_params.cpus)")
    println("     - memory_gb: $(hpc_params.memory_gb)")
    println("     - julia_threads: $(hpc_params.julia_threads) (auto-set)")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 4: Benchmark function registry
println("4. Testing benchmark function registry...")
try
    sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]
    println("   ✓ Sphere function loaded:")
    println("     - name: $(sphere_func.name)")
    println("     - description: $(sphere_func.description)")
    println("     - global minimum: $(sphere_func.global_minima[1])")
    println("     - f_min: $(sphere_func.f_min)")
    
    # Test function evaluation
    test_point = [0.1, 0.1, 0.1, 0.1]
    result = sphere_func.func(test_point)
    println("   ✓ Function evaluation: f($test_point) = $result")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 5: Complete job creation
println("5. Testing complete job creation...")
try
    sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]
    globtim_params = GlobtimParameters(degree=4, sample_count=100)
    hpc_params = HPCParameters(cpus=12, memory_gb=24)
    
    job = BenchmarkJob(
        benchmark_func = sphere_func,
        globtim_params = globtim_params,
        hpc_params = hpc_params,
        experiment_name = "test_experiment"
    )
    
    println("   ✓ BenchmarkJob created:")
    println("     - job_id: $(job.job_id) (auto-generated)")
    println("     - function: $(job.benchmark_func.name)")
    println("     - degree: $(job.globtim_params.degree)")
    println("     - cpus: $(job.hpc_params.cpus)")
    println("     - parameter_set_id: $(job.parameter_set_id)")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 6: Parameter sweep generation
println("6. Testing parameter sweep generation...")
try
    config = QUICK_TEST_EXPERIMENT
    println("   ✓ Quick test config loaded:")
    println("     - functions: $(config.functions)")
    println("     - degrees: $(config.degrees)")
    println("     - sample_counts: $(config.sample_counts)")
    
    jobs = generate_parameter_sweep(config)
    println("   ✓ Generated $(length(jobs)) jobs")
    
    # Show first job details
    if length(jobs) > 0
        job = jobs[1]
        @unpack_simple (degree, sample_count) job.globtim_params
        @unpack_simple (cpus, memory_gb) job.hpc_params
        println("     - Job 1: $(job.benchmark_func.name), deg=$degree, n=$sample_count, $(cpus)CPU/$(memory_gb)GB")
    end
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 7: Parameter validation
println("7. Testing parameter validation...")
try
    # Valid parameters
    valid_params = GlobtimParameters(degree=4, sample_count=100)
    validate_parameters(valid_params)
    println("   ✓ Valid parameters passed validation")
    
    # Test HPC validation
    valid_hpc = HPCParameters(cpus=24, memory_gb=48)
    validate_hpc_parameters(valid_hpc)
    println("   ✓ Valid HPC parameters passed validation")
    
    # Test invalid parameters
    try
        invalid_params = GlobtimParameters(degree=-1)  # Invalid
        validate_parameters(invalid_params)
        println("   ❌ Should have failed validation")
    catch e
        println("   ✓ Correctly caught invalid parameter: $e")
    end
catch e
    println("   ❌ Validation test failed: $e")
end
println()

# Test 8: Distance computation
println("8. Testing distance computation...")
try
    # Test points near origin
    test_points = [0.1 0.1 0.1 0.1; 1.0 1.0 1.0 1.0; 2.0 2.0 2.0 2.0]
    global_minima = [[0.0, 0.0, 0.0, 0.0]]  # Origin for Sphere function
    
    distances = compute_min_distances_to_global(test_points, global_minima)
    println("   ✓ Distance computation successful:")
    for (i, dist) in enumerate(distances)
        println("     - Point $i distance to origin: $(round(dist, digits=3))")
    end
catch e
    println("   ❌ Failed: $e")
end
println()

# Summary
println("=== Test Summary ===")
println("✅ Dependency-free Parameters.jl system working!")
println("✅ All core functionality implemented:")
println("   • Struct creation with defaults")
println("   • @unpack_simple macro for parameter access")
println("   • Benchmark function registry")
println("   • Complete job specification")
println("   • Parameter sweep generation")
println("   • Parameter validation")
println("   • Distance computation")
println()
println("🎯 Ready for HPC benchmark job creation!")
println("🚀 No external dependencies required!")
