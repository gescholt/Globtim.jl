# DaggerWorkerContext.jl - Worker Context Management for Issue #53
# Ensures proper package import context in Dagger distributed workers

module DaggerWorkerContext

using Distributed
using Dagger
using LinearAlgebra

export setup_worker_context, validate_worker_packages, initialize_dagger_workers
export create_worker_safe_task, run_with_worker_validation, get_worker_diagnostics

# Worker context configuration
struct WorkerContextConfig
    required_packages::Vector{String}
    initialization_functions::Vector{Function}
    validation_timeout::Int
    max_retries::Int

    function WorkerContextConfig(;
        required_packages = ["LinearAlgebra", "Dagger"],
        initialization_functions = Function[],
        validation_timeout = 30,
        max_retries = 3
    )
        new(required_packages, initialization_functions, validation_timeout, max_retries)
    end
end

const DEFAULT_CONFIG = WorkerContextConfig()

# Worker validation result
struct WorkerValidationResult
    worker_id::Int
    success::Bool
    available_packages::Vector{String}
    missing_packages::Vector{String}
    error_details::Union{String, Nothing}
    julia_version::VersionNumber

    function WorkerValidationResult(worker_id::Int, success::Bool;
                                  available_packages=String[],
                                  missing_packages=String[],
                                  error_details=nothing,
                                  julia_version=VERSION)
        new(worker_id, success, available_packages, missing_packages, error_details, julia_version)
    end
end

"""
    setup_worker_context(config::WorkerContextConfig = DEFAULT_CONFIG) -> Dict{Int, Bool}

Set up package context on all available workers.
"""
function setup_worker_context(config::WorkerContextConfig = DEFAULT_CONFIG)::Dict{Int, Bool}
    results = Dict{Int, Bool}()

    # Initialize packages on all workers
    @everywhere using LinearAlgebra
    @everywhere using Dagger

    # Additional package loading based on configuration
    for package in config.required_packages
        if package ∉ ["LinearAlgebra", "Dagger"]  # Already loaded above
            try
                @eval @everywhere using $(Symbol(package))
            catch e
                @warn "Failed to load package $package on workers: $e"
            end
        end
    end

    # Run custom initialization functions
    for init_func in config.initialization_functions
        try
            @everywhere $init_func()
        catch e
            @warn "Worker initialization function failed: $e"
        end
    end

    # Validate setup on each worker
    for worker_id in workers()
        results[worker_id] = validate_single_worker(worker_id, config)
    end

    return results
end

"""
    validate_single_worker(worker_id::Int, config::WorkerContextConfig) -> Bool

Validate package context on a single worker.
"""
function validate_single_worker(worker_id::Int, ::WorkerContextConfig)::Bool
    try
        # Test basic LinearAlgebra functionality
        test_result = remotecall_fetch(worker_id) do
            try
                using LinearAlgebra
                # Test norm function
                test_vector = [3.0, 4.0]
                norm_result = norm(test_vector)
                expected = 5.0

                return (
                    success = true,
                    norm_result = norm_result,
                    correct = abs(norm_result - expected) < 1e-10,
                    packages_available = true
                )
            catch e
                return (
                    success = false,
                    error = string(e),
                    packages_available = false
                )
            end
        end

        return test_result.success && test_result.correct
    catch e
        @warn "Worker validation failed for worker $worker_id: $e"
        return false
    end
end

