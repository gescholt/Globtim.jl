"""
EnhancedMetrics Module

Implements comprehensive statistics collection for GlobTim experiments (Issue #128).
Provides reproducibility metadata, mathematical quality metrics, convergence analysis,
resource utilization tracking, and baseline comparison capabilities.

This module integrates with the experiment runner to automatically collect metrics
during experiment execution.
"""
module EnhancedMetrics

using Dates
using Statistics
using LinearAlgebra

# Export main structs and functions
export ReproducibilityMetadata, MathematicalQualityMetrics, ConvergenceMetrics
export ResourceUtilization, ComparisonMetrics, EnhancedExperimentMetrics
export collect_enhanced_metrics, metrics_to_dict
export get_git_commit_hash, get_git_branch, hash_manifest_file
export compute_sparsity, analyze_coefficients, compute_basis_usage
export estimate_convergence_rate, classify_convergence, detect_stagnation
export estimate_optimal_degree, compute_degree_improvements

# ============================================================================
# Core Data Structures
# ============================================================================

"""
    ReproducibilityMetadata

Captures all information needed to reproduce an experiment exactly.

# Fields
- `git_commit::String`: Git commit hash (SHA-1)
- `git_branch::String`: Git branch name
- `julia_version::VersionNumber`: Julia version used
- `package_manifest_hash::String`: SHA256 hash of Manifest.toml
- `hostname::String`: Machine hostname
- `cluster_node::Union{String, Nothing}`: HPC cluster node identifier (if applicable)
- `execution_timestamp::DateTime`: When experiment was executed
- `experiment_id::String`: Unique experiment identifier
"""
struct ReproducibilityMetadata
    git_commit::String
    git_branch::String
    julia_version::VersionNumber
    package_manifest_hash::String
    hostname::String
    cluster_node::Union{String, Nothing}
    execution_timestamp::DateTime
    experiment_id::String
end

"""
    MathematicalQualityMetrics

Metrics assessing the mathematical quality of polynomial approximations.

# Fields
- `polynomial_sparsity::Float64`: Percentage of coefficients below threshold
- `coefficient_stats::Dict{String, Float64}`: Min, max, mean, std of coefficient magnitudes
- `basis_utilization::Union{Vector{Float64}, Nothing}`: Per-dimension basis usage (for multi-d)
- `gradient_magnitude_stats::Union{Dict{String, Float64}, Nothing}`: Gradient statistics at critical points
- `domain_coverage_score::Union{Float64, Nothing}`: Assessment of sample coverage (future)
"""
struct MathematicalQualityMetrics
    polynomial_sparsity::Float64
    coefficient_stats::Dict{String, Float64}
    basis_utilization::Union{Vector{Float64}, Nothing}
    gradient_magnitude_stats::Union{Dict{String, Float64}, Nothing}
    domain_coverage_score::Union{Float64, Nothing}
end

"""
    ConvergenceMetrics

Analysis of convergence behavior across polynomial degrees.

# Fields
- `convergence_rate::Union{Float64, Nothing}`: Estimated convergence rate
- `rate_type::Union{String, Nothing}`: "exponential", "polynomial", "stagnated", or "unknown"
- `optimal_degree_estimate::Union{Int, Nothing}`: Estimated optimal polynomial degree
- `degree_improvements::Union{Vector{Float64}, Nothing}`: Relative improvement at each degree
- `stagnation_detected::Bool`: Whether convergence has stagnated
"""
struct ConvergenceMetrics
    convergence_rate::Union{Float64, Nothing}
    rate_type::Union{String, Nothing}
    optimal_degree_estimate::Union{Int, Nothing}
    degree_improvements::Union{Vector{Float64}, Nothing}
    stagnation_detected::Bool
end

"""
    ResourceUtilization

Computational resource usage metrics.

# Fields
- `cpu_utilization_percent::Union{Float64, Nothing}`: CPU utilization (future - requires external tools)
- `peak_memory_gb::Float64`: Peak memory allocated (GB)
- `mean_memory_gb::Float64`: Mean memory allocated (GB)
- `execution_time_seconds::Float64`: Total execution time
- `disk_read_mb::Union{Float64, Nothing}`: Disk read volume (future)
- `disk_write_mb::Union{Float64, Nothing}`: Disk write volume (future)
- `network_transfer_mb::Union{Float64, Nothing}`: Network transfer volume (future)
"""
struct ResourceUtilization
    cpu_utilization_percent::Union{Float64, Nothing}
    peak_memory_gb::Float64
    mean_memory_gb::Float64
    execution_time_seconds::Float64
    disk_read_mb::Union{Float64, Nothing}
    disk_write_mb::Union{Float64, Nothing}
    network_transfer_mb::Union{Float64, Nothing}
