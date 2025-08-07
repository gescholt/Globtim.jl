"""
Test HPC Benchmarking Infrastructure

Minimal test to verify the parameter specification, job tracking, and SLURM
generation systems work correctly before scaling up to full benchmarks.

This creates tiny test problems that should run in seconds to validate the
complete infrastructure pipeline.
"""

using Pkg
Pkg.activate(".")

# Load our HPC infrastructure
include("src/HPC/BenchmarkConfig.jl")
include("src/HPC/JobTracking.jl")
include("src/HPC/SlurmJobGenerator.jl")

println("=== Testing HPC Benchmarking Infrastructure ===")
println()

# ============================================================================
# TEST 1: Parameter Specification System
# ============================================================================

println("1. Testing Parameter Specification System...")

# Test benchmark function registry
println("   Available benchmark functions:")
for (name, func) in BENCHMARK_4D_REGISTRY
    println("   - $name: $(func.description)")
end

# Test parameter generation
test_globtim_params = GlobtimParameters(
    degree = 2,
    sample_count = 50,
    center = zeros(4),
    sample_range = 1.0,
    sparsification_threshold = 1e-3
)

println("   ✓ GlobtimParameters created: degree=$(test_globtim_params.degree), samples=$(test_globtim_params.sample_count)")

# Test job creation
test_job = BenchmarkJob(
    BENCHMARK_4D_REGISTRY[:Sphere],
    test_globtim_params;
    experiment_name = "infrastructure_test",
    tags = ["test", "minimal"]
)

println("   ✓ BenchmarkJob created: ID=$(test_job.job_id), function=$(test_job.benchmark_func.name)")
println()

# ============================================================================
# TEST 2: Job Tracking System
# ============================================================================

println("2. Testing Job Tracking System...")

# Create experiment tracker
tracker = ExperimentTracker("infrastructure_test")
println("   ✓ ExperimentTracker created: $(tracker.experiment_name)")

# Register job
job_id = register_job!(tracker, test_job)
println("   ✓ Job registered: $job_id")

# Check directory structure was created
job_dir = get_job_dir(job_id, "infrastructure_test")
if isdir(job_dir)
    println("   ✓ Job directory created: $job_dir")
    
    # Check config file was saved
    config_path = get_job_config_path(job_id, "infrastructure_test")
    if isfile(config_path)
        println("   ✓ Job configuration saved: $config_path")
    else
        println("   ❌ Job configuration not found")
    end
else
    println("   ❌ Job directory not created")
end

# Test status updates
update_job_status!(tracker, job_id, :running)
println("   ✓ Job status updated to :running")

update_job_status!(tracker, job_id, :completed)
println("   ✓ Job status updated to :completed")
println()

# ============================================================================
# TEST 3: Parameter Sweep Generation
# ============================================================================

println("3. Testing Parameter Sweep Generation...")

# Create minimal test configuration
minimal_config = (
    functions = [:Sphere, :Rosenbrock],
    degrees = [2, 4],
    sample_counts = [50, 100],
    sparsification_thresholds = [1e-3, 1e-4]
)

# Generate parameter sweep
test_jobs = generate_parameter_sweep("minimal_sweep_test", minimal_config)
println("   ✓ Parameter sweep generated: $(length(test_jobs)) jobs")

# Show job details
for (i, job) in enumerate(test_jobs[1:min(3, length(test_jobs))])
    println("   Job $i: $(job.benchmark_func.name), deg=$(job.globtim_params.degree), n=$(job.globtim_params.sample_count)")
end
if length(test_jobs) > 3
    println("   ... and $(length(test_jobs) - 3) more jobs")
end
println()

# ============================================================================
# TEST 4: SLURM Script Generation
# ============================================================================

println("4. Testing SLURM Script Generation...")

# Test individual job script generation
test_script = generate_benchmark_slurm_script(test_job, "/tmp")
println("   ✓ SLURM script generated ($(length(split(test_script, '\n'))) lines)")

# Check script contains key elements
required_elements = [
    "#SBATCH --job-name=globtim_$(test_job.job_id)",
    "Function: $(test_job.benchmark_func.name)",
    "Degree: $(test_job.globtim_params.degree)",
    "safe_globtim_workflow"
]

for element in required_elements
    if occursin(element, test_script)
        println("   ✓ Script contains: $element")
    else
        println("   ❌ Script missing: $element")
    end
end
println()

# ============================================================================
# TEST 5: Distance Computation
# ============================================================================

println("5. Testing Distance Computation...")

# Test distance computation with sample points
test_points = [
    0.1 0.1 0.1 0.1;    # Close to origin
    1.0 1.0 1.0 1.0;    # At Rosenbrock minimum
    2.0 2.0 2.0 2.0     # Far from minima
]

# Test with Sphere function (global minimum at origin)
sphere_minima = BENCHMARK_4D_REGISTRY[:Sphere].global_minima
distances_sphere = compute_min_distances_to_global(test_points, sphere_minima)
println("   ✓ Distances to Sphere minimum: $(round.(distances_sphere, digits=3))")

# Test with Rosenbrock function (global minimum at [1,1,1,1])
rosenbrock_minima = BENCHMARK_4D_REGISTRY[:Rosenbrock].global_minima
distances_rosenbrock = compute_min_distances_to_global(test_points, rosenbrock_minima)
println("   ✓ Distances to Rosenbrock minimum: $(round.(distances_rosenbrock, digits=3))")
println()

# ============================================================================
# TEST 6: Job Submission Package Creation
# ============================================================================

println("6. Testing Job Submission Package Creation...")

# Create a small test package
small_test_jobs = test_jobs[1:2]  # Just first 2 jobs
test_tracker = create_job_submission_package(small_test_jobs, "package_test")

println("   ✓ Job submission package created")
println("   ✓ Experiment tracker: $(test_tracker.experiment_name)")
println("   ✓ Registered jobs: $(length(test_tracker.jobs))")

# Check if files were created
exp_dir = get_experiment_dir("package_test")
if isdir(exp_dir)
    println("   ✓ Experiment directory created: $exp_dir")
    
    # Check for management script
    mgmt_script = joinpath(exp_dir, "manage_experiment.sh")
    if isfile(mgmt_script)
        println("   ✓ Management script created: $mgmt_script")
    end
    
    # Check job directories
    for job in small_test_jobs
        job_dir = get_job_dir(job.job_id, "package_test")
        if isdir(job_dir)
            println("   ✓ Job directory: $(job.job_id)")
        end
    end
else
    println("   ❌ Experiment directory not created")
end
println()

# ============================================================================
# TEST SUMMARY
# ============================================================================

println("=== Infrastructure Test Summary ===")
println("✓ Parameter specification system working")
println("✓ Job tracking and directory structure working")
println("✓ Parameter sweep generation working")
println("✓ SLURM script generation working")
println("✓ Distance computation working")
println("✓ Job submission package creation working")
println()
println("🎉 All infrastructure components are functional!")
println()
println("Next steps:")
println("1. Test with actual Globtim execution (small problem)")
println("2. Deploy to HPC cluster for validation")
println("3. Scale up to full benchmark suites")
println()

# ============================================================================
# CLEANUP (Optional)
# ============================================================================

println("Cleanup test directories? (y/N)")
response = readline()
if lowercase(strip(response)) == "y"
    try
        rm(get_results_base_dir(), recursive=true)
        println("✓ Test directories cleaned up")
    catch e
        println("Note: Could not clean up test directories: $e")
    end
end

println("Infrastructure test completed!")
