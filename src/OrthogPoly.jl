# ============= Orthogonal Polynomials =============

# Chebyshev #
"""
    ChebyshevPoly(d::Int, x)

Generate the Chebyshev polynomial of degree `d` in the variable `x` with rational coefficients.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.
- `x`: Variable for the polynomial.

# Returns
- The Chebyshev polynomial of degree `d` in the variable `x`.

# Example
```julia
ChebyshevPoly(3, x)
```
"""
function ChebyshevPoly(d::Int, x)
    if d == 0
        return rationalize(1.0)
    elseif d == 1
        return x
    else
        T_prev = rationalize(1.0)
        T_curr = x
        for n in 2:d
            T_next = rationalize(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

# """
#     ChebyshevPolyExact(d::Int)::Vector{Int}

# Generate a vector of integer coefficients of the Chebyshev polynomial of degree `d` in one variable.

# # Arguments
# - `d::Int`: Degree of the Chebyshev polynomial.

# # Returns
# - A vector of integer coefficients of the Chebyshev polynomial of degree `d`.

# # Example
# ```julia
# ChebyshevPolyExact(3)
# ```
# """
# function ChebyshevPolyExact(d::Int)::Vector{Int}
#     if d == 0
#         return [1]
#     elseif d == 1
#         return [0, 1]
#     else
#         Tn_1 = ChebyshevPolyExact(d - 1)
#         Tn_2 = ChebyshevPolyExact(d - 2)
#         Tn = [0; 2 * Tn_1] - vcat(Tn_2, [0, 0])
#         return Tn
#     end
# end

"""
    closest_pow2denom_rational(r::Rational{BigInt})::Rational{BigInt}

Convert a rational number to one with a power-of-2 denominator, 
adjusting the numerator to maintain the closest possible value.

# Arguments
- `r::Rational{BigInt}`: Input rational number

# Returns
- A rational number with power-of-2 denominator
"""
function closest_pow2denom_rational(r::Rational{BigInt})::Rational{BigInt}
    num = numerator(r)
    den = denominator(r)
    new_den = BigInt(2)^ceil(Int, log2(den))
    new_num = round(BigInt, num * new_den / den)
    return new_num // new_den
end

"""
    ChebyshevPolyExact(d::Int)::Vector{Rational{BigInt}}

Generate a vector of rational coefficients of the Chebyshev polynomial of degree `d` in one variable,
with denominators being powers of 2.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.

# Returns
- A vector of rational coefficients of the Chebyshev polynomial of degree `d`.

# Example
```julia
julia> ChebyshevPolyExact(3)
4-element Vector{Rational{BigInt}}:
 0 // 1
 -3 // 1
 0 // 1
 1 // 1
```
"""
function ChebyshevPolyExact(d::Int)::Vector{Rational{BigInt}}
    if d == 0
        return [BigInt(1) // 1]
    elseif d == 1
        return [BigInt(0) // 1, BigInt(1) // 1]
    else
        Tn_1 = ChebyshevPolyExact(d - 1)
        Tn_2 = ChebyshevPolyExact(d - 2)

        # Multiply by 2 and convert to power-of-2 denominator
        doubled = map(r -> closest_pow2denom_rational(2 * r), Tn_1)

        # Create the new polynomial
        Tn = [BigInt(0) // 1; doubled] - vcat(Tn_2, [BigInt(0) // 1, BigInt(0) // 1])

        # Convert final results to power-of-2 denominators
        return map(closest_pow2denom_rational, Tn)
    end
end


"""
    BigFloatChebyshevPoly(d::Int, x)

Generate the Chebyshev polynomial with `BigFloat` coefficients of degree `d` in the variable `x`.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.
- `x`: Variable for the polynomial.

# Returns
- The Chebyshev polynomial of degree `d` in the variable `x` with `BigFloat` coefficients.

# Example
```julia
BigFloatChebyshevPoly(3, x)
```
"""
function BigFloatChebyshevPoly(d::Int, x)
    if d == 0
        return BigFloat(1.0)
    elseif d == 1
        return x
    else
        T_prev = BigFloat(1.0)
        T_curr = x
        for n in 2:d
            T_next = BigFloat(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

# Legendre #

@polyvar x

"""
    get_coefficient_type(P)

Helper function to determine coefficient type of a polynomial or constant.
"""
function get_coefficient_type(P)
    if P isa Integer
        return typeof(P)
    elseif P isa AbstractPolynomial
        return typeof(coefficient(first(terms(P))))
    else
        return typeof(P)
    end
end

"""
    evaluate_legendre(P, x::Number)

Evaluate Legendre polynomial P at x.
"""
function evaluate_legendre(P, x_val::Number)
    if abs(x_val) > 1
        throw(DomainError(x_val, "Argument must be in [-1, 1]"))
    end

    # Handle constant polynomials (integers)
    if P isa Integer
        return P
    end

    # Pass the pair directly
    return DynamicPolynomials.subs(P, x => x_val)
end

# """
#     symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)

# Generate the symbolic Legendre polynomial of degree n.
# If normalized=true, returns the L²-normalized version.
# """
# function symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)
#     n < 0 && throw(ArgumentError("Degree must be non-negative"))

#     # Get the unnormalized polynomial
#     P = if n == 0
#         use_bigint ? big(1) : 1
#     elseif n == 1
#         x  # Use global x
#     else
#         try
#             _symbolic_legendre_impl(n, use_bigint)
#         catch e
#             if e isa OverflowError && !use_bigint
#                 @warn "Integer overflow detected, switching to BigInt"
#                 _symbolic_legendre_impl(n, true)
#             else
#                 rethrow(e)
#             end
#         end
#     end

#     # Apply normalization if requested
#     if normalized
#         # Normalization factor: √((2n+1)/2)
#         norm_factor = sqrt((2n + 1) / 2)
#         return norm_factor * P
#     else
#         return P
#     end
# end

"""
    symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)

Generate the symbolic Legendre polynomial of degree n using DynamicPolynomials.

# Arguments
- `n::Integer`: Degree of the Legendre polynomial
- `use_bigint::Bool=false`: Whether to use BigInt for computation
- `normalized::Bool=true`: If true, returns the L²-normalized version

# Returns
- The Legendre polynomial of degree n

# Throws
- ArgumentError: If n < 0
"""
function symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))

    # Get the unnormalized polynomial using multiple dispatch
    P = _get_legendre_polynomial(n, Val(use_bigint))

    # Apply normalization if requested
    if normalized
        norm_factor = sqrt((2n + 1) // 2)  # Using rational arithmetic for exactness
        return norm_factor * P
    end
    return P
end

# Helper functions using multiple dispatch
function _get_legendre_polynomial(n::Integer, ::Val{false})
    n == 0 && return one(x)  # x is defined globally via @polyvar
    n == 1 && return x
    return _symbolic_legendre_impl(n, false)
end

function _get_legendre_polynomial(n::Integer, ::Val{true})
    n == 0 && return big(1)
    n == 1 && return x
    return _symbolic_legendre_impl(n, true)
end

"""
    _symbolic_legendre_impl(n::Integer, use_bigint::Bool)

Internal implementation of Legendre polynomial generation.
"""
function _symbolic_legendre_impl(n::Integer, use_bigint::Bool)
    T = use_bigint ? BigInt : Int

    p_prev = use_bigint ? big(1) : 1  # P₀
    p_curr = x                        # P₁ (use global x)

    for k in T(1):T(n - 1)
        p_next = ((2k + 1) // (k + 1) * x * p_curr -
                  k // (k + 1) * p_prev)
        p_prev = p_curr
        p_curr = p_next
    end

    return p_curr
end

function get_legendre_coeffs(max_degree::Integer)
    # Cache coefficients for Legendre polynomials from degree 0 to max_degree
    legendre_coeffs = Vector{Vector{Rational{BigInt}}}(undef, max_degree + 1)

    # For each degree, generate polynomial and extract coefficients
    for deg in 0:max_degree
        P = symbolic_legendre(deg, normalized=true)

        # If constant polynomial
        if P isa Number
            legendre_coeffs[deg+1] = [convert(Rational{BigInt}, P)]
        else
            # Extract coefficients from terms
            terms_array = terms(P)
            degrees = [degree(t) for t in terms_array]
            coeffs = [convert(Rational{BigInt}, coefficient(t)) for t in terms_array]

            # Create full coefficient vector (padding with zeros)
            full_coeffs = zeros(Rational{BigInt}, deg + 1)
            for (d, c) in zip(degrees, coeffs)
                full_coeffs[d+1] = c
            end

            legendre_coeffs[deg+1] = full_coeffs
        end
    end

    return legendre_coeffs
end 