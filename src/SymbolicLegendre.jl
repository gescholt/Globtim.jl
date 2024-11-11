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
    symbolic_legendre(n::Integer; use_bigint::Bool=false)

Generate the symbolic Legendre polynomial of degree n.
"""
function symbolic_legendre(n::Integer; use_bigint::Bool=false)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))
    
    if n == 0
        return use_bigint ? big(1) : 1
    elseif n == 1
        return x  # Use global x
    end
    
    try
        return _symbolic_legendre_impl(n, use_bigint)
    catch e
        if e isa OverflowError && !use_bigint
            @warn "Integer overflow detected, switching to BigInt"
            return _symbolic_legendre_impl(n, true)
        else
            rethrow(e)
        end
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
    
    for k in T(1):T(n-1)
        p_next = ((2k + 1) // (k + 1) * x * p_curr - 
                  k // (k + 1) * p_prev)
        p_prev = p_curr
        p_curr = p_next
    end
    
    return p_curr
end

