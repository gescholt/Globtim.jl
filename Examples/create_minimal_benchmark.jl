"""
Create Minimal Benchmark Example

Demonstrates how to use the HPC benchmarking infrastructure to create
a small-scale test that can be deployed to the cluster for validation.

This example creates a minimal parameter sweep with 2 functions, 2 degrees,
and 2 sample counts - resulting in 8 total jobs that should run quickly.
"""

# This script is designed to run on the HPC cluster where all packages are available
# It demonstrates the complete workflow from parameter specification to job creation

println("=== Creating Minimal Benchmark Example ===")
println()

# Load the HPC infrastructure (will be available on cluster)
include("../src/HPC/BenchmarkConfig.jl")
include("../src/HPC/JobTracking.jl") 
include("../src/HPC/SlurmJobGenerator.jl")

# ============================================================================
# STEP 1: Define Minimal Test Configuration
# ============================================================================

println("Step 1: Defining minimal test configuration...")

# Very small parameter sweep for quick validation
minimal_test_config = (
    functions = [:Sphere, :Rosenbrock],           # 2 functions
    degrees = [2, 4],                             # 2 degrees  
    sample_counts = [50, 100],                    # 2 sample counts
    sparsification_thresholds = [1e-3]            # 1 threshold
)

println("   Functions: $(minimal_test_config.functions)")
println("   Degrees: $(minimal_test_config.degrees)")
println("   Sample counts: $(minimal_test_config.sample_counts)")
println("   Thresholds: $(minimal_test_config.sparsification_thresholds)")

total_jobs = length(minimal_test_config.functions) * 
             length(minimal_test_config.degrees) * 
             length(minimal_test_config.sample_counts) * 
             length(minimal_test_config.sparsification_thresholds)

println("   Total jobs: $total_jobs")
println()

# ============================================================================
# STEP 2: Generate Parameter Sweep
# ============================================================================

println("Step 2: Generating parameter sweep...")

experiment_name = "minimal_validation_$(Dates.format(now(), "yyyymmdd_HHMMSS"))"
jobs = generate_parameter_sweep(experiment_name, minimal_test_config)

println("   Experiment: $experiment_name")
println("   Generated $(length(jobs)) jobs")

# Show details of first few jobs
for (i, job) in enumerate(jobs[1:min(3, length(jobs))])
    println("   Job $i: $(job.job_id) - $(job.benchmark_func.name), deg=$(job.globtim_params.degree), n=$(job.globtim_params.sample_count)")
end
if length(jobs) > 3
    println("   ... and $(length(jobs) - 3) more jobs")
end
println()

# ============================================================================
# STEP 3: Create Job Submission Package
# ============================================================================

println("Step 3: Creating job submission package...")

tracker = create_job_submission_package(jobs, experiment_name)

println("   ✓ Experiment tracker created")
println("   ✓ Job directories created")
println("   ✓ SLURM scripts generated")
println("   ✓ Management scripts created")

# Show directory structure
exp_dir = get_experiment_dir(experiment_name)
println("   Experiment directory: $exp_dir")

# List created files
if isdir(exp_dir)
    println("   Created files:")
    for (root, dirs, files) in walkdir(exp_dir)
        for file in files
            rel_path = relpath(joinpath(root, file), exp_dir)
            println("     - $rel_path")
        end
    end
end
println()

# ============================================================================
# STEP 4: Show Usage Instructions
# ============================================================================

println("Step 4: Usage instructions...")
println()

println("To submit jobs to the HPC cluster:")
println("1. Upload this experiment to the cluster:")
println("   ./sync_fileserver_to_hpc.sh")
println()

println("2. Submit jobs using the management script:")
println("   ssh scholten@falcon")
println("   cd globtim_hpc/results/experiments/$experiment_name")
println("   ./manage_experiment.sh submit")
println()

println("3. Monitor job progress:")
println("   ./manage_experiment.sh status")
println()

println("4. Check results when complete:")
println("   ./manage_experiment.sh results")
println()

println("Alternative: Submit individual jobs:")
for (i, job) in enumerate(jobs[1:2])
    println("   sbatch jobs/$(job.job_id)/job_script.sh")
end
println()

# ============================================================================
# STEP 5: Expected Results
# ============================================================================

println("Step 5: Expected results...")
println()

println("Each job will produce:")
println("   - results_summary.json: Key metrics and convergence data")
println("   - critical_points.csv: All critical points found")
println("   - minimizers.csv: Local minimizers only")
println("   - distances_analysis.csv: Distance to global minima")
println()

println("Key metrics to track:")
println("   - min_distance_to_global: How close we get to true minimum")
println("   - convergence_rate: Fraction of minimizers near global minimum")
println("   - l2_error: Polynomial approximation quality")
println("   - construction_time: Computational efficiency")
println()

println("For Sphere function (global min at origin):")
println("   - Expect min_distance_to_global < 0.1 for good convergence")
println("   - Expect convergence_rate > 0.5 for degree ≥ 4")
println()

println("For Rosenbrock function (global min at [1,1,1,1]):")
println("   - More challenging - expect larger distances")
println("   - Convergence rate may be lower due to narrow valley")
println()

# ============================================================================
# STEP 6: Analysis Template
# ============================================================================

println("Step 6: Analysis template...")
println()

println("After jobs complete, analyze results with:")
println("""
# Load results
using CSV, DataFrames, Statistics

# Read aggregated results
results_df = CSV.read("aggregated/all_results.csv", DataFrame)

# Analyze convergence by function
for func in unique(results_df.function_name)
    func_results = filter(row -> row.function_name == func, results_df)
    
    println("Function: \$func")
    println("  Best distance: ", minimum(func_results.min_distance_to_global))
    println("  Mean convergence rate: ", mean(func_results.convergence_rate))
    println("  Mean L2 error: ", mean(func_results.l2_error))
    println()
end

# Compare degree effects
for deg in unique(results_df.degree)
    deg_results = filter(row -> row.degree == deg, results_df)
    println("Degree \$deg: mean distance = ", mean(deg_results.min_distance_to_global))
end
""")

println()
println("=== Minimal Benchmark Example Created Successfully! ===")
println()
println("This example demonstrates:")
println("✓ Parameter specification and sweep generation")
println("✓ Job tracking and directory organization") 
println("✓ SLURM script generation with proper labeling")
println("✓ Distance computation for convergence analysis")
println("✓ Complete workflow from parameters to results")
println()
println("Ready for HPC deployment and validation! 🚀")
