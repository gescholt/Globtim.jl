# src/cheb_poly.jl
# Functions for Chebyshev polynomial operations in the Globtim module

using DynamicPolynomials
using LinearAlgebra

# Global variable to use for creating symbolic polynomials
@polyvar x


"""
    symbolic_chebyshev(
        n::Integer; 
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true,
        power_of_two_denom::Bool=false
    )

Generate the symbolic Chebyshev polynomial of degree n.

# Arguments
- `n::Integer`: Degree of the Chebyshev polynomial
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: If true, returns the L²-normalized version
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2

# Returns
- The Chebyshev polynomial of degree n with specified precision
"""
function symbolic_chebyshev(
    n::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false
)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))

    # Get the unnormalized polynomial
    T = _build_chebyshev_polynomial(n, precision)

    # Apply normalization if requested
    if normalized
        norm_factor = _chebyshev_normalization_factor(n, precision)
        T = norm_factor * T
    end

    # Apply power-of-two denominator conversion if requested
    if power_of_two_denom && precision == RationalPrecision
        return _convert_to_power_of_two_denom(T)
    end

    return T
end

"""
    _build_chebyshev_polynomial(n::Integer, precision::PrecisionType)

Internal function to build a Chebyshev polynomial of degree n using recurrence relation.
"""
function _build_chebyshev_polynomial(n::Integer, precision::PrecisionType)
    # Handle base cases directly
    if n == 0
        return _convert_value(1, precision)
    elseif n == 1
        return x  # Global variable x
    end

    # Use recurrence relation for higher degrees
    t_prev = _convert_value(1, precision)  # T₀(x)
    t_curr = x                            # T₁(x)

    for k in 2:n
        # Recurrence relation: T_n(x) = 2x·T_{n-1}(x) - T_{n-2}(x)
        two = _convert_value(2, precision)
        t_next = two * x * t_curr - t_prev

        t_prev = t_curr
        t_curr = t_next
    end

    return t_curr
end

"""
    _chebyshev_normalization_factor(n::Integer, precision::PrecisionType)

Compute the L² normalization factor for Chebyshev polynomials.
"""
function _chebyshev_normalization_factor(n::Integer, precision::PrecisionType)
    if precision == Float64Precision
        # Use floating point directly for Float64Precision
        if n == 0
            return 1 / sqrt(π)
        else
            return sqrt(2 / π)
        end
    else
        # For other precision types, carefully convert π
        if n == 0
            pi_val = _convert_value(π, precision)
            return 1 / sqrt(pi_val)
        else
            pi_val = _convert_value(π, precision)
            two = _convert_value(2, precision)
            return sqrt(two / pi_val)
        end
    end
end

"""
    _convert_value(val, precision::PrecisionType)

Convert a numeric value to the specified precision type.
Handles all numeric types including irrationals.
"""
function _convert_value(val, precision::PrecisionType)
    if precision == Float64Precision
        return Float64(val)
    elseif precision == RationalPrecision
        if val isa Irrational
            # Handle irrational constants like π by rationalizing them
            return rationalize(BigInt, Float64(val))
        elseif isnan(val)
            error("Cannot convert NaN to rational number. Check computation for numerical instability.")
        else
            return typeof(val) <: Rational ? val : Rational{BigInt}(val)
        end
    elseif precision == BigFloatPrecision
        return BigFloat(val)
    elseif precision == AdaptivePrecision
        # For AdaptivePrecision, use BigFloat with adaptive precision
        return _convert_value_adaptive(val)
    else # BigIntPrecision
        if val isa Integer
            return BigInt(val)
        elseif val isa Irrational
            error("Cannot convert irrational to BigInt")
        else
            error("Cannot convert non-integer to BigInt")
        end
    end
end

"""
    _convert_value_adaptive(val)

Convert value to BigFloat with adaptive precision based on magnitude and context.
For AdaptivePrecision, we use BigFloat but with smart precision selection.
"""
function _convert_value_adaptive(val)
    # Set BigFloat precision based on value magnitude and global context
    # Higher precision for smaller values (more sensitive to precision loss)
    abs_val = abs(Float64(val))

    if abs_val < 1e-12
        # Very small values need high precision
        old_precision = Base.precision(BigFloat)
        Base.setprecision(BigFloat, 512)  # High precision
        result = BigFloat(val)
        Base.setprecision(BigFloat, old_precision)
        return result
    elseif abs_val < 1e-6
        # Small values need medium precision
        old_precision = Base.precision(BigFloat)
        Base.setprecision(BigFloat, 256)  # Medium precision
        result = BigFloat(val)
        Base.setprecision(BigFloat, old_precision)
        return result
    else
        # Normal values use standard BigFloat precision
        return BigFloat(val)
    end
end

