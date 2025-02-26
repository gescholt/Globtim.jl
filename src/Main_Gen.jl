# src/Main_gen.jl
# Main generation and manipulation functions for polynomial approximations


"""
    MainGenerate(
        f,
        n::Int,
        d::Int,
        delta::Float64,
        alpha::Float64,
        scale_factor::Float64,
        scl::Float64;
        center::Vector{Float64} = fill(0.0, n),
        verbose = 1,
        basis::Symbol = :chebyshev,
        GN::Union{Int,Nothing} = nothing,
        precision::PrecisionType = RationalPrecision,
        normalized::Bool = true,
        power_of_two_denom::Bool = false
    )::ApproxPoly

Compute the coefficients of a polynomial approximant of degree `d` in the specified basis.

# Arguments
- `f`: The objective function to approximate
- `n`: Number of variables
- `d`: Maximum degree of the polynomial
- `delta`: Sampling parameter
- `alpha`: Probability parameter
- `scale_factor`: Scaling factor for the domain
- `scl`: Scaling factor to reduce the number of points in the grid
- `center`: The center of the domain
- `verbose`: Verbosity level
- `basis`: Type of basis (:chebyshev or :legendre)
- `GN`: Number of grid points per dimension (computed if not provided)
- `precision`: Precision type for coefficients
- `normalized`: Whether to use normalized basis polynomials
- `power_of_two_denom`: For rational precision, ensures denominators are powers of 2

# Returns
- `ApproxPoly`: An object containing the polynomial approximation and related data
"""
function MainGenerate(
    f,
    n::Int,
    d::Int,
    delta::Float64,
    alpha::Float64,
    scale_factor::Float64,
    scl::Float64;
    center::Vector{Float64}=fill(0.0, n),
    verbose=1,
    basis::Symbol=:chebyshev,
    GN::Union{Int,Nothing}=nothing,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false
)::ApproxPoly
    m = binomial(n + d, d)  # Dimension of vector space
    K = calculate_samples(m, delta, alpha)

    # Use provided GN if given, otherwise compute it
    actual_GN = if isnothing(GN)
        Int(round(K^(1 / n) * scl) + 1)
    else
        GN
    end

    Lambda = SupportGen(n, d)
    if n <= 4
        grid = generate_grid_small_n(n, actual_GN, basis=basis)
    else
        grid = generate_grid(n, actual_GN, basis=basis)
    end
    matrix_from_grid = reduce(vcat, map(x -> x', reshape(grid, :)))
    VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
    G_original = VL' * VL
    scaled_center = SVector{n,Float64}(center)
    F = map(x -> f(scale_factor * x + scaled_center), reshape(grid, :))
    RHS = VL' * F
    linear_prob = LinearProblem(G_original, RHS)
    if verbose == 1
        println("Condition number of G: ", cond(G_original))
        sol = LinearSolve.solve(linear_prob, verbose=true)
        println("Chosen method: ", typeof(sol.alg))
    else
        sol = LinearSolve.solve(linear_prob)
    end

    # Compute norm based on basis type
    nrm = if basis == :chebyshev
        # Compute Riemann sum norm over the Chebyshev grid
        residual = x -> (VL*sol.u-F)[findfirst(y -> y == x, reshape(grid, :))]
        discrete_l2_norm_riemann(residual, grid)
    else  # Legendre case
        # Use uniform weights for Legendre grid
        sqrt((2 / actual_GN)^n * sum(abs2.(VL * sol.u - F)))
    end

    # Store the basis parameters in the ApproxPoly object
    return ApproxPoly{Float64}(
        sol, d, nrm, actual_GN, scale_factor, matrix_from_grid, F;
        basis=basis,
        precision=precision,
        normalized=normalized,
        power_of_two_denom=power_of_two_denom
    )
end


"""
    Constructor(
        T::test_input,
        degree::Int;
        verbose = 0,
        basis::Symbol = :chebyshev,
        precision::PrecisionType = RationalPrecision,
        normalized::Bool = true,
        power_of_two_denom::Bool = false
    )::ApproxPoly

Compute a polynomial approximant satisfying a given tolerance.

# Arguments
- `T`: Test input containing objective function and parameters
- `degree`: Starting degree for the polynomial
- `verbose`: Verbosity level
- `basis`: Type of basis (:chebyshev or :legendre)
- `precision`: Precision type for coefficients
- `normalized`: Whether to use normalized basis polynomials
- `power_of_two_denom`: For rational precision, ensures denominators are powers of 2

# Returns
- `ApproxPoly`: The polynomial approximation
"""
function Constructor(
    T::test_input,
    degree::Int;
    verbose=0,
    basis::Symbol=:chebyshev,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false
)::ApproxPoly
    if !(basis in [:chebyshev, :legendre])
        throw(ArgumentError("basis must be either :chebyshev or :legendre"))
    end

    if !isnothing(T.GN) && isa(T.GN, Int)
        p = MainGenerate(
            T.objective,
            T.dim,
            degree,
            T.prec[2],
            T.prec[1],
            T.sample_range,
            T.reduce_samples;
            center=T.center,
            verbose=verbose,
            basis=basis,
            GN=T.GN,
            precision=precision,
            normalized=normalized,
            power_of_two_denom=power_of_two_denom
        )
        println("current L2-norm: ", p.nrm)
        return p
    end

    p = nothing
    while true
        p = MainGenerate(
            T.objective,
            T.dim,
            degree,
            T.prec[2],
            T.prec[1],
            T.sample_range,
            T.reduce_samples;
            center=T.center,
            verbose=verbose,
            basis=basis,
            GN=T.GN,
            precision=precision,
            normalized=normalized,
            power_of_two_denom=power_of_two_denom
        )
        if p.nrm < T.tolerance
            println("attained the desired L2-norm: ", p.nrm)
            println("Degree :$degree ")
            break
        else
            degree += 1
            println("Increase degree to: $degree")
        end
    end
    return p
end
