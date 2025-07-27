# src/lege_poly.jl
# Functions for Legendre polynomial operations in the Globtim module

using DynamicPolynomials
using LinearAlgebra

# Global variable to use for creating symbolic polynomials
@polyvar x


"""
    symbolic_legendre(
        n::Integer;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true
    )

Generate the symbolic Legendre polynomial of degree n.

# Arguments
- `n::Integer`: Degree of the Legendre polynomial
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: If true, returns the L²-normalized version

# Returns
- The Legendre polynomial of degree n with specified precision
"""
function symbolic_legendre(
    n::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))

    # Get the unnormalized polynomial
    P = _build_legendre_polynomial(n, precision)

    # Apply normalization if requested
    if normalized
        norm_factor = _legendre_normalization_factor(n, precision)
        return norm_factor * P
    end

    return P
end

"""
    _build_legendre_polynomial(n::Integer, precision::PrecisionType)

Internal function to build a Legendre polynomial of degree n using recurrence relation.
"""
function _build_legendre_polynomial(n::Integer, precision::PrecisionType)
    # Handle base cases directly
    if n == 0
        return _convert_value(1, precision)
    elseif n == 1
        return x  # Global variable x
    end

    # Use recurrence relation for higher degrees
    p_prev = _convert_value(1, precision)  # P₀(x)
    p_curr = x                            # P₁(x)

    for k = 1:(n-1)
        if precision == Float64Precision
            # Use floating-point division for Float64Precision
            k_rat = Float64(k)
            factor1 = (2k_rat + 1) / (k_rat + 1)
            factor2 = k_rat / (k_rat + 1)
        else
            # Use rational division for other precision types
            k_rat = _convert_value(k, precision)
            factor1 = (2k_rat + 1) // (k_rat + 1)
            factor2 = k_rat // (k_rat + 1)
        end

        p_next = factor1 * x * p_curr - factor2 * p_prev

        p_prev = p_curr
        p_curr = p_next
    end

    return p_curr
end

"""
    _legendre_normalization_factor(n::Integer, precision::PrecisionType)

Compute the L² normalization factor for Legendre polynomials.
"""
function _legendre_normalization_factor(n::Integer, precision::PrecisionType)
    # Normalization factor: √((2n+1)/2)
    factor = (2n + 1) // 2
    return sqrt(_convert_value(factor, precision))
end


"""
    evaluate_legendre(P, x_val::Number)

Evaluate a Legendre polynomial P at a specific value x_val.

# Arguments
- `P`: Legendre polynomial
- `x_val::Number`: Value to evaluate at (must be in [-1, 1])

# Returns
- The value of the polynomial at x_val
"""
function evaluate_legendre(P, x_val::Number)
    if abs(x_val) > 1
        throw(DomainError(x_val, "Argument must be in [-1, 1] for Legendre polynomials"))
    end

    # Handle constant polynomials
    if P isa Number
        return P
    end

    # Substitute x with x_val
    substituted = DynamicPolynomials.subs(P, x => x_val)

    # If it's already a number after substitution, return it
    if substituted isa Number
        return substituted
    end

    # Otherwise, extract the constant term (assuming all variables were substituted)
    terms = DynamicPolynomials.terms(substituted)

    # If there are no terms, return 0
    if isempty(terms)
        return zero(Float64)
    end

    # If there's just one term and it has no variables, return its coefficient
    if length(terms) == 1 && DynamicPolynomials.nvariables(terms[1]) == 0
        return DynamicPolynomials.coefficient(terms[1])
    end

    # If we got here, the polynomial still has variables after substitution
    # This shouldn't happen if x was the only variable and we substituted it
    error("Failed to fully evaluate Legendre polynomial after substitution: $substituted")
end

"""
    get_legendre_coeffs(
        max_degree::Integer;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true
    )

Generate coefficient vectors for Legendre polynomials from degree 0 to max_degree.

# Arguments
- `max_degree::Integer`: Maximum degree of polynomials to generate
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized polynomials

# Returns
- Vector of coefficient vectors for polynomials of degrees 0 to max_degree
"""
function get_legendre_coeffs(
    max_degree::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
)
    # Vector to store coefficient vectors
    legendre_coeffs = Vector{Vector}(undef, max_degree + 1)

    # For each degree, generate polynomial and extract coefficients
    for deg = 0:max_degree
        P = symbolic_legendre(deg; precision = precision, normalized = normalized)

        # Handle constant polynomials
        if P isa Number
            coeff_type = precision == RationalPrecision ? Rational{BigInt} : Float64
            # Convert to the correct type
            legendre_coeffs[deg+1] = [convert(coeff_type, P)]
        else
            # Extract coefficients from terms
            terms_array = terms(P)
            degrees = [degree(t) for t in terms_array]
            coeffs = [coefficient(t) for t in terms_array]

            # Determine coefficient type
            coeff_type = precision == RationalPrecision ? Rational{BigInt} : Float64

            # Create full coefficient vector (padding with zeros)
            full_coeffs = zeros(coeff_type, deg + 1)
            for (d, c) in zip(degrees, coeffs)
                # Convert each coefficient to the desired type
                full_coeffs[d+1] = convert(coeff_type, c)
            end

            legendre_coeffs[deg+1] = full_coeffs
        end
    end

    return legendre_coeffs
end

"""
    legendre_coeff_matrix(
        n::Integer;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true
    )

Generate a matrix where each row contains the coefficients of a Legendre polynomial.

# Arguments
- `n::Integer`: Maximum degree of polynomials (matrix will have n+1 rows)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized polynomials

# Returns
- Matrix of coefficients where row i+1 contains coefficients of P_i(x)
"""
function legendre_coeff_matrix(
    n::Integer;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
)
    coeffs = get_legendre_coeffs(n; precision = precision, normalized = normalized)

    # Create a matrix with proper dimensions
    T = eltype(coeffs[end])
    result = zeros(T, n + 1, n + 1)

    # Fill in the coefficient matrix
    for i = 0:n
        row = coeffs[i+1]
        result[i+1, 1:length(row)] = row
    end

    return result
end

"""
    construct_legendre_approx(
        x_vars::Vector{<:Variable},
        coeffs::Vector{<:Number},
        degree::Int;
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true
    )

Construct a multivariate Legendre polynomial approximation.

# Arguments
- `x_vars::Vector{<:Variable}`: Vector of variables
- `coeffs::Vector{<:Number}`: Vector of coefficients
- `degree::Int`: Maximum degree of the approximation
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials

# Returns
- The multivariate Legendre polynomial approximation
"""
function construct_legendre_approx(
    x_vars::Vector{<:Variable},
    coeffs::Vector{<:Number},
    degree;
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false,
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

    # Cache Legendre polynomial coefficients up to max degree
    max_degree = maximum(lambda)
    legendre_coeffs =
        get_legendre_coeffs(max_degree; precision = precision, normalized = normalized)

    # Initialize polynomial
    S = zero(x_vars[1])

    # Construct polynomial using Legendre basis
    for j = 1:m
        term = one(x_vars[1])
        for k = 1:n
            deg = lambda[j, k]
            coeff_vec = legendre_coeffs[deg+1]

            # Create monomial vector for this variable
            monom_vec = MonomialVector([x_vars[k]], 0:deg)

            # Multiply by appropriate Legendre polynomial
            term *= sum(coeff_vec .* monom_vec)
        end

        # Add term with coefficient to the polynomial
        S += coeffs_converted[j] * term
    end

    return S
end