end

"""
    ComparisonMetrics

Comparison against baseline or historical experiments.

# Fields
- `baseline_name::Union{String, Nothing}`: Name of baseline for comparison
- `performance_delta_percent::Union{Float64, Nothing}`: % change in execution time
- `quality_improvement_percent::Union{Float64, Nothing}`: % change in L2 norm
- `experiment_rank_in_campaign::Union{Int, Nothing}`: Rank within experiment campaign
- `percentile_rank::Union{Float64, Nothing}`: Percentile rank (0-100)
"""
struct ComparisonMetrics
    baseline_name::Union{String, Nothing}
    performance_delta_percent::Union{Float64, Nothing}
    quality_improvement_percent::Union{Float64, Nothing}
    experiment_rank_in_campaign::Union{Int, Nothing}
    percentile_rank::Union{Float64, Nothing}
end

"""
    EnhancedExperimentMetrics

Complete enhanced metrics for a GlobTim experiment.

# Fields
- `experiment_id::String`: Unique experiment identifier
- `batch_id::Union{String, Nothing}`: Batch/campaign identifier
- `gitlab_issue_id::Union{Int, Nothing}`: Associated GitLab issue ID
- `reproducibility::ReproducibilityMetadata`: Reproducibility metadata
- `mathematical_quality::MathematicalQualityMetrics`: Mathematical quality metrics
- `convergence::ConvergenceMetrics`: Convergence analysis
- `resources::ResourceUtilization`: Resource utilization
- `comparison::Union{ComparisonMetrics, Nothing}`: Comparison metrics (optional)
"""
struct EnhancedExperimentMetrics
    experiment_id::String
    batch_id::Union{String, Nothing}
    gitlab_issue_id::Union{Int, Nothing}
    reproducibility::ReproducibilityMetadata
    mathematical_quality::MathematicalQualityMetrics
    convergence::ConvergenceMetrics
    resources::ResourceUtilization
    comparison::Union{ComparisonMetrics, Nothing}
end

# ============================================================================
# Reproducibility Metadata Collection
# ============================================================================

"""
    get_git_commit_hash() -> String

Get the current git commit hash. Returns "unknown" if not in a git repository.
"""
function get_git_commit_hash()
    try
        return readchomp(`git rev-parse HEAD`)
    catch e
        @debug "Could not get git commit hash" exception=(e, catch_backtrace())
        return "unknown"
    end
end

"""
    get_git_branch() -> String

Get the current git branch name. Returns "unknown" if not in a git repository.
"""
function get_git_branch()
    try
        return readchomp(`git rev-parse --abbrev-ref HEAD`)
    catch e
        @debug "Could not get git branch" exception=(e, catch_backtrace())
        return "unknown"
    end
end

"""
    hash_manifest_file() -> String

Placeholder for dependency tracking. Returns "no_manifest" since
Manifest.toml is not shipped with the package.
"""
function hash_manifest_file()
    return "no_manifest"
end

"""
    get_cluster_node() -> Union{String, Nothing}

Get HPC cluster node identifier if running on a cluster.
Checks common environment variables (SLURM_NODEID, PBS_NODEID, etc.).
"""
function get_cluster_node()
    # Check SLURM
    if haskey(ENV, "SLURM_NODEID")
        return ENV["SLURM_NODEID"]
    elseif haskey(ENV, "SLURM_JOB_NODELIST")
        return ENV["SLURM_JOB_NODELIST"]
    end

    # Check PBS
    if haskey(ENV, "PBS_NODEID")
        return ENV["PBS_NODEID"]
    end

    # Check SGE
    if haskey(ENV, "SGE_TASK_ID")
        return ENV["SGE_TASK_ID"]
    end

    return nothing
end

"""
    generate_experiment_id(config=nothing) -> String

Generate unique experiment ID based on timestamp and random component.
"""
function generate_experiment_id(config=nothing)
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    random_suffix = bytes2hex(rand(UInt8, 4))
    return "exp_$(timestamp)_$(random_suffix)"
