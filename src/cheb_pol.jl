# ============= Chebyshev Polynomials =============

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
    ChebyshevPolyExact(d::Int, power_of_two::Bool=false)::Vector{Rational{BigInt}}

Generate a vector of rational coefficients of the Chebyshev polynomial of degree `d` in one variable.
When power_of_two is true, denominators are adjusted to be powers of 2.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.
- `power_of_two::Bool`: If true, ensure denominators are powers of 2. Default is false.

# Returns
- A vector of rational coefficients of the Chebyshev polynomial of degree `d`.

# Example
```julia
julia> ChebyshevPolyExact(3)
4-element Vector{Rational{BigInt}}:
 0//1
 -3//1
 0//1
 4//4
```
"""
function ChebyshevPolyExact(d::Int, power_of_two::Bool=false)::Vector{Rational{BigInt}}
    if d == 0
        return [BigInt(1) // 1]
    elseif d == 1
        return [BigInt(0) // 1, BigInt(1) // 1]
    else
        Tn_1 = ChebyshevPolyExact(d - 1, power_of_two)
        Tn_2 = ChebyshevPolyExact(d - 2, power_of_two)

        # Double Tn_1
        doubled = map(r -> 2 * r, Tn_1)
        
        # Create the new polynomial
        Tn = [BigInt(0) // 1; doubled] - vcat(Tn_2, [BigInt(0) // 1, BigInt(0) // 1])
        
        # Convert to power-of-2 denominators if requested
        return power_of_two ? map(closest_pow2denom_rational, Tn) : Tn
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