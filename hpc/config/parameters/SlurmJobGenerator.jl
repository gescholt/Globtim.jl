"""
SLURM Job Generation System

Generates SLURM job scripts for systematic benchmark execution with proper
parameter tracking, result collection, and integration with the job tracking system.

Supports both individual jobs and job arrays for parameter sweeps.
"""

using Dates
using Printf

include("BenchmarkConfig.jl")
include("JobTracking.jl")

# ============================================================================
# SLURM JOB SCRIPT GENERATION
# ============================================================================

"""
    generate_benchmark_slurm_script(job::BenchmarkJob, output_dir::String)

Generate a complete SLURM script for a benchmark job.
"""
function generate_benchmark_slurm_script(job::BenchmarkJob, output_dir::String)
    script_content = """#!/bin/bash
#SBATCH --job-name=globtim_$(job.job_id)
#SBATCH --partition=$(job.partition)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$(job.cpus)
#SBATCH --time=$(job.time_limit)
#SBATCH --mem=$(job.memory_gb)G
#SBATCH --output=$(output_dir)/globtim_$(job.job_id)_%j.out
#SBATCH --error=$(output_dir)/globtim_$(job.job_id)_%j.err

# Globtim Benchmark Job: $(job.parameter_set_id)
# Job ID: $(job.job_id)
# Function: $(job.benchmark_func.name)
# Degree: $(job.globtim_params.degree), Samples: $(job.globtim_params.sample_count)
# Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

echo "=== Globtim Benchmark Job ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: \$SLURM_CPUS_PER_TASK"
echo "Memory: \$SLURM_MEM_PER_NODE MB"
echo "Start time: \$(date)"
echo "Function: $(job.benchmark_func.name)"
echo "Degree: $(job.globtim_params.degree)"
echo "Samples: $(job.globtim_params.sample_count)"
echo ""

# Set Julia environment
export JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_\${USER}_\${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_\${SLURM_JOB_ID}"

# Create working directory
mkdir -p \$TMPDIR
cd \$TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: \$JULIA_NUM_THREADS"
echo "Julia depot: \$JULIA_DEPOT_PATH"
echo "Working directory: \$(pwd)"
echo "Available space: \$(df -h . | tail -1 | awk '{print \$4}')"
echo ""

echo "=== Downloading Globtim from Fileserver ==="
# Download Globtim source and HPC configuration
scp -r scholten@fileserver-ssh:globtim/src .
scp scholten@fileserver-ssh:globtim/Project_HPC.toml ./Project.toml

# Download job configuration
scp scholten@fileserver-ssh:globtim/results/experiments/$(job.experiment_name)/jobs/$(job.job_id)/config.toml ./job_config.toml

echo "✓ Globtim source and configuration downloaded"
echo ""

echo "=== Running Benchmark ==="
/sw/bin/julia --project=. -e '
# Load required packages
using LinearAlgebra, Statistics, Random, DataFrames, CSV, Dates
Random.seed!(42)

# Load Globtim modules
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl") 
include("src/LibFunctions.jl")
include("src/HPC/BenchmarkConfig.jl")
include("src/HPC/JobTracking.jl")

println("=== Globtim Benchmark Execution ===")
println("Job ID: $(job.job_id)")
println("Function: $(job.benchmark_func.name)")
println("Degree: $(job.globtim_params.degree)")
println("Samples: $(job.globtim_params.sample_count)")
println()

# Get benchmark function
benchmark_func = BENCHMARK_4D_REGISTRY[:$(job.benchmark_func.name)]
test_function = benchmark_func.func

# Record start time
start_time = time()
start_memory = Sys.total_memory() - Sys.free_memory()

try
    # Run Globtim workflow
    println("Running Globtim workflow...")
    results = safe_globtim_workflow(
        test_function,
        dim = 4,
        center = $(job.globtim_params.center),
        sample_range = $(job.globtim_params.sample_range),
        degree = $(job.globtim_params.degree),
        GN = $(job.globtim_params.sample_count),
        enable_hessian = $(job.globtim_params.enable_hessian),
        basis = :$(job.globtim_params.basis),
        precision = $(job.globtim_params.precision),
        max_retries = $(job.globtim_params.max_retries)
    )
    
    # Record end time and memory
    end_time = time()
    end_memory = Sys.total_memory() - Sys.free_memory()
    
    println("✓ Globtim workflow completed successfully!")
    println("   - L2 error: ", @sprintf("%.2e", results.polynomial.nrm))
    println("   - Critical points: ", nrow(results.critical_points))
    println("   - Minimizers: ", nrow(results.minima))
    println("   - Construction time: ", @sprintf("%.2f", results.construction_time), " seconds")
    println()
    
    # Compute distance analysis (key convergence metric)
    println("=== Distance Analysis ===")
    if nrow(results.minima) > 0
        minimizer_points = Matrix{Float64}(results.minima[:, 1:4])
        distances = compute_min_distances_to_global(minimizer_points, benchmark_func.global_minima)
        
        min_distance = minimum(distances)
        mean_distance = mean(distances)
        tolerance = 0.1
        convergence_rate = sum(distances .< tolerance) / length(distances)
        
        println("   - Minimum distance to global: ", @sprintf("%.6f", min_distance))
        println("   - Mean distance to global: ", @sprintf("%.6f", mean_distance))
        println("   - Convergence rate (< 0.1): ", @sprintf("%.2f%%", convergence_rate * 100))
        
        # Save distance analysis
        distances_df = DataFrame(
            minimizer_index = 1:length(distances),
            distance_to_global = distances,
            x1 = minimizer_points[:, 1],
            x2 = minimizer_points[:, 2], 
            x3 = minimizer_points[:, 3],
            x4 = minimizer_points[:, 4]
        )
        CSV.write("distances_analysis.csv", distances_df)
    else
        println("   - No minimizers found")
        min_distance = Inf
        mean_distance = Inf
        convergence_rate = 0.0
    end
    println()
    
    # Save detailed results
    println("=== Saving Results ===")
    CSV.write("critical_points.csv", results.critical_points)
    CSV.write("minimizers.csv", results.minima)
    
    # Create comprehensive results summary
    results_summary = Dict(
        "job_id" => "$(job.job_id)",
        "slurm_job_id" => ENV["SLURM_JOB_ID"],
        "compute_node" => ENV["SLURMD_NODENAME"],
        "execution_timestamp" => string(now()),
        "function_name" => "$(job.benchmark_func.name)",
        "degree" => $(job.globtim_params.degree),
        "sample_count" => $(job.globtim_params.sample_count),
        "sparsification_threshold" => $(job.globtim_params.sparsification_threshold),
        "l2_error" => results.polynomial.nrm,
        "construction_time" => results.construction_time,
        "critical_points_count" => nrow(results.critical_points),
        "minimizers_count" => nrow(results.minima),
        "min_distance_to_global" => min_distance,
        "mean_distance_to_global" => mean_distance,
        "convergence_rate" => convergence_rate,
        "cpu_time_seconds" => end_time - start_time,
        "memory_usage_mb" => (end_memory - start_memory) / 1024^2,
        "exit_code" => 0
    )
    
    # Save as JSON
    open("results_summary.json", "w") do io
        JSON3.pretty(io, results_summary)
    end
    
    println("✓ Results saved successfully")
    println("   - critical_points.csv: ", nrow(results.critical_points), " points")
    println("   - minimizers.csv: ", nrow(results.minima), " points") 
    println("   - distances_analysis.csv: distance metrics")
    println("   - results_summary.json: comprehensive summary")
    
catch e
    println("❌ ERROR in Globtim execution:")
    println(e)
    
    # Save error information
    error_info = Dict(
        "job_id" => "$(job.job_id)",
        "slurm_job_id" => ENV["SLURM_JOB_ID"],
        "error_message" => string(e),
        "exit_code" => 1
    )
    
    open("error_summary.json", "w") do io
        JSON3.pretty(io, error_info)
    end
    
    exit(1)
end

println()
println("=== Benchmark Completed Successfully ===")
'

echo ""
echo "=== Uploading Results to Fileserver ==="
# Upload all results back to fileserver
RESULTS_DIR="scholten@fileserver-ssh:globtim/results/experiments/$(job.experiment_name)/jobs/$(job.job_id)/"

if [ -f "results_summary.json" ]; then
    scp results_summary.json \$RESULTS_DIR
    echo "✓ Results summary uploaded"
fi

if [ -f "critical_points.csv" ]; then
    scp critical_points.csv \$RESULTS_DIR
    echo "✓ Critical points uploaded"
fi

if [ -f "minimizers.csv" ]; then
    scp minimizers.csv \$RESULTS_DIR
    echo "✓ Minimizers uploaded"
fi

if [ -f "distances_analysis.csv" ]; then
    scp distances_analysis.csv \$RESULTS_DIR
    echo "✓ Distance analysis uploaded"
fi

if [ -f "error_summary.json" ]; then
    scp error_summary.json \$RESULTS_DIR
    echo "✓ Error summary uploaded"
fi

# Upload SLURM output files
scp \$SLURM_SUBMIT_DIR/globtim_$(job.job_id)_\$SLURM_JOB_ID.out \$RESULTS_DIR/slurm_output/ 2>/dev/null || echo "Output file not found"
scp \$SLURM_SUBMIT_DIR/globtim_$(job.job_id)_\$SLURM_JOB_ID.err \$RESULTS_DIR/slurm_output/ 2>/dev/null || echo "Error file not found"

echo ""
echo "=== Cleanup ==="
cd /
rm -rf \$TMPDIR
rm -rf \$JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "End time: \$(date)"
echo "Total duration: \$SECONDS seconds"
echo "Results uploaded to: \$RESULTS_DIR"
"""

    return script_content
