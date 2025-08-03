"""
HPC Job Tracking and Result Management System

Comprehensive system for tracking benchmark jobs, collecting results, and
maintaining full traceability from parameters to final statistics.

Integrates with HomotopyContinuation.jl results and provides systematic
organization of all computational outputs.
"""

using Dates
using UUIDs
using JSON3
using DataFrames
using CSV
using LinearAlgebra
using Statistics

include("BenchmarkConfig.jl")

# ============================================================================
# RESULT STRUCTURES
# ============================================================================

"""
    BenchmarkResult

Complete results from a single benchmark job execution.
"""
struct BenchmarkResult
    job_id::String
    execution_timestamp::DateTime
    
    # Job specification (for traceability)
    job_config::BenchmarkJob
    
    # Globtim execution results
    l2_error::Float64
    construction_time::Float64
    critical_points_count::Int
    minimizers_count::Int
    
    # Critical point analysis
    critical_points::DataFrame  # All critical points found
    minimizers::DataFrame       # Local minimizers only
    
    # Distance analysis (key metric from Triple_Graph_deuf_4d.ipynb)
    distances_to_global::Vector{Float64}  # Distance of each minimizer to nearest global minimum
    min_distance_to_global::Float64       # Best distance achieved
    mean_distance_to_global::Float64      # Average distance
    convergence_rate::Float64             # How many minimizers are "close" to global minima
    
    # Sparsification analysis
    sparsification_stats::NamedTuple
    
    # Performance metrics
    memory_usage_mb::Float64
    cpu_time_seconds::Float64
    wall_time_seconds::Float64
    
    # HPC execution info
    slurm_job_id::String
    compute_node::String
    exit_code::Int
    
    function BenchmarkResult(job_id, job_config, globtim_results, hpc_info)
        execution_timestamp = now()
        
        # Extract critical points and minimizers
        critical_points = globtim_results.critical_points
        minimizers = globtim_results.minima
        
        # Compute distances to global minima (key convergence metric)
        if nrow(minimizers) > 0
            minimizer_points = Matrix{Float64}(minimizers[:, 1:4])  # Assuming 4D
            distances = compute_min_distances_to_global(
                minimizer_points, 
                job_config.benchmark_func.global_minima
            )
            min_dist = minimum(distances)
            mean_dist = mean(distances)
            
            # Convergence rate: fraction of minimizers within tolerance of global minimum
            tolerance = 0.1  # Configurable tolerance
            convergence_rate = sum(distances .< tolerance) / length(distances)
        else
            distances = Float64[]
            min_dist = Inf
            mean_dist = Inf
            convergence_rate = 0.0
        end
        
        new(
            job_id, execution_timestamp, job_config,
            globtim_results.polynomial.nrm, globtim_results.construction_time,
            nrow(critical_points), nrow(minimizers),
            critical_points, minimizers,
            distances, min_dist, mean_dist, convergence_rate,
            globtim_results.sparsification_results,
            hpc_info.memory_usage_mb, hpc_info.cpu_time_seconds, hpc_info.wall_time_seconds,
            hpc_info.slurm_job_id, hpc_info.compute_node, hpc_info.exit_code
        )
    end
end

"""
    ExperimentTracker

Tracks multiple related benchmark jobs and aggregates results.
"""
mutable struct ExperimentTracker
    experiment_name::String
    start_time::DateTime
    jobs::Dict{String, BenchmarkJob}           # job_id -> job config
    results::Dict{String, BenchmarkResult}     # job_id -> results
    job_status::Dict{String, Symbol}           # job_id -> :pending, :running, :completed, :failed
    
    function ExperimentTracker(experiment_name::String)
        new(experiment_name, now(), Dict(), Dict(), Dict())
    end
end

# ============================================================================
# JOB MANAGEMENT
# ============================================================================

"""
    register_job!(tracker::ExperimentTracker, job::BenchmarkJob)

Register a new job with the experiment tracker.
"""
function register_job!(tracker::ExperimentTracker, job::BenchmarkJob)
    tracker.jobs[job.job_id] = job
    tracker.job_status[job.job_id] = :pending
    
    # Create job directory structure
    create_job_directories(job)
    
    # Save job configuration for reproducibility
    config_path = get_job_config_path(job.job_id)
    save_job_config(job, config_path)
    
    return job.job_id
