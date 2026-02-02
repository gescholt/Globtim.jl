"""
Safe Wrapper Functions for Globtim.jl

This module provides enhanced versions of core Globtim functions with comprehensive
error handling, validation, and automatic recovery mechanisms.
"""

using Dates

# ============================================================================
# SAFE TEST INPUT CONSTRUCTION
# ============================================================================

"""
    safe_test_input(f::Function; dim::Int, center::Vector{Float64}, 
                   sample_range::Float64, GN::Int=100, kwargs...)

Safe wrapper for test_input constructor with comprehensive validation and error handling.

This function provides the same functionality as test_input but with:
- Comprehensive parameter validation
- Automatic error recovery
- Progress monitoring for large problems
- Resource usage monitoring

# Arguments
- `f::Function`: Objective function to analyze
- `dim::Int`: Problem dimension
- `center::Vector{Float64}`: Center point for sampling
- `sample_range::Float64`: Range for sampling around center
- `GN::Int=100`: Number of sample points
- `kwargs...`: Additional arguments passed to test_input

# Returns
- `test_input`: Validated test input structure

# Throws
- `InputValidationError`: If parameters are invalid
- `ResourceError`: If resource limits are exceeded
- `ComputationError`: If construction fails

# Examples
```julia
# Basic usage with validation
f(x) = sum(x.^2)
TR = safe_test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0, GN=100)

# Automatic parameter adjustment on failure
try
    TR = safe_test_input(complex_function, dim=4, center=zeros(4), sample_range=10.0, GN=5000)
catch e
    println("Construction failed: ", e)
end
```
"""
function safe_test_input(f::Function; dim::Int, center::Vector{Float64},
    sample_range::Float64, GN::Int = 100, kwargs...)

    # Comprehensive parameter validation
    validate_test_input_parameters(f, dim, center, sample_range, GN)

    # Create parameter dictionary for error handling
    params = Dict{String, Any}(
        "dim" => dim,
        "center" => center,
        "sample_range" => sample_range,
        "GN" => GN
    )
    merge!(params, Dict(string(k) => v for (k, v) in kwargs))

    # Define the construction function
    function construct_test_input(;
        dim = dim,
        center = center,
        sample_range = sample_range,
        GN = GN,
        kwargs...
    )
        try
            # Monitor memory usage
            check_memory_usage("test_input_construction")

            # Create test input
            TR = test_input(
                f,
                dim = dim,
                center = center,
                sample_range = sample_range,
                GN = GN;
                kwargs...
            )

            @info "Test input constructed successfully" dim = dim sample_count = GN
            return TR

        catch e
            context = create_error_context("test_input_construction", params)

            if isa(e, OutOfMemoryError)
                throw(
                    ResourceError(
                        "memory", NaN, NaN,
                        "Reduce sample count (GN) or problem dimension"
                    )
                )
            elseif isa(e, BoundsError) || isa(e, DimensionMismatch)
                throw(
                    ComputationError(
                        "test_input_construction", "dimension_mismatch",
                        context,
                        [
                            "Check center vector dimension",
                            "Verify function accepts correct input size"
                        ]
                    )
                )
            else
                # Wrap unexpected errors
                throw(
                    ComputationError(
                        "test_input_construction", "unexpected_error",
                        merge(context, Dict("original_error" => string(e))),
                        [
                            "Check function implementation",
                            "Verify all parameters",
                            "Contact developers"
                        ]
                    )
                )
            end
        end
    end

    # Execute with automatic retry and parameter adjustment
    return safe_execute_with_fallback(
        construct_test_input, params,
        max_retries = 3, operation_name = "test_input_construction"
    )
end

# ============================================================================
# SAFE POLYNOMIAL CONSTRUCTION
# ============================================================================

