"""
HPC Benchmark Configuration System

Comprehensive parameter specification and tracking infrastructure for running
Globtim benchmarks on HPC clusters with full traceability and statistics collection.

Based on Examples/4d_benchmark_tests/benchmark_4d_framework.jl but designed for
systematic HPC deployment with parameter sweeps and result aggregation.
"""

using Dates
using UUIDs
using Parameters  # For @with_kw macro and @unpack functionality
# using TOML  # Will be available on HPC cluster
# using DataFrames  # Will be available on HPC cluster
using LinearAlgebra

# ============================================================================
# CORE CONFIGURATION STRUCTURES
# ============================================================================

"""
    BenchmarkFunction

Specification for a benchmark function with known properties.
Uses Parameters.jl for enhanced functionality.
"""
@with_kw struct BenchmarkFunction
    name::Symbol
    func::Function
    domain::Vector{Float64}  # [min, max] for each dimension
    global_minima::Vector{Vector{Float64}}  # Can have multiple global minima
    f_min::Float64
    description::String = ""

    # Custom constructor to ensure global_minima is properly formatted
    function BenchmarkFunction(name, func, domain, global_minima, f_min, description="")
        # Ensure global_minima is a vector of vectors
        if global_minima isa Vector{Float64}
            global_minima = [global_minima]
        end
        new(name, func, domain, global_minima, f_min, description)
    end
end

"""
    GlobtimParameters

Parameters for the Globtim algorithm.
"""
struct GlobtimParameters
    degree::Int
    sample_count::Int
    center::Vector{Float64}
    sample_range::Float64
    basis::Symbol  # :chebyshev, :monomial, etc.
    precision::Type  # RationalPrecision, Float64, etc.
    enable_hessian::Bool
    sparsification_threshold::Float64
    max_retries::Int
    
    function GlobtimParameters(;
        degree::Int,
        sample_count::Int,
        center::Vector{Float64},
        sample_range::Float64 = 1.0,
        basis::Symbol = :chebyshev,
        precision::Type = Float64,
        enable_hessian::Bool = true,
        sparsification_threshold::Float64 = 1e-4,
        max_retries::Int = 3
    )
        new(degree, sample_count, center, sample_range, basis, precision, 
            enable_hessian, sparsification_threshold, max_retries)
    end
end

"""
    BenchmarkJob

Complete specification for a single benchmark job.
"""
struct BenchmarkJob
    job_id::String
    timestamp::DateTime
    
    # Function and algorithm parameters
    benchmark_func::BenchmarkFunction
    globtim_params::GlobtimParameters
    
    # HPC parameters
    partition::String
    cpus::Int
    memory_gb::Int
    time_limit::String
    
    # Metadata for tracking
    experiment_name::String
    parameter_set_id::String
    tags::Vector{String}
    
    function BenchmarkJob(benchmark_func, globtim_params; 
                         partition="batch", cpus=24, memory_gb=32, time_limit="02:00:00",
                         experiment_name="default", parameter_set_id="", tags=String[])
        job_id = string(uuid4())[1:8]  # Short UUID for job identification
        timestamp = now()
        if isempty(parameter_set_id)
            parameter_set_id = "$(benchmark_func.name)_deg$(globtim_params.degree)_n$(globtim_params.sample_count)"
        end
        
        new(job_id, timestamp, benchmark_func, globtim_params, 
            partition, cpus, memory_gb, time_limit,
            experiment_name, parameter_set_id, tags)
    end
end

# ============================================================================
# BENCHMARK FUNCTION REGISTRY
# ============================================================================

"""
Registry of 4D benchmark functions with known properties.
"""
const BENCHMARK_4D_REGISTRY = Dict{Symbol, BenchmarkFunction}(
    :Sphere => BenchmarkFunction(
        :Sphere, x -> sum(x.^2), [-5.12, 5.12], [zeros(4)], 0.0,
        "Simple quadratic bowl - unimodal, easy convergence"
    ),
    
    :Rosenbrock => BenchmarkFunction(
        :Rosenbrock, x -> sum(100 * (x[2:end] - x[1:end-1].^2).^2 + (1 .- x[1:end-1]).^2), 
        [-2.048, 2.048], [ones(4)], 0.0,
        "Classic optimization test - narrow curved valley"
    ),
    
    :Zakharov => BenchmarkFunction(
        :Zakharov, x -> sum(x.^2) + (sum(0.5 * (1:length(x)) .* x))^2 + (sum(0.5 * (1:length(x)) .* x))^4,
        [-5.0, 5.0], [zeros(4)], 0.0,
        "Unimodal with increasing difficulty"
    ),
    
    :Griewank => BenchmarkFunction(
        :Griewank, x -> 1 + sum(x.^2)/4000 - prod(cos.(x ./ sqrt.(1:length(x)))),
        [-600.0, 600.0], [zeros(4)], 0.0,
        "Multimodal with many local minima"
    ),
    
    :Rastringin => BenchmarkFunction(
        :Rastringin, x -> 10*length(x) + sum(x.^2 - 10*cos.(2π*x)),
        [-5.12, 5.12], [zeros(4)], 0.0,
        "Highly multimodal - many local minima"
    )
)

# ============================================================================
# PARAMETER SWEEP GENERATION
# ============================================================================