end

"""
    update_job_status!(tracker::ExperimentTracker, job_id::String, status::Symbol)

Update the status of a job.
"""
function update_job_status!(tracker::ExperimentTracker, job_id::String, status::Symbol)
    if haskey(tracker.job_status, job_id)
        tracker.job_status[job_id] = status
        
        # Log status change
        timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        status_log_path = get_job_status_log_path(job_id)
        open(status_log_path, "a") do io
            println(io, "$timestamp: $status")
        end
    else
        error("Job $job_id not found in tracker")
    end
end

"""
    record_result!(tracker::ExperimentTracker, job_id::String, result::BenchmarkResult)

Record the results of a completed job.
"""
function record_result!(tracker::ExperimentTracker, job_id::String, result::BenchmarkResult)
    tracker.results[job_id] = result
    tracker.job_status[job_id] = :completed
    
    # Save detailed results
    save_job_results(result)
    
    # Update experiment summary
    update_experiment_summary(tracker)
end

# ============================================================================
# FILE SYSTEM ORGANIZATION
# ============================================================================

"""
Systematic directory structure for organizing all benchmark results:

results/
├── experiments/
│   └── {experiment_name}/
│       ├── experiment_summary.json
│       ├── jobs/
│       │   └── {job_id}/
│       │       ├── config.toml
│       │       ├── status.log
│       │       ├── results.json
│       │       ├── critical_points.csv
│       │       ├── minimizers.csv
│       │       ├── distances.csv
│       │       └── slurm_output/
│       │           ├── job_{slurm_id}.out
│       │           └── job_{slurm_id}.err
│       └── aggregated/
│           ├── all_results.csv
│           ├── convergence_analysis.csv
│           └── performance_summary.csv
"""

function get_results_base_dir()
    return joinpath(pwd(), "results")
end

function get_experiment_dir(experiment_name::String)
    return joinpath(get_results_base_dir(), "experiments", experiment_name)
end

function get_job_dir(job_id::String, experiment_name::String="")
    if isempty(experiment_name)
        # Try to find experiment from existing jobs
        base_dir = joinpath(get_results_base_dir(), "experiments")
        for exp_dir in readdir(base_dir)
            job_path = joinpath(base_dir, exp_dir, "jobs", job_id)
            if isdir(job_path)
                return job_path
            end
        end
        error("Job $job_id not found in any experiment")
    else
        return joinpath(get_experiment_dir(experiment_name), "jobs", job_id)
    end
end

function get_job_config_path(job_id::String, experiment_name::String="")
    return joinpath(get_job_dir(job_id, experiment_name), "config.toml")
end

function get_job_status_log_path(job_id::String, experiment_name::String="")
    return joinpath(get_job_dir(job_id, experiment_name), "status.log")
end

function get_job_results_path(job_id::String, experiment_name::String="")
    return joinpath(get_job_dir(job_id, experiment_name), "results.json")
end

"""
    create_job_directories(job::BenchmarkJob)

Create the complete directory structure for a job.
"""
function create_job_directories(job::BenchmarkJob)
    job_dir = get_job_dir(job.job_id, job.experiment_name)
    mkpath(job_dir)
    mkpath(joinpath(job_dir, "slurm_output"))
    
    # Create experiment directory if it doesn't exist
    exp_dir = get_experiment_dir(job.experiment_name)
    mkpath(joinpath(exp_dir, "aggregated"))
end

# ============================================================================
# RESULT PERSISTENCE
# ============================================================================

