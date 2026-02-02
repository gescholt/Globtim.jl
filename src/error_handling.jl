"""
Error Handling Framework for Globtim.jl

This module provides comprehensive error handling, validation, and recovery mechanisms
for robust polynomial approximation and critical point analysis.
"""

# ============================================================================
# ERROR TYPE HIERARCHY
# ============================================================================

"""
    GlobtimError <: Exception

Base abstract type for all Globtim-specific errors.
All custom errors in Globtim should inherit from this type.
"""
abstract type GlobtimError <: Exception end

"""
    InputValidationError <: GlobtimError

Error thrown when input parameters are invalid or out of acceptable ranges.

# Fields
- `parameter::String`: Name of the invalid parameter
- `value::Any`: The invalid value provided
- `constraints::String`: Description of valid constraints
- `suggestion::String`: Suggested fix for the user
"""
struct InputValidationError <: GlobtimError
    parameter::String
    value::Any
    constraints::String
    suggestion::String
end

"""
    NumericalError <: GlobtimError

Error thrown when numerical instabilities or computational issues occur.

# Fields
- `operation::String`: The operation that failed
- `details::String`: Detailed description of the numerical issue
- `suggestions::Vector{String}`: List of suggested remedies
- `context::Dict{String,Any}`: Additional context information
"""
struct NumericalError <: GlobtimError
    operation::String
    details::String
    suggestions::Vector{String}
    context::Dict{String, Any}

    function NumericalError(operation, details, suggestions, context = Dict{String, Any}())
        new(operation, details, suggestions, context)
    end
end

"""
    ComputationError <: GlobtimError

Error thrown when a computation stage fails.

# Fields
- `stage::String`: The computation stage that failed
- `error_type::String`: Type of error that occurred
- `context::Dict{String,Any}`: Context information about the failure
- `recovery_options::Vector{String}`: Possible recovery strategies
"""
struct ComputationError <: GlobtimError
    stage::String
    error_type::String
    context::Dict{String, Any}
    recovery_options::Vector{String}
end

"""
    ResourceError <: GlobtimError

Error thrown when resource limits are exceeded.

# Fields
- `resource::String`: Type of resource (memory, time, disk)
- `current::Float64`: Current usage
- `limit::Float64`: Limit that was exceeded
- `suggestion::String`: Suggested action to resolve
"""
struct ResourceError <: GlobtimError
    resource::String
    current::Float64
    limit::Float64
    suggestion::String
end

"""
    ConvergenceError <: GlobtimError

Error thrown when iterative algorithms fail to converge.

# Fields
- `algorithm::String`: Name of the algorithm
- `iterations::Int`: Number of iterations attempted
- `tolerance::Float64`: Target tolerance
- `final_error::Float64`: Final error achieved
- `suggestions::Vector{String}`: Suggested remedies
"""
struct ConvergenceError <: GlobtimError
    algorithm::String
    iterations::Int
    tolerance::Float64
    final_error::Float64
    suggestions::Vector{String}
end

# ============================================================================
# USER-FRIENDLY ERROR DISPLAY
# ============================================================================

"""
Custom error display for InputValidationError with helpful formatting.
"""
function Base.showerror(io::IO, e::InputValidationError)
    println(io, "🚨 Invalid Input Parameter: $(e.parameter)")
    println(io, "   Value provided: $(e.value)")
    println(io, "   Valid range: $(e.constraints)")
    println(io, "   💡 Suggestion: $(e.suggestion)")
end

"""
Custom error display for NumericalError with detailed diagnostics.
"""
function Base.showerror(io::IO, e::NumericalError)
    println(io, "⚠️  Numerical Instability in $(e.operation)")
    println(io, "   Problem: $(e.details)")

    if !isempty(e.context)
        println(io, "   Context:")
        for (key, value) in e.context
            println(io, "     • $key: $value")
        end
    end

    println(io, "   💡 Suggestions:")
    for suggestion in e.suggestions
        println(io, "     • $suggestion")
    end
end

"""
Custom error display for ComputationError with recovery options.
"""
function Base.showerror(io::IO, e::ComputationError)
    println(io, "❌ Computation Failed at Stage: $(e.stage)")
    println(io, "   Error Type: $(e.error_type)")

    if !isempty(e.context)
        println(io, "   Context:")
        for (key, value) in e.context
            println(io, "     • $key: $value")
        end
    end

    println(io, "   🔧 Recovery Options:")
    for option in e.recovery_options
        println(io, "     • $option")
    end