end

"""
    generate_job_array_script(jobs::Vector{BenchmarkJob}, experiment_name::String, output_dir::String)

Generate a SLURM job array script for running multiple benchmark jobs efficiently.
"""
function generate_job_array_script(jobs::Vector{BenchmarkJob}, experiment_name::String, output_dir::String)
    if isempty(jobs)
        error("No jobs provided for job array")
    end
    
    # Determine resource requirements (use maximum across all jobs)
    max_cpus = maximum(job -> job.cpus, jobs)
    max_memory = maximum(job -> job.memory_gb, jobs)
    max_time = jobs[1].time_limit  # Assume all jobs have similar time requirements
    partition = jobs[1].partition   # Assume all jobs use same partition
    
    n_jobs = length(jobs)
    
    script_content = """#!/bin/bash
#SBATCH --job-name=globtim_array_$(experiment_name)
#SBATCH --partition=$(partition)
#SBATCH --array=1-$(n_jobs)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$(max_cpus)
#SBATCH --time=$(max_time)
#SBATCH --mem=$(max_memory)G
#SBATCH --output=$(output_dir)/globtim_array_$(experiment_name)_%A_%a.out
#SBATCH --error=$(output_dir)/globtim_array_$(experiment_name)_%A_%a.err

# Globtim Benchmark Job Array: $(experiment_name)
# Total jobs: $(n_jobs)
# Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

echo "=== Globtim Job Array ==="
echo "Experiment: $(experiment_name)"
echo "Array Job ID: \$SLURM_ARRAY_JOB_ID"
echo "Array Task ID: \$SLURM_ARRAY_TASK_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Start time: \$(date)"
echo ""

# Job configuration mapping (array index -> job_id)
declare -A JOB_IDS
$(join(["\nJOB_IDS[\$i]=\"$(jobs[i].job_id)\"" for i in 1:length(jobs)]))

# Get current job ID
CURRENT_JOB_ID=\${JOB_IDS[\$SLURM_ARRAY_TASK_ID]}
echo "Processing Job ID: \$CURRENT_JOB_ID"

# Download and execute the specific job script
TEMP_SCRIPT="/tmp/job_\${CURRENT_JOB_ID}_\${SLURM_ARRAY_TASK_ID}.sh"
scp scholten@fileserver-ssh:globtim/results/experiments/$(experiment_name)/jobs/\$CURRENT_JOB_ID/job_script.sh \$TEMP_SCRIPT

if [ -f "\$TEMP_SCRIPT" ]; then
    chmod +x \$TEMP_SCRIPT
    \$TEMP_SCRIPT
    rm \$TEMP_SCRIPT
else
    echo "ERROR: Job script not found for \$CURRENT_JOB_ID"
    exit 1
fi

echo ""
echo "=== Array Task Completed ==="
echo "Job ID: \$CURRENT_JOB_ID"
echo "Array Task: \$SLURM_ARRAY_TASK_ID"
echo "End time: \$(date)"
"""

    return script_content
