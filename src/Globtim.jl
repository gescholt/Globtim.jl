module Globtim

using CSV
using DataFrames
using DynamicPolynomials
using HomotopyContinuation
using LinearSolve
using LinearAlgebra

include("lib_func.jl")
include("Samples.jl")
include("ApproxConstruct.jl")



function MainGenerate(f, n::Int, d::Int, delta::Float64, alph::Float64, C::Float64, scl::Float64; center::Vector{Float64}=fill(0.0, n))::ApproxPoly
    # =======================================================
    #   Computation of the coefficients of the polynomial approximant of degree d in the Chebyshev basis.
    #   slc is a scaling factor to reduce the number of points in the grid.
    #   The center parameter only affects the domain of the function.
    #   We want to construct the Vandermonde like matrix wth monomials centered at the origin for stability and applicability of the theorems.
    #   We then rescale the critical points to put them at the right spot in the domain.
    # =======================================================
    symb_approx = []
    NRM = []
    m = binomial(n + d, d)  # Dimension of vector space
    K = calculate_samples(m, delta, alph)
    GN = Int(round(K^(1 / n) * scl) + 1) # need fewer points for high degre stuff # 
    Lambda = SupportGen(n, d)
    grid = generate_grid(n, GN)
    matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'
    VL = lambda_vandermonde(Lambda, matrix_from_grid)
    G_original = VL' * VL
    F = [f([C * matrix_from_grid[Int(i), :]...] + center) for i in 1:(GN+1)^n]
    RHS = VL' * F

    # Solve linear system using an appropriate LinearSolve function
    linear_prob = LinearProblem(G_original, RHS) # Define the linear problem
    # Now solve the problem with proper choice of compute method. 
    sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
    nrm = norm(VL * sol.u - F)/(GN^n) # Watch out, we divide by GN to get the discrete norm
    return ApproxPoly(sol, nrm, GN)
end


function main_2d(d::Int, coeffs_poly_approx::Vector{Float64}, x, coeff_type=:BigFloat)
    # =======================================================
    # Computes the coefficients of a bivariate polynomial in the standard monomial basis through an expansion in BigFloat format 
    # coeffs_poly_approx is the vector of coefficients of the polynomial approximant in the Chebyshev basis
    # x: DynamicPolynomials variables
    # Has to be used inside of a DynamicPolynomial environment where the variables x are defined (@polyvar)
    # =======================================================
    lambda = SupportGen(2, d).data  # Assuming support_gen is defined elsewhere
    m, n = size(lambda)
    if coeff_type == :RationalBigInt
        coeffs = convert.(Rational, coeffs_poly_approx)
    else
        coeffs = convert.(BigFloat, coeffs_poly_approx)
        println("Check")
    end
    if length(coeffs) != m
        println(coeffs)
        println("\n")
        error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
    end

    S_rat = zero(x[1])
    for j in 1:m
        prd = one(x[1])
        for k in 1:n
            prd *= BigFloatChebyshevPoly(lambda[j, k], x[k])
        end
        if coeff_type == :RationalBigInt
            S_rat += coeffs[j] * prd
        elseif coeff_type == :BigFloat
            S_rat += coeffs[j] * prd
        else
            error("Unsupported coefficient type. Use :RationalBigInt or :BigFloat.")
        end
    end
    return coefficients(S_rat)
end

function main_nd(n::Int, d::Int, coeffs_poly_approx::Vector{Float64}, x, coeff_type=:BigFloat)
    # =======================================================
    # Computes the coefficients of a bivariate polynomial in the standard monomial basis through an expansion in BigFloat format 
    # coeffs_poly_approx is the vector of coefficients of the polynomial approximant in the Chebyshev basis
    # n: number of variables
    # x: DynamicPolynomials variables
    # Has to be used inside of a DynamicPolynomial environment where the variables x are defined (@polyvar)
    # =======================================================
    lambda = SupportGen(n, d).data  # Assuming support_gen is defined elsewhere
    m = size(lambda)[1]
    if coeff_type == :RationalBigInt
        coeffs = convert.(Rational, coeffs_poly_approx)
    else
        coeffs = convert.(BigFloat, coeffs_poly_approx)
        println("Check")
    end
    if length(coeffs) != m
        println(coeffs)
        println("\n")
        error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
    end

    S_rat = zero(x[1])
    for j in 1:m
        prd = one(x[1])
        for k in 1:n
            prd *= BigFloatChebyshevPoly(lambda[j, k], x[k])
        end
        if coeff_type == :RationalBigInt
            S_rat += coeffs[j] * prd
        elseif coeff_type == :BigFloat
            S_rat += coeffs[j] * prd
        else
            error("Unsupported coefficient type. Use :RationalBigInt or :BigFloat.")
        end
    end
    return coefficients(S_rat)
end

# Export the primary functions and types
export MainGenerate, ApproxPoly, camel, main_2d, main_nd

end