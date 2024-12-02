# ======================================================= Structures ======================================================
"""
    struct ApproxPoly

A structure to represent the polynomial approximation and related data.

# Fields
- `coeffs::Vector`: The coefficients of the polynomial approximation. Could be floats or Big
rationals. 
_ `degree::Int`: The degree of the polynomial approximation.
- `nrm::Float64`: The norm of the polynomial approximation.
- `N::Int`: The number of grid points used in the approximation.
- `scale_factor::Float64`: The scaling factor applied to the domain.
- `grid::Matrix{Float64}`: The grid of points used in the approximation.
- `z::Vector{Float64}`: The values of the function objective at the grid points.

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
z = 
approx_poly = ApproxPoly(coeffs, nrm, N, scale_factor, grid, z)
"""
struct ApproxPoly{T<:Number}
    coeffs::Vector{T}
    degree::Int
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
    center::Vector{Float64}
    prec::Tuple{Float64,Float64} # alpha and delta, probabilistic parameters
    tolerance::Float64
    noise::Tuple{Float64,Float64}
    sample_range::Float64
    reduce_samples::Float64
    # minimizer_size::Vector
    objective::Function
end

# ======================================================= Functions ======================================================



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
function MainGenerate(f, n::Int, d::Int, delta::Float64, alph::Float64, scale_factor::Float64, scl::Float64;
    center::Vector{Float64}=fill(0.0, n), verbose=0, basis=:chebyshev, GN::Union{Int,Nothing}=nothing)::ApproxPoly
    m = binomial(n + d, d)  # Dimension of vector space
    K = calculate_samples(m, delta, alph)

    # Use provided GN if given, otherwise compute it
    actual_GN = if isnothing(GN)
        Int(round(K^(1 / n) * scl) + 1)
    else
        GN
    end

    Lambda = SupportGen(n, d)
    matrix_from_grid = generate_grid(n, actual_GN, basis=basis)
    VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
    G_original = VL' * VL
    if verbose == 1
        println("Condition number of G: ", cond(G_original))
    end
    F = [f([scale_factor * matrix_from_grid[Int(i), :]...] + center) for i in 1:(actual_GN+1)^n]
    RHS = VL' * F
    # Solve linear system using an appropriate LinearSolve function
    linear_prob = LinearProblem(G_original, RHS) # Define the linear problem
    # Now solve the problem with proper choice of compute method. 
    sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
    nrm = norm(VL * sol.u - F) / (actual_GN^n) # Watch out, we divide by GN to get the discrete norm
    return ApproxPoly{Float64}(sol, d, nrm, actual_GN, scale_factor, matrix_from_grid, F)
end

"""
    main_nd(x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
    n::Int, d::Int, coeffs::Vector{Float64})::Polynomial{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder},Rational{BigInt}}    

Construct a polynomial in the standard monomial basis from a vector of coefficients (which have been computed in the tensorized Chebyshev basis).

"""
function main_nd(x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
    n::Int, d::Int, coeffs::Vector{Float64};
    basis=:chebyshev,
    verbose=false,
    bigint=false)

    lambda = SupportGen(n, d).data
    m = size(lambda)[1]

    if verbose
        println("Dimension m of the vector space: ", m)
    end

    if length(coeffs) != m
        if verbose
            println("The length of coeffs_poly_approx does not match the dimension of the space we project onto")
        end
        error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
    end

    coeffs = convert.(Rational{bigint ? BigInt : Int}, coeffs)
    S_rat = zero(x[1])

    if basis == :chebyshev
        for j in 1:m
            prd = one(x[1])
            for k in 1:n
                coeff_vec = ChebyshevPolyExact(lambda[j, k])
                sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
                prd *= sum(sized_coeff_vec .* MonomialVector([x[k]], 0:d))
            end
            S_rat += coeffs[j] * prd
        end
    elseif basis == :legendre
        max_degree = maximum(lambda)
        legendre_coeffs = get_legendre_coeffs(max_degree)

        for j in 1:m
            prd = one(x[1])
            for k in 1:n
                deg = lambda[j, k]
                coeff_vec = legendre_coeffs[deg+1]
                sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
                prd *= sum(sized_coeff_vec .* MonomialVector([x[k]], 0:d))
            end
            S_rat += coeffs[j] * prd
        end
    end

    # If not using BigInt, convert coefficients to simpler rational numbers
    if !bigint
        terms_array = terms(S_rat)
        simplified_terms = map(terms_array) do term
            coeff = coefficient(term)
            try
                # Try to convert to simpler Rational{Int}
                simple_coeff = convert(Rational{Int}, rationalize(Float64(coeff)))
                simple_coeff * monomial(term)
            catch e
                @warn "Coefficient too large for Int, switching to BigInt for this term"
                coeff * monomial(term)  # Keep original BigInt coefficient
            end
        end
        return sum(simplified_terms)
    end

    return S_rat
end

"""
Constructor(T, degree) takes a test input and a starting degree and computes the polynomial approximant satisfying that tolerance. 
If GN, the number of samples (per dimension), is specified, it will only compute the polynomial approximant for that number of samples.

"""
function Constructor(T::test_input, degree::Int; verbose=0, basis::Symbol=:chebyshev, GN::Union{Int,Nothing}=nothing)::ApproxPoly
    # Validate the basis parameter
    if !(basis in [:chebyshev, :legendre])
        throw(ArgumentError("basis must be either :chebyshev or :legendre"))
    end

    if !isnothing(GN)
        # If GN is specified, just do one construction
        p = MainGenerate(T.objective, T.dim, degree, T.prec[2], T.prec[1], T.sample_range, T.reduce_samples,
            center=T.center, verbose=verbose, basis=basis, GN=GN)
        println("current L2-norm: ", p.nrm)
        println("Number of samples: ", p.N)
        return p
    end

    # Original behavior for when GN is nothing
    p = nothing
    while true
        p = MainGenerate(T.objective, T.dim, degree, T.prec[2], T.prec[1], T.sample_range, T.reduce_samples,
            center=T.center, verbose=verbose, basis=basis, GN=GN)
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
    create_test_input()
Generate standard inputs for test function 
"""
# Function to create a pre-populated instance of test_input
function create_test_input(f::Function;
    n=2,
    center=fill(0.0, n),
    tolerance=2e-3,
    alpha=0.1,
    delta=0.5,
    sample_range=1.0,
    reduce_samples=1.0,
    model=nothing,  # New parameter
    outputs=nothing  # New parameter
)::test_input
    prec = (alpha, delta)  # Example values for alpha and delta
    noise = (0.0, 0.0)   # Example values for noise parameters
    #sample range: rescales the [-1, 1]^n hypercube ?

    objective = (x) -> f(x, model=model, measured_data=outputs)  # Wrap function to include model and outputs

    return test_input(n, center, prec, tolerance, noise, sample_range, reduce_samples, objective)
end