end

"""
Custom error display for ResourceError with resource usage information.
"""
function Base.showerror(io::IO, e::ResourceError)
    println(io, "🚫 Resource Limit Exceeded: $(e.resource)")
    println(io, "   Current usage: $(e.current)")
    println(io, "   Limit: $(e.limit)")
    println(io, "   💡 Suggestion: $(e.suggestion)")
end

"""
Custom error display for ConvergenceError with algorithm details.
"""
function Base.showerror(io::IO, e::ConvergenceError)
    println(io, "🔄 Convergence Failed: $(e.algorithm)")
    println(io, "   Iterations: $(e.iterations)")
    println(io, "   Target tolerance: $(e.tolerance)")
    println(io, "   Final error: $(e.final_error)")
    println(io, "   💡 Suggestions:")
    for suggestion in e.suggestions
        println(io, "     • $suggestion")
    end
end

# ============================================================================
# INPUT VALIDATION FUNCTIONS
# ============================================================================

"""
    validate_dimension(dim::Int; max_dim::Int=10)

Validate that the problem dimension is within acceptable bounds.

# Arguments
- `dim::Int`: Problem dimension to validate
- `max_dim::Int=10`: Maximum allowed dimension

# Throws
- `InputValidationError`: If dimension is invalid
"""
function validate_dimension(dim::Int; max_dim::Int = 10)
    if dim < 1
        throw(
            InputValidationError(
                "dim", dim, "dim ≥ 1",
                "Problem dimension must be at least 1"
            )
        )
    end

    if dim > max_dim
        throw(
            InputValidationError(
                "dim", dim, "dim ≤ $max_dim",
                "For dimensions > $max_dim, consider domain decomposition or contact developers"
            )
        )
    end
end

"""
    validate_polynomial_degree(degree::Int, sample_count::Int)

Validate polynomial degree against sample count and computational limits.

# Arguments
- `degree::Int`: Polynomial degree to validate
- `sample_count::Int`: Number of samples available

# Throws
- `InputValidationError`: If degree is invalid
"""
function validate_polynomial_degree(degree::Int, sample_count::Int)
    if degree < 1
        throw(
            InputValidationError(
                "degree", degree, "degree ≥ 1",
                "Polynomial degree must be at least 1"
            )
        )
    end

    # More conservative degree limits based on dimension
    max_safe_degree = 8  # Conservative default
    if degree > max_safe_degree
        throw(
            InputValidationError(
                "degree", degree, "degree ≤ $max_safe_degree",
                "High degrees (>$max_safe_degree) may cause memory exhaustion. For degree $degree, consider domain decomposition or contact developers."
            )
        )
    end

    # Estimate number of polynomial terms more accurately
    # For multivariate polynomials: C(degree + dim, dim) terms
    # Use a conservative estimate assuming 4D for safety
    estimated_coeffs = binomial(degree + 4, 4)

    # Check if this will cause memory issues
    estimated_memory_mb = estimated_coeffs * sample_count * 8 / 1024^2  # 8 bytes per Float64
    if estimated_memory_mb > 1000  # > 1GB for Vandermonde matrix
        throw(
            InputValidationError(
                "degree", degree, "memory-safe degree",
                "Degree $degree with $sample_count samples needs ~$(round(estimated_memory_mb))MB memory. Reduce degree to ≤6 or reduce samples."
            )
        )
    end

    # Check sample count vs coefficients ratio
    if sample_count < 3 * estimated_coeffs
        throw(
            InputValidationError(
                "degree", degree, "sufficient samples for degree",
                "Degree $degree needs ~$(3*estimated_coeffs) samples for stability, but only $sample_count provided. Reduce degree or increase samples."
            )
        )
    end
end

