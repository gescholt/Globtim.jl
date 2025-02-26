# src/OrthogonalInterface.jl
# Unified interface for orthogonal polynomials

"""
    symbolic_orthopoly(type::Symbol, n::Integer; kwargs...)

Create a symbolic orthogonal polynomial of the specified type and degree.

# Arguments
- `type::Symbol`: Type of polynomial (:legendre or :chebyshev)
- `n::Integer`: Degree of the polynomial
- `precision::PrecisionType=RationalPrecision`: Precision type
- `normalized::Bool=true`: Whether to normalize the polynomial
- `power_of_two_denom::Bool=false`: (Chebyshev only) Use power-of-2 denominators

# Returns
- The orthogonal polynomial of the specified type and degree
"""
function symbolic_orthopoly(type::Symbol, n::Integer; kwargs...)
    if type == :legendre
        return symbolic_legendre(n; kwargs...)
    elseif type == :chebyshev
        return symbolic_chebyshev(n; kwargs...)
    else
        throw(ArgumentError("Unsupported polynomial type: $type. Use :legendre or :chebyshev"))
    end
end

"""
    evaluate_orthopoly(type::Symbol, P, x_val::Number)

Evaluate an orthogonal polynomial at a specific value.

# Arguments
- `type::Symbol`: Type of polynomial (:legendre or :chebyshev)
- `P`: The polynomial to evaluate
- `x_val::Number`: Point at which to evaluate
"""
function evaluate_orthopoly(type::Symbol, P, x_val::Number)
    if type == :legendre
        return evaluate_legendre(P, x_val)
    elseif type == :chebyshev
        return evaluate_chebyshev(P, x_val)
    else
        throw(ArgumentError("Unsupported polynomial type: $type. Use :legendre or :chebyshev"))
    end
end

"""
    get_orthopoly_coeffs(type::Symbol, max_degree::Integer; kwargs...)

Get coefficients for orthogonal polynomials up to the specified degree.

# Arguments
- `type::Symbol`: Type of polynomial (:legendre or :chebyshev)
- `max_degree::Integer`: Maximum degree
- `kwargs...`: Additional arguments passed to the specific implementation
"""
function get_orthopoly_coeffs(type::Symbol, max_degree::Integer; kwargs...)
    if type == :legendre
        return get_legendre_coeffs(max_degree; kwargs...)
    elseif type == :chebyshev
        return get_chebyshev_coeffs(max_degree; kwargs...)
    else
        throw(ArgumentError("Unsupported polynomial type: $type. Use :legendre or :chebyshev"))
    end
end


"""
    construct_orthopoly_polynomial(
        x::Vector{<:Variable},
        coeffs::Vector{<:Number},
        degree::Int,
        basis::Symbol=:chebyshev,
        precision::PrecisionType=RationalPrecision;
        normalized::Bool=true,
        power_of_two_denom::Bool=false,
        verbose::Bool=false
    )

Construct a multivariate orthogonal polynomial in the standard monomial basis 
from a vector of coefficients computed in the specified orthogonal basis.
Converts coefficients to the specified precision for arithmetic operations.

# Arguments
- `x::Vector{<:Variable}`: Vector of polynomial variables
- `coeffs::Vector{<:Number}`: Coefficients for the polynomial approximation (typically Float64)
- `degree::Int`: Maximum degree of the polynomial
- `basis::Symbol`: Type of basis (:chebyshev or :legendre)
- `precision::PrecisionType`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2
- `verbose::Bool=false`: Whether to print verbose output

# Returns
- The multivariate orthogonal polynomial in the standard monomial basis
"""
function construct_orthopoly_polynomial(
    x::Vector{<:Variable},
    coeffs::Vector{<:Number},
    degree::Int,
    basis::Symbol=:chebyshev,
    precision::PrecisionType=RationalPrecision;
    normalized::Bool=true,
    power_of_two_denom::Bool=false,
    verbose::Bool=false
)
    n = length(x)
    lambda = SupportGen(n, degree)
    m = lambda.size[1]

    if verbose
        println("Dimension m of the vector space: ", m)
        println("Input coefficient types: ", typeof(coeffs))
        println("First few input coefficients: ", coeffs[1:min(3, length(coeffs))])
        println("precision parameter: ", precision)
    end

    if length(coeffs) != m
        if verbose
            println("The length of coeffs ($(length(coeffs))) does not match the dimension of the space we project onto ($m)")
        end
        error("The length of coeffs must match the dimension of the space we project onto")
    end

    # Convert coefficients to appropriate precision before passing to basis-specific functions
    coeffs_converted = map(c -> _convert_value(c, precision), coeffs)

    if verbose
        println("Converted coefficient types: ", typeof(coeffs_converted))
        println("First few converted coefficients: ", coeffs_converted[1:min(3, length(coeffs_converted))])
    end

    # Debug the _convert_value function itself
    if verbose && !isempty(coeffs)
        println("Testing _convert_value directly:")
        println("Input: ", coeffs[1], " (", typeof(coeffs[1]), ")")
        println("Output: ", _convert_value(coeffs[1], precision), " (", typeof(_convert_value(coeffs[1], precision)), ")")
    end

    # Create the polynomial
    local result
    if basis == :legendre
        result = construct_legendre_approx(x, coeffs_converted, degree;
            precision=precision,
            normalized=normalized,
            power_of_two_denom=power_of_two_denom)
    elseif basis == :chebyshev
        result = construct_chebyshev_approx(x, coeffs_converted, degree;
            precision=precision,
            normalized=normalized,
            power_of_two_denom=power_of_two_denom)
    else
        throw(ArgumentError("Unsupported polynomial basis: $basis. Use :legendre or :chebyshev"))
    end

    # Debug the resulting polynomial
    if verbose
        println("Result type: ", typeof(result))
        println("First terms of result: ", string(result)[1:min(200, length(string(result)))])
    end

    return result
end