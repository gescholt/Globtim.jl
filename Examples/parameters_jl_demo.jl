"""
Parameters.jl Demo for Globtim HPC Benchmarking

Demonstrates the enhanced parameter specification system using Parameters.jl
with @with_kw macros for defaults and @unpack for clean parameter access.
"""

# Load the Parameters.jl-enhanced configuration system
include("../hpc/config/parameters/BenchmarkConfigParameters.jl")

println("=== Parameters.jl Demo for Globtim HPC Benchmarking ===")
println()

# ============================================================================
# DEMO 1: Creating Parameters with Defaults
# ============================================================================

println("1. Creating parameters with @with_kw defaults...")

# Create Globtim parameters with some custom values, others use defaults
globtim_params = GlobtimParameters(
    degree = 6,                    # Custom value
    sample_count = 200,            # Custom value
    # center defaults to zeros(4)
    # sample_range defaults to 1.0
    # basis defaults to :chebyshev
    sparsification_threshold = 1e-5 # Custom value
    # All other fields use defaults
)

println("   ✓ GlobtimParameters created:")
println("     - degree: $(globtim_params.degree)")
println("     - sample_count: $(globtim_params.sample_count)")
println("     - center: $(globtim_params.center)")
println("     - basis: $(globtim_params.basis)")
println("     - sparsification_threshold: $(globtim_params.sparsification_threshold)")
println("     - enable_hessian: $(globtim_params.enable_hessian) (default)")
println()

# Create HPC parameters with defaults
hpc_params = HPCParameters(
    cpus = 48,                     # Custom value
    memory_gb = 64,                # Custom value
    # partition defaults to "batch"
    # time_limit defaults to "02:00:00"
    # julia_threads defaults to cpus
)

println("   ✓ HPCParameters created:")
println("     - partition: $(hpc_params.partition) (default)")
println("     - cpus: $(hpc_params.cpus)")
println("     - memory_gb: $(hpc_params.memory_gb)")
println("     - time_limit: $(hpc_params.time_limit) (default)")
println("     - julia_threads: $(hpc_params.julia_threads) (auto-set to cpus)")
println()

# ============================================================================
# DEMO 2: Using @unpack for Clean Parameter Access
# ============================================================================

println("2. Using @unpack for clean parameter access...")

function demo_globtim_workflow(globtim_params::GlobtimParameters, hpc_params::HPCParameters)
    # Extract parameters cleanly with @unpack
    @unpack degree, sample_count, center, sample_range, basis = globtim_params
    @unpack cpus, memory_gb, partition = hpc_params
    
    println("   Running workflow with:")
    println("     - Function evaluation at degree $degree")
    println("     - Using $sample_count sample points")
    println("     - Centered at $center with range $sample_range")
    println("     - Using $basis basis functions")
    println("     - On $partition partition with $cpus CPUs and $(memory_gb)GB RAM")
    
    # Simulate some computation
    complexity = degree^4 * sample_count
    estimated_time = complexity / (cpus * 1e6)  # Rough estimate
    
    println("     - Estimated complexity: $complexity")
    println("     - Estimated time: $(round(estimated_time, digits=2)) seconds")
    
    return (complexity=complexity, estimated_time=estimated_time)
end

result = demo_globtim_workflow(globtim_params, hpc_params)
println("   ✓ Workflow simulation completed")
println()

# ============================================================================
# DEMO 3: Creating Complete Jobs with Auto-Generated IDs
# ============================================================================

println("3. Creating complete benchmark jobs...")

# Get a benchmark function from registry
sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]
println("   Using benchmark function: $(sphere_func.name)")
println("   Description: $(sphere_func.description)")
println("   Global minimum at: $(sphere_func.global_minima[1])")
println()

# Create a complete benchmark job (ID and timestamp auto-generated)
job = BenchmarkJob(
    benchmark_func = sphere_func,
    globtim_params = globtim_params,
    hpc_params = hpc_params,
    experiment_name = "parameters_demo",
    tags = ["demo", "sphere", "parameters_jl"]
)

println("   ✓ BenchmarkJob created:")
println("     - job_id: $(job.job_id) (auto-generated)")
println("     - timestamp: $(job.timestamp) (auto-generated)")
println("     - parameter_set_id: $(job.parameter_set_id) (auto-generated)")
println("     - experiment_name: $(job.experiment_name)")
println("     - tags: $(job.tags)")
println()

# ============================================================================
# DEMO 4: Experiment Configuration and Parameter Sweeps
# ============================================================================

println("4. Creating experiment configurations...")