"""
    validate_sample_count(GN::Int; min_samples::Int=10, max_samples::Int=50000)

Validate that sample count is within reasonable bounds.

# Arguments
- `GN::Int`: Sample count to validate
- `min_samples::Int=10`: Minimum required samples
- `max_samples::Int=50000`: Maximum allowed samples

# Throws
- `InputValidationError`: If sample count is invalid
"""
function validate_sample_count(GN::Int; min_samples::Int = 10, max_samples::Int = 50000)
    if GN < min_samples
        throw(
            InputValidationError(
                "GN", GN, "GN ≥ $min_samples",
                "Need at least $min_samples samples for reliable approximation"
            )
        )
    end

    if GN > max_samples
        throw(
            InputValidationError(
                "GN", GN, "GN ≤ $max_samples",
                "Very large sample counts (>$max_samples) may cause memory issues. Consider domain decomposition."
            )
        )
    end
end

"""
    validate_center_vector(center::Vector{Float64}, dim::Int)

Validate that center vector has correct dimension and finite values.

# Arguments
- `center::Vector{Float64}`: Center vector to validate
- `dim::Int`: Expected dimension

# Throws
- `InputValidationError`: If center vector is invalid
"""
function validate_center_vector(center::Vector{Float64}, dim::Int)
    if length(center) != dim
        throw(
            InputValidationError(
                "center", center, "vector of length $dim",
                "Center vector must have exactly $dim elements to match problem dimension"
            )
        )
    end

    if any(!isfinite, center)
        throw(
            InputValidationError(
                "center", center, "finite real values",
                "All center coordinates must be finite (no NaN or Inf values)"
            )
        )
    end
end

"""
    validate_sample_range(sample_range::Float64)

Validate that sample range is positive and reasonable.

# Arguments
- `sample_range::Float64`: Sample range to validate

# Throws
- `InputValidationError`: If sample range is invalid
"""
function validate_sample_range(sample_range::Float64)
    if !isfinite(sample_range)
        throw(
            InputValidationError(
                "sample_range", sample_range, "finite positive value",
                "Sample range must be a finite positive number"
            )
        )
    end

    if sample_range <= 0
        throw(
            InputValidationError(
                "sample_range", sample_range, "sample_range > 0",
                "Sample range must be positive"
            )
        )
    end

    if sample_range > 1000
        throw(
            InputValidationError(
                "sample_range", sample_range, "reasonable range (≤ 1000)",
                "Very large sample ranges may cause numerical issues. Consider rescaling your problem."
            )
        )
    end
end

# ============================================================================
# FUNCTION VALIDATION
# ============================================================================

"""
    validate_objective_function(f::Function, dim::Int, center::Vector{Float64})

Validate that the objective function is well-behaved at the center point.

# Arguments
- `f::Function`: Objective function to validate
- `dim::Int`: Problem dimension
- `center::Vector{Float64}`: Center point for testing

# Throws
- `InputValidationError`: If function is invalid or ill-behaved
"""
function validate_objective_function(f::Function, dim::Int, center::Vector{Float64})
    try
        # Test function evaluation at center
        result = f(center)

        # Check return type
        if !isa(result, Real)
            throw(
                InputValidationError(
                    "function", typeof(result), "real number",
                    "Objective function must return a real number, got $(typeof(result))"
                )
            )
        end

        # Check for NaN/Inf
        if !isfinite(result)
            throw(
                InputValidationError(
                    "function", result, "finite real number",
                    "Function returns $(result) at center point. Check function definition for singularities."
                )
            )
        end

        # Test function at a few nearby points to check for basic continuity
        test_points = [
            center + 0.1 * randn(dim),
            center + 0.01 * randn(dim),
            center - 0.1 * randn(dim)
        ]

        for (i, point) in enumerate(test_points)
            try
                test_result = f(point)
                if !isfinite(test_result)
                    @warn "Function may have singularities near center point" point = point value =
                        test_result
                end
            catch e
                throw(
                    InputValidationError(
                        "function", e, "evaluable at test points",
                        "Function failed at test point $i: $e. Check function domain and implementation."
                    )
                )
            end
        end

    catch e
        if isa(e, InputValidationError)
            rethrow(e)
        else
            throw(
                InputValidationError(
                    "function", e, "callable function",
                    "Function evaluation failed: $e. Ensure function accepts Vector{Float64} input."
                )
            )
        end
    end
end

# ============================================================================
# NUMERICAL STABILITY MONITORING
# ============================================================================