"""
    generate_parameter_sweep(experiment_name::String, config::NamedTuple)

Generate a comprehensive parameter sweep for systematic benchmarking.
"""
function generate_parameter_sweep(experiment_name::String, config::NamedTuple)
    jobs = BenchmarkJob[]
    
    for func_name in config.functions
        if !haskey(BENCHMARK_4D_REGISTRY, func_name)
            @warn "Function $func_name not found in registry, skipping"
            continue
        end
        
        benchmark_func = BENCHMARK_4D_REGISTRY[func_name]
        
        for degree in config.degrees
            for sample_count in config.sample_counts
                for threshold in config.sparsification_thresholds
                    # Create Globtim parameters
                    globtim_params = GlobtimParameters(
                        degree = degree,
                        sample_count = sample_count,
                        center = zeros(4),  # 4D center at origin
                        sample_range = (benchmark_func.domain[2] - benchmark_func.domain[1]) / 4,
                        sparsification_threshold = threshold
                    )
                    
                    # Create job with appropriate HPC resources
                    hpc_params = get_hpc_parameters(degree, sample_count)
                    
                    job = BenchmarkJob(
                        benchmark_func, globtim_params;
                        partition = hpc_params.partition,
                        cpus = hpc_params.cpus,
                        memory_gb = hpc_params.memory_gb,
                        time_limit = hpc_params.time_limit,
                        experiment_name = experiment_name,
                        tags = ["sweep", "4d", string(func_name)]
                    )
                    
                    push!(jobs, job)
                end
            end
        end
    end
    
    return jobs
end

"""
    get_hpc_parameters(degree::Int, sample_count::Int)

Determine appropriate HPC resources based on problem size.
"""
function get_hpc_parameters(degree::Int, sample_count::Int)
    # Estimate computational complexity
    complexity_score = degree^4 * sample_count
    
    if complexity_score < 1e6
        return (partition="batch", cpus=4, memory_gb=8, time_limit="00:30:00")
    elseif complexity_score < 1e7
        return (partition="batch", cpus=12, memory_gb=24, time_limit="01:00:00")
    elseif complexity_score < 1e8
        return (partition="batch", cpus=24, memory_gb=48, time_limit="02:00:00")
    else
        return (partition="long", cpus=24, memory_gb=64, time_limit="04:00:00")
    end
end

# ============================================================================
# CONFIGURATION PRESETS
# ============================================================================

"""
Predefined configuration presets for different testing scenarios.
"""
const QUICK_TEST_CONFIG = (
    functions = [:Sphere, :Rosenbrock],
    degrees = [2, 4],
    sample_counts = [50, 100],
    sparsification_thresholds = [1e-3, 1e-4]
)

const STANDARD_4D_CONFIG = (
    functions = [:Sphere, :Rosenbrock, :Zakharov, :Griewank],
    degrees = [4, 6, 8],
    sample_counts = [100, 200, 500],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5]
)

const INTENSIVE_4D_CONFIG = (
    functions = collect(keys(BENCHMARK_4D_REGISTRY)),
    degrees = [6, 8, 10, 12],
    sample_counts = [200, 500, 1000],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5, 1e-6]
)

# ============================================================================
# SERIALIZATION AND PERSISTENCE
# ============================================================================

"""
    save_job_config(job::BenchmarkJob, filepath::String)

Save job configuration to TOML file for persistence and reproducibility.
"""
function save_job_config(job::BenchmarkJob, filepath::String)
    config_dict = Dict(
        "job_id" => job.job_id,
        "timestamp" => string(job.timestamp),
        "experiment_name" => job.experiment_name,
        "parameter_set_id" => job.parameter_set_id,
        "tags" => job.tags,
        
        "benchmark_function" => Dict(
            "name" => string(job.benchmark_func.name),
            "domain" => job.benchmark_func.domain,
            "f_min" => job.benchmark_func.f_min,
            "description" => job.benchmark_func.description
        ),
        
        "globtim_parameters" => Dict(
            "degree" => job.globtim_params.degree,
            "sample_count" => job.globtim_params.sample_count,
            "center" => job.globtim_params.center,
            "sample_range" => job.globtim_params.sample_range,
            "basis" => string(job.globtim_params.basis),
            "precision" => string(job.globtim_params.precision),
            "enable_hessian" => job.globtim_params.enable_hessian,
            "sparsification_threshold" => job.globtim_params.sparsification_threshold,
            "max_retries" => job.globtim_params.max_retries
        ),
        
        "hpc_parameters" => Dict(
            "partition" => job.partition,
            "cpus" => job.cpus,
            "memory_gb" => job.memory_gb,
            "time_limit" => job.time_limit
        )
    )
    
    open(filepath, "w") do io
        TOML.print(io, config_dict)
    end
end

"""
    compute_min_distances_to_global(points::Matrix{Float64}, global_minima::Vector{Vector{Float64}})

Compute minimum distance from each point to the nearest global minimum.
Inspired by compute_min_distances from Triple_Graph_deuf_4d.ipynb.
"""
function compute_min_distances_to_global(points::Matrix{Float64}, global_minima::Vector{Vector{Float64}})
    n_points = size(points, 1)
    min_distances = Vector{Float64}(undef, n_points)
    
    for i in 1:n_points
        point = points[i, :]
        distances_to_minima = [norm(point - gmin) for gmin in global_minima]
        min_distances[i] = minimum(distances_to_minima)
    end
    
    return min_distances
end
