# Conservative Valley Walking with Function Value Validation
#
# This module implements a very conservative valley walking algorithm that strictly
# validates each step by ensuring function values remain low (decrease or stay constant).

using LinearAlgebra
using ForwardDiff

"""
    ConservativeValleyConfig

Conservative configuration for valley walking with strict function value validation.

# Fields
- `initial_step_size::Float64`: Initial step size (default: 1e-5, very small!)
- `min_step_size::Float64`: Minimum step size before giving up (default: 1e-12)
- `max_step_size::Float64`: Maximum allowed step size (default: 1e-3)
- `function_tolerance::Float64`: Maximum allowed function value increase (default: 1e-12)
- `require_decrease::Bool`: Require function value to decrease (default: false, allow constant)
- `step_reduction_factor::Float64`: Factor to reduce step when f increases (default: 0.5)
- `step_increase_factor::Float64`: Factor to increase step when f decreases (default: 1.05)
- `max_steps::Int`: Maximum number of steps (default: 2000)
- `gradient_tolerance::Float64`: Gradient norm tolerance for critical points (default: 1e-10)
- `eigenvalue_threshold::Float64`: Threshold for zero eigenvalues (default: 1e-8)
"""
struct ConservativeValleyConfig
    initial_step_size::Float64
    min_step_size::Float64
    max_step_size::Float64
    function_tolerance::Float64
    require_decrease::Bool
    step_reduction_factor::Float64
    step_increase_factor::Float64
    max_steps::Int
    gradient_tolerance::Float64
    eigenvalue_threshold::Float64

    function ConservativeValleyConfig(;
        initial_step_size::Float64 = 1e-5,
        min_step_size::Float64 = 1e-12,
        max_step_size::Float64 = 1e-3,
        function_tolerance::Float64 = 1e-12,
        require_decrease::Bool = false,
        step_reduction_factor::Float64 = 0.5,
        step_increase_factor::Float64 = 1.05,
        max_steps::Int = 2000,
        gradient_tolerance::Float64 = 1e-10,
        eigenvalue_threshold::Float64 = 1e-8
    )
        new(initial_step_size, min_step_size, max_step_size, function_tolerance,
            require_decrease, step_reduction_factor, step_increase_factor, max_steps,
            gradient_tolerance, eigenvalue_threshold)
    end
end

"""
    ConservativeValleyStep

Result of a single conservative valley walking step.

# Fields
- `point::Vector{Float64}`: The point location
- `function_value::Float64`: Function value at this point
- `gradient_norm::Float64`: Gradient norm at this point
- `min_eigenvalue::Float64`: Smallest eigenvalue magnitude
- `is_valley::Bool`: Whether this point is in a valley
- `step_size::Float64`: Step size used to reach this point
- `step_accepted::Bool`: Whether this step was accepted
"""
struct ConservativeValleyStep
    point::Vector{Float64}
    function_value::Float64
    gradient_norm::Float64
    min_eigenvalue::Float64
    is_valley::Bool
    step_size::Float64
    step_accepted::Bool
end

