"""
HPC Benchmark Configuration System - Parameters.jl Version

Enhanced parameter specification using Parameters.jl for better ergonomics,
type safety, and default value management. This version provides @with_kw
macros for clean struct definitions and @unpack for convenient parameter access.

Based on Julia best practices research for HPC cluster computing.
"""

using Dates
using UUIDs
using Parameters  # For @with_kw macro and @unpack functionality
using LinearAlgebra

# ============================================================================
# CORE CONFIGURATION STRUCTURES WITH PARAMETERS.JL
# ============================================================================

"""
    BenchmarkFunction

Specification for a benchmark function with known properties.
Enhanced with Parameters.jl for better default handling.
"""
@with_kw struct BenchmarkFunction
    name::Symbol
    func::Function
    domain::Vector{Float64}  # [min, max] for each dimension
    global_minima::Vector{Vector{Float64}}  # Can have multiple global minima
    f_min::Float64
    description::String = ""
end

# Helper constructor for BenchmarkFunction
function BenchmarkFunction(name::Symbol, func::Function, domain::Vector{Float64}, 
                          global_minima, f_min::Float64, description::String="")
    # Ensure global_minima is a vector of vectors
    if global_minima isa Vector{Float64}
        global_minima = [global_minima]
    end
    return BenchmarkFunction(
        name=name, func=func, domain=domain, 
        global_minima=global_minima, f_min=f_min, description=description
    )
end

"""
    GlobtimParameters

Parameters for the Globtim algorithm with sensible defaults.
Uses @with_kw for clean default value specification.
"""
@with_kw struct GlobtimParameters
    degree::Int = 4
    sample_count::Int = 100
    center::Vector{Float64} = zeros(4)
    sample_range::Float64 = 1.0
    basis::Symbol = :chebyshev
    precision::Type = Float64
    enable_hessian::Bool = true
    sparsification_threshold::Float64 = 1e-4
    max_retries::Int = 3
end

"""
    HPCParameters

HPC cluster resource specification with defaults optimized for typical jobs.
"""
@with_kw struct HPCParameters
    partition::String = "batch"
    cpus::Int = 24
    memory_gb::Int = 32
    time_limit::String = "02:00:00"
    julia_threads::Int = cpus
end

"""
    BenchmarkJob

Complete specification for a single benchmark job.
Enhanced with Parameters.jl for better ergonomics.
"""
@with_kw struct BenchmarkJob
    # Identifiers (auto-generated if not provided)
    job_id::String = string(uuid4())[1:8]
    timestamp::DateTime = now()
    
    # Core parameters (required)
    benchmark_func::BenchmarkFunction
    globtim_params::GlobtimParameters
    
    # HPC parameters (with defaults)
    hpc_params::HPCParameters = HPCParameters()
    
    # Metadata for tracking
    experiment_name::String = "default"
    parameter_set_id::String = "$(benchmark_func.name)_deg$(globtim_params.degree)_n$(globtim_params.sample_count)"
    tags::Vector{String} = String[]
end

"""
    ExperimentConfig

Top-level configuration for an entire experiment.
"""
@with_kw struct ExperimentConfig
    name::String
    description::String = ""
    output_dir::String = "results/experiments/$name"
    created_at::DateTime = now()
    
    # Parameter sweep specifications
    functions::Vector{Symbol} = [:Sphere, :Rosenbrock]
    degrees::Vector{Int} = [4, 6, 8]
    sample_counts::Vector{Int} = [100, 200, 500]
    sparsification_thresholds::Vector{Float64} = [1e-3, 1e-4, 1e-5]
    
    # Default HPC settings
    default_hpc::HPCParameters = HPCParameters()
end

# ============================================================================
# BENCHMARK FUNCTION REGISTRY (UPDATED)
# ============================================================================

"""
Registry of 4D benchmark functions with known properties.
Updated to use new BenchmarkFunction constructor.
"""
const BENCHMARK_4D_REGISTRY = Dict{Symbol, BenchmarkFunction}(
    :Sphere => BenchmarkFunction(
        :Sphere, 
        x -> sum(x.^2), 
        [-5.12, 5.12], 
        [zeros(4)], 
        0.0,
        "Simple quadratic bowl - unimodal, easy convergence"
    ),
    
    :Rosenbrock => BenchmarkFunction(
        :Rosenbrock, 
        x -> sum(100 * (x[2:end] - x[1:end-1].^2).^2 + (1 .- x[1:end-1]).^2), 
        [-2.048, 2.048], 
        [ones(4)], 
        0.0,
        "Classic optimization test - narrow curved valley"
    ),
    
    :Zakharov => BenchmarkFunction(
        :Zakharov, 
        x -> sum(x.^2) + (sum(0.5 * (1:length(x)) .* x))^2 + (sum(0.5 * (1:length(x)) .* x))^4,
        [-5.0, 5.0], 
        [zeros(4)], 
        0.0,
        "Unimodal with increasing difficulty"
    ),
    
    :Griewank => BenchmarkFunction(
        :Griewank, 
        x -> 1 + sum(x.^2)/4000 - prod(cos.(x ./ sqrt.(1:length(x)))),
        [-600.0, 600.0], 
        [zeros(4)], 
        0.0,
        "Multimodal with many local minima"
    ),
    
    :Rastringin => BenchmarkFunction(
        :Rastringin, 
        x -> 10*length(x) + sum(x.^2 - 10*cos.(2π*x)),
        [-5.12, 5.12], 
        [zeros(4)], 
        0.0,
        "Highly multimodal - many local minima"
    )
)

