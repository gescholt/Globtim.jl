"""
capability_detection.jl

Auto-detection of ForwardDiff compatibility for objective functions.
Resolves GitHub Issue #2: Graceful handling of complex-valued functions.

This module provides:
1. Detection of ForwardDiff compatibility at runtime
2. Automatic feature toggle adjustment
3. User warnings about disabled features

Background:
-----------
ForwardDiff.jl fails on functions using complex arithmetic (SAR imaging,
Fourier series, etc.) because it creates Complex{Dual} types that many
Julia functions don't support. This module detects such incompatibilities
and automatically disables gradient/Hessian-dependent features.

Created: 2025-11-17
"""

using ForwardDiff
using LinearAlgebra
using Accessors

# =============================================================================
# Core Data Structures
# =============================================================================

"""
    CapabilityReport

Results from ForwardDiff capability detection.

# Fields
- `gradient_compatible::Bool` - Can compute gradients with ForwardDiff
- `hessian_compatible::Bool` - Can compute Hessians with ForwardDiff
- `error_message::Union{String, Nothing}` - Description of failure (if any)
- `test_point::Vector{Float64}` - Point where detection was performed
- `detection_time::Float64` - Time taken for detection (seconds)

# Notes
- If `gradient_compatible` is false, `hessian_compatible` will also be false
  (can't compute Hessian if gradient fails)
- `error_message` contains exception details for debugging
"""
struct CapabilityReport
    gradient_compatible::Bool
    hessian_compatible::Bool
    error_message::Union{String, Nothing}
    test_point::Vector{Float64}
    detection_time::Float64
end

# =============================================================================
# Helper Functions
# =============================================================================

"""
    _choose_test_point(domain_bounds::Vector{Tuple{Float64, Float64}}) -> Vector{Float64}

Choose a representative test point in the domain (center of bounds).

# Arguments
- `domain_bounds::Vector{Tuple{Float64, Float64}}` - Domain bounds [(min, max), ...]

# Returns
`Vector{Float64}`: Center point of domain

# Example
```julia
bounds = [(-1.0, 1.0), (-2.0, 2.0)]
test_point = _choose_test_point(bounds)  # [0.0, 0.0]
```
"""
function _choose_test_point(domain_bounds::Vector{Tuple{Float64, Float64}})
    return [(bounds[1] + bounds[2]) / 2.0 for bounds in domain_bounds]
end

"""
    _test_gradient_compatibility(f::Function, test_point::Vector{Float64}) -> (Bool, Union{String, Nothing})

Test if ForwardDiff can compute gradient at test point.

# Arguments
- `f::Function` - Objective function to test
- `test_point::Vector{Float64}` - Point to evaluate at

# Returns
- `Bool`: true if gradient computation succeeds
- `Union{String, Nothing}`: Error message if failed, nothing if succeeded

# Implementation Details
Catches all exceptions and checks for NaN/Inf in gradient.
"""
function _test_gradient_compatibility(f::Function, test_point::Vector{Float64})
    try
        g = ForwardDiff.gradient(f, test_point)

        # Check for NaN or Inf in gradient
        if !all(isfinite, g)
            return (false, "Gradient contains NaN or Inf")
        end

        return (true, nothing)
    catch e
        # Capture exception details
        error_msg = string(typeof(e)) * ": " * string(e)
        return (false, error_msg)
    end
end

"""
    _test_hessian_compatibility(f::Function, test_point::Vector{Float64}) -> (Bool, Union{String, Nothing})

Test if ForwardDiff can compute Hessian at test point.

# Arguments
- `f::Function` - Objective function to test
- `test_point::Vector{Float64}` - Point to evaluate at

# Returns
- `Bool`: true if Hessian computation succeeds
- `Union{String, Nothing}`: Error message if failed, nothing if succeeded

# Implementation Details
Only called if gradient test passes. Catches all exceptions and checks for NaN/Inf.
"""
function _test_hessian_compatibility(f::Function, test_point::Vector{Float64})
    try
        H = ForwardDiff.hessian(f, test_point)

        # Check for NaN or Inf in Hessian
        if !all(isfinite, H)
            return (false, "Hessian contains NaN or Inf")
        end

        return (true, nothing)
    catch e
        # Capture exception details
        error_msg = string(typeof(e)) * ": " * string(e)
        return (false, error_msg)
    end
end

# =============================================================================
# Main Detection Function
# =============================================================================

