"""
Configuration Module

Provides exception types and validation utilities for experiment configuration.

The primary config type is `ExperimentPipelineConfig` in `config_loader.jl`.
This module provides supporting exception types and validation constants.
"""

using JSON3
using TOML

# ============================================================================
# EXCEPTION TYPES
# ============================================================================

"""
    ConfigError <: Exception

Base exception type for configuration errors.
"""
abstract type ConfigError <: Exception end

struct ConfigValidationError <: ConfigError
    message::String
end

struct ConfigParseError <: ConfigError
    message::String
    filepath::Union{String, Nothing}
end

# ============================================================================
# VALIDATION CONSTANTS
# ============================================================================

const VALID_PRECISION_TYPES = [
    "Float64Precision",
    "AdaptivePrecision",
    "RationalPrecision",
    "BigFloatPrecision",
    "BigIntPrecision"
]
const VALID_BASIS_TYPES = ["chebyshev", "legendre"]
const VALID_RESULT_FORMATS = ["json", "hdf5"]
const VALID_DOMAIN_STRATEGIES = ["centered_at_true", "explicit_bounds", "random_offset"]
const VALID_ODE_SOLVERS = [
    "Rosenbrock23", "Rodas4", "Rodas5", "Rodas5P",  # Rosenbrock methods
    "Tsit5", "Vern7", "Vern8", "Vern9",             # Runge-Kutta methods
    "TRBDF2", "KenCarp4", "KenCarp5"                # SDIRK methods
]
const VALID_PRECISION_MODES = ["float64", "adaptive", "Float64Precision", "AdaptivePrecision"]

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

"""
    validate_precision_type(precision::String) -> Bool

Validate that precision type is supported.
"""
function validate_precision_type(precision::String)
    precision in VALID_PRECISION_TYPES
end

"""
    validate_basis_type(basis::String) -> Bool

Validate that basis type is supported.
"""
function validate_basis_type(basis::String)
    basis in VALID_BASIS_TYPES
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    print_validation_errors(result::ValidationResult)

Print validation errors in a readable format.
Handles errors as generic objects — prints string representation of each error.
"""
function print_validation_errors(result::ValidationResult)
    if result.success
        println("Configuration is valid")
        return
    end

    println("Configuration validation failed:")
    println()

    for err in result.errors
        println("  Error: $(string(err))")
        println()
    end
end

# ============================================================================
# EXPORTS
# ============================================================================

# Exception types
export ConfigError, ConfigValidationError, ConfigParseError

# Validation constants
export VALID_PRECISION_TYPES, VALID_BASIS_TYPES, VALID_RESULT_FORMATS
export VALID_DOMAIN_STRATEGIES, VALID_ODE_SOLVERS, VALID_PRECISION_MODES

# Validation functions
export validate_precision_type, validate_basis_type
export print_validation_errors