"""
    validate_worker_packages(config::WorkerContextConfig = DEFAULT_CONFIG) -> Vector{WorkerValidationResult}

Comprehensive validation of worker package contexts.
"""
function validate_worker_packages(config::WorkerContextConfig = DEFAULT_CONFIG)::Vector{WorkerValidationResult}
    results = WorkerValidationResult[]

    for worker_id in workers()
        try
            validation_result = remotecall_fetch(worker_id) do
                available_packages = String[]
                missing_packages = String[]
                error_details = nothing

                try
                    # Test required packages
                    for package in config.required_packages
                        try
                            pkg_symbol = Symbol(package)
                            @eval using $pkg_symbol
                            push!(available_packages, package)

                            # Special validation for LinearAlgebra
                            if package == "LinearAlgebra"
                                test_vector = [1.0, 2.0, 3.0]
                                norm_result = norm(test_vector)
                                if !(norm_result ≈ sqrt(14))
                                    error_details = "LinearAlgebra.norm function not working correctly"
                                end
                            end

                        catch e
                            push!(missing_packages, package)
                            if error_details === nothing
                                error_details = "Failed to load $package: $(string(e))"
                            end
                        end
                    end

                    success = isempty(missing_packages) && error_details === nothing

                    return (
                        success = success,
                        available_packages = available_packages,
                        missing_packages = missing_packages,
                        error_details = error_details,
                        julia_version = VERSION
                    )

                catch e
                    return (
                        success = false,
                        available_packages = String[],
                        missing_packages = config.required_packages,
                        error_details = "Worker validation error: $(string(e))",
                        julia_version = VERSION
                    )
                end
            end

            push!(results, WorkerValidationResult(
                worker_id,
                validation_result.success,
                available_packages = validation_result.available_packages,
                missing_packages = validation_result.missing_packages,
                error_details = validation_result.error_details,
                julia_version = validation_result.julia_version
            ))

        catch e
            push!(results, WorkerValidationResult(
                worker_id,
                false,
                error_details = "Remote call failed: $(string(e))"
            ))
        end
    end

    return results
end

"""
    initialize_dagger_workers(n_workers::Int = 2; config::WorkerContextConfig = DEFAULT_CONFIG) -> Bool

Initialize Dagger workers with proper package context.
"""
function initialize_dagger_workers(n_workers::Int = 2; config::WorkerContextConfig = DEFAULT_CONFIG)::Bool
    try
        # Add workers if needed
        current_workers = length(workers())
        if current_workers < n_workers
            addprocs(n_workers - current_workers)
        end

        # Setup context on all workers
        _ = setup_worker_context(config)

        # Validate all workers
        validation_results = validate_worker_packages(config)

        all_valid = all(result -> result.success, validation_results)

        if !all_valid
            failed_workers = [result.worker_id for result in validation_results if !result.success]
            @warn "Worker initialization failed for workers: $failed_workers"
        end

        return all_valid

    catch e
        @error "Failed to initialize Dagger workers: $e"
        return false
    end
end

"""
    create_worker_safe_task(func::Function, args...; config::WorkerContextConfig = DEFAULT_CONFIG)

Create a Dagger task with worker context validation.
"""
function create_worker_safe_task(func::Function, args...; ::WorkerContextConfig = DEFAULT_CONFIG)
    # Create wrapper function that ensures package context
    wrapper_func = function(input_args...)
        # Ensure LinearAlgebra is available
        try
            using LinearAlgebra
            using Dagger
        catch e
            throw(ErrorException("Worker package context error: $(string(e))"))
        end

        # Validate LinearAlgebra.norm is working
        try
            test_norm = norm([1.0, 0.0])
            if !(test_norm ≈ 1.0)
                throw(ErrorException("LinearAlgebra.norm validation failed"))
            end
        catch e
            throw(ErrorException("LinearAlgebra.norm context validation error: $(string(e))"))
        end

        # Execute the actual function
        return func(input_args...)
    end

    return Dagger.@spawn wrapper_func(args...)
end

"""
    run_with_worker_validation(func::Function, args...; config::WorkerContextConfig = DEFAULT_CONFIG)

Run a function with automatic worker validation and context setup.
"""
function run_with_worker_validation(func::Function, args...; config::WorkerContextConfig = DEFAULT_CONFIG)
    # Validate workers first
    validation_results = validate_worker_packages(config)
    failed_workers = [result.worker_id for result in validation_results if !result.success]

    if !isempty(failed_workers)
        @warn "Attempting to fix failed workers: $failed_workers"

        # Try to fix worker contexts
        _ = setup_worker_context(config)

        # Re-validate
        revalidation_results = validate_worker_packages(config)
        still_failed = [result.worker_id for result in revalidation_results if !result.success]

        if !isempty(still_failed)
            throw(ErrorException("Cannot fix worker context on workers: $still_failed"))
        end
    end

    # Create and execute worker-safe task
    task = create_worker_safe_task(func, args...)
    return fetch(task)