"""
    safe_constructor(TR::test_input, degree::Int; 
                    basis::Symbol=:chebyshev, precision::PrecisionType=RationalPrecision,
                    verbose::Int=0, max_retries::Int=3)

Safe wrapper for Constructor with comprehensive error handling and automatic recovery.

This function provides enhanced polynomial construction with:
- Numerical stability monitoring
- Automatic parameter adjustment on failure
- Progress monitoring for large problems
- Detailed error diagnostics

# Arguments
- `TR::test_input`: Test input structure
- `degree::Int`: Polynomial degree
- `basis::Symbol=:chebyshev`: Polynomial basis (:chebyshev or :legendre)
- `precision::PrecisionType=RationalPrecision`: Precision type
- `verbose::Int=0`: Verbosity level
- `max_retries::Int=3`: Maximum retry attempts

# Returns
- `ApproxPoly`: Constructed polynomial approximation

# Throws
- `NumericalError`: If numerical instabilities occur
- `ComputationError`: If construction fails
- `ResourceError`: If resource limits are exceeded

# Examples
```julia
# Basic usage with error handling
TR = safe_test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
pol = safe_constructor(TR, 8)

# With custom parameters and retry logic
pol = safe_constructor(TR, 12, basis=:legendre, precision=AdaptivePrecision, max_retries=5)
```
"""
function safe_constructor(TR::test_input, degree::Int;
    basis::Symbol = :chebyshev, precision::PrecisionType = RationalPrecision,
    verbose::Int = 0, max_retries::Int = 3)

    # Comprehensive parameter validation
    validate_constructor_parameters(TR, degree, basis = basis, precision = precision)

    # Create parameter dictionary
    params = Dict{String, Any}(
        "degree" => degree,
        "basis" => basis,
        "precision" => precision,
        "verbose" => verbose
    )

    # Define the construction function with progress monitoring
    function construct_polynomial(;
        degree = degree,
        basis = basis,
        precision = precision,
        verbose = verbose
    )

        function construction_with_progress(progress::ComputationProgress)
            try
                update_progress!(progress, 0.1, "Validating parameters")

                # Additional numerical stability checks
                complexity = estimate_computation_complexity(TR.dim, degree, TR.GN)

                update_progress!(progress, 0.2, "Checking computational complexity")

                # Much more conservative memory limits
                if complexity["total_memory_mb"] > 1500  # > 1.5GB total
                    throw(
                        ResourceError(
                            "memory", complexity["total_memory_mb"], 1500,
                            "Reduce polynomial degree to ≤4 or reduce sample count significantly"
                        )
                    )
                end

                # Check if computation is feasible
                if !complexity["memory_feasible"]
                    throw(
                        ResourceError(
                            "memory", complexity["total_memory_mb"], 2000,
                            "Problem too large for available memory. Use degree ≤4 for dimensions ≥3"
                        )
                    )
                end

                if !complexity["time_feasible"]
                    @warn "Long computation time expected" estimated_time =
                        complexity["estimated_time_s"]
                end

                # Warn about all complexity issues
                for warning in complexity["warnings"]
                    @warn warning
                end

                update_progress!(progress, 0.3, "Constructing polynomial")

                # Monitor memory during construction
                check_memory_usage("polynomial_construction")

                # Construct the polynomial
                pol = Constructor(
                    TR,
                    degree,
                    basis = basis,
                    precision = precision,
                    verbose = verbose
                )

                update_progress!(progress, 0.7, "Validating coefficients")

                # Validate the resulting polynomial
                validate_polynomial_coefficients(pol.coeffs, "polynomial_construction")

                update_progress!(progress, 0.9, "Checking conditioning")

                # Check Vandermonde conditioning if available
                if hasfield(typeof(pol), :cond_vandermonde) && !isnan(pol.cond_vandermonde)
                    check_matrix_conditioning(
                        reshape([pol.cond_vandermonde], 1, 1),
                        "vandermonde_matrix",
                        max_condition = 1e12
                    )
                end

                update_progress!(progress, 1.0, "Construction completed")

                @info "Polynomial constructed successfully" degree = degree basis = basis l2_error =
                    pol.nrm condition_number = get(pol, :cond_vandermonde, "N/A")

                return pol

            catch e
                context = create_error_context("polynomial_construction", params)
                context["TR_dim"] = TR.dim
                context["TR_GN"] = TR.GN

                if isa(e, GlobtimError)
                    log_error_details(e, context)
                    rethrow(e)
                elseif isa(e, OutOfMemoryError)
                    throw(
                        ResourceError(
                            "memory", NaN, NaN,
                            "Reduce polynomial degree or sample count"
                        )
                    )
                elseif isa(e, SingularException) || isa(e, LinearAlgebra.LAPACKException)
                    throw(
                        NumericalError(
                            "polynomial_construction",
                            "Matrix singularity or LAPACK error: $e",
                            [
                                "Reduce polynomial degree",
                                "Increase sample count",
                                "Try different basis (Chebyshev vs Legendre)",
                                "Use AdaptivePrecision for better numerical stability"
                            ],
                            context
                        )
                    )
                else
                    throw(
                        ComputationError(
                            "polynomial_construction", "unexpected_error",
                            merge(context, Dict("original_error" => string(e))),
                            [
                                "Check input parameters",
                                "Try lower degree",
                                "Contact developers"
                            ]
                        )
                    )
                end
            end
        end

        # Execute with progress monitoring
        return with_progress_monitoring(
            construction_with_progress,
            "Polynomial Construction (degree $degree)",
            interruptible = true
        )
    end

    # Execute with automatic retry and parameter adjustment
    return safe_execute_with_fallback(
        construct_polynomial, params,
        max_retries = max_retries, operation_name = "polynomial_construction"
    )