"""
    _convert_to_power_of_two_denom(poly)

Convert rational coefficients in a polynomial to have power-of-2 denominators.
"""
function _convert_to_power_of_two_denom(poly)
    if !(poly isa Polynomial)
        if poly isa Rational
            return closest_pow2denom_rational(poly)
        end
        return poly
    end

    terms_array = terms(poly)
    new_terms = map(terms_array) do term
        coeff = coefficient(term)
        if coeff isa Rational
            new_coeff = closest_pow2denom_rational(coeff)
            new_coeff * monomial(term)
        else
            term
        end
    end

    return sum(new_terms)
end

"""
    closest_pow2denom_rational(r::Rational{BigInt})::Rational{BigInt}

Convert a rational number to one with a power-of-2 denominator.
"""
function closest_pow2denom_rational(r::Rational{BigInt})::Rational{BigInt}
    num = numerator(r)
    den = denominator(r)
    new_den = BigInt(2)^ceil(Int, log2(den))
    new_num = round(BigInt, num * new_den / den)
    return new_num // new_den
end

"""
    evaluate_chebyshev(T, x_val::Number)

Evaluate a Chebyshev polynomial T at a specific value x_val.

# Arguments
- `T`: Chebyshev polynomial
- `x_val::Number`: Value to evaluate at (must be in [-1, 1])

# Returns
- The value of the polynomial at x_val
"""
function evaluate_chebyshev(T, x_val::Number)
    if abs(x_val) > 1
        throw(DomainError(x_val, "Argument must be in [-1, 1] for Chebyshev polynomials"))
    end

    # Handle constant polynomials
    if T isa Number
        return T
    end

    # Evaluate the polynomial
    return DynamicPolynomials.subs(T, x => x_val)
end

function get_chebyshev_coeffs(
    max_degree::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false
)
    # Vector to store coefficient vectors
    chebyshev_coeffs = Vector{Vector}(undef, max_degree + 1)

    # For each degree, generate polynomial and extract coefficients
    for deg in 0:max_degree
        T = symbolic_chebyshev(
            deg;
            precision = precision,
            normalized = normalized,
            power_of_two_denom = power_of_two_denom
        )

        # Handle constant polynomials
        if T isa Number
            coeff_type = precision == RationalPrecision ? Rational{BigInt} : Float64
            # Convert to the correct type
            chebyshev_coeffs[deg + 1] = [convert(coeff_type, T)]
        else
            # Extract coefficients from terms
            terms_array = terms(T)
            degrees = [degree(t) for t in terms_array]
            coeffs = [coefficient(t) for t in terms_array]

            # Determine coefficient type
            coeff_type = precision == RationalPrecision ? Rational{BigInt} : Float64

            # Create full coefficient vector (padding with zeros)
            full_coeffs = zeros(coeff_type, deg + 1)
            for (d, c) in zip(degrees, coeffs)
                # Convert each coefficient to the desired type
                full_coeffs[d + 1] = convert(coeff_type, c)
            end

            chebyshev_coeffs[deg + 1] = full_coeffs
        end
    end

    return chebyshev_coeffs
end

"""
    chebyshev_coeff_matrix(
        n::Integer;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true,
        power_of_two_denom::Bool=false
    )

Generate a matrix where each row contains the coefficients of a Chebyshev polynomial.

# Arguments
- `n::Integer`: Maximum degree of polynomials (matrix will have n+1 rows)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2

# Returns
- Matrix of coefficients where row i+1 contains coefficients of T_i(x)
"""
function chebyshev_coeff_matrix(
    n::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false
)
    coeffs = get_chebyshev_coeffs(
        n;
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom
    )

    # Create a matrix with proper dimensions
    T = eltype(coeffs[end])
    result = zeros(T, n + 1, n + 1)

    # Fill in the coefficient matrix
    for i in 0:n
        row = coeffs[i + 1]
        result[i + 1, 1:length(row)] = row
    end

    return result
end