"""
    save_job_results(result::BenchmarkResult)

Save comprehensive job results to multiple formats for analysis.
"""
function save_job_results(result::BenchmarkResult)
    job_dir = get_job_dir(result.job_id, result.job_config.experiment_name)
    
    # Save main results as JSON
    results_dict = Dict(
        "job_id" => result.job_id,
        "execution_timestamp" => string(result.execution_timestamp),
        "l2_error" => result.l2_error,
        "construction_time" => result.construction_time,
        "critical_points_count" => result.critical_points_count,
        "minimizers_count" => result.minimizers_count,
        "min_distance_to_global" => result.min_distance_to_global,
        "mean_distance_to_global" => result.mean_distance_to_global,
        "convergence_rate" => result.convergence_rate,
        "memory_usage_mb" => result.memory_usage_mb,
        "cpu_time_seconds" => result.cpu_time_seconds,
        "wall_time_seconds" => result.wall_time_seconds,
        "slurm_job_id" => result.slurm_job_id,
        "compute_node" => result.compute_node,
        "exit_code" => result.exit_code
    )
    
    open(joinpath(job_dir, "results.json"), "w") do io
        JSON3.pretty(io, results_dict)
    end
    
    # Save critical points and minimizers as CSV
    CSV.write(joinpath(job_dir, "critical_points.csv"), result.critical_points)
    CSV.write(joinpath(job_dir, "minimizers.csv"), result.minimizers)
    
    # Save distance analysis
    distances_df = DataFrame(
        minimizer_index = 1:length(result.distances_to_global),
        distance_to_global = result.distances_to_global
    )
    CSV.write(joinpath(job_dir, "distances.csv"), distances_df)
end

"""
    load_job_results(job_id::String, experiment_name::String="")

Load results for a specific job.
"""
function load_job_results(job_id::String, experiment_name::String="")
    results_path = get_job_results_path(job_id, experiment_name)
    if !isfile(results_path)
        error("Results file not found for job $job_id")
    end
    
    return JSON3.read(read(results_path, String))
end

"""
    aggregate_experiment_results(tracker::ExperimentTracker)

Aggregate all results from an experiment into summary statistics.
"""
function aggregate_experiment_results(tracker::ExperimentTracker)
    if isempty(tracker.results)
        return DataFrame()
    end
    
    # Create comprehensive results DataFrame
    rows = []
    for (job_id, result) in tracker.results
        job = tracker.jobs[job_id]
        
        push!(rows, (
            job_id = job_id,
            experiment_name = job.experiment_name,
            function_name = job.benchmark_func.name,
            degree = job.globtim_params.degree,
            sample_count = job.globtim_params.sample_count,
            sparsification_threshold = job.globtim_params.sparsification_threshold,
            l2_error = result.l2_error,
            construction_time = result.construction_time,
            critical_points_count = result.critical_points_count,
            minimizers_count = result.minimizers_count,
            min_distance_to_global = result.min_distance_to_global,
            mean_distance_to_global = result.mean_distance_to_global,
            convergence_rate = result.convergence_rate,
            memory_usage_mb = result.memory_usage_mb,
            cpu_time_seconds = result.cpu_time_seconds,
            wall_time_seconds = result.wall_time_seconds,
            compute_node = result.compute_node
        ))
    end
    
    return DataFrame(rows)
end

"""
    update_experiment_summary(tracker::ExperimentTracker)

Update the experiment summary file with current results.
"""
function update_experiment_summary(tracker::ExperimentTracker)
    exp_dir = get_experiment_dir(tracker.experiment_name)
    
    # Aggregate results
    results_df = aggregate_experiment_results(tracker)
    
    # Save aggregated results
    if !isempty(results_df)
        CSV.write(joinpath(exp_dir, "aggregated", "all_results.csv"), results_df)
    end
    
    # Create experiment summary
    summary = Dict(
        "experiment_name" => tracker.experiment_name,
        "start_time" => string(tracker.start_time),
        "last_updated" => string(now()),
        "total_jobs" => length(tracker.jobs),
        "completed_jobs" => count(status -> status == :completed, values(tracker.job_status)),
        "failed_jobs" => count(status -> status == :failed, values(tracker.job_status)),
        "pending_jobs" => count(status -> status == :pending, values(tracker.job_status)),
        "running_jobs" => count(status -> status == :running, values(tracker.job_status))
    )
    
    open(joinpath(exp_dir, "experiment_summary.json"), "w") do io
        JSON3.pretty(io, summary)
    end
end