"""
    conservative_valley_walk(f, start_point::Vector{Float64}, direction::Vector{Float64}, 
                            config::ConservativeValleyConfig = ConservativeValleyConfig())

Perform conservative valley walking in a specific direction with strict function value validation.

This algorithm takes extremely small steps and validates each step by ensuring:
1. Function value does not increase beyond tolerance
2. Gradient remains small (critical point condition)
3. Hessian remains rank-deficient (valley condition)

# Arguments
- `f`: Objective function
- `start_point::Vector{Float64}`: Starting point (should be a critical point in valley)
- `direction::Vector{Float64}`: Direction to walk (should be valley direction)
- `config::ConservativeValleyConfig`: Configuration parameters

# Returns
- `Vector{ConservativeValleyStep}`: Sequence of validated steps along valley
- `String`: Termination reason

# Examples
```julia
f = x -> x[1]^4 + x[2]^2  # Valley along x[1] = 0
start_point = [0.0, 0.0]
direction = [0.0, 1.0]    # Walk along y-axis

config = ConservativeValleyConfig(initial_step_size=1e-6)
steps, reason = conservative_valley_walk(f, start_point, direction, config)

println("Walked \$(length(steps)) steps, terminated: \$reason")
```
"""
function conservative_valley_walk(f, start_point::Vector{Float64},
    direction::Vector{Float64},
    config::ConservativeValleyConfig = ConservativeValleyConfig())

    # Normalize direction vector
    direction = direction / norm(direction)

    # Initialize
    steps = ConservativeValleyStep[]
    current_point = copy(start_point)
    current_step_size = config.initial_step_size

    # Validate starting point
    start_f = f(start_point)
    start_grad = ForwardDiff.gradient(f, start_point)
    start_hess = ForwardDiff.hessian(f, start_point)
    start_eigenvals = eigvals(start_hess)
    start_min_eigenval = minimum(abs.(start_eigenvals))

    # Check if starting point is valid
    if norm(start_grad) > config.gradient_tolerance
        return steps,
        "Starting point is not a critical point (gradient too large: $(norm(start_grad)))"
    end

    if start_min_eigenval > config.eigenvalue_threshold
        return steps,
        "Starting point is not in a valley (no small eigenvalues: $(start_min_eigenval))"
    end

    # Add starting point to steps
    push!(
        steps,
        ConservativeValleyStep(
            copy(start_point), start_f, norm(start_grad), start_min_eigenval,
            true, 0.0, true
        )
    )

    @info "Starting conservative valley walk from f=$(start_f), grad_norm=$(norm(start_grad))"

    # Main walking loop
    for step_num in 1:(config.max_steps)
        # Propose new point
        candidate_point = current_point + current_step_size * direction

        # Evaluate function at candidate point
        candidate_f = f(candidate_point)
        f_change = candidate_f - steps[end].function_value

        # Check function value constraint
        function_valid = if config.require_decrease
            f_change <= -config.function_tolerance
        else
            f_change <= config.function_tolerance
        end

        if !function_valid
            # Function value increased too much - reduce step size
            current_step_size *= config.step_reduction_factor

            # Check if step size is too small
            if current_step_size < config.min_step_size
                return steps,
                "Step size became too small: $(current_step_size) < $(config.min_step_size)"
            end

            @debug "Function value increased by $(f_change), reducing step to $(current_step_size)"

            # Record failed step
            candidate_grad = ForwardDiff.gradient(f, candidate_point)
            candidate_hess = ForwardDiff.hessian(f, candidate_point)
            candidate_eigenvals = eigvals(candidate_hess)
            candidate_min_eigenval = minimum(abs.(candidate_eigenvals))

            push!(
                steps,
                ConservativeValleyStep(
                    copy(candidate_point), candidate_f, norm(candidate_grad),
                    candidate_min_eigenval, false, current_step_size, false
                )
            )

            continue  # Try again with smaller step
        end

        # Function value is acceptable - now check valley conditions
        candidate_grad = ForwardDiff.gradient(f, candidate_point)
        candidate_hess = ForwardDiff.hessian(f, candidate_point)
        candidate_eigenvals = eigvals(candidate_hess)
        candidate_min_eigenval = minimum(abs.(candidate_eigenvals))

        # Check if we're still at a critical point
        if norm(candidate_grad) > config.gradient_tolerance
            return steps,
            "Left critical point region (gradient norm: $(norm(candidate_grad)))"
        end

        # Check if we're still in a valley
        if candidate_min_eigenval > config.eigenvalue_threshold
            return steps, "Left valley region (min eigenvalue: $(candidate_min_eigenval))"
        end

        # Step is valid! Accept it
        is_valley = candidate_min_eigenval <= config.eigenvalue_threshold

        push!(
            steps,
            ConservativeValleyStep(
                copy(candidate_point), candidate_f, norm(candidate_grad),
                candidate_min_eigenval, is_valley, current_step_size, true
            )
        )

        current_point = candidate_point

        @debug "Step $(step_num) accepted: f=$(candidate_f), change=$(f_change), step_size=$(current_step_size)"

        # Adaptive step size: if function decreased, we can try slightly larger steps
        if f_change < -config.function_tolerance
            current_step_size =
                min(current_step_size * config.step_increase_factor, config.max_step_size)
        end
    end

    return steps, "Maximum steps reached: $(config.max_steps)"
end

