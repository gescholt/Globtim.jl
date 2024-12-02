# Define the variable at module level
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

"""
    symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)

Generate the symbolic Legendre polynomial of degree n.
If normalized=true, returns the L²-normalized version.
"""
function symbolic_legendre(n::Integer; use_bigint::Bool=false, normalized::Bool=true)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))

    # Get the unnormalized polynomial
    P = if n == 0
        use_bigint ? big(1) : 1
    elseif n == 1
        x  # Use global x
    else
        try
            _symbolic_legendre_impl(n, use_bigint)
        catch e
            if e isa OverflowError && !use_bigint
                @warn "Integer overflow detected, switching to BigInt"
                _symbolic_legendre_impl(n, true)
            else
                rethrow(e)
            end
        end
    end

    # Apply normalization if requested
    if normalized
        # Normalization factor: √((2n+1)/2)
        norm_factor = sqrt((2n + 1) / 2)
        return norm_factor * P
    else
        return P
    end
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

