
using DynamicPolynomials


"""
    symbolic_legendre(n::Integer; use_bigint::Bool=false)

Generate the symbolic Legendre polynomial of degree n with exact rational coefficients.
Returns the polynomial in terms of the variable x.

Parameters:
- n: Degree of the Legendre polynomial
- use_bigint: If true, uses BigInt for calculations to avoid overflow
"""
function symbolic_legendre(n::Integer; use_bigint::Bool=false)
    n < 0 && throw(ArgumentError("Degree must be non-negative"))

    @polyvar x

    if n == 0
        return use_bigint ? big(1) : 1
    elseif n == 1
        return x
    end

    # Try with regular integers first, switch to BigInt if overflow occurs
    try
        return _symbolic_legendre_impl(n, x, use_bigint)
    catch e
        if e isa OverflowError && !use_bigint
            # If overflow occurred and we weren't using BigInt, try again with BigInt
            @warn "Integer overflow detected, switching to BigInt"
            return _symbolic_legendre_impl(n, x, true)
        else
            rethrow(e)
        end
    end
end

"""
Internal implementation with type selection
"""
function _symbolic_legendre_impl(n::Integer, x, use_bigint::Bool)
    T = use_bigint ? BigInt : Int

    p_prev = use_bigint ? big(1) : 1  # P₀
    p_curr = x                         # P₁

    for k in T(1):T(n - 1)
        # Use exact rational arithmetic with the chosen integer type
        p_next = ((2k + 1) // (k + 1) * x * p_curr -
                  k // (k + 1) * p_prev)
        p_prev = p_curr
        p_curr = p_next
    end

    return p_curr
end

"""
    evaluate_legendre(P, x::Number)

Evaluate a symbolic Legendre polynomial at a point x.
"""
function evaluate_legendre(P, x::Number)
    if abs(x) > 1
        throw(DomainError(x, "Argument must be in [-1, 1]"))
    end

    @polyvar X
    try
        return DynamicPolynomials.subs(P, X => x)
    catch e
        if e isa OverflowError
            # Try with BigInt/BigFloat
            @warn "Overflow in evaluation, switching to BigFloat"
            return DynamicPolynomials.subs(P, X => big(x))
        else
            rethrow(e)
        end
    end
end

"""
Print the polynomial in a more readable format
"""
function Base.show(io::IO, P::AbstractPolynomial)
    println(io, "Legendre polynomial: ", P)
end