"""
    check_matrix_conditioning(matrix::Matrix{T}, operation_name::String;
                             max_condition::Float64=1e12) where T

Check matrix conditioning and warn about potential numerical issues.

# Arguments
- `matrix::Matrix{T}`: Matrix to check
- `operation_name::String`: Name of operation for error reporting
- `max_condition::Float64=1e12`: Maximum acceptable condition number

# Throws
- `NumericalError`: If matrix is severely ill-conditioned
"""
function check_matrix_conditioning(matrix::Matrix{T}, operation_name::String;
    max_condition::Float64 = 1e12) where {T}
    if isempty(matrix)
        throw(
            NumericalError(
                operation_name,
                "Empty matrix encountered",
                ["Check input data", "Verify problem setup"],
                Dict("matrix_size" => size(matrix))
            )
        )
    end

    try
        cond_num = cond(matrix)

        if !isfinite(cond_num)
            throw(
                NumericalError(
                    operation_name,
                    "Matrix is singular or nearly singular",
                    [
                        "Reduce polynomial degree",
                        "Increase number of samples",
                        "Check for duplicate sample points",
                        "Try different basis (Chebyshev vs Legendre)"
                    ],
                    Dict("condition_number" => cond_num, "matrix_size" => size(matrix))
                )
            )
        end

        if cond_num > max_condition
            throw(
                NumericalError(
                    operation_name,
                    "Matrix is severely ill-conditioned (condition number: $(cond_num))",
                    [
                        "Reduce polynomial degree from current value",
                        "Increase sample count for better conditioning",
                        "Consider using regularization",
                        "Try AdaptivePrecision for extended precision arithmetic"
                    ],
                    Dict("condition_number" => cond_num, "matrix_size" => size(matrix))
                )
            )
        elseif cond_num > 1e8
            @warn "Matrix is moderately ill-conditioned" operation = operation_name condition_number =
                cond_num
        end

        return cond_num

    catch e
        if isa(e, NumericalError)
            rethrow(e)
        else
            throw(
                NumericalError(
                    operation_name,
                    "Failed to compute matrix condition number: $e",
                    ["Check matrix for NaN/Inf values", "Verify matrix dimensions"],
                    Dict("matrix_size" => size(matrix), "error" => string(e))
                )
            )
        end
    end
end

"""
    validate_polynomial_coefficients(coeffs::Vector{T}, operation_name::String) where T

Validate polynomial coefficients for numerical issues.

# Arguments
- `coeffs::Vector{T}`: Polynomial coefficients to validate
- `operation_name::String`: Name of operation for error reporting

# Throws
- `NumericalError`: If coefficients contain NaN/Inf or are all zero
"""
function validate_polynomial_coefficients(
    coeffs::Vector{T},
    operation_name::String
) where {T}
    if isempty(coeffs)
        throw(
            NumericalError(
                operation_name,
                "Empty coefficient vector",
                ["Check polynomial construction", "Verify input parameters"],
                Dict("coefficient_count" => 0)
            )
        )
    end

    # Check for NaN/Inf
    nan_count = count(isnan, coeffs)
    inf_count = count(isinf, coeffs)

    if nan_count > 0 || inf_count > 0
        throw(
            NumericalError(
                operation_name,
                "Polynomial coefficients contain $(nan_count) NaN and $(inf_count) Inf values",
                [
                    "Reduce polynomial degree",
                    "Increase sample count",
                    "Check objective function for singularities",
                    "Try different precision type (AdaptivePrecision)"
                ],
                Dict(
                    "total_coeffs" => length(coeffs),
                    "nan_count" => nan_count,
                    "inf_count" => inf_count
                )
            )
        )
    end

    # Check if all coefficients are effectively zero
    max_abs_coeff = maximum(abs, coeffs)
    if max_abs_coeff < 1e-15
        throw(
            NumericalError(
                operation_name,
                "All polynomial coefficients are effectively zero (max: $(max_abs_coeff))",
                [
                    "Check objective function implementation",
                    "Verify sample range covers function variation",
                    "Increase polynomial degree if function is complex"
                ],
                Dict(
                    "max_coefficient" => max_abs_coeff,
                    "coefficient_count" => length(coeffs)
                )
            )
        )
    end

    # Warn about very large coefficients
    if max_abs_coeff > 1e10
        @warn "Very large polynomial coefficients detected" max_coefficient = max_abs_coeff operation =
            operation_name
    end
