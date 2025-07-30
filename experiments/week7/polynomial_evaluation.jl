"""
    polynomial_evaluation.jl

Functions for evaluating Globtim polynomial approximants at arbitrary points.
Based on the approach used in Globtim's LevelSetViz.jl
"""

using Globtim
using DynamicPolynomials
using LinearAlgebra

"""
    evaluate_polynomial_at_point(pol::ApproxPoly, TR::test_input, point::AbstractVector)

Evaluate a Globtim polynomial approximant at a given point.

# Arguments
- `pol`: ApproxPoly object from Globtim
- `TR`: test_input object containing domain information
- `point`: Point in the actual domain (not the [-1, 1]^n domain)

# Returns
- Polynomial value at the point
"""
function evaluate_polynomial_at_point(pol::ApproxPoly, TR::test_input, point::AbstractVector)
    # Convert polynomial to standard monomial basis
    n = TR.dim
    @polyvar x[1:n]
    wd_in_std_basis = to_exact_monomial_basis(pol, variables=x)
    
    # Transform point from actual domain to [-1, 1]^n (pullback)
    # Handle both scalar and vector scale_factor
    if isa(pol.scale_factor, Number)
        point_normalized = (1 / pol.scale_factor) * (point .- TR.center)
    else
        point_normalized = [(point[i] - TR.center[i]) / pol.scale_factor[i] for i in 1:n]
    end
    
    # Evaluate polynomial
    return DynamicPolynomials.subs(wd_in_std_basis, x => point_normalized)
end

"""
    compute_approximation_error_on_grid(objective_func, pol::ApproxPoly, TR::test_input, x_range, y_range)

Compute approximation error f(x) - w_d(x) on a 2D grid.

# Arguments
- `objective_func`: Original objective function
- `pol`: Polynomial approximant
- `TR`: test_input object
- `x_range`: Range of x values
- `y_range`: Range of y values

# Returns
- Matrix of approximation errors
"""
function compute_approximation_error_on_grid(objective_func, pol::ApproxPoly, TR::test_input, x_range, y_range)
    nx = length(x_range)
    ny = length(y_range)
    Z_error = zeros(ny, nx)
    
    # Convert polynomial to standard monomial basis once
    n = TR.dim
    @polyvar x[1:n]
    wd_in_std_basis = to_exact_monomial_basis(pol, variables=x)
    
    # Function to evaluate polynomial after pullback
    poly_func = p -> begin
        # Pullback transformation
        if isa(pol.scale_factor, Number)
            p_normalized = (1 / pol.scale_factor) * (p .- TR.center)
        else
            p_normalized = [(p[i] - TR.center[i]) / pol.scale_factor[i] for i in 1:n]
        end
        # Evaluate polynomial
        DynamicPolynomials.coefficients(
            DynamicPolynomials.subs(wd_in_std_basis, x => p_normalized)
        )[1]
    end
    
    for (j, y) in enumerate(y_range)
        for (i, x_val) in enumerate(x_range)
            point = [x_val, y]
            f_val = objective_func(point)
            p_val = poly_func(point)
            Z_error[j, i] = f_val - p_val
        end
    end
    
    return Z_error
end

"""
    compute_polynomial_values_on_grid(pol::ApproxPoly, TR::test_input, x_range, y_range)

Compute polynomial values w_d(x) on a 2D grid.

# Arguments
- `pol`: Polynomial approximant
- `TR`: test_input object
- `x_range`: Range of x values
- `y_range`: Range of y values

# Returns
- Matrix of polynomial values
"""
function compute_polynomial_values_on_grid(pol::ApproxPoly, TR::test_input, x_range, y_range)
    nx = length(x_range)
    ny = length(y_range)
    Z_poly = zeros(ny, nx)
    
    # Convert polynomial to standard monomial basis once
    n = TR.dim
    @polyvar x[1:n]
    wd_in_std_basis = to_exact_monomial_basis(pol, variables=x)
    
    # Function to evaluate polynomial after pullback
    poly_func = p -> begin
        # Pullback transformation
        if isa(pol.scale_factor, Number)
            p_normalized = (1 / pol.scale_factor) * (p .- TR.center)
        else
            p_normalized = [(p[i] - TR.center[i]) / pol.scale_factor[i] for i in 1:n]
        end
        # Evaluate polynomial
        DynamicPolynomials.coefficients(
            DynamicPolynomials.subs(wd_in_std_basis, x => p_normalized)
        )[1]
    end
    
    for (j, y) in enumerate(y_range)
        for (i, x_val) in enumerate(x_range)
            point = [x_val, y]
            Z_poly[j, i] = poly_func(point)
        end
    end
    
    return Z_poly
end