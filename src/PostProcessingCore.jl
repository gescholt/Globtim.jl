"""
PostProcessingCore.jl

Lightweight post-processing for GlobTim standardized example outputs.
Uses only Julia standard library - no external dependencies.

Focuses on computational outputs from actual standardized architecture:
- JSON result files with L2_norm, condition_number, degree, etc.
- CSV function evaluation files
- Critical point analysis

Author: GlobTim Team
Date: September 2025
"""

# Only use Julia standard library
using JSON
using Printf
using Statistics
using LinearAlgebra

"""
    ExperimentData

Lightweight container for standardized experiment outputs.
"""
struct ExperimentData
    # Core metrics from JSON output
    l2_norm::Union{Float64,Nothing}
    condition_number::Union{Float64,Nothing}
    degree::Union{Int,Nothing}
    dimension::Union{Int,Nothing}
    
    # Sampling information
    total_samples::Union{Int,Nothing}
    samples_per_dim::Union{Float64,Nothing}
    sample_range::Union{Float64,Nothing}
    
    # Parameter information
    center::Union{Vector{Float64},Nothing}
    
    # Function evaluation data (if CSV available)
    eval_points::Union{Matrix{Float64},Nothing}
    eval_values::Union{Vector{Float64},Nothing}
    
    # Critical points (if available)
    critical_points::Union{Vector{Vector{Float64}},Nothing}
    critical_values::Union{Vector{Float64},Nothing}
    
    # Source file for traceability
    source_file::String
end

"""
    load_experiment_data(file_path::String) -> ExperimentData

Load experiment data from JSON file or directory containing results.
Only uses standard library - no external CSV parsing dependencies.
"""
function load_experiment_data(file_path::String)
    if isfile(file_path) && endswith(file_path, ".json")
        return load_from_json(file_path)
    elseif isdir(file_path)
        return load_from_directory(file_path)
    else
        error("Unsupported file path: $file_path")
    end
end

function load_from_json(json_file::String)
    data = JSON.parsefile(json_file)
    
    return ExperimentData(
        get(data, "L2_norm", nothing),
        get(data, "condition_number", nothing),
        get(data, "degree", nothing),
        get(data, "dimension", nothing),
        get(data, "total_samples", nothing),
        get(data, "samples_per_dim", nothing),
        get(data, "sample_range", nothing),
        haskey(data, "center") ? Vector{Float64}(data["center"]) : nothing,
        nothing, # eval_points - would need CSV parsing
        nothing, # eval_values
        nothing, # critical_points
        nothing, # critical_values
        json_file
    )
end

function load_from_directory(dir_path::String)
    # Look for JSON files in directory
    json_files = filter(f -> endswith(f, ".json"), readdir(dir_path))
    
    if isempty(json_files)
        error("No JSON files found in directory: $dir_path")
    end
    
    # Use first JSON file found (could be enhanced to merge multiple)
    json_file = joinpath(dir_path, json_files[1])
    return load_from_json(json_file)
end

"""
    compute_quality_metrics(data::ExperimentData) -> Dict{String,Any}

Compute quality assessment metrics based on L2 norm and other indicators.
Enhanced to track percentage improvements when available.
"""
function compute_quality_metrics(data::ExperimentData)
    metrics = Dict{String,Any}()
    
    if data.l2_norm !== nothing
        l2 = data.l2_norm
        metrics["l2_norm"] = l2
        metrics["log10_l2_norm"] = log10(l2)
        
        # Quality classification (can be enhanced for % improvement tracking)
        if l2 < 1e-10
            metrics["quality_class"] = "excellent"
            metrics["quality_score"] = 4
        elseif l2 < 1e-6
            metrics["quality_class"] = "good"
            metrics["quality_score"] = 3
        elseif l2 < 1e-3
            metrics["quality_class"] = "acceptable"
            metrics["quality_score"] = 2
        else
            metrics["quality_class"] = "poor"
            metrics["quality_score"] = 1
        end
    end
    
    # Stability assessment
    if data.condition_number !== nothing
        cond = data.condition_number
        metrics["condition_number"] = cond
        metrics["log10_condition"] = log10(cond)
        
        if cond < 1e8
            metrics["stability_class"] = "good"
            metrics["stability_score"] = 3
        elseif cond < 1e12
            metrics["stability_class"] = "moderate"
            metrics["stability_score"] = 2
        else
            metrics["stability_class"] = "poor"
            metrics["stability_score"] = 1
        end
    end
    
    return metrics
end

"""
    compute_sampling_efficiency(data::ExperimentData) -> Dict{String,Any}

Analyze sampling efficiency based on theoretical requirements.
"""
function compute_sampling_efficiency(data::ExperimentData)
    metrics = Dict{String,Any}()
    
    if data.dimension !== nothing && data.degree !== nothing
        dim = data.dimension
        deg = data.degree
        
        # Theoretical number of monomials
        theoretical_monomials = binomial(dim + deg, deg)
        metrics["theoretical_monomials"] = theoretical_monomials
        
        if data.total_samples !== nothing
            samples = data.total_samples
            sample_ratio = samples / theoretical_monomials
            metrics["sample_monomial_ratio"] = sample_ratio
            
            # Sampling assessment
            if sample_ratio >= 2.0
                metrics["sampling_class"] = "well_conditioned"
                metrics["sampling_score"] = 3
            elseif sample_ratio >= 1.0
                metrics["sampling_class"] = "marginal"
                metrics["sampling_score"] = 2
            else
                metrics["sampling_class"] = "underdetermined"
                metrics["sampling_score"] = 1
            end
        end
        
        # Samples per dimension
        if data.total_samples !== nothing
            metrics["samples_per_dimension"] = data.total_samples / dim
        end
    end
    
    return metrics