end

# ============================================================================
# RESOURCE MONITORING
# ============================================================================

"""
    check_memory_usage(operation_name::String; memory_limit_gb::Float64=8.0)

Monitor memory usage and throw error if limit is exceeded.

# Arguments
- `operation_name::String`: Name of operation for error reporting
- `memory_limit_gb::Float64=8.0`: Memory limit in GB

# Throws
- `ResourceError`: If memory limit is exceeded
"""
function check_memory_usage(operation_name::String; memory_limit_gb::Float64 = 8.0)
    try
        # Get current memory usage (this is approximate)
        gc_stats = Base.gc_num()
        allocated_mb = gc_stats.allocd / 1024^2
        allocated_gb = allocated_mb / 1024

        if allocated_gb > memory_limit_gb
            throw(
                ResourceError(
                    "memory",
                    allocated_gb,
                    memory_limit_gb,
                    "Reduce problem size (lower degree, fewer samples) or increase available memory"
                )
            )
        elseif allocated_gb > 0.8 * memory_limit_gb
            @warn "High memory usage detected" operation = operation_name memory_gb =
                allocated_gb limit_gb = memory_limit_gb
        end

    catch e
        if isa(e, ResourceError)
            rethrow(e)
        else
            @debug "Could not check memory usage" error = e
        end
    end
end

"""
    estimate_computation_complexity(dim::Int, degree::Int, sample_count::Int)

Estimate computational complexity and warn about potentially expensive operations.

# Arguments
- `dim::Int`: Problem dimension
- `degree::Int`: Polynomial degree
- `sample_count::Int`: Number of samples

# Returns
- `Dict{String,Any}`: Complexity estimates and warnings
"""
function estimate_computation_complexity(dim::Int, degree::Int, sample_count::Int)
    # Estimate number of polynomial terms: C(degree + dim, dim)
    estimated_terms = binomial(degree + dim, dim)

    # Estimate Vandermonde matrix size
    matrix_elements = sample_count * estimated_terms
    matrix_memory_mb = matrix_elements * 8 / 1024^2  # 8 bytes per Float64

    # Estimate additional memory for intermediate computations (factor of 3-5x)
    total_memory_mb = matrix_memory_mb * 4

    # Estimate polynomial system solving complexity (cubic in number of terms)
    system_complexity = estimated_terms^3

    # Estimate construction time (rough heuristic)
    estimated_construction_time_s = matrix_elements / 1e6  # Very rough estimate

    complexity_info = Dict{String, Any}(
        "estimated_terms" => estimated_terms,
        "matrix_elements" => matrix_elements,
        "matrix_memory_mb" => matrix_memory_mb,
        "total_memory_mb" => total_memory_mb,
        "system_complexity" => system_complexity,
        "estimated_time_s" => estimated_construction_time_s,
        "warnings" => String[],
        "memory_feasible" => total_memory_mb < 2000,  # < 2GB
        "time_feasible" => estimated_construction_time_s < 300  # < 5 minutes
    )

    # Add warnings for potentially expensive operations
    if estimated_terms > 200  # Much more conservative
        push!(complexity_info["warnings"],
            "High polynomial complexity ($estimated_terms terms). Degree $degree in $(dim)D may be too high."
        )
    end

    if matrix_memory_mb > 500  # More conservative memory warning
        push!(complexity_info["warnings"],
            "Large Vandermonde matrix (~$(round(matrix_memory_mb))MB). Risk of memory exhaustion."
        )
    end

    if total_memory_mb > 2000  # Total memory warning
        push!(complexity_info["warnings"],
            "Very high memory usage expected (~$(round(total_memory_mb))MB). Likely to cause system issues."
        )
    end

    if system_complexity > 1e6  # Much more conservative
        push!(complexity_info["warnings"],
            "Expensive polynomial system solving expected. May take very long time.")
    end

    if estimated_construction_time_s > 60  # Warn about long construction times
        push!(complexity_info["warnings"],
            "Long construction time expected (~$(round(estimated_construction_time_s))s). Consider reducing degree."
        )
    end

    # Add specific recommendations based on dimension and degree
    if dim >= 3 && degree >= 8
        push!(complexity_info["warnings"],
            "Degree $degree in $(dim)D is very expensive. Recommend degree ≤ 6 for dimensions ≥ 3."
        )
    end

    if dim >= 4 && degree >= 6
        push!(complexity_info["warnings"],
            "Degree $degree in $(dim)D may exhaust memory. Recommend degree ≤ 4 for dimensions ≥ 4."
        )
    end

    return complexity_info