end

"""
    get_worker_diagnostics(config::WorkerContextConfig = DEFAULT_CONFIG) -> Dict{String, Any}

Get comprehensive diagnostics for all workers.
"""
function get_worker_diagnostics(config::WorkerContextConfig = DEFAULT_CONFIG)::Dict{String, Any}
    diagnostics = Dict{String, Any}(
        "timestamp" => now(),
        "total_workers" => length(workers()),
        "worker_details" => Dict{Int, Any}(),
        "summary" => Dict{String, Any}()
    )

    # Get detailed diagnostics for each worker
    validation_results = validate_worker_packages(config)

    successful_workers = 0
    failed_workers = 0

    for result in validation_results
        worker_info = Dict{String, Any}(
            "success" => result.success,
            "julia_version" => result.julia_version,
            "available_packages" => result.available_packages,
            "missing_packages" => result.missing_packages
        )

        if result.error_details !== nothing
            worker_info["error_details"] = result.error_details
        end

        diagnostics["worker_details"][result.worker_id] = worker_info

        if result.success
            successful_workers += 1
        else
            failed_workers += 1
        end
    end

    # Summary statistics
    diagnostics["summary"] = Dict{String, Any}(
        "successful_workers" => successful_workers,
        "failed_workers" => failed_workers,
        "success_rate" => successful_workers / (successful_workers + failed_workers),
        "all_workers_valid" => failed_workers == 0
    )

    return diagnostics
end

"""
    mathematical_worker_test(test_data::Vector{Vector{Float64}}) -> Vector{Float64}

Test function for mathematical operations in distributed workers.
"""
function mathematical_worker_test(test_data::Vector{Vector{Float64}})::Vector{Float64}
    # This function tests LinearAlgebra operations in a Dagger context
    using LinearAlgebra

    results = Float64[]
    for vector in test_data
        # Multiple LinearAlgebra operations
        norm_result = norm(vector)
        normalized = vector / norm_result
        _ = dot(normalized, normalized)  # Should be ≈ 1.0 (validation check)

        push!(results, norm_result)
    end

    return results
end

"""
    repair_worker_context!(worker_id::Int, config::WorkerContextConfig = DEFAULT_CONFIG) -> Bool

Attempt to repair worker context for a specific worker.
"""
function repair_worker_context!(worker_id::Int, config::WorkerContextConfig = DEFAULT_CONFIG)::Bool
    try
        # Force package reloading on specific worker
        repair_result = remotecall_fetch(worker_id) do
            try
                # Clear any potentially corrupted state
                for package in config.required_packages
                    pkg_symbol = Symbol(package)
                    try
                        # Force reload
                        @eval using $pkg_symbol
                    catch _
                        # If standard using fails, try Base.require
                        Base.require(Main, pkg_symbol)
                    end
                end

                # Test functionality
                using LinearAlgebra
                test_vector = [1.0, 2.0, 3.0]
                norm_result = norm(test_vector)
                expected = sqrt(14)

                return abs(norm_result - expected) < 1e-10

            catch _
                return false
            end
        end

        return repair_result

    catch e
        @warn "Failed to repair worker $worker_id: $e"
        return false
    end
end

# Convenience functions
"""
    quick_worker_check() -> Bool

Quick check if all workers have proper LinearAlgebra context.
"""
function quick_worker_check()::Bool
    validation_results = validate_worker_packages()
    return all(result -> result.success, validation_results)
end

"""
    auto_fix_workers() -> Bool

Automatically attempt to fix all worker context issues.
"""
function auto_fix_workers()::Bool
    if quick_worker_check()
        return true
    end

    # Setup context
    setup_worker_context()

    # Validate again
    return quick_worker_check()
end

end # module DaggerWorkerContext