"""
    construct_chebyshev_approx(
        x_vars::Vector{<:Variable},
        coeffs::Vector{<:Number},
        degree::Int;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true,
        power_of_two_denom::Bool=false
    )

Construct a multivariate Chebyshev polynomial approximation.

# Arguments
- `x_vars::Vector{<:Variable}`: Vector of variables
- `coeffs::Vector{<:Number}`: Vector of coefficients
- `degree::Int`: Maximum degree of the approximation
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2

# Returns
- The multivariate Chebyshev polynomial approximation
"""
function construct_chebyshev_approx(
    x_vars::Vector{<:Variable},
    coeffs::Vector{<:Number},
    degree;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false
)
    n = length(x_vars)  # number of variables

    # Handle backward compatibility: convert integer degree to tuple format
    degree_tuple = if isa(degree, Int)
        (:one_d_for_all, degree)
    else
        degree
    end

    # Generate multi-index set for given degree
    lambda = SupportGen(n, degree_tuple).data
    m = size(lambda, 1)

    # Check coefficients length matches space dimension
    length(coeffs) == m ||
        error("coeffs length ($(length(coeffs))) must match space dimension ($m)")

    # Convert coefficients to appropriate precision
    coeffs_converted = map(c -> _convert_value(c, precision), coeffs)

    # Cache Chebyshev polynomial coefficients up to max degree
    max_degree = maximum(lambda)
    # @info "" lambda max_degree
    chebyshev_coeffs = get_chebyshev_coeffs(
        max_degree;
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom
    )

    # Initialize polynomial
    S = zero(x_vars[1])

    # Construct polynomial using Chebyshev basis
    for j in 1:m
        term = one(x_vars[1])
        for k in 1:n
            deg = lambda[j, k]
            coeff_vec = chebyshev_coeffs[deg + 1]

            # Create monomial vector for this variable
            monom_vec = MonomialVector([x_vars[k]], 0:deg)

            # Multiply by appropriate Chebyshev polynomial
            term *= sum(coeff_vec .* monom_vec)
        end

        # Add term with coefficient to the polynomial
        S += coeffs_converted[j] * term
    end

    # Apply power-of-two denominator conversion if requested
    if power_of_two_denom && precision == RationalPrecision
        S = _convert_to_power_of_two_denom(S)
    end

    return S
end

"""
    truncate_polynomial_adaptive(poly, threshold::Real; relative::Bool=false)

Truncate polynomial coefficients using extended precision for accurate threshold comparison.
This function is designed to work well with AdaptivePrecision polynomials.

# Arguments
- `poly`: DynamicPolynomials.Polynomial with extended precision coefficients
- `threshold::Real`: Truncation threshold
- `relative::Bool`: If true, threshold is relative to largest coefficient

# Returns
- Truncated polynomial with small coefficients removed
- Statistics about the truncation (number of terms removed, etc.)
"""
function truncate_polynomial_adaptive(poly, threshold::Real; relative::Bool=false)
    terms_list = terms(poly)
    coeffs = [coefficient(t) for t in terms_list]

    # Convert to Float64 for magnitude comparison (but keep original precision)
    coeff_magnitudes = [abs(Float64(c)) for c in coeffs]

    # Determine effective threshold
    effective_threshold = if relative
        threshold * maximum(coeff_magnitudes)
    else
        Float64(threshold)
    end

    # Find terms to keep
    keep_mask = coeff_magnitudes .> effective_threshold
    n_kept = sum(keep_mask)
    n_total = length(coeffs)

    if n_kept == n_total
        # No truncation needed
        return poly, (n_total=n_total, n_kept=n_kept, n_removed=0, sparsity_ratio=0.0)
    elseif n_kept == 0
        # All coefficients too small - keep the largest one
        max_idx = argmax(coeff_magnitudes)
        keep_mask[max_idx] = true
        n_kept = 1
    end

    # Build truncated polynomial
    kept_terms = terms_list[keep_mask]
    truncated_poly = sum(kept_terms)

    # Statistics
    n_removed = n_total - n_kept
    sparsity_ratio = n_removed / n_total

    stats = (
        n_total = n_total,
        n_kept = n_kept,
        n_removed = n_removed,
        sparsity_ratio = sparsity_ratio,
        threshold_used = effective_threshold,
        largest_removed = n_removed > 0 ? maximum(coeff_magnitudes[.!keep_mask]) : 0.0,
        smallest_kept = minimum(coeff_magnitudes[keep_mask])
    )

    return truncated_poly, stats
end

"""
    analyze_coefficient_distribution(poly)

Analyze the distribution of polynomial coefficients for truncation guidance.
Works with extended precision coefficients from AdaptivePrecision.
"""
function analyze_coefficient_distribution(poly)
    coeffs = [coefficient(t) for t in terms(poly)]
    coeff_magnitudes = [abs(Float64(c)) for c in coeffs]

    # Sort by magnitude
    sorted_mags = sort(coeff_magnitudes, rev=true)

    # Statistics
    n_total = length(sorted_mags)
    max_coeff = maximum(sorted_mags)
    min_coeff = minimum(sorted_mags[sorted_mags .> 0])

    # Find natural gaps in coefficient magnitudes (potential truncation points)
    log_mags = log10.(sorted_mags[sorted_mags .> 0])
    gaps = diff(log_mags)
    large_gaps = findall(gaps .< -2.0)  # Gaps of more than 2 orders of magnitude

    suggested_thresholds = if !isempty(large_gaps)
        [10^log_mags[gap_idx+1] for gap_idx in large_gaps[1:min(3, end)]]
    else
        [max_coeff * 1e-12, max_coeff * 1e-10, max_coeff * 1e-8]
    end

    return (
        n_total = n_total,
        max_coefficient = max_coeff,
        min_coefficient = min_coeff,
        dynamic_range = max_coeff / min_coeff,
        suggested_thresholds = suggested_thresholds,
        coefficient_magnitudes = coeff_magnitudes
    )
end