end

# ============================================================================
# AUTOMATIC PARAMETER ADJUSTMENT AND RECOVERY
# ============================================================================

"""
    suggest_parameter_adjustments(error::GlobtimError, current_params::Dict{String,Any})

Suggest parameter adjustments based on the type of error encountered.

# Arguments
- `error::GlobtimError`: The error that occurred
- `current_params::Dict{String,Any}`: Current parameter values

# Returns
- `Dict{String,Any}`: Suggested parameter adjustments
"""
function suggest_parameter_adjustments(
    error::GlobtimError,
    current_params::Dict{String, Any}
)
    suggestions = Dict{String, Any}()

    if isa(error, NumericalError)
        if occursin("condition", error.details) || occursin("singular", error.details)
            # Reduce degree more aggressively for better conditioning
            current_degree = get(current_params, "degree", 8)
            suggestions["degree"] = max(2, current_degree - 3)  # More aggressive reduction
            suggestions["reason"] = "Reduced degree to improve numerical conditioning"
        end

        if occursin("coefficient", error.details)
            # Try different precision and reduce degree
            suggestions["precision"] = AdaptivePrecision
            current_degree = get(current_params, "degree", 8)
            suggestions["degree"] = max(2, current_degree - 2)
            suggestions["reason"] = "Switched to adaptive precision and reduced degree for stability"
        end

        if occursin("memory", error.details) || occursin("complexity", error.details)
            # Aggressively reduce degree for memory issues
            current_degree = get(current_params, "degree", 8)
            suggestions["degree"] = max(2, min(4, current_degree - 4))  # Cap at degree 4
            suggestions["reason"] = "Reduced degree to prevent memory exhaustion"
        end
    elseif isa(error, ResourceError)
        if error.resource == "memory"
            # Reduce both sample count and degree
            current_samples = get(current_params, "GN", 100)
            current_degree = get(current_params, "degree", 8)
            suggestions["GN"] = max(50, current_samples ÷ 2)
            suggestions["degree"] = max(2, min(4, current_degree - 2))  # Also reduce degree
            suggestions["reason"] = "Reduced sample count and degree to decrease memory usage"
        end
    elseif isa(error, InputValidationError)
        if error.parameter == "degree"
            # If degree validation failed, suggest much lower degree
            current_degree = get(current_params, "degree", 8)
            suggestions["degree"] = min(4, max(2, current_degree ÷ 2))
            suggestions["reason"] = "Reduced degree to safe level"
        end
    elseif isa(error, ComputationError)
        if error.stage == "polynomial_construction"
            # Try different basis
            current_basis = get(current_params, "basis", :chebyshev)
            suggestions["basis"] = current_basis == :chebyshev ? :legendre : :chebyshev
            suggestions["reason"] = "Switched polynomial basis"
        end
    end

    return suggestions
end