# ============================================================================
# ENHANCED PARAMETER SWEEP GENERATION
# ============================================================================

"""
    generate_parameter_sweep(config::ExperimentConfig)

Generate a comprehensive parameter sweep using Parameters.jl structs.
Enhanced with @unpack for clean parameter access.
"""
function generate_parameter_sweep(config::ExperimentConfig)
    @unpack functions, degrees, sample_counts, sparsification_thresholds = config
    @unpack default_hpc, name = config
    
    jobs = BenchmarkJob[]
    
    for func_name in functions
        if !haskey(BENCHMARK_4D_REGISTRY, func_name)
            @warn "Function $func_name not found in registry, skipping"
            continue
        end
        
        benchmark_func = BENCHMARK_4D_REGISTRY[func_name]
        
        for degree in degrees
            for sample_count in sample_counts
                for threshold in sparsification_thresholds
                    # Create Globtim parameters with @with_kw defaults
                    globtim_params = GlobtimParameters(
                        degree = degree,
                        sample_count = sample_count,
                        center = zeros(4),  # 4D center at origin
                        sample_range = (benchmark_func.domain[2] - benchmark_func.domain[1]) / 4,
                        sparsification_threshold = threshold
                    )
                    
                    # Determine HPC resources based on problem complexity
                    hpc_params = get_optimal_hpc_parameters(degree, sample_count, default_hpc)
                    
                    # Create job with automatic ID generation
                    job = BenchmarkJob(
                        benchmark_func = benchmark_func,
                        globtim_params = globtim_params,
                        hpc_params = hpc_params,
                        experiment_name = name,
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
    get_optimal_hpc_parameters(degree::Int, sample_count::Int, defaults::HPCParameters)

Determine optimal HPC resources based on problem complexity.
Uses @unpack for clean parameter access.
"""
function get_optimal_hpc_parameters(degree::Int, sample_count::Int, defaults::HPCParameters)
    @unpack partition, memory_gb = defaults
    
    # Estimate computational complexity
    complexity_score = degree^4 * sample_count
    
    if complexity_score < 1e6
        return HPCParameters(partition="batch", cpus=4, memory_gb=8, time_limit="00:30:00")
    elseif complexity_score < 1e7
        return HPCParameters(partition="batch", cpus=12, memory_gb=24, time_limit="01:00:00")
    elseif complexity_score < 1e8
        return HPCParameters(partition="batch", cpus=24, memory_gb=48, time_limit="02:00:00")
    else
        return HPCParameters(partition="long", cpus=24, memory_gb=64, time_limit="04:00:00")
    end
end

# ============================================================================
# CONFIGURATION PRESETS (ENHANCED)
# ============================================================================

"""
Predefined experiment configurations using Parameters.jl structs.
"""
const QUICK_TEST_EXPERIMENT = ExperimentConfig(
    name = "quick_test",
    description = "Quick validation test with minimal parameters",
    functions = [:Sphere, :Rosenbrock],
    degrees = [2, 4],
    sample_counts = [50, 100],
    sparsification_thresholds = [1e-3, 1e-4]
)

const STANDARD_4D_EXPERIMENT = ExperimentConfig(
    name = "standard_4d",
    description = "Standard 4D benchmark suite",
    functions = [:Sphere, :Rosenbrock, :Zakharov, :Griewank],
    degrees = [4, 6, 8],
    sample_counts = [100, 200, 500],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5]
)

const INTENSIVE_4D_EXPERIMENT = ExperimentConfig(
    name = "intensive_4d",
    description = "Comprehensive 4D benchmark with all functions",
    functions = collect(keys(BENCHMARK_4D_REGISTRY)),
    degrees = [6, 8, 10, 12],
    sample_counts = [200, 500, 1000],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5, 1e-6]
)

# ============================================================================
# PARAMETER VALIDATION
# ============================================================================

"""
    validate_parameters(params::GlobtimParameters)

Validate Globtim parameters using @unpack for clean access.
"""
function validate_parameters(params::GlobtimParameters)
    @unpack degree, sample_count, sparsification_threshold, center = params
    
    @assert degree > 0 "Degree must be positive"
    @assert sample_count > 0 "Sample count must be positive"
    @assert sparsification_threshold > 0 "Threshold must be positive"
    @assert length(center) > 0 "Center must be non-empty"
    
    return true
end

"""
    validate_hpc_parameters(params::HPCParameters)

Validate HPC parameters.
"""
function validate_hpc_parameters(params::HPCParameters)
    @unpack cpus, memory_gb, julia_threads = params
    
    @assert cpus > 0 "CPU count must be positive"
    @assert memory_gb > 0 "Memory must be positive"
    @assert julia_threads > 0 "Julia threads must be positive"
    @assert julia_threads <= cpus "Julia threads cannot exceed CPU count"
    
    return true
end

# ============================================================================
# DISTANCE COMPUTATION (UNCHANGED)
# ============================================================================

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
