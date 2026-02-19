"""
Error Categorization Module for Globtim.jl

This module provides comprehensive error categorization, classification, and analysis
capabilities for systematic distinction between interface bugs and mathematical failures.

Provides systematic distinction between interface bugs and mathematical failures.
"""

module ErrorCategorization

using DataFrames
using JSON3
using Printf
using Statistics
using Dates
using StatsBase

export ErrorCategory, ErrorClassification, categorize_error, analyze_experiment_errors,
    generate_error_report, ERROR_TAXONOMY, SEVERITY_LEVELS, FIX_SUGGESTIONS

# ============================================================================
# ERROR TAXONOMY DEFINITIONS
# ============================================================================

"""
    ErrorCategory

Enumeration of error categories for systematic classification.
"""
@enum ErrorCategory INTERFACE_BUG MATHEMATICAL_FAILURE INFRASTRUCTURE_ISSUE CONFIGURATION_ERROR UNKNOWN_ERROR

"""
    SeverityLevel

Enumeration of error severity levels for prioritization.
"""
@enum SeverityLevel CRITICAL HIGH MEDIUM LOW UNKNOWN

"""
Error taxonomy patterns organized by category.
Each category maps to a vector of regex patterns for detection.
"""
const ERROR_TAXONOMY = Dict{ErrorCategory, Vector{Regex}}(
    INTERFACE_BUG => [
        r"df_critical\.val"i,
        r"column name :val not found"i,
        r"type.*has no field"i,
        r"no method matching.*signature mismatch"i,
        r"function.*exists.*no method.*defined"i,
        r"API.*deprecated"i,
        r"interface.*changed"i
    ],
    MATHEMATICAL_FAILURE => [
        r"failed to converge"i,
        r"singular matrix"i,
        r"HomotopyContinuation.*failed"i,
        r"polynomial system.*unsolvable"i,
        r"numerical instability"i,
        r"condition number.*too large"i,
        r"eigenvalue.*computation.*failed"i,
        r"optimization.*convergence.*failed"i,
        r"critical point.*solving.*failed"i
    ],
    INFRASTRUCTURE_ISSUE => [
        r"OutOfMemoryError"i,
        r"Package.*not found"i,
        r"disk space"i,
        r"permission denied"i,
        r"network.*error"i,
        r"file.*not.*found"i,
        r"precompilation.*failed"i,
        r"dependency.*missing"i,
        r"environment.*inconsistent"i
    ],
    CONFIGURATION_ERROR => [
        r"DimensionMismatch"i,
        r"BoundsError"i,
        r"InexactError"i,
        r"domain range.*invalid"i,
        r"parameter.*out of bounds"i,
        r"degree.*too.*high"i,
        r"sample.*count.*insufficient"i,
        r"precision.*type.*incompatible"i,
        r"grid.*generation.*invalid"i
    ]
)

"""
Severity mapping for each error category.
"""
const SEVERITY_LEVELS = Dict{ErrorCategory, SeverityLevel}(
    INTERFACE_BUG => LOW,           # Easy to fix, low impact
    MATHEMATICAL_FAILURE => MEDIUM, # Requires parameter tuning
    INFRASTRUCTURE_ISSUE => HIGH,   # System-level problems
    CONFIGURATION_ERROR => MEDIUM,  # Parameter adjustment needed
    UNKNOWN_ERROR => UNKNOWN
)

"""
Fix suggestions for each error category.
"""
const FIX_SUGGESTIONS = Dict{ErrorCategory, Vector{String}}(
    INTERFACE_BUG => [
        "Update script to use df_critical.z instead of df_critical.val",
        "Check API documentation for recent interface changes",
        "Validate function signatures match current Globtim version",
        "Review parameter names and field access patterns",
        "Update deprecated function calls to new API"
    ],
    MATHEMATICAL_FAILURE => [
        "Reduce polynomial degree to improve numerical stability",
        "Adjust domain range to avoid problematic regions",
        "Increase sampling density (GN parameter)",
        "Try different precision type (e.g., RationalPrecision)",
        "Check objective function for singularities or discontinuities",
        "Validate initial conditions are within valid domain"
    ],
    INFRASTRUCTURE_ISSUE => [
        "Increase memory allocation or use smaller problem size",
        "Verify all required packages are installed and up-to-date",
        "Check disk space availability on target system",
        "Restart Julia session to clear memory leaks",
        "Verify network connectivity for package downloads",
        "Check file system permissions"
    ],
    CONFIGURATION_ERROR => [
        "Validate parameter bounds and constraints",
        "Reduce problem dimension or polynomial degree",
        "Increase sample count for better coverage",
        "Check domain range is appropriate for objective function",
        "Verify precision type compatibility with problem size",
        "Review grid generation parameters"
    ],
    UNKNOWN_ERROR => [
        "Review full error message and stack trace",
        "Check Globtim documentation for similar issues",
        "Create minimal reproduction case",
        "Report issue to Globtim maintainers with full context"
    ]
)

