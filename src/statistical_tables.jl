# Statistical Tables for Phase 3 Enhanced Analysis
#
# This module provides comprehensive statistical table functionality for
# Phase 2 Hessian analysis, including type-specific statistics, condition
# number quality assessment, and mathematical validation.

using Statistics
using DataFrames
using LinearAlgebra

# Abstract base type for all statistical tables
abstract type StatisticalTable end

# Core statistical data structures
struct RobustStatistics
    count::Int
    mean::Float64
    std::Float64
    median::Float64
    min::Float64
    max::Float64
    q1::Float64
    q3::Float64
    iqr::Float64
    outlier_count::Int
    outlier_percentage::Float64
    range::Float64
end

struct ConditionNumberAnalysis
    total_count::Int
    excellent_count::Int      # < 1e3
    good_count::Int          # 1e3-1e6
    fair_count::Int          # 1e6-1e9
    poor_count::Int          # 1e9-1e12
    critical_count::Int      # >= 1e12
    well_conditioned_percentage::Float64
    overall_quality::String
    recommendations::Vector{String}
end

struct ValidationResults
    eigenvalue_signs_correct::Union{Bool,Missing}
    positive_eigenvalue_count::Union{Int,Missing}
    negative_eigenvalue_count::Union{Int,Missing}
    mixed_eigenvalue_signs::Union{Bool,Missing}
    determinant_positive::Union{Bool,Missing}
    determinant_sign_consistent::Union{Bool,Missing}
    additional_checks::Dict{String,Any}
end

# Main statistical table types
struct HessianNormTable <: StatisticalTable
    point_type::Symbol
    statistics::RobustStatistics
    display_format::Symbol
    validation_results::ValidationResults
end

struct ConditionNumberTable <: StatisticalTable
    point_type::Symbol
    analysis::ConditionNumberAnalysis
    display_format::Symbol
end

struct ComprehensiveStatsTable <: StatisticalTable
    point_type::Symbol
    hessian_stats::RobustStatistics
    condition_analysis::ConditionNumberAnalysis
    validation_results::ValidationResults
    eigenvalue_stats::Union{RobustStatistics,Missing}
    display_format::Symbol
end

"""
    compute_robust_statistics(values::Vector{Float64})

Compute comprehensive robust statistical measures including outlier detection.

# Returns
- `RobustStatistics`: Complete statistical summary with outlier analysis
"""
function compute_robust_statistics(values::Vector{Float64})
    if isempty(values)
        return RobustStatistics(0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 0, 0.0, NaN)
    end

    # Basic statistics
    n = length(values)
    mean_val = mean(values)
    std_val = n > 1 ? std(values) : 0.0
    median_val = median(values)
    min_val = minimum(values)
    max_val = maximum(values)

    # Robust statistics
    q1 = quantile(values, 0.25)
    q3 = quantile(values, 0.75)
    iqr = q3 - q1

    # Outlier detection (1.5 * IQR rule)
    if iqr > 0
        lower_fence = q1 - 1.5 * iqr
        upper_fence = q3 + 1.5 * iqr
        outliers = values[(values.<lower_fence).|(values.>upper_fence)]
        outlier_count = length(outliers)
        outlier_percentage = round(100 * outlier_count / n, digits = 1)
    else
        outlier_count = 0
        outlier_percentage = 0.0
    end

    return RobustStatistics(
        n,
        mean_val,
        std_val,
        median_val,
        min_val,
        max_val,
        q1,
        q3,
        iqr,
        outlier_count,
        outlier_percentage,
        max_val - min_val,
    )
end