end

"""
    create_job_submission_package(jobs::Vector{BenchmarkJob}, experiment_name::String)

Create a complete package of SLURM scripts and configurations for job submission.
"""
function create_job_submission_package(jobs::Vector{BenchmarkJob}, experiment_name::String)
    # Create experiment tracker
    tracker = ExperimentTracker(experiment_name)
    
    # Register all jobs
    for job in jobs
        register_job!(tracker, job)
    end
    
    # Generate individual job scripts
    for job in jobs
        job_dir = get_job_dir(job.job_id, experiment_name)
        script_content = generate_benchmark_slurm_script(job, job_dir)
        
        # Save job script
        script_path = joinpath(job_dir, "job_script.sh")
        open(script_path, "w") do io
            write(io, script_content)
        end
        chmod(script_path, 0o755)  # Make executable
    end
    
    # Generate job array script if multiple jobs
    if length(jobs) > 1
        exp_dir = get_experiment_dir(experiment_name)
        array_script_content = generate_job_array_script(jobs, experiment_name, exp_dir)
        
        array_script_path = joinpath(exp_dir, "submit_job_array.sh")
        open(array_script_path, "w") do io
            write(io, array_script_content)
        end
        chmod(array_script_path, 0o755)
    end
    
    # Create submission helper script
    create_submission_helper(experiment_name, length(jobs))
    
    return tracker