# ============================================================================
# ERROR CLASSIFICATION STRUCTURE
# ============================================================================

"""
    ErrorClassification

Comprehensive classification of a single error instance.

# Fields
- `category::ErrorCategory`: Primary error category
- `severity::SeverityLevel`: Severity level for prioritization
- `confidence::Float64`: Confidence in classification (0.0-1.0)
- `patterns_matched::Vector{String}`: Patterns that triggered this classification
- `suggested_fixes::Vector{String}`: Recommended remediation steps
- `priority_score::Int`: Calculated priority for action ordering
- `context::Dict{String,Any}`: Additional context information
"""
struct ErrorClassification
    category::ErrorCategory
    severity::SeverityLevel
    confidence::Float64
    patterns_matched::Vector{String}
    suggested_fixes::Vector{String}
    priority_score::Int
    context::Dict{String, Any}
end

# ============================================================================
# CORE CATEGORIZATION FUNCTIONS
# ============================================================================

"""
    categorize_error(error_message::String;
                    context::Dict{String,Any} = Dict()) -> ErrorClassification

Categorize a single error message using the comprehensive taxonomy.

# Arguments
- `error_message::String`: The error message to categorize
- `context::Dict{String,Any}`: Additional context (experiment ID, timing, etc.)

# Returns
- `ErrorClassification`: Comprehensive classification of the error

# Example
```julia
error_msg = "BoundsError: attempt to access df_critical.val"
classification = categorize_error(error_msg)
println("Category: \$(classification.category)")
println("Severity: \$(classification.severity)")
```
"""
function categorize_error(error_message::String;
    context::Dict{String, Any} = Dict{String, Any}())::ErrorClassification

    # Initialize tracking variables
    matched_categories = Vector{Tuple{ErrorCategory, Vector{String}, Float64}}()

    # Check each category for pattern matches
    for (category, patterns) in ERROR_TAXONOMY
        matched_patterns = String[]
        pattern_scores = Float64[]

        for pattern in patterns
            if occursin(pattern, error_message)
                push!(matched_patterns, string(pattern))
                # Calculate pattern confidence based on specificity
                pattern_confidence = calculate_pattern_confidence(pattern, error_message)
                push!(pattern_scores, pattern_confidence)
            end
        end

        if !isempty(matched_patterns)
            # Calculate overall confidence for this category
            category_confidence =
                mean(pattern_scores) * (length(matched_patterns) / length(patterns))
            push!(matched_categories, (category, matched_patterns, category_confidence))
        end
    end

    # Determine primary category
    if isempty(matched_categories)
        primary_category = UNKNOWN_ERROR
        confidence = 0.0
        patterns_matched = String[]
    else
        # Sort by confidence and select highest
        sort!(matched_categories, by = x -> x[3], rev = true)
        primary_category, patterns_matched, confidence = matched_categories[1]
    end

    # Get severity and suggestions
    severity = get(SEVERITY_LEVELS, primary_category, UNKNOWN)
    suggested_fixes = get(FIX_SUGGESTIONS, primary_category, String[])

    # Calculate priority score
    priority_score = calculate_priority_score(severity, confidence, patterns_matched)

    # Enhance context with classification metadata
    enhanced_context = merge(
        context,
        Dict(
            "classification_timestamp" => string(now()),
            "total_categories_matched" => length(matched_categories),
            "error_message_length" => length(error_message)
        )
    )

    return ErrorClassification(
        primary_category,
        severity,
        confidence,
        patterns_matched,
        suggested_fixes,
        priority_score,
        enhanced_context
    )
end

"""
    calculate_pattern_confidence(pattern::Regex, message::String) -> Float64

Calculate confidence score for a specific pattern match.
"""
function calculate_pattern_confidence(pattern::Regex, message::String)::Float64
    # Base confidence for any match
    base_confidence = 0.5

    # Bonus for specific patterns
    pattern_str = string(pattern)
    specificity_bonus = 0.0

    # More specific patterns get higher confidence
    if length(pattern_str) > 20
        specificity_bonus += 0.3
    elseif length(pattern_str) > 10
        specificity_bonus += 0.2
    else
        specificity_bonus += 0.1
    end

    # Case-sensitive matches get slight bonus
    if !contains(pattern_str, "i")
        specificity_bonus += 0.1
    end

    return min(1.0, base_confidence + specificity_bonus)
