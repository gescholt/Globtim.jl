# exact_conversion.jl
# Functions for converting polynomials from orthogonal bases to monomial basis with exact arithmetic

"""
    to_exact_monomial_basis(pol::ApproxPoly; variables=nothing)

Convert a polynomial from orthogonal basis (Chebyshev/Legendre) to monomial basis using exact arithmetic.

# Arguments
- `pol::ApproxPoly`: Polynomial approximation from Globtim
- `variables`: Array of polynomial variables (created automatically if not provided)

# Returns
- `DynamicPolynomials.Polynomial`: Polynomial in monomial basis with exact coefficients

# Example
```julia
TR = test_input(x -> sin(x[1]), dim=1, center=[0.0], sample_range=1.0)
pol = Constructor(TR, 10, basis=:chebyshev)
@polyvar x
mono_poly = to_exact_monomial_basis(pol, variables=[x])
```
"""
function to_exact_monomial_basis(pol::ApproxPoly; variables=nothing)
    # Get dimension from the polynomial
    dim = size(pol.grid, 2)
    
    # Create variables if not provided
    if variables === nothing
        @polyvar x[1:dim]
        variables = x
    end
    
    # Use Globtim's function to construct the polynomial
    # This handles the basis conversion internally
    mono_poly = construct_orthopoly_polynomial(
        variables,
        pol.coeffs,
        pol.degree,
        pol.basis,
        pol.precision;
        normalized=pol.normalized,
        power_of_two_denom=pol.power_of_two_denom
    )
    
    # Scale the polynomial to account for domain transformation
    # Globtim uses [-1,1]^n as reference domain, scaled by scale_factor
    if pol.scale_factor != 1.0
        # Substitute scaled variables
        scaled_vars = [v => v * pol.scale_factor for v in variables]
        mono_poly = substitute(mono_poly, scaled_vars)
    end
    
    return mono_poly
end

"""
    exact_polynomial_coefficients(f::Function, dim::Int, degree::Int; kwargs...)

Convenience function to get exact monomial coefficients directly from a function.

# Arguments
- `f::Function`: Function to approximate
- `dim::Int`: Dimension of the input
- `degree::Int`: Maximum polynomial degree
- `basis::Symbol = :chebyshev`: Basis to use (`:chebyshev` or `:legendre`)
- `center::Vector = zeros(dim)`: Center of approximation domain
- `sample_range::Real = 1.0`: Radius of approximation domain
- `tolerance::Real = 0.5`: Tolerance for approximation
- `precision = FloatPrecision`: Arithmetic precision

# Returns
- `DynamicPolynomials.Polynomial`: Polynomial in monomial basis

# Example
```julia
f = x -> x[1]^2 + x[2]^2
mono_poly = exact_polynomial_coefficients(f, 2, 4, basis=:chebyshev)
```
"""
function exact_polynomial_coefficients(f::Function, dim::Int, degree::Int;
                                     basis::Symbol = :chebyshev,
                                     center::Vector = zeros(dim),
                                     sample_range::Real = 1.0,
                                     tolerance::Real = 0.5,
                                     precision = Float64Precision)
    # Create test input
    TR = test_input(f, dim=dim, center=center, 
                   sample_range=sample_range, tolerance=tolerance)
    
    # Construct polynomial approximation
    pol = Constructor(TR, degree, basis=basis, precision=precision)
    
    # Convert to monomial basis
    return to_exact_monomial_basis(pol)
end