"""
    compute_condition_number_analysis(condition_numbers::Vector{Float64})

Classify condition numbers by quality and generate recommendations.

# Returns
- `ConditionNumberAnalysis`: Quality breakdown and assessment
"""
function compute_condition_number_analysis(condition_numbers::Vector{Float64})
    if isempty(condition_numbers)
        return ConditionNumberAnalysis(0, 0, 0, 0, 0, 0, 0.0, "NO_DATA", String[])
    end

    n = length(condition_numbers)

    # Quality classification thresholds
    excellent = sum(condition_numbers .< 1e3)      # Well-conditioned
    good = sum(1e3 .<= condition_numbers .< 1e6)   # Acceptable
    fair = sum(1e6 .<= condition_numbers .< 1e9)   # Marginal
    poor = sum(1e9 .<= condition_numbers .< 1e12)  # Poor
    critical = sum(condition_numbers .>= 1e12)     # Numerically unstable

    # Overall quality assessment
    well_conditioned_percentage = round(100 * (excellent + good) / n, digits = 1)
    overall_quality = if well_conditioned_percentage > 80
        "EXCELLENT"
    elseif well_conditioned_percentage > 60
        "GOOD"
    elseif well_conditioned_percentage > 40
        "FAIR"
    else
        "POOR"
    end

    # Generate recommendations
    recommendations = String[]
    if well_conditioned_percentage > 90
        push!(recommendations, "Numerical quality is excellent")
    elseif well_conditioned_percentage > 70
        push!(recommendations, "Good numerical stability overall")
    else
        push!(recommendations, "Consider higher precision for stability")
    end

    if critical > 0
        push!(recommendations, "$(critical) critical points may be unreliable")
    end

    if poor + critical > n ÷ 4  # More than 25% problematic
        push!(recommendations, "Problem may benefit from rescaling")
    end

    return ConditionNumberAnalysis(
        n,
        excellent,
        good,
        fair,
        poor,
        critical,
        well_conditioned_percentage,
        overall_quality,
        recommendations,
    )
end

"""
    perform_mathematical_validation(type_data::DataFrame, point_type::Symbol)

Perform mathematical validation of critical point classifications.

# Returns
- `ValidationResults`: Comprehensive validation results
"""
function perform_mathematical_validation(type_data::DataFrame, point_type::Symbol)
    additional_checks = Dict{String,Any}()

    # Initialize validation results
    eigenvalue_signs_correct = missing
    positive_eigenvalue_count = missing
    negative_eigenvalue_count = missing
    mixed_eigenvalue_signs = missing
    determinant_positive = missing
    determinant_sign_consistent = missing

    if point_type == :minimum
        # For minima: all eigenvalues should be positive
        if hasproperty(type_data, :smallest_positive_eigenval)
            pos_eigenvals = filter(!isnan, type_data.smallest_positive_eigenval)
            if !isempty(pos_eigenvals)
                all_positive = all(λ -> λ > 1e-12, pos_eigenvals)
                eigenvalue_signs_correct = all_positive
                positive_eigenvalue_count = sum(pos_eigenvals .> 1e-12)
                negative_eigenvalue_count = sum(pos_eigenvals .<= 1e-12)
                additional_checks["smallest_positive_eigenval_mean"] = mean(pos_eigenvals)
            end
        end

    elseif point_type == :maximum
        # For maxima: all eigenvalues should be negative
        if hasproperty(type_data, :largest_negative_eigenval)
            neg_eigenvals = filter(!isnan, type_data.largest_negative_eigenval)
            if !isempty(neg_eigenvals)
                all_negative = all(λ -> λ < -1e-12, neg_eigenvals)
                eigenvalue_signs_correct = all_negative
                negative_eigenvalue_count = sum(neg_eigenvals .< -1e-12)
                positive_eigenvalue_count = sum(neg_eigenvals .>= -1e-12)
                additional_checks["largest_negative_eigenval_mean"] = mean(neg_eigenvals)
            end
        end

    elseif point_type == :saddle
        # For saddles: mixed eigenvalue signs expected
        if hasproperty(type_data, :hessian_eigenvalue_min) &&
           hasproperty(type_data, :hessian_eigenvalue_max)
            min_eigenvals = filter(!isnan, type_data.hessian_eigenvalue_min)
            max_eigenvals = filter(!isnan, type_data.hessian_eigenvalue_max)

            if !isempty(min_eigenvals) && !isempty(max_eigenvals)
                has_negative = any(λ -> λ < -1e-12, min_eigenvals)
                has_positive = any(λ -> λ > 1e-12, max_eigenvals)
                mixed_eigenvalue_signs = has_negative && has_positive
                additional_checks["negative_eigenval_count"] = sum(min_eigenvals .< -1e-12)
                additional_checks["positive_eigenval_count"] = sum(max_eigenvals .> 1e-12)
            end
        end
    end

    # Determinant consistency check
    if hasproperty(type_data, :hessian_determinant)
        determinants = filter(!isnan, type_data.hessian_determinant)
        if !isempty(determinants)
            if point_type == :minimum
                determinant_positive = all(det -> det > 1e-12, determinants)
                additional_checks["determinant_mean"] = mean(determinants)
            elseif point_type == :maximum
                # For maxima, determinant sign depends on dimension
                # Even dimensions: positive, odd dimensions: negative
                # We'll check if determinants are consistent in sign
                pos_dets = sum(determinants .> 1e-12)
                neg_dets = sum(determinants .< -1e-12)
                determinant_sign_consistent = (pos_dets == 0) || (neg_dets == 0)
                additional_checks["positive_determinants"] = pos_dets
                additional_checks["negative_determinants"] = neg_dets
            end
        end
    end

    return ValidationResults(
        eigenvalue_signs_correct,
        positive_eigenvalue_count,
        negative_eigenvalue_count,
        mixed_eigenvalue_signs,
        determinant_positive,
        determinant_sign_consistent,
        additional_checks,
    )