end

"""
    calculate_priority_score(severity::SeverityLevel, confidence::Float64,
                           patterns::Vector{String}) -> Int

Calculate numerical priority score for error ordering.
Higher scores indicate higher priority.
"""
function calculate_priority_score(severity::SeverityLevel, confidence::Float64,
    patterns::Vector{String})::Int
    # Base score from severity
    severity_score = if severity == CRITICAL
        100
    elseif severity == HIGH
        75
    elseif severity == MEDIUM
        50
    elseif severity == LOW
        25
    else
        10
    end

    # Confidence modifier (0-20 points)
    confidence_modifier = round(Int, confidence * 20)

    # Pattern count modifier (more patterns = higher confidence)
    pattern_modifier = min(10, length(patterns) * 2)

    return severity_score + confidence_modifier + pattern_modifier
end

# ============================================================================
# BATCH ANALYSIS FUNCTIONS
# ============================================================================

"""
    analyze_experiment_errors(results::Vector{Dict}) -> DataFrame

Analyze a collection of experiment results and categorize all errors.

# Arguments
- `results::Vector{Dict}`: Collection of experiment results with error information

# Returns
- `DataFrame`: Comprehensive analysis with error classifications

# Example
```julia
results = load_experiment_results("path/to/results")
error_analysis = analyze_experiment_errors(results)
```
"""
function analyze_experiment_errors(results::Vector{<:Dict})::DataFrame

    error_classifications = Vector{Dict{String, Any}}()

    for (idx, result) in enumerate(results)
        # Extract error information
        error_msg = get(result, "error", "")
        experiment_id = get(result, "experiment", "unknown_$idx")
        success = get(result, "success", false)

        # Skip successful experiments
        if success || isempty(error_msg)
            continue
        end

        # Build context for classification
        context = Dict{String, Any}(
            "experiment_id" => experiment_id,
            "computation_time" => get(result, "total_computation_time", 0.0),
            "degree" => get(result, "degree", 0),
            "domain_range" => get(result, "domain_range", 0.0),
            "result_index" => idx
        )

        # Categorize the error
        classification = categorize_error(error_msg; context = context)

        # Build result dictionary
        error_data = Dict{String, Any}(
            "experiment_id" => experiment_id,
            "error_message" => error_msg,
            "category" => string(classification.category),
            "severity" => string(classification.severity),
            "confidence" => classification.confidence,
            "priority_score" => classification.priority_score,
            "patterns_matched" => join(classification.patterns_matched, ", "),
            "suggested_fixes" => join(classification.suggested_fixes, " | "),
            "computation_time" => get(context, "computation_time", 0.0),
            "degree" => get(context, "degree", 0),
            "domain_range" => get(context, "domain_range", 0.0)
        )

        push!(error_classifications, error_data)
    end

    # Convert to DataFrame for analysis
    if isempty(error_classifications)
        # Return empty DataFrame with proper columns
        return DataFrame(
            experiment_id = String[],
            error_message = String[],
            category = String[],
            severity = String[],
            confidence = Float64[],
            priority_score = Int[],
            patterns_matched = String[],
            suggested_fixes = String[],
            computation_time = Float64[],
            degree = Int[],
            domain_range = Float64[]
        )
    end

    return DataFrame(error_classifications)
end