"""
    detect_forwarddiff_capabilities(
        f::Function,
        dimension::Int,
        domain_bounds::Vector{Tuple{Float64, Float64}},
        config
    ) -> CapabilityReport

Detect ForwardDiff compatibility by attempting differentiation at a test point.

Tests at the center of the domain:
1. Attempt gradient computation with ForwardDiff.gradient()
2. If gradient succeeds, attempt Hessian with ForwardDiff.hessian()
3. Capture any errors and classify compatibility

# Arguments
- `f::Function` - Objective function to test
- `dimension::Int` - Problem dimension
- `domain_bounds::Vector{Tuple{Float64, Float64}}` - Domain bounds
- `config` - Experiment configuration (checked for pre-disabled features)

# Returns
`CapabilityReport` with detection results

# Performance
Typically completes in < 100ms for most functions.

# Example
```julia
f(x) = sum(x.^2)
dimension = 3
bounds = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
config = ExperimentParams(...)

report = detect_forwarddiff_capabilities(f, dimension, bounds, config)
# => CapabilityReport(true, true, nothing, [0.0, 0.0, 0.0], 0.002)
```
"""
function detect_forwarddiff_capabilities(
    f::Function,
    dimension::Int,
    domain_bounds::Vector{Tuple{Float64, Float64}},
    config
)
    start_time = time()

    # Choose test point (center of domain)
    test_point = _choose_test_point(domain_bounds)

    # Test gradient computation
    gradient_ok, grad_error = _test_gradient_compatibility(f, test_point)

    # Test Hessian computation (only if gradient works)
    hessian_ok = false
    hessian_error = nothing

    if gradient_ok
        hessian_ok, hessian_error = _test_hessian_compatibility(f, test_point)
    else
        # If gradient fails, hessian will also fail
        hessian_error = "Skipped (gradient incompatible)"
    end

    # Determine final error message
    error_msg = nothing
    if !gradient_ok
        error_msg = "Gradient computation failed: $grad_error"
    elseif !hessian_ok && hessian_error !== nothing
        error_msg = "Hessian computation failed: $hessian_error"
    end

    detection_time = time() - start_time

    return CapabilityReport(
        gradient_ok,
        hessian_ok,
        error_msg,
        test_point,
        detection_time
    )
end

# =============================================================================
# Config Adjustment
# =============================================================================

"""
    apply_capability_adjustments(config, capabilities::CapabilityReport)

Apply auto-detected capability constraints to experiment configuration.

If ForwardDiff incompatibility is detected:
1. Disable affected features
2. Log warning to user (via @warn)
3. Return adjusted config

# Feature Toggle Logic
- If gradient incompatible: Disable gradient, hessian, AND BFGS
  (BFGS requires gradients, so must be disabled)
- If only hessian incompatible: Disable hessian only
  (Gradient and BFGS can still work)
- If both compatible: No changes

# Pre-Disabled Features
If user already disabled features manually, those remain disabled.
Auto-detection only disables additional features when incompatibility detected.

# Arguments
- `config` - Original ExperimentParams
- `capabilities::CapabilityReport` - Detection results

# Returns
Adjusted ExperimentParams with features disabled if incompatible

# Example
```julia
config = ExperimentParams(enable_gradient_computation=true, ...)
capabilities = CapabilityReport(false, false, "MethodError: Complex{Dual}", ...)

adjusted = apply_capability_adjustments(config, capabilities)
# => All features disabled, warning logged
```
"""
function apply_capability_adjustments(config, capabilities::CapabilityReport)
    # Extract current settings
    enable_gradient = config.enable_gradient_computation
    enable_hessian = config.enable_hessian_computation
    enable_bfgs = config.enable_bfgs_refinement

    # Determine if adjustments needed
    needs_adjustment = false

    # Adjust based on compatibility
    if !capabilities.gradient_compatible
        # Gradient incompatible → disable gradient, hessian, and BFGS
        if enable_gradient || enable_hessian || enable_bfgs
            needs_adjustment = true
            enable_gradient = false
            enable_hessian = false
            enable_bfgs = false

            @warn """
            ForwardDiff incompatibility detected!

            Objective function failed gradient computation (likely uses complex arithmetic).
            Auto-disabling ForwardDiff-dependent features:
              - Gradient computation
              - Hessian computation
              - BFGS refinement

            Reason: $(capabilities.error_message)

            Experiment will continue with:
              - Polynomial approximation (still works)
              - Critical point finding (still works)
              - Objective function evaluation (still works)

            To suppress this warning, manually disable features in config:
              enable_gradient_computation = false
              enable_hessian_computation = false
              enable_bfgs_refinement = false
            """
        end
    elseif !capabilities.hessian_compatible
        # Gradient OK, but hessian incompatible → disable hessian only
        if enable_hessian
            needs_adjustment = true
            enable_hessian = false

            @warn """
            ForwardDiff Hessian incompatibility detected!

            Objective function supports gradients but not Hessians.
            Auto-disabling:
              - Hessian computation

            Gradient computation and BFGS refinement remain enabled.

            Reason: $(capabilities.error_message)
            """
        end
    end

    # Return adjusted config if needed
    if needs_adjustment
        # Use Accessors.jl for immutable struct updates
        # This works with any config type that has these three fields
        adjusted_config = @set config.enable_gradient_computation = enable_gradient
        adjusted_config = @set adjusted_config.enable_hessian_computation = enable_hessian
        adjusted_config = @set adjusted_config.enable_bfgs_refinement = enable_bfgs
        return adjusted_config
    else
        # No adjustments needed
        return config
    end
end