# Create a custom experiment configuration
custom_experiment = ExperimentConfig(
    name = "custom_demo",
    description = "Custom demo experiment with Parameters.jl",
    functions = [:Sphere, :Rosenbrock],
    degrees = [4, 6],
    sample_counts = [100, 200],
    sparsification_thresholds = [1e-3, 1e-4],
    default_hpc = HPCParameters(cpus=24, memory_gb=48)
)

println("   ✓ ExperimentConfig created:")
println("     - name: $(custom_experiment.name)")
println("     - description: $(custom_experiment.description)")
println("     - functions: $(custom_experiment.functions)")
println("     - degrees: $(custom_experiment.degrees)")
println("     - sample_counts: $(custom_experiment.sample_counts)")
println("     - output_dir: $(custom_experiment.output_dir) (auto-generated)")
println()

# Generate parameter sweep
jobs = generate_parameter_sweep(custom_experiment)
println("   ✓ Parameter sweep generated: $(length(jobs)) jobs")

# Show details of first few jobs
for (i, job) in enumerate(jobs[1:min(3, length(jobs))])
    @unpack job_id, benchmark_func, globtim_params, hpc_params = job
    @unpack degree, sample_count = globtim_params
    @unpack cpus, memory_gb = hpc_params
    
    println("     Job $i: $(job_id) - $(benchmark_func.name), deg=$degree, n=$sample_count, $(cpus)CPU/$(memory_gb)GB")
end
if length(jobs) > 3
    println("     ... and $(length(jobs) - 3) more jobs")
end
println()

# ============================================================================
# DEMO 5: Parameter Validation
# ============================================================================

println("5. Parameter validation...")

# Validate good parameters
try
    validate_parameters(globtim_params)
    validate_hpc_parameters(hpc_params)
    println("   ✓ All parameters valid")
catch e
    println("   ❌ Validation failed: $e")
end

# Try invalid parameters
try
    invalid_params = GlobtimParameters(degree = -1)  # Invalid degree
    validate_parameters(invalid_params)
    println("   ❌ Should have failed validation")
catch e
    println("   ✓ Correctly caught invalid parameter: $e")
end
println()

# ============================================================================
# DEMO 6: Using Configuration Presets
# ============================================================================

println("6. Using configuration presets...")

println("   Available presets:")
println("     - QUICK_TEST_EXPERIMENT: $(QUICK_TEST_EXPERIMENT.description)")
println("     - STANDARD_4D_EXPERIMENT: $(STANDARD_4D_EXPERIMENT.description)")
println("     - INTENSIVE_4D_EXPERIMENT: $(INTENSIVE_4D_EXPERIMENT.description)")
println()

# Use a preset
quick_jobs = generate_parameter_sweep(QUICK_TEST_EXPERIMENT)
println("   ✓ Quick test sweep: $(length(quick_jobs)) jobs")

# Show resource allocation for different job sizes
for (i, job) in enumerate(quick_jobs[1:min(2, length(quick_jobs))])
    @unpack benchmark_func, globtim_params, hpc_params = job
    @unpack degree, sample_count = globtim_params
    @unpack cpus, memory_gb, time_limit = hpc_params
    
    complexity = degree^4 * sample_count
    println("     Job $i: $(benchmark_func.name) (complexity: $complexity)")
    println("       → Allocated: $(cpus) CPUs, $(memory_gb)GB, $time_limit")
end
println()

# ============================================================================
# DEMO SUMMARY
# ============================================================================

println("=== Parameters.jl Demo Summary ===")
println("✅ Benefits demonstrated:")
println("   • @with_kw macro for clean default values")
println("   • @unpack macro for convenient parameter access")
println("   • Automatic ID and timestamp generation")
println("   • Type safety with validation")
println("   • Flexible configuration presets")
println("   • Clean parameter sweep generation")
println()
println("🎯 Key advantages over plain structs:")
println("   • Less boilerplate code")
println("   • Better ergonomics for parameter handling")
println("   • Consistent default value management")
println("   • Enhanced readability with @unpack")
println()
println("🚀 Ready for HPC deployment with Parameters.jl!")
println()

# Show comparison of parameter access styles
println("📋 Parameter access comparison:")
println()
println("   Without @unpack (verbose):")
println("   degree = globtim_params.degree")
println("   sample_count = globtim_params.sample_count")
println("   center = globtim_params.center")
println("   # ... many more lines")
println()
println("   With @unpack (clean):")
println("   @unpack degree, sample_count, center = globtim_params")
println("   # All parameters available directly")
println()
println("✨ Parameters.jl makes parameter management elegant and efficient!")