end

# ============================================================================
# Mathematical Quality Metrics
# ============================================================================

"""
    compute_sparsity(coeffs::Vector, threshold=1e-12) -> Float64

Compute percentage of polynomial coefficients below threshold (near-zero).
"""
function compute_sparsity(coeffs::Vector, threshold=1e-12)
    total = length(coeffs)
    if total == 0
        return 0.0
    end
    near_zero = count(abs(c) < threshold for c in coeffs)
    return 100.0 * near_zero / total
end

"""
    analyze_coefficients(coeffs::Vector) -> Dict{String, Float64}

Compute statistics of polynomial coefficient magnitudes.

Returns dictionary with keys: "min", "max", "mean", "std".
"""
function analyze_coefficients(coeffs::Vector)
    abs_coeffs = abs.(coeffs)
    return Dict(
        "min" => minimum(abs_coeffs),
        "max" => maximum(abs_coeffs),
        "mean" => mean(abs_coeffs),
        "std" => std(abs_coeffs)
    )
end

"""
    compute_basis_usage(polynomial) -> Union{Vector{Float64}, Nothing}

Compute basis function utilization per dimension (for multi-dimensional polynomials).
Returns nothing for now - future implementation.
"""
function compute_basis_usage(polynomial)
    # Future implementation: analyze which basis functions are used per dimension
    return nothing
end

"""
    analyze_gradient_magnitudes(critical_points_df) -> Union{Dict{String, Float64}, Nothing}

Analyze gradient magnitudes at critical points.
Expects DataFrame with gradient norm columns.
"""
function analyze_gradient_magnitudes(critical_points_df)
    # Check if gradient norms are available in the DataFrame
    if isempty(critical_points_df)
        return nothing
    end

    # Look for gradient norm column (various possible names)
    grad_col = nothing
    for col_name in ["gradient_norm", "grad_norm", "∇f_norm"]
        if hasproperty(critical_points_df, col_name)
            grad_col = col_name
            break
        end
    end

    if grad_col === nothing
        return nothing
    end

    grad_norms = critical_points_df[!, grad_col]

    return Dict(
        "min" => minimum(grad_norms),
        "max" => maximum(grad_norms),
        "mean" => mean(grad_norms),
        "std" => std(grad_norms)
    )
end

# ============================================================================
# Convergence Analysis
# ============================================================================

"""
    estimate_convergence_rate(l2_norms::Vector{Float64}) -> Union{Float64, Nothing}

Estimate convergence rate from L2 norms across degrees.
Returns mean of improvement ratios, or nothing if insufficient data.
"""
function estimate_convergence_rate(l2_norms::Vector{Float64})
    if length(l2_norms) < 2
        return nothing
    end

    # Compute improvement ratios (how much each degree improves over previous)
    improvements = [l2_norms[i-1] / l2_norms[i] for i in 2:length(l2_norms)]

    # Return mean improvement rate
    return mean(improvements)
end

"""
    classify_convergence(l2_norms::Vector{Float64}) -> Union{String, Nothing}

Classify convergence type: "exponential", "polynomial", "stagnated", or "unknown".
"""
function classify_convergence(l2_norms::Vector{Float64})
    if length(l2_norms) < 3
        return "unknown"
    end

    # Check for stagnation first
    if detect_stagnation(l2_norms)
        return "stagnated"
    end

    # Compute log of norms for exponential vs polynomial detection
    log_norms = log.(max.(l2_norms, 1e-16))  # Avoid log(0)
    degrees = collect(1:length(l2_norms))

    # Simple heuristic: if log(norm) is roughly linear in degree, it's exponential
    # If log(norm) is sublinear, it's polynomial
    # Fit linear regression to log(norms) vs degrees
    mean_deg = mean(degrees)
    mean_log = mean(log_norms)

    numerator = sum((degrees .- mean_deg) .* (log_norms .- mean_log))
    denominator = sum((degrees .- mean_deg).^2)

    if denominator > 0
        slope = numerator / denominator

        # Negative slope indicates improvement
        # Steep negative slope suggests exponential convergence
        if slope < -0.5
            return "exponential"
        elseif slope < 0
            return "polynomial"
        else
            return "stagnated"
        end
    end

    return "unknown"
end