end

# ============================================================================
# SAFE CRITICAL POINT ANALYSIS
# ============================================================================

"""
    safe_solve_polynomial_system(x, pol::ApproxPoly;
                                 solver::Symbol=:homotopy_continuation,
                                 max_retries::Int=2)

Safe wrapper for solve_polynomial_system with error handling.

# Arguments
- `x`: Polynomial variables
- `pol::ApproxPoly`: Polynomial approximation
- `solver::Symbol=:homotopy_continuation`: Solver to use (:homotopy_continuation or :msolve)
- `max_retries::Int=2`: Maximum retry attempts

# Returns
- `Vector{Vector{Float64}}`: Critical points found

# Throws
- `ComputationError`: If solver fails
"""
function safe_solve_polynomial_system(x, pol::ApproxPoly;
    solver::Symbol = :homotopy_continuation, max_retries::Int = 2)

    params = Dict{String, Any}(
        "degree" => pol.degree,
        "basis" => pol.basis,
        "solver" => solver
    )

    function solve_with_solver(; solver = solver, kwargs...)
        try
            @info "Attempting polynomial system solving" solver = solver degree = pol.degree

            if solver == :homotopy_continuation
                solutions = solve_polynomial_system(x, pol)
            else
                solutions = solve_polynomial_system(x, pol.dim, pol.degree, pol.coeffs,
                    basis = pol.basis, precision = pol.precision)
            end

            @info "Polynomial system solved successfully" solver = solver solution_count =
                length(solutions)
            return solutions

        catch e
            @error "Solver failed" solver = solver error = e

            context = create_error_context("polynomial_system_solving", params)
            context["solver_error"] = string(e)

            throw(
                ComputationError(
                    "polynomial_system_solving", "solver_failed",
                    context,
                    [
                        "Try different solver (homotopy_continuation or msolve)",
                        "Reduce polynomial degree",
                        "Try different basis (Chebyshev vs Legendre)",
                        "Use different precision type",
                        "Check for numerical instabilities in polynomial coefficients"
                    ]
                )
            )
        end
    end

    return safe_execute_with_fallback(
        solve_with_solver, params,
        max_retries = max_retries, operation_name = "polynomial_system_solving"
    )
end

