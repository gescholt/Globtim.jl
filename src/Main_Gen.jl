# Modified MainGenerate function to handle vector scale_factor

"""
    MainGenerate(
        f,
        n::Int,
        d::Union{Tuple{Symbol,Int}, Tuple{Symbol,Vector{Int}}, Matrix{Float64}},
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
- `d`: Either:
  - Degree specification: `(:one_d_for_all, degree)` or `(:one_d_per_dim, [degrees...])`
  - Pre-generated grid: `Matrix{Float64}` where each row is a point in n-dimensional space
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
    d::Union{Tuple{Symbol,Int}, Tuple{Symbol,Vector{Int}}, Matrix{Float64}},
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
    # Check if d is a grid (Matrix format)
    grid_provided = isa(d, Matrix)
    
    if grid_provided
        # Validate grid dimensions
        @assert size(d, 2) == n "Grid dimension mismatch: expected $n, got $(size(d, 2))"
        @assert size(d, 1) > 0 "Empty grid provided"
        
        # Store grid information
        matrix_from_grid = d
        actual_GN = size(d, 1)
        
        # Infer polynomial degree from grid size
        # For tensor product grids: n_points ≈ (degree + 1)^dim
        n_per_dim = round(Int, actual_GN^(1/n))
        degree_est = n_per_dim - 1
        
        # Generate Lambda support based on inferred degree
        Lambda = SupportGen(n, (:one_d_for_all, degree_est))
        
        # Set D for compatibility
        D = degree_est
        K = actual_GN  # Use grid size as sample count
        
        # No need to generate grid - we already have it
        grid = nothing  # Will be set later for function evaluation
    else
        # Existing degree-based logic
        D = if d[1] == :one_d_for_all
            maximum(d[2])  
        elseif d[1] == :one_d_per_dim
            maximum(d[2])  
        elseif d[1] == :fully_custom
            0
        else
            throw(ArgumentError("Invalid degree format. Use :one_d_for_all or :one_d_per_dim or :fully_custom."))
        end

        m = binomial(n + D, D)  # Dimension of vector space
        K = calculate_samples(m, delta, alpha)

        # Use provided GN if given, otherwise compute it
        actual_GN = if isnothing(GN)
            Int(round(K^(1 / n) * scl) + 1)
        else
            GN
        end

        Lambda = SupportGen(n, d)
        
        # Generate grid
        if n <= 0
            grid = generate_grid_small_n(n, actual_GN, basis=basis)
        else
            grid = generate_grid(n, actual_GN, basis=basis)
        end
        matrix_from_grid = reduce(vcat, map(x -> x', reshape(grid, :)))
    end
    VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
    G_original = VL' * VL

    # Convert center to SVector
    scaled_center = SVector{n,Float64}(center)

    # Handle different scale_factor types for function evaluation
    TimerOutputs.@timeit _TO "evaluation" begin
        # Handle grid format differences
        if grid_provided
            # Grid is already in matrix format, create SVectors for evaluation
            grid_points = [SVector{n,Float64}(matrix_from_grid[i,:]) for i in 1:size(matrix_from_grid, 1)]
        else
            # Use existing grid (Vector of SVectors)
            grid_points = reshape(grid, :)
        end
        
        # Evaluate function on grid points
        if isa(scale_factor, Number)
            # Scalar scale_factor
            F = map(x -> f(scale_factor * x + scaled_center), grid_points)
        else
            # Vector scale_factor - element-wise multiplication for each coordinate
            # Create a function to apply per-coordinate scaling
            function apply_scale(x)
                scaled_x = SVector{n,Float64}([scale_factor[i] * x[i] for i in 1:n])
                return f(scaled_x + scaled_center)
            end
            F = map(apply_scale, grid_points)
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
        # Use grid_points which works for both cases
        compute_norm(scale_factor, VL, sol, F, grid_provided ? grid_points : grid, n, d)
    else  # Legendre case
        # Use uniform weights for Legendre grid
        sqrt((2 / actual_GN)^n * sum(abs2.(VL * sol.u - F)))
    end

    # Store the basis parameters in the ApproxPoly object
    # Use the smart constructor to get correct type parameters
    # For grid input, store the inferred degree format
    degree_info = grid_provided ? (:one_d_for_all, degree_est) : d
    
    return ApproxPoly(
        sol.u, Lambda.data, degree_info, nrm, actual_GN, scale_factor, matrix_from_grid, F,
        basis, precision, normalized, power_of_two_denom, cond_vandermonde
    )
end

"""
    Constructor(T::test_input, degree; kwargs...) -> ApproxPoly

Construct a polynomial approximation of the objective function using discrete least squares.

This is the main entry point for creating polynomial approximations in Globtim. The function
samples the objective on a tensorized grid of Chebyshev or Legendre nodes and fits a 
polynomial of the specified degree.

# Arguments
- `T::test_input`: Test input specification containing the objective function and domain
- `degree::Int`: Maximum degree of the polynomial approximation

# Keyword Arguments
- `verbose::Int=0`: Verbosity level (0=silent, 1=basic info, 2=detailed)
- `basis::Symbol=:chebyshev`: Basis type (`:chebyshev` or `:legendre`)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=false`: Whether to normalize the polynomial
- `power_of_two_denom::Bool=false`: Use power-of-two denominators for rationals

# Returns
- `ApproxPoly`: Polynomial approximation object containing:
  - `coeffs`: Coefficient matrix
  - `nrm`: L2-norm approximation error over the domain
  - `scale_factor`: Scaling factors used for the domain
  - Additional metadata about the approximation

# Notes
- The approximation error (`pol.nrm`) provides a measure of approximation quality
- Higher degrees generally reduce approximation error but increase computational cost
- Chebyshev basis is recommended for most problems due to better conditioning
- The function automatically handles both uniform and non-uniform domain scaling

# Examples
```julia
# Basic usage with default Chebyshev basis
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, 8)
println("L2-norm error: ", pol.nrm)

# Using Legendre basis with higher verbosity
pol = Constructor(TR, 10, basis=:legendre, verbose=1)

# High precision approximation
pol = Constructor(TR, 12, normalized=true)
```
"""
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
            degree isa Tuple ? degree : (:one_d_for_all, degree),
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
            (:one_d_for_all, degree),
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