end

"""
    create_submission_helper(experiment_name::String, n_jobs::Int)

Create a helper script for easy job submission and monitoring.
"""
function create_submission_helper(experiment_name::String, n_jobs::Int)
    exp_dir = get_experiment_dir(experiment_name)
    
    helper_content = """#!/bin/bash

# Globtim Benchmark Submission Helper
# Experiment: $(experiment_name)
# Jobs: $(n_jobs)

EXPERIMENT_NAME="$(experiment_name)"
EXPERIMENT_DIR="$(exp_dir)"

case "\$1" in
    "submit")
        echo "Submitting $(experiment_name) benchmark jobs..."
        if [ $(n_jobs) -eq 1 ]; then
            # Single job submission
            JOB_SCRIPT=\$(find \$EXPERIMENT_DIR/jobs -name "job_script.sh" | head -1)
            sbatch \$JOB_SCRIPT
        else
            # Job array submission
            sbatch \$EXPERIMENT_DIR/submit_job_array.sh
        fi
        ;;
    "status")
        echo "Checking status for experiment: \$EXPERIMENT_NAME"
        squeue -u \$USER --name=globtim_*
        ;;
    "results")
        echo "Results summary for \$EXPERIMENT_NAME:"
        if [ -f "\$EXPERIMENT_DIR/experiment_summary.json" ]; then
            cat \$EXPERIMENT_DIR/experiment_summary.json
        else
            echo "No results summary found yet"
        fi
        ;;
    *)
        echo "Usage: \$0 {submit|status|results}"
        echo "  submit  - Submit all jobs for this experiment"
        echo "  status  - Check job status"
        echo "  results - Show results summary"
        ;;
esac
"""

    helper_path = joinpath(exp_dir, "manage_experiment.sh")
    open(helper_path, "w") do io
        write(io, helper_content)
    end
    chmod(helper_path, 0o755)
    
    println("Created experiment management script: $helper_path")
end
