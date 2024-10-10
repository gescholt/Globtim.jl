# ======================================================= Structures ======================================================
"""
    struct ApproxPoly

A structure to represent the polynomial approximation and related data.

# Fields
- `coeffs::Vector`: The coefficients of the polynomial approximation.
- `nrm::Float64`: The norm of the polynomial approximation.
- `N::Int`: The number of grid points used in the approximation.
- `scale_factor::Float64`: The scaling factor applied to the domain.
- `grid::Matrix{Float64}`: The grid of points used in the approximation.
- `z::Vector{Float64}`: The values of the function at the grid points.

# Description
The `ApproxPoly` struct is used to store the results of a polynomial approximation, including the coefficients of the polynomial, the norm of the approximation, the number of grid points, the scaling factor, the grid of points, and the values of the function at the grid points.

# Comment
It should also return the degree of the object

# Example
```julia
coeffs = [1.0, 2.0, 3.0]
nrm = 0.1
N = 10
scale_factor = 1.0
grid = rand(10, 2)
z = rand(10)
approx_poly = ApproxPoly(coeffs, nrm, N, scale_factor, grid, z)
"""
struct ApproxPoly
    coeffs::Vector
    nrm::Float64
    N::Int
    scale_factor::Float64
    grid::Matrix{Float64}
    z::Vector{Float64}
end
"""
    struct test_input

    Contains all the parameters to run a test. 

    sample_scale: scales the range of the square on which we sample 
    reduce_samples: Take only a precentage of the required samples if sample set size gets too big. 

"""

struct test_input
    dim::Int
    prec::Tuple{Float64,Float64} # alpha and delta, probabilistic parameters
    tolerance::Float64
    noise::Tuple{Float64,Float64}
    sample_scale::Float64
    reduce_samples::Float64
    # minimizer_size::Vector
    objective::Function
end

"""
    create_test_input()
Generate standard inputs for test function 
"""
# Function to create a pre-populated instance of test_input
function create_test_input(f::Function; n = 2, alpha = .1, delta = .5, reduce_samples = 1.)::test_input
    # Set predefined values
    prec = (alpha, delta)  # Example values for alpha and delta
    noise = (0., 0.)   # Example values for noise parameters
    tolerance = 2e-3     # Example tolerance value
    sample_scale = 1.0    # Reduce number of taken samples
    return test_input(n, prec, tolerance, noise, sample_scale, reduce_samples, f)
end

"""
Constructor(T, degree) takes a test input and a starting degree and computes the polynomial approximant satisfying that tolerance. 

"""
function Constructor(T::test_input, degree::Int)::ApproxPoly
    p = nothing  # Initialize p to ensure it is defined before the loop
    while true # Potential infinite loop
        p = MainGenerate(T.objective, T.dim, degree, T.prec[2], T.prec[1], T.sample_scale, T.reduce_samples)
        if p.nrm < T.tolerance
            println("attained the desired L2-norm: ", p.nrm)
            println("Degree :$degree ")
            break
        else 
            println("current L2-norm: ", p.nrm)
            println("Number of samples: ", p.N)
            degree += 1
            println("Increase degree to: $degree")
        end
    end 
    println("current L2-norm: ", p.nrm)
    println("Number of samples: ", p.N)
    return p 
end 