"""
    safe_execute_with_fallback(f::Function, params::Dict{String,Any};
                              max_retries::Int=3, operation_name::String="operation")

Execute a function with automatic parameter adjustment and retry on failure.

# Arguments
- `f::Function`: Function to execute (should accept params as keyword arguments)
- `params::Dict{String,Any}`: Initial parameters
- `max_retries::Int=3`: Maximum number of retry attempts
- `operation_name::String="operation"`: Name for logging

# Returns
- Result of successful function execution

# Throws
- Final error if all retries fail
"""
function safe_execute_with_fallback(f::Function, params::Dict{String, Any};
    max_retries::Int = 3, operation_name::String = "operation")
    current_params = copy(params)
    last_error = nothing

    for attempt in 1:max_retries
        try
            @debug "Attempting $operation_name" attempt = attempt params = current_params
            return f(; [Symbol(k) => v for (k, v) in current_params]...)

        catch e
            last_error = e

            if attempt == max_retries
                @error "All retry attempts failed for $operation_name" attempts =
                    max_retries final_error = e
                rethrow(e)
            end

            if isa(e, GlobtimError)
                # Log error details safely
                if isa(e, NumericalError)
                    @warn "Attempt $attempt failed for $operation_name: $(typeof(e))" operation =
                        e.operation details = e.details
                elseif isa(e, ResourceError)
                    @warn "Attempt $attempt failed for $operation_name: $(typeof(e))" resource =
                        e.resource suggestion = e.suggestion
                elseif isa(e, InputValidationError)
                    @warn "Attempt $attempt failed for $operation_name: $(typeof(e))" parameter =
                        e.parameter value = e.value
                else
                    @warn "Attempt $attempt failed for $operation_name: $(typeof(e))"
                end

                # Get parameter suggestions
                suggestions = suggest_parameter_adjustments(e, current_params)

                if !isempty(suggestions)
                    reason = pop!(suggestions, "reason", "Automatic adjustment")
                    @info "Adjusting parameters for retry" reason = reason adjustments =
                        suggestions
                    merge!(current_params, suggestions)
                else
                    @warn "No automatic parameter adjustments available for this error type"
                    break  # No point in retrying with same parameters
                end
            else
                @warn "Attempt $attempt failed for $operation_name with non-Globtim error: $e"
                break  # Don't retry for unexpected errors
            end
        end
    end

    # If we get here, all retries failed
    rethrow(last_error)
end

# ============================================================================
# PROGRESS MONITORING AND INTERRUPTION HANDLING
# ============================================================================

"""
    ComputationProgress

Mutable structure to track computation progress and handle interruptions.

# Fields
- `stage::String`: Current computation stage
- `progress::Float64`: Progress percentage (0.0 to 1.0)
- `estimated_time_remaining::Float64`: Estimated time remaining in seconds
- `can_interrupt::Bool`: Whether computation can be safely interrupted
- `cleanup_function::Union{Function, Nothing}`: Function to call for cleanup on interruption
- `start_time::Float64`: Time when computation started
"""
mutable struct ComputationProgress
    stage::String
    progress::Float64
    estimated_time_remaining::Float64
    can_interrupt::Bool
    cleanup_function::Union{Function, Nothing}
    start_time::Float64

    function ComputationProgress(
        stage::String;
        can_interrupt::Bool = true,
        cleanup_function = nothing
    )
        new(stage, 0.0, NaN, can_interrupt, cleanup_function, time())
    end
end

"""
    update_progress!(progress::ComputationProgress, new_progress::Float64, stage::String="")

Update computation progress and estimate remaining time.

# Arguments
- `progress::ComputationProgress`: Progress tracker to update
- `new_progress::Float64`: New progress value (0.0 to 1.0)
- `stage::String=""`: Optional new stage description
"""
function update_progress!(
    progress::ComputationProgress,
    new_progress::Float64,
    stage::String = ""
)
    progress.progress = clamp(new_progress, 0.0, 1.0)

    if !isempty(stage)
        progress.stage = stage
    end

    # Estimate remaining time
    if progress.progress > 0.01  # Avoid division by very small numbers
        elapsed_time = time() - progress.start_time
        total_estimated_time = elapsed_time / progress.progress
        progress.estimated_time_remaining = total_estimated_time - elapsed_time
    end
end

"""
    with_progress_monitoring(f::Function, description::String;
                           interruptible::Bool=true, cleanup_function=nothing)

Execute a function with progress monitoring and interruption handling.

# Arguments
- `f::Function`: Function to execute (should accept ComputationProgress as first argument)
- `description::String`: Description of the computation
- `interruptible::Bool=true`: Whether computation can be interrupted
- `cleanup_function=nothing`: Function to call for cleanup on interruption

# Returns
- Result of function execution

# Throws
- `InterruptException`: If computation is interrupted by user
"""
function with_progress_monitoring(f::Function, description::String;
    interruptible::Bool = true, cleanup_function = nothing)
    progress = ComputationProgress(
        description,
        can_interrupt = interruptible,
        cleanup_function = cleanup_function
    )

    try
        @info "Starting computation: $description"
        result = f(progress)
        @info "Computation completed: $description"
        return result

    catch e
        if isa(e, InterruptException)
            @info "Computation interrupted: $description"

            if progress.cleanup_function !== nothing
                @info "Running cleanup function..."
                try
                    progress.cleanup_function()
                    @info "Cleanup completed successfully"
                catch cleanup_error
                    @error "Cleanup failed" error = cleanup_error
                end
            end

            rethrow(e)
        else
            @error "Computation failed: $description" error = e
            rethrow(e)
        end
    end