"""
    safe_analyze_critical_points(f::Function, df::DataFrame, TR::test_input;
                                 enable_hessian::Bool=true, max_retries::Int=2, kwargs...)

Safe wrapper for analyze_critical_points with comprehensive error handling.

# Arguments
- `f::Function`: Objective function
- `df::DataFrame`: Critical points DataFrame
- `TR::test_input`: Test input structure
- `enable_hessian::Bool=true`: Enable Hessian-based classification
- `max_retries::Int=2`: Maximum retry attempts
- `kwargs...`: Additional arguments for analyze_critical_points

# Returns
- `Tuple{DataFrame, DataFrame}`: Enhanced critical points and minima DataFrames

# Throws
- `ComputationError`: If analysis fails
- `NumericalError`: If numerical issues occur
"""
function safe_analyze_critical_points(f::Function, df::DataFrame, TR::test_input;
    enable_hessian::Bool = true, max_retries::Int = 2, kwargs...)

    if nrow(df) == 0
        @warn "No critical points to analyze"
        return df, DataFrame()
    end

    params = Dict{String, Any}(
        "enable_hessian" => enable_hessian,
        "critical_point_count" => nrow(df)
    )
    merge!(params, Dict(string(k) => v for (k, v) in kwargs))

    function analyze_with_monitoring(; enable_hessian = enable_hessian, kwargs...)

        function analysis_with_progress(progress::ComputationProgress)
            try
                update_progress!(progress, 0.1, "Validating critical points")

                # Validate input DataFrame
                required_cols = [Symbol("x$i") for i in 1:(TR.dim)]
                missing_cols = setdiff(required_cols, names(df))
                if !isempty(missing_cols)
                    throw(
                        ComputationError(
                            "critical_point_analysis", "invalid_dataframe",
                            Dict("missing_columns" => missing_cols),
                            [
                                "Check DataFrame structure",
                                "Ensure all coordinate columns are present"
                            ]
                        )
                    )
                end

                update_progress!(progress, 0.2, "Starting BFGS refinement")

                # Monitor memory usage
                check_memory_usage("critical_point_analysis")

                # Perform the analysis
                df_enhanced, df_min = analyze_critical_points(
                    f, copy(df), TR;
                    enable_hessian = enable_hessian,
                    verbose = false,  # Suppress verbose output for cleaner error handling
                    kwargs...
                )

                update_progress!(progress, 0.8, "Validating results")

                # Validate results
                if nrow(df_enhanced) != nrow(df)
                    @warn "Row count changed during analysis" original = nrow(df) enhanced =
                        nrow(df_enhanced)
                end

                # Check for NaN values in critical results
                critical_cols = [:close, :converged]
                for col in critical_cols
                    if col in names(df_enhanced)
                        nan_count = count(ismissing, df_enhanced[!, col])
                        if nan_count > 0
                            @warn "Found missing values in critical analysis" column = col count =
                                nan_count
                        end
                    end
                end

                update_progress!(progress, 1.0, "Analysis completed")

                @info "Critical point analysis completed" original_points = nrow(df) enhanced_points =
                    nrow(df_enhanced) minima_found = nrow(df_min)

                return df_enhanced, df_min

            catch e
                context = create_error_context("critical_point_analysis", params)
                context["TR_dim"] = TR.dim
                context["critical_point_count"] = nrow(df)

                if isa(e, GlobtimError)
                    log_error_details(e, context)
                    rethrow(e)
                elseif isa(e, OutOfMemoryError)
                    throw(
                        ResourceError(
                            "memory", NaN, NaN,
                            "Reduce number of critical points or disable Hessian analysis"
                        )
                    )
                elseif occursin("Optim", string(e)) || occursin("BFGS", string(e))
                    throw(
                        ComputationError(
                            "critical_point_analysis", "optimization_failed",
                            merge(context, Dict("optim_error" => string(e))),
                            [
                                "Disable Hessian analysis (enable_hessian=false)",
                                "Adjust BFGS tolerances",
                                "Check objective function for discontinuities"
                            ]
                        )
                    )
                else
                    throw(
                        ComputationError(
                            "critical_point_analysis", "unexpected_error",
                            merge(context, Dict("original_error" => string(e))),
                            [
                                "Check function implementation",
                                "Try with enable_hessian=false",
                                "Contact developers"
                            ]
                        )
                    )
                end
            end
        end

        return with_progress_monitoring(
            analysis_with_progress,
            "Critical Point Analysis ($(nrow(df)) points)",
            interruptible = true
        )
    end

    return safe_execute_with_fallback(
        analyze_with_monitoring, params,
        max_retries = max_retries, operation_name = "critical_point_analysis"
    )
