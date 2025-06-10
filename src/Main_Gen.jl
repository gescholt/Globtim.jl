# Modified MainGenerate function to handle vector scale_factor

"""
    MainGenerate(
        f,
        n::Int,
        d::Int,
        delta::Float64,
        alpha::Float64,
        scale_factor::Union{Float64,Vector{Float64}},
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
- `scale_factor`: Scaling factor(s) for the domain (scalar or vector)
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
TimerOutputs.@timeit _TO function MainGenerate(
    f,
    n::Int,
    d,
    delta::Float64,
    alpha::Float64,
    scale_factor::Union{Float64,Vector{Float64}},
    scl::Float64;
    center::Vector{Float64}=fill(0.0, n),
    verbose=1,
    basis::Symbol=:chebyshev,
    GN::Union{Int,Nothing}=nothing,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false
)::ApproxPoly
    m = binomial(n + maximum(d), maximum(d))  # Dimension of vector space
    K = calculate_samples(m, delta, alpha)

    # Use provided GN if given, otherwise compute it
    actual_GN = if isnothing(GN)
        Int(round(K^(1 / n) * scl) + 1)
    else
        GN
    end

    Lambda = SupportGen(n, d)
    if n <= 0
        grid = generate_grid_small_n(n, actual_GN, basis=basis)
    else
        grid = generate_grid(n, actual_GN, basis=basis)
    end
    matrix_from_grid = reduce(vcat, map(x -> x', reshape(grid, :)))
    VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
    G_original = VL' * VL

    # Convert center to SVector
    scaled_center = SVector{n,Float64}(center)

    # Handle different scale_factor types for function evaluation
    TimerOutputs.@timeit _TO "evaluation" begin
        if isa(scale_factor, Number)
            # Scalar scale_factor
            F = map(x -> f(scale_factor * x + scaled_center), reshape(grid, :))
        else
            # Vector scale_factor - element-wise multiplication for each coordinate
            # Create a function to apply per-coordinate scaling
            function apply_scale(x)
                scaled_x = SVector{n,Float64}([scale_factor[i] * x[i] for i in 1:n])
                return f(scaled_x + scaled_center)
            end
            F = map(apply_scale, reshape(grid, :))
        end
    end

    cond_vandermonde = cond(G_original)
    TimerOutputs.@timeit _TO "linear_solve_vandermonde" begin
        RHS = VL' * F
        linear_prob = LinearProblem(G_original, RHS)
        if verbose == 1
            println("Condition number of G: ", cond_vandermonde)
            sol = LinearSolve.solve(linear_prob, verbose=true)
            println("Chosen method: ", typeof(sol.alg))
        else
            sol = LinearSolve.solve(linear_prob)
        end
    end

    # Compute norm based on basis type
    TimerOutputs.@timeit _TO "norm_computation" nrm = if basis == :chebyshev
        # Type-stable norm computation
        compute_norm(scale_factor, VL, sol, F, grid, n, d)
    else  # Legendre case
        # Use uniform weights for Legendre grid
        sqrt((2 / actual_GN)^n * sum(abs2.(VL * sol.u - F)))
    end

    # Store the basis parameters in the ApproxPoly object
    # Use the smart constructor to get correct type parameters
    return ApproxPoly(
        sol.u, d, nrm, actual_GN, scale_factor, matrix_from_grid, F,
        basis, precision, normalized, power_of_two_denom, cond_vandermonde
    )
end

# Update the Constructor function to pass through the vector scale_factor
TimerOutputs.@timeit _TO function Constructor(
    T::test_input,
    degree;
    verbose=0,
    basis::Symbol=:chebyshev,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=false,
    power_of_two_denom::Bool=false
)
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