end

"""
    compute_type_specific_statistics(df::DataFrame, point_type::Symbol)

Compute comprehensive statistics for a specific critical point type.

# Returns
- `ComprehensiveStatsTable`: Complete statistical analysis
"""
function compute_type_specific_statistics(df::DataFrame, point_type::Symbol)
    # Validate that required columns exist
    required_columns = [:critical_point_type, :hessian_norm, :hessian_condition_number]
    available_columns = Symbol.(names(df))  # Convert String to Symbol
    missing_columns = [col for col in required_columns if !(col in available_columns)]

    if !isempty(missing_columns)
        error(
            "DataFrame is missing required columns for Phase 3 analysis: $(missing_columns). " *
            "Please run analyze_critical_points with enable_hessian=true first.",
        )
    end

    # Filter data by critical point type
    type_mask = df.critical_point_type .== point_type
    type_data = df[type_mask, :]

    if nrow(type_data) == 0
        # Return empty statistics
        empty_stats =
            RobustStatistics(0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 0, 0.0, NaN)
        empty_condition =
            ConditionNumberAnalysis(0, 0, 0, 0, 0, 0, 0.0, "NO_DATA", String[])
        empty_validation = ValidationResults(
            missing,
            missing,
            missing,
            missing,
            missing,
            missing,
            Dict{String,Any}(),
        )

        return ComprehensiveStatsTable(
            point_type,
            empty_stats,
            empty_condition,
            empty_validation,
            missing,
            :console,
        )
    end

    # Extract key numerical columns
    hessian_norms = if hasproperty(type_data, :hessian_norm)
        filter(!isnan, type_data.hessian_norm)
    else
        Float64[]
    end

    condition_numbers = if hasproperty(type_data, :hessian_condition_number)
        filter(x -> isfinite(x) && x > 0, type_data.hessian_condition_number)
    else
        Float64[]
    end

    # Compute comprehensive statistics
    hessian_stats = compute_robust_statistics(hessian_norms)
    condition_analysis = compute_condition_number_analysis(condition_numbers)
    validation_results = perform_mathematical_validation(type_data, point_type)

    # Eigenvalue statistics (if available)
    eigenvalue_stats = missing
    if hasproperty(type_data, :hessian_eigenvalue_min)
        eigenvals = filter(!isnan, type_data.hessian_eigenvalue_min)
        if !isempty(eigenvals)
            eigenvalue_stats = compute_robust_statistics(eigenvals)
        end
    end

    return ComprehensiveStatsTable(
        point_type,
        hessian_stats,
        condition_analysis,
        validation_results,
        eigenvalue_stats,
        :console,
    )
end

"""
    format_validation_key(key::String)

Format validation result keys for display.
"""
function format_validation_key(key::String)
    key_map = Dict(
        "eigenvalue_signs_correct" => "Eigenvalue signs correct",
        "positive_eigenvalue_count" => "Positive eigenvalues",
        "negative_eigenvalue_count" => "Negative eigenvalues",
        "mixed_eigenvalue_signs" => "Mixed eigenvalue signs",
        "determinant_positive" => "Determinant positive",
        "determinant_sign_consistent" => "Determinant sign consistent",
    )

    return get(key_map, key, titlecase(replace(key, "_" => " ")))
end

"""
    format_validation_value(value)

Format validation result values for display.
"""
function format_validation_value(value)
    if ismissing(value)
        return "N/A"
    elseif value === true
        return "✓ YES"
    elseif value === false
        return "✗ NO"
    else
        return string(value)
    end
end