"""
    detect_stagnation(l2_norms::Vector{Float64}, threshold=0.01) -> Bool

Detect if convergence has stagnated (improvements < threshold).
"""
function detect_stagnation(l2_norms::Vector{Float64}, threshold=0.01)
    if length(l2_norms) < 3
        return false
    end

    # Compute relative improvements
    improvements = [(l2_norms[i-1] - l2_norms[i]) / l2_norms[i-1] for i in 2:length(l2_norms)]

    # Check if recent improvements are below threshold
    num_recent = min(3, length(improvements))
    recent = improvements[end-num_recent+1:end]

    return all(imp < threshold for imp in recent)
end

"""
    estimate_optimal_degree(l2_norms::Vector{Float64}, degrees::Vector{Int},
                           improvement_threshold=0.05) -> Union{Int, Nothing}

Estimate optimal polynomial degree where improvements drop below threshold.
"""
function estimate_optimal_degree(l2_norms::Vector{Float64}, degrees::Vector{Int},
                                 improvement_threshold=0.05)
    if length(l2_norms) < 2
        return nothing
    end

    # Compute relative improvements
    improvements = [(l2_norms[i-1] - l2_norms[i]) / l2_norms[i-1] for i in 2:length(l2_norms)]

    # Find first degree where improvement drops below threshold
    for (i, imp) in enumerate(improvements)
        if imp < improvement_threshold
            return degrees[i]  # Return degree where improvement is insufficient
        end
    end

    # If all improvements are good, suggest continuing to higher degree
    return degrees[end]
end

"""
    compute_degree_improvements(l2_norms::Vector{Float64}) -> Union{Vector{Float64}, Nothing}

Compute relative improvement at each degree increase.
"""
function compute_degree_improvements(l2_norms::Vector{Float64})
    if length(l2_norms) < 2
        return nothing
    end

    return [(l2_norms[i-1] - l2_norms[i]) / l2_norms[i-1] for i in 2:length(l2_norms)]
end

# ============================================================================
# Resource Utilization
# ============================================================================

"""
    measure_memory_gb() -> (Float64, Float64)

Measure current memory usage.
Returns (peak_memory_gb, mean_memory_gb).
"""
function measure_memory_gb()
    gc_stats = Base.gc_num()
    allocated_gb = gc_stats.allocd / 1024^3

    # For now, we don't track mean separately - would need continuous monitoring
    return (allocated_gb, allocated_gb)
end

# ============================================================================
# Main Collection Function
# ============================================================================

"""
    collect_enhanced_metrics(
        polynomial,
        execution_time::Float64,
        critical_points_df=nothing;
        l2_norms_by_degree=nothing,
        degrees=nothing,
        config=nothing,
        batch_id=nothing,
        gitlab_issue_id=nothing
    ) -> EnhancedExperimentMetrics

Collect all enhanced metrics for a GlobTim experiment.

# Arguments
- `polynomial`: ApproxPoly object from GlobTim
- `execution_time`: Total execution time in seconds
- `critical_points_df`: DataFrame of critical points (optional)
- `l2_norms_by_degree`: Vector of L2 norms across degrees (optional)
- `degrees`: Vector of polynomial degrees tested (optional)
- `config`: Experiment configuration (optional)
- `batch_id`: Batch/campaign identifier (optional)
- `gitlab_issue_id`: GitLab issue ID (optional)

# Returns
- `EnhancedExperimentMetrics` with all collected metrics
"""
function collect_enhanced_metrics(
    polynomial,
    execution_time::Float64,
    critical_points_df=nothing;
    l2_norms_by_degree=nothing,
    degrees=nothing,
    config=nothing,
    batch_id=nothing,
    gitlab_issue_id=nothing
)
    # Generate experiment ID
    exp_id = generate_experiment_id(config)

    # Collect reproducibility metadata
    reproducibility = ReproducibilityMetadata(
        get_git_commit_hash(),
        get_git_branch(),
        VERSION,
        hash_manifest_file(),
        gethostname(),
        get_cluster_node(),
        now(),
        exp_id
    )

    # Collect mathematical quality metrics
    mathematical_quality = MathematicalQualityMetrics(
        compute_sparsity(polynomial.coeffs),
        analyze_coefficients(polynomial.coeffs),
        compute_basis_usage(polynomial),
        critical_points_df !== nothing ? analyze_gradient_magnitudes(critical_points_df) : nothing,
        nothing  # domain_coverage_score - future
    )

    # Collect convergence metrics (if multi-degree data available)
    if l2_norms_by_degree !== nothing && length(l2_norms_by_degree) > 1
        convergence = ConvergenceMetrics(
            estimate_convergence_rate(l2_norms_by_degree),
            classify_convergence(l2_norms_by_degree),
            degrees !== nothing ? estimate_optimal_degree(l2_norms_by_degree, degrees) : nothing,
            compute_degree_improvements(l2_norms_by_degree),
            detect_stagnation(l2_norms_by_degree)
        )
    else
        # Single degree - no convergence analysis possible
        convergence = ConvergenceMetrics(
            nothing,
            nothing,
            nothing,
            nothing,
            false
        )
    end

    # Collect resource utilization
    peak_mem, mean_mem = measure_memory_gb()
    resources = ResourceUtilization(
        nothing,  # CPU utilization - future
        peak_mem,
        mean_mem,
        execution_time,
        nothing,  # disk_read_mb - future
        nothing,  # disk_write_mb - future
        nothing   # network_transfer_mb - future
    )

    # Comparison metrics (not implemented yet)
    comparison = nothing

    return EnhancedExperimentMetrics(
        exp_id,
        batch_id,
        gitlab_issue_id,
        reproducibility,
        mathematical_quality,
        convergence,
        resources,
        comparison
    )