end

# ============================================================================
# COMPREHENSIVE VALIDATION FUNCTIONS
# ============================================================================

"""
    validate_test_input_parameters(f::Function, dim::Int, center::Vector{Float64},
                                  sample_range::Float64, GN::Int)

Comprehensive validation of all test_input parameters.

# Arguments
- `f::Function`: Objective function
- `dim::Int`: Problem dimension
- `center::Vector{Float64}`: Center point
- `sample_range::Float64`: Sample range
- `GN::Int`: Sample count

# Throws
- `InputValidationError`: If any parameter is invalid
"""
function validate_test_input_parameters(f::Function, dim::Int, center::Vector{Float64},
    sample_range::Float64, GN::Int)
    # Validate each parameter
    validate_dimension(dim)
    validate_center_vector(center, dim)
    validate_sample_range(sample_range)
    validate_sample_count(GN)
    validate_objective_function(f, dim, center)

    # Check complexity estimates
    complexity = estimate_computation_complexity(dim, 8, GN)  # Assume degree 8 for estimation

    for warning in complexity["warnings"]
        @warn warning
    end

    @info "Parameter validation completed successfully" dim = dim sample_count = GN sample_range =
        sample_range
end

"""
    validate_constructor_parameters(TR::test_input, degree::Int;
                                   basis::Symbol=:chebyshev, precision::PrecisionType=RationalPrecision)

Comprehensive validation of Constructor parameters.

# Arguments
- `TR::test_input`: Test input structure
- `degree::Int`: Polynomial degree
- `basis::Symbol=:chebyshev`: Polynomial basis
- `precision::PrecisionType=RationalPrecision`: Precision type

# Throws
- `InputValidationError`: If any parameter is invalid
"""
function validate_constructor_parameters(TR::test_input, degree::Int;
    basis::Symbol = :chebyshev, precision::PrecisionType = RationalPrecision)
    validate_polynomial_degree(degree, TR.GN)

    # Validate basis
    if !(basis in [:chebyshev, :legendre])
        throw(
            InputValidationError(
                "basis", basis, ":chebyshev or :legendre",
                "Only Chebyshev and Legendre bases are currently supported"
            )
        )
    end

    # Check memory requirements
    check_memory_usage("polynomial_construction")

    # Get complexity estimates
    complexity = estimate_computation_complexity(TR.dim, degree, TR.GN)

    if complexity["matrix_memory_mb"] > 2000  # > 2GB
        @warn "Very large matrix expected" memory_mb = complexity["matrix_memory_mb"]
    end

    @info "Constructor parameter validation completed" degree = degree basis = basis precision =
        precision estimated_terms = complexity["estimated_terms"]
end

# ============================================================================
# UTILITY FUNCTIONS FOR ERROR CONTEXT
# ============================================================================

"""
    create_error_context(operation::String, params::Dict{String,Any})

Create standardized error context information.

# Arguments
- `operation::String`: Name of the operation
- `params::Dict{String,Any}`: Parameters involved in the operation

# Returns
- `Dict{String,Any}`: Standardized context information
"""
function create_error_context(operation::String, params::Dict{String, Any})
    context = Dict{String, Any}(
        "operation" => operation,
        "timestamp" => Dates.now(),
        "julia_version" => string(VERSION),
        "globtim_version" => "1.1.2"  # Update as needed
    )

    # Add relevant parameters
    merge!(context, params)

    return context
end

"""
    log_error_details(error::GlobtimError, context::Dict{String,Any})

Log detailed error information for debugging purposes.

# Arguments
- `error::GlobtimError`: The error that occurred
- `context::Dict{String,Any}`: Context information
"""
function log_error_details(error::GlobtimError, context::Dict{String, Any})
    @error "Globtim Error Details" error_type = typeof(error) context = context

    if isa(error, NumericalError)
        @debug "Numerical Error Details" operation = error.operation details = error.details suggestions =
            error.suggestions
    elseif isa(error, ComputationError)
        @debug "Computation Error Details" stage = error.stage error_type = error.error_type recovery_options =
            error.recovery_options
    end
end