end

"""
    compute_critical_point_distances(critical_points::Vector{Vector{Float64}}, 
                                   true_solution::Vector{Float64}) -> Vector{Float64}

Compute distances from critical points to true solution.
Uses only standard library linear algebra.
"""
function compute_critical_point_distances(critical_points::Vector{Vector{Float64}}, 
                                         true_solution::Vector{Float64})
    return [norm(cp - true_solution) for cp in critical_points]
end

"""
    compute_critical_point_distances(critical_points::Vector{Vector{Float64}}) -> Dict{String,Float64}

Compute inter-critical-point distances and statistics.
"""
function compute_critical_point_distances(critical_points::Vector{Vector{Float64}})
    if length(critical_points) < 2
        return Dict("min_distance" => NaN, "max_distance" => NaN, "mean_distance" => NaN)
    end
    
    distances = Float64[]
    n = length(critical_points)
    
    for i in 1:n-1
        for j in i+1:n
            push!(distances, norm(critical_points[i] - critical_points[j]))
        end
    end
    
    return Dict(
        "min_distance" => minimum(distances),
        "max_distance" => maximum(distances),
        "mean_distance" => mean(distances),
        "std_distance" => std(distances)
    )
end

"""
    analyze_degree_progression(experiments::Vector{ExperimentData}) -> Dict{String,Any}

Analyze L2 norm improvement across different degrees.
Enhanced version that tracks percentage decrease.
"""
function analyze_degree_progression(experiments::Vector{ExperimentData})
    # Filter experiments with valid L2 norm and degree data
    valid_exps = filter(exp -> exp.l2_norm !== nothing && exp.degree !== nothing, experiments)
    
    if length(valid_exps) < 2
        return Dict("error" => "Need at least 2 experiments with degree and L2 norm data")
    end
    
    # Sort by degree
    sort!(valid_exps, by=exp -> exp.degree)
    
    degrees = [exp.degree for exp in valid_exps]
    l2_norms = [exp.l2_norm for exp in valid_exps]
    
    # Compute percentage improvements
    improvements = Float64[]
    for i in 2:length(l2_norms)
        prev_norm = l2_norms[i-1]
        curr_norm = l2_norms[i]
        improvement = (prev_norm - curr_norm) / prev_norm * 100.0
        push!(improvements, improvement)
    end
    
    return Dict(
        "degrees" => degrees,
        "l2_norms" => l2_norms,
        "improvements_percent" => improvements,
        "total_improvement" => length(improvements) > 0 ? (l2_norms[1] - l2_norms[end]) / l2_norms[1] * 100.0 : 0.0,
        "mean_improvement" => length(improvements) > 0 ? mean(improvements) : 0.0,
        "best_improvement" => length(improvements) > 0 ? maximum(improvements) : 0.0
    )
end

"""
    create_computational_summary(data::ExperimentData) -> String

Create computational summary focusing on numerical results.
Minimal text, maximum numerical content.
"""
function create_computational_summary(data::ExperimentData)
    io = IOBuffer()
    
    println(io, "# Computational Results Summary")
    println(io, "Source: $(basename(data.source_file))")
    println(io)
    
    # Core metrics
    if data.dimension !== nothing && data.degree !== nothing
        println(io, "Dimension: $(data.dimension)")
        println(io, "Degree: $(data.degree)")
    end
    
    if data.l2_norm !== nothing
        println(io, "L2_norm: $(@sprintf("%.6e", data.l2_norm))")
        println(io, "log10(L2_norm): $(@sprintf("%.2f", log10(data.l2_norm)))")
    end
    
    if data.condition_number !== nothing
        println(io, "Condition_number: $(@sprintf("%.6e", data.condition_number))")
        println(io, "log10(Condition): $(@sprintf("%.2f", log10(data.condition_number)))")
    end
    
    # Quality assessment
    quality_metrics = compute_quality_metrics(data)
    if haskey(quality_metrics, "quality_class")
        println(io, "Quality: $(quality_metrics["quality_class"])")
    end
    
    # Sampling efficiency
    sampling_metrics = compute_sampling_efficiency(data)
    if haskey(sampling_metrics, "theoretical_monomials")
        println(io, "Theoretical_monomials: $(sampling_metrics["theoretical_monomials"])")
        if haskey(sampling_metrics, "sample_monomial_ratio")
            println(io, "Sample_ratio: $(@sprintf("%.3f", sampling_metrics["sample_monomial_ratio"]))")
            println(io, "Sampling: $(sampling_metrics["sampling_class"])")
        end
    end
    
    # Parameter information
    if data.center !== nothing
        center_str = join([@sprintf("%.3f", x) for x in data.center], ", ")
        println(io, "Center: [$center_str]")
    end
    
    if data.sample_range !== nothing
        println(io, "Sample_range: $(data.sample_range)")
    end
    
    return String(take!(io))
end

# Export main functions
export ExperimentData, load_experiment_data, compute_quality_metrics, 
       compute_sampling_efficiency, compute_critical_point_distances,
       analyze_degree_progression, create_computational_summary