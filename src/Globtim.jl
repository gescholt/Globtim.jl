module Globtim

# Import LinearAlgebra
using CSV
using Colors
using DataFrames
using DynamicPolynomials
using HomotopyContinuation
using MultivariatePolynomials
using Optim
using PlotlyJS
using ProgressLogging


# Import necessary packages
using LinearAlgebra
include("lib_func.jl")

# Your code here



# ======================================================= Structures ======================================================
struct ApproxResult
    coeffs::Vector{Vector{Float64}}
    nrm::Vector{Float64}
end

# ======================================================= Functions =======================================================

function zeta(x::Float64)::Float64
    # =======================================================
    # Relative tolearance function for the number of samples
    # =======================================================
    return x + (1 - x) * log(1 - x)
end


# Function to calculate the required number of samples
function calculate_samples(m::Int, delta::Float64, alph::Float64)::Int
    # =======================================================
    # Generate enought samples to satisfy the error bound with respect to tensorized Chebyshev polynomial basis.
    # m: dimension of the polynomial space
    # delta: relative error bound
    # alph: probability, confidence level
    # =======================================================
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

function support_gen(n::Int, d::Int)::NamedTuple
    # =======================================================
    # Function to compute the support of polynomial of total degree at most $d$. 
    # =======================================================
    ranges = [0:d for _ in 1:n]     # Generate ranges for each dimension
    iter = Iterators.product(ranges...) # Create the Cartesian product over the ranges
    # Initialize a list to hold valid tuples
    lambda_list = []
    # Loop through the Cartesian product, filtering valid tuples
    for tuple in iter
        if sum(tuple) <= d
            push!(lambda_list, collect(tuple))  # Convert each tuple to an array
        end
    end
    # Check if lambda_list is empty to handle edge cases
    if length(lambda_list) == 0
        lambda_matrix = zeros(0, n)  # Return an empty matrix with 0 rows and n columns
    else
        # Convert the list of arrays to an N x n matrix
        lambda_matrix = hcat(lambda_list...)'
    end
    # Return a NamedTuple containing the matrix and its size attributes
    return (data=lambda_matrix, size=size(lambda_matrix))
end

function generate_grid(n::Int, GN::Int)
    # =======================================================
    # Function to generate tensorized Chebyshev grid 
    # =======================================================
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
end

function chebyshev_poly(d::Int, x)
    # =======================================================
    # Function to generate Chebyshev polynomial of degree d in the variable x 
    # =======================================================
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

function lambda_vandermonde(Lambda, S)
    # =======================================================
    # Generate Vandermonde like matrix in Chebyshev tensored basis.
    # Lambda: matrix of the support of the polynomial space
    # =======================================================
    m, N = Lambda.size
    n, N = size(S)
    V = zeros(n, m)
    for i in 1:n # Number of samples
        for j in 1:m # Dimension of vector space of polynomials
            P = 1.0
            for k in 1:N # Dimension of each sample
                P *= chebyshev_poly(Lambda.data[j, k], S[i, k])
            end
            V[i, j] = P
        end
    end
    return V
end

# Geneate the approximants in the new optim file, more parameters are added to the function.
function main_gen(f, n::Int, d1::Int, d2::Int, ds::Int, delta::Float64, alph::Float64, C::Float64, scl::Float64; center::Vector{Float64}=fill(0.0, n))::Vector{Vector{Float64}}
    # =======================================================
    #   Computation of the coefficients of the polynomial approximant in the Chebyshev basis.
    #   slc is a scaling factor to reduce the number of points in the grid.
    #   The center parameter only affects the domain of the function.
    #   We want to construct the Vandermonde like matrix wth monomials centered at the origin for stability and applicability of the theorems.
    #   We then rescale the critical points to put them at the right spot in the domain.
    # =======================================================
    symb_approx = []
    NRM = []
    for d in d1:ds:d2
        m = binomial(n + d, d)  # Dimension of vector space
        K = calculate_samples(m, delta, alph)
        GN = Int(round(K^(1 / n) * scl) + 1) # need fewe points for high degre stuff # 
        Lambda = support_gen(n, d)
        grid = generate_grid(n, GN)
        matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'
        VL = lambda_vandermonde(Lambda, matrix_from_grid)
        G_original = VL' * VL
        F = [f([C * matrix_from_grid[Int(i), :]...] + center) for i in 1:(GN+1)^n]
        RHS = VL' * F

        # Solve linear system using an appropriate LinearSolve function
        linear_prob = LinearProblem(G_original, RHS) # Define a linear problem
        # Now solve the problem with proper choice of compute method. 

        sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
        nrm = norm(VL.sol.u - F)

        push!(symb_approx, sol.u)
        push!(NRM, nrm)
    end
    return ApproxResult(symb_approx, NRM)
end

# Export the primary functions and types
export main_gen, ApproxResult

end