end

# ============================================================================
# COMPLETE WORKFLOW WRAPPER
# ============================================================================

"""
    safe_globtim_workflow(f::Function; dim::Int, center::Vector{Float64},
                         sample_range::Float64, degree::Int=6, GN::Int=100,
                         enable_hessian::Bool=true, basis::Symbol=:chebyshev,
                         precision::PrecisionType=RationalPrecision, max_retries::Int=3)

Complete safe workflow for Globtim analysis with comprehensive error handling.

This function provides a complete end-to-end analysis workflow with automatic
error recovery, progress monitoring, and detailed diagnostics.

# Arguments
- `f::Function`: Objective function to analyze
- `dim::Int`: Problem dimension
- `center::Vector{Float64}`: Center point for analysis
- `sample_range::Float64`: Sampling range around center
- `degree::Int=6`: Polynomial degree (conservative default)
- `GN::Int=100`: Number of sample points
- `enable_hessian::Bool=true`: Enable Hessian-based critical point classification
- `basis::Symbol=:chebyshev`: Polynomial basis
- `precision::PrecisionType=RationalPrecision`: Precision type
- `max_retries::Int=3`: Maximum retry attempts for each stage

# Returns
- `NamedTuple`: Complete analysis results including:
  - `test_input`: Test input structure
  - `polynomial`: Polynomial approximation
  - `critical_points`: Raw critical points
  - `critical_points_enhanced`: Enhanced critical points with classification
  - `minima`: Identified minima
  - `analysis_summary`: Summary statistics

# Throws
- Various `GlobtimError` types if analysis fails completely

# Examples
```julia
# Basic usage
f(x) = sum(x.^2) + 0.1*prod(x)
results = safe_globtim_workflow(f, dim=2, center=[0.0, 0.0], sample_range=2.0)

# Access results
println("L2 error: ", results.polynomial.nrm)
println("Critical points found: ", nrow(results.critical_points))
println("Minima identified: ", nrow(results.minima))

# Advanced usage with custom parameters
results = safe_globtim_workflow(
    complex_function,
    dim=3, center=zeros(3), sample_range=5.0,
    degree=10, GN=500, basis=:legendre,
    precision=AdaptivePrecision, max_retries=5
)
```
"""
function safe_globtim_workflow(f::Function; dim::Int, center::Vector{Float64},
    sample_range::Float64, degree::Int = 6, GN::Int = 100,
    enable_hessian::Bool = true, basis::Symbol = :chebyshev,
    precision::PrecisionType = RationalPrecision, max_retries::Int = 3)

    workflow_start_time = time()

    @info "Starting safe Globtim workflow" dim = dim degree = degree sample_count = GN basis =
        basis precision = precision

    try
        # Stage 1: Create test input
        @info "Stage 1: Creating test input"
        TR = safe_test_input(
            f,
            dim = dim,
            center = center,
            sample_range = sample_range,
            GN = GN
        )

        # Stage 2: Construct polynomial approximation
        @info "Stage 2: Constructing polynomial approximation"
        pol = safe_constructor(
            TR,
            degree,
            basis = basis,
            precision = precision,
            max_retries = max_retries
        )

        # Stage 3: Find critical points
        @info "Stage 3: Finding critical points"
        @polyvar x[1:dim]
        solutions = safe_solve_polynomial_system(x, pol, max_retries = max_retries)

        # Stage 4: Process critical points
        @info "Stage 4: Processing critical points"
        df_critical = process_crit_pts(solutions, f, TR)

        # Stage 5: Enhanced analysis (if critical points found)
        df_enhanced = DataFrame()
        df_min = DataFrame()

        if nrow(df_critical) > 0
            @info "Stage 5: Enhanced critical point analysis"
            df_enhanced, df_min = safe_analyze_critical_points(
                f, df_critical, TR,
                enable_hessian = enable_hessian,
                max_retries = max_retries
            )
        else
            @warn "No critical points found - skipping enhanced analysis"
            df_enhanced = df_critical
        end

        # Create analysis summary
        workflow_time = time() - workflow_start_time

        analysis_summary = Dict{String, Any}(
            "workflow_time_seconds" => workflow_time,
            "polynomial_degree" => degree,
            "polynomial_basis" => basis,
            "precision_type" => precision,
            "l2_approximation_error" => pol.nrm,
            "condition_number" => get(pol, :cond_vandermonde, NaN),
            "sample_count" => GN,
            "critical_points_found" => nrow(df_critical),
            "critical_points_analyzed" => nrow(df_enhanced),
            "minima_identified" => nrow(df_min),
            "hessian_analysis_enabled" => enable_hessian,
            "workflow_completed_successfully" => true
        )

        # Add convergence statistics if available
        if nrow(df_enhanced) > 0 && :converged in names(df_enhanced)
            converged_count = count(df_enhanced.converged)
            analysis_summary["bfgs_convergence_rate"] = converged_count / nrow(df_enhanced)
        end

        @info "Workflow completed successfully" total_time = workflow_time critical_points =
            nrow(df_critical) minima = nrow(df_min)

        # Return comprehensive results
        return (
            test_input = TR,
            polynomial = pol,
            critical_points = df_critical,
            critical_points_enhanced = df_enhanced,
            minima = df_min,
            analysis_summary = analysis_summary
        )

    catch e
        workflow_time = time() - workflow_start_time

        @error "Workflow failed" total_time = workflow_time error = e

        # Create failure summary
        failure_summary = Dict{String, Any}(
            "workflow_time_seconds" => workflow_time,
            "workflow_completed_successfully" => false,
            "failure_stage" => "unknown",
            "error_type" => string(typeof(e)),
            "error_message" => string(e)
        )

        # Try to determine failure stage from error context
        if isa(e, GlobtimError) && hasfield(typeof(e), :context) &&
           haskey(e.context, "operation")
            failure_summary["failure_stage"] = e.context["operation"]
        end

        # Log detailed error information
        if isa(e, GlobtimError)
            log_error_details(
                e,
                Dict(
                    "workflow_params" => Dict(
                        "dim" => dim, "degree" => degree, "GN" => GN,
                        "basis" => basis, "precision" => precision
                    )
                )
            )
        end

        # Re-throw the error with additional context
        rethrow(e)
    end