"""
    validate_valley_point(f, point::Vector{Float64}, config::ConservativeValleyConfig)

Validate that a point satisfies valley conditions (critical point + rank-deficient Hessian).

# Returns
- `Bool`: Whether point is valid valley point
- `String`: Validation message
- `NamedTuple`: Detailed validation metrics
"""
function validate_valley_point(f, point::Vector{Float64}, config::ConservativeValleyConfig)
    grad = ForwardDiff.gradient(f, point)
    hess = ForwardDiff.hessian(f, point)
    eigenvals = eigvals(hess)

    grad_norm = norm(grad)
    min_eigenval = minimum(abs.(eigenvals))

    is_critical = grad_norm <= config.gradient_tolerance
    is_valley = min_eigenval <= config.eigenvalue_threshold

    is_valid = is_critical && is_valley

    message = if !is_critical
        "Not a critical point (gradient norm: $(grad_norm))"
    elseif !is_valley
        "Not in valley (min eigenvalue: $(min_eigenval))"
    else
        "Valid valley point"
    end

    metrics = (
        gradient_norm = grad_norm,
        min_eigenvalue = min_eigenval,
        is_critical = is_critical,
        is_valley = is_valley,
        function_value = f(point)
    )

    return is_valid, message, metrics
end

"""
    explore_valley_manifold_conservative(f, seed_point::Vector{Float64}, 
                                       config::ConservativeValleyConfig = ConservativeValleyConfig())

Explore a valley manifold in all directions using conservative walking.

Starting from a seed point, this function identifies valley directions and explores
the manifold in both positive and negative directions for each valley direction.

# Returns
- `Dict{String, Vector{ConservativeValleyStep}}`: Steps in each direction
- `Dict{String, String}`: Termination reasons for each direction
- `NamedTuple`: Summary statistics
"""
function explore_valley_manifold_conservative(f, seed_point::Vector{Float64},
    config::ConservativeValleyConfig = ConservativeValleyConfig())

    # Validate seed point
    is_valid, message, metrics = validate_valley_point(f, seed_point, config)
    if !is_valid
        error("Seed point is not valid: $message")
    end

    @info "Exploring valley manifold from valid seed point (f=$(metrics.function_value))"

    # Get valley directions from Hessian nullspace
    hess = ForwardDiff.hessian(f, seed_point)
    eigendecomp = eigen(hess)
    eigenvals = eigendecomp.values
    eigenvecs = eigendecomp.vectors

    # Find valley directions (eigenvectors with small eigenvalues)
    valley_mask = abs.(eigenvals) .<= config.eigenvalue_threshold
    valley_directions = eigenvecs[:, valley_mask]

    @info "Found $(sum(valley_mask)) valley directions"

    # Explore in each direction (positive and negative)
    all_steps = Dict{String, Vector{ConservativeValleyStep}}()
    termination_reasons = Dict{String, String}()

    for (i, direction) in enumerate(eachcol(valley_directions))
        # Positive direction
        pos_key = "direction_$(i)_positive"
        steps_pos, reason_pos = conservative_valley_walk(f, seed_point, direction, config)
        all_steps[pos_key] = steps_pos
        termination_reasons[pos_key] = reason_pos

        # Negative direction
        neg_key = "direction_$(i)_negative"
        steps_neg, reason_neg = conservative_valley_walk(f, seed_point, -direction, config)
        all_steps[neg_key] = steps_neg
        termination_reasons[neg_key] = reason_neg

        @info "Direction $i: +$(length(steps_pos)) steps, -$(length(steps_neg)) steps"
    end

    # Compute summary statistics
    total_steps = sum(length(steps) for steps in values(all_steps))
    total_accepted =
        sum(sum(step.step_accepted for step in steps) for steps in values(all_steps))

    all_function_values = Float64[]
    for steps in values(all_steps)
        for step in steps
            if step.step_accepted
                push!(all_function_values, step.function_value)
            end
        end
    end

    summary = (
        total_steps = total_steps,
        total_accepted = total_accepted,
        acceptance_rate = total_accepted / max(total_steps, 1),
        min_function_value = length(all_function_values) > 0 ?
                             minimum(all_function_values) : metrics.function_value,
        max_function_value = length(all_function_values) > 0 ?
                             maximum(all_function_values) : metrics.function_value,
        function_value_range = length(all_function_values) > 0 ?
                               maximum(all_function_values) - minimum(all_function_values) : 0.0,
        valley_dimension = sum(valley_mask)
    )

    return all_steps, termination_reasons, summary
end