"""
    generate_error_report(error_df::DataFrame) -> Dict{String,Any}

Generate comprehensive error analysis report.

# Arguments
- `error_df::DataFrame`: DataFrame from analyze_experiment_errors

# Returns
- `Dict{String,Any}`: Comprehensive report with statistics and recommendations
"""
function generate_error_report(error_df::DataFrame)::Dict{String, Any}

    if nrow(error_df) == 0
        return Dict{String, Any}(
            "total_errors" => 0,
            "summary" => "No errors found in the analyzed experiments.",
            "recommendations" => String[]
        )
    end

    # Category distribution
    category_counts = combine(groupby(error_df, :category), nrow => :count)
    sort!(category_counts, :count, rev = true)

    # Severity distribution
    severity_counts = combine(groupby(error_df, :severity), nrow => :count)
    sort!(severity_counts, :count, rev = true)

    # High priority errors (priority_score > 75)
    high_priority_errors = filter(row -> row.priority_score > 75, error_df)

    # Most common patterns
    all_patterns = String[]
    for patterns_str in error_df.patterns_matched
        if !isempty(patterns_str)
            append!(all_patterns, split(patterns_str, ", "))
        end
    end
    pattern_counts = sort(collect(countmap(all_patterns)), by = x -> x[2], rev = true)

    # Generate recommendations
    recommendations = generate_recommendations(error_df, category_counts)

    # Summary statistics
    total_errors = nrow(error_df)
    avg_confidence = mean(error_df.confidence)
    interface_bugs = nrow(filter(row -> row.category == "INTERFACE_BUG", error_df))
    mathematical_failures =
        nrow(filter(row -> row.category == "MATHEMATICAL_FAILURE", error_df))

    return Dict{String, Any}(
        "analysis_timestamp" => string(now()),
        "total_errors" => total_errors,
        "average_confidence" => round(avg_confidence, digits = 3),
        "high_priority_count" => nrow(high_priority_errors),
        "category_distribution" => [
            Dict("category" => row.category, "count" => row.count,
                "percentage" => round(100 * row.count / total_errors, digits = 1))
            for row in eachrow(category_counts)
        ],
        "severity_distribution" => [
            Dict("severity" => row.severity, "count" => row.count,
                "percentage" => round(100 * row.count / total_errors, digits = 1))
            for row in eachrow(severity_counts)
        ],
        "most_common_patterns" => [
            Dict("pattern" => pattern, "count" => count)
            for (pattern, count) in pattern_counts[1:min(5, length(pattern_counts))]
        ],
        "key_insights" => [
            "Interface bugs: $interface_bugs errors ($(round(100*interface_bugs/total_errors, digits=1))%)",
            "Mathematical failures: $mathematical_failures errors ($(round(100*mathematical_failures/total_errors, digits=1))%)",
            "Average classification confidence: $(round(100*avg_confidence, digits=1))%",
            "High priority errors requiring immediate attention: $(nrow(high_priority_errors))"
        ], "recommendations" => recommendations,
        "detailed_errors" => [
            Dict(
                "experiment_id" => row.experiment_id,
                "category" => row.category,
                "severity" => row.severity,
                "priority_score" => row.priority_score,
                "confidence" => row.confidence,
                "suggested_fixes" => split(row.suggested_fixes, " | ")
            )
            for row in eachrow(
                first(sort(error_df, :priority_score, rev = true), min(10, nrow(error_df)))
            )
        ]
    )
end

"""
    generate_recommendations(error_df::DataFrame, category_counts::DataFrame) -> Vector{String}

Generate actionable recommendations based on error analysis.
"""
function generate_recommendations(
    error_df::DataFrame,
    category_counts::DataFrame
)::Vector{String}
    recommendations = String[]

    if nrow(error_df) == 0
        return recommendations
    end

    total_errors = nrow(error_df)

    # Check for dominant error categories
    if nrow(category_counts) > 0
        top_category = category_counts[1, :category]
        top_count = category_counts[1, :count]
        top_percentage = round(100 * top_count / total_errors, digits = 1)

        if top_percentage > 50
            push!(recommendations,
                "PRIMARY FOCUS: $top_category represents $top_percentage% of errors. " *
                "Addressing this category will have maximum impact.")
        end
    end

    # Interface bug recommendations
    interface_bugs = nrow(filter(row -> row.category == "INTERFACE_BUG", error_df))
    if interface_bugs > 0
        interface_percentage = round(100 * interface_bugs / total_errors, digits = 1)
        push!(recommendations,
            "INTERFACE ISSUES: $interface_bugs errors ($interface_percentage%) are interface bugs. " *
            "These are typically quick fixes - review API usage and update deprecated patterns."
        )
    end

    # Mathematical failure recommendations
    math_failures = nrow(filter(row -> row.category == "MATHEMATICAL_FAILURE", error_df))
    if math_failures > 0
        math_percentage = round(100 * math_failures / total_errors, digits = 1)
        push!(recommendations,
            "MATHEMATICAL TUNING: $math_failures errors ($math_percentage%) are mathematical failures. " *
            "Consider reducing polynomial degrees, adjusting domain ranges, or increasing sampling density."
        )
    end

    # High priority recommendations
    high_priority = nrow(filter(row -> row.priority_score > 75, error_df))
    if high_priority > 0
        push!(recommendations,
            "URGENT ACTION: $high_priority errors have high priority scores (>75). " *
            "Address these first for maximum stability improvement.")
    end

    # Low confidence recommendations
    low_confidence = nrow(filter(row -> row.confidence < 0.5, error_df))
    if low_confidence > 0
        low_conf_percentage = round(100 * low_confidence / total_errors, digits = 1)
        push!(recommendations,
            "INVESTIGATION NEEDED: $low_confidence errors ($low_conf_percentage%) have low classification confidence. " *
            "Manual review may be needed to properly categorize these issues.")
    end

    return recommendations
end

end # module ErrorCategorization