end

# ============================================================================
# UTILITY FUNCTIONS FOR SAFE WRAPPERS
# ============================================================================

"""
    diagnose_globtim_setup()

Diagnose Globtim setup and dependencies for troubleshooting.

# Returns
- `Dict{String,Any}`: Diagnostic information
"""
function diagnose_globtim_setup()
    diagnostics = Dict{String, Any}(
        "julia_version" => string(VERSION),
        "globtim_loaded" => true,
        "timestamp" => Dates.now()
    )

    # Check required packages
    required_packages = [
        "DynamicPolynomials", "DataFrames", "LinearAlgebra",
        "Optim", "ForwardDiff", "HomotopyContinuation"
    ]

    package_status = Dict{String, Bool}()
    for pkg in required_packages
        try
            eval(:(using $(Symbol(pkg))))
            package_status[pkg] = true
        catch
            package_status[pkg] = false
        end
    end

    diagnostics["package_status"] = package_status

    # Check memory
    try
        gc_stats = Base.gc_num()
        diagnostics["memory_allocated_mb"] = gc_stats.allocd / 1024^2
    catch
        diagnostics["memory_allocated_mb"] = "unknown"
    end

    # Check for common issues
    issues = String[]

    if !package_status["Optim"]
        push!(issues, "Optim.jl not available - BFGS refinement will fail")
    end

    if !package_status["HomotopyContinuation"]
        push!(
            issues,
            "HomotopyContinuation.jl not available - polynomial system solving may fail"
        )
    end

    diagnostics["potential_issues"] = issues
    diagnostics["setup_healthy"] = isempty(issues)

    return diagnostics
end