end

# ============================================================================
# JSON Serialization Helper
# ============================================================================

"""
    metrics_to_dict(metrics::EnhancedExperimentMetrics) -> Dict{String, Any}

Convert EnhancedExperimentMetrics to a JSON-serializable dictionary.
"""
function metrics_to_dict(metrics::EnhancedExperimentMetrics)
    return Dict{String, Any}(
        "experiment_id" => metrics.experiment_id,
        "batch_id" => metrics.batch_id,
        "gitlab_issue_id" => metrics.gitlab_issue_id,
        "reproducibility" => Dict{String, Any}(
            "git_commit" => metrics.reproducibility.git_commit,
            "git_branch" => metrics.reproducibility.git_branch,
            "julia_version" => string(metrics.reproducibility.julia_version),
            "package_manifest_hash" => metrics.reproducibility.package_manifest_hash,
            "hostname" => metrics.reproducibility.hostname,
            "cluster_node" => metrics.reproducibility.cluster_node,
            "execution_timestamp" => string(metrics.reproducibility.execution_timestamp),
            "experiment_id" => metrics.reproducibility.experiment_id
        ),
        "mathematical_quality" => Dict{String, Any}(
            "polynomial_sparsity" => metrics.mathematical_quality.polynomial_sparsity,
            "coefficient_stats" => metrics.mathematical_quality.coefficient_stats,
            "basis_utilization" => metrics.mathematical_quality.basis_utilization,
            "gradient_magnitude_stats" => metrics.mathematical_quality.gradient_magnitude_stats,
            "domain_coverage_score" => metrics.mathematical_quality.domain_coverage_score
        ),
        "convergence" => Dict{String, Any}(
            "convergence_rate" => metrics.convergence.convergence_rate,
            "rate_type" => metrics.convergence.rate_type,
            "optimal_degree_estimate" => metrics.convergence.optimal_degree_estimate,
            "degree_improvements" => metrics.convergence.degree_improvements,
            "stagnation_detected" => metrics.convergence.stagnation_detected
        ),
        "resources" => Dict{String, Any}(
            "cpu_utilization_percent" => metrics.resources.cpu_utilization_percent,
            "peak_memory_gb" => metrics.resources.peak_memory_gb,
            "mean_memory_gb" => metrics.resources.mean_memory_gb,
            "execution_time_seconds" => metrics.resources.execution_time_seconds,
            "disk_read_mb" => metrics.resources.disk_read_mb,
            "disk_write_mb" => metrics.resources.disk_write_mb,
            "network_transfer_mb" => metrics.resources.network_transfer_mb
        ),
        "comparison" => metrics.comparison !== nothing ? Dict{String, Any}(
            "baseline_name" => metrics.comparison.baseline_name,
            "performance_delta_percent" => metrics.comparison.performance_delta_percent,
            "quality_improvement_percent" => metrics.comparison.quality_improvement_percent,
            "experiment_rank_in_campaign" => metrics.comparison.experiment_rank_in_campaign,
            "percentile_rank" => metrics.comparison.percentile_rank
        ) : nothing
    )
end

end  # module EnhancedMetrics