"""
    MainGenerate(f, n::Int, d::Int, delta::Float64, alph::Float64, scale_factor::Float64, scl::Float64; center::Vector{Float64}=fill(0.0, n))::ApproxPoly

Compute the coefficients of the polynomial approximant of degree `d` in the Chebyshev basis.

# Arguments
- `f::Function`: The objective function to approximate.
- `n::Int`: The number of variables.
- `d::Int`: The degree of the polynomial.
- `delta::Float64`: Sampling parameter.
- `alph::Float64`: Probability parameter.
- `scale_factor::Float64`: Scaling factor for the domain.
- `scl::Float64`: Scaling factor to reduce the number of points in the grid.
- `center::Vector{Float64}`: The center of the domain (default is a zero vector of length `n`).

# Returns
- `ApproxPoly`: An object containing the polynomial approximation and related data.

# Description
This function computes the coefficients of a polynomial approximant of degree `d` in the Chebyshev basis. The function constructs a Vandermonde-like matrix with monomials centered at the origin for stability and applicability of the theorems. The critical points are then rescaled to the appropriate positions in the domain.

# Example
```julia
f = x -> sum(x.^2)
n = 2
d = 3
delta = 0.1
alph = 0.05
scale_factor = 1.0
scl = 0.5
center = [0.0, 0.0]
approx_poly = MainGenerate(f, n, d, delta, alph, scale_factor, scl, center=center)
# approx_poly is an ApproxPoly object containing the polynomial approximation and related data
"""
function MainGenerate(f, n::Int, d::Int, delta::Float64, alph::Float64, scale_factor::Float64, scl::Float64; center::Vector{Float64}=fill(0.0, n))::ApproxPoly
    m = binomial(n + d, d)  # Dimension of vector space
    K = calculate_samples(m, delta, alph)
    GN = Int(round(K^(1 / n) * scl) + 1) # need fewer points for high degre stuff # 
    Lambda = SupportGen(n, d)
    grid = generate_grid(n, GN) # Intermediate grid
    matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))' # the tensor we return in matrix form. 
    VL = lambda_vandermonde(Lambda, matrix_from_grid)
    G_original = VL' * VL
    F = [f([scale_factor * matrix_from_grid[Int(i), :]...] + center) for i in 1:(GN+1)^n]
    RHS = VL' * F

    # Solve linear system using an appropriate LinearSolve function
    linear_prob = LinearProblem(G_original, RHS) # Define the linear problem
    # Now solve the problem with proper choice of compute method. 
    sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
    nrm = norm(VL * sol.u - F)/(GN^n) # Watch out, we divide by GN to get the discrete norm
    return ApproxPoly(sol, nrm, GN, scale_factor, matrix_from_grid, F)
end


"""
    main_nd(n::Int, d::Int, coeffs::Vector{Float64})::Vector{Rational{BigInt}}

Compute the coefficients of a bivariate polynomial in the standard monomial basis through an expansion in `Rational{BigInt}` format.

# Arguments
- `n::Int`: The number of variables.
- `d::Int`: The degree of the polynomial approximant.
- `coeffs::Vector{Float64}`: A vector of coefficients of the polynomial approximant in the Chebyshev basis.

# Returns
- `Vector{Rational{BigInt}}`: A vector of coefficients of the bivariate polynomial in the standard monomial basis.

# Description
This function computes the coefficients of a bivariate polynomial in the standard monomial basis through an expansion in `Rational{BigInt}` format. The input `coeffs` is a vector of coefficients of the polynomial approximant in the Chebyshev basis. The function assumes that the variables `x` are defined in a `DynamicPolynomials` environment using `@polyvar`.

# Example
```julia
n = 2
d = 3
coeffs = [0.5, 1.0, -0.5, 0.25]
result = main_nd(n, d, coeffs)
# result is a vector of Rational{BigInt} coefficients
"""
function main_nd(n::Int, d::Int, coeffs::Vector{Float64})::Vector{Rational{BigInt}}
    lambda = SupportGen(n, d).data  # Assuming support_gen is defined elsewhere
    m = size(lambda)[1]
    if length(coeffs) != m
        println(coeffs)
        println("\n")
        error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
    end
    coeffs = convert.(Rational{BigInt}, coeffs)
    @polyvar x[1:n]
    S_rat = zero(x[1])
    for j in 1:m
        prd = one(x[1])
        for k in 1:n
            coeff_vec = ChebyshevPolyExact(lambda[j, k])
            sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
            prd *= sum(sized_coeff_vec .* MonomialVector([x[k]], 0:d))
        end
        S_rat += coeffs[j] * prd
    end
    return coefficients(S_rat)
end


