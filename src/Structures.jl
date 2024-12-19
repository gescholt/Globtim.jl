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

A structure containing all parameters needed to run a test.

# Fields
- `dim::Int`: Dimension of the problem space
- `center::Vector{Float64}`: Center point of the sampling region
- `GN::Union{Int, Nothing}`: Number of samples (optional)
- `prec::Union{Tuple{Float64,Float64}, Nothing}`: Precision parameters (α, δ)
- `tolerance::Union{Float64, Nothing}`: Convergence tolerance
- `noise::Union{Tuple{Float64,Float64}, Nothing}`: Noise parameters
- `sample_range::Union{Float64, Nothing}`: Range for sampling around center
- `reduce_samples::Union{Float64, Nothing}`: Reduction factor for sample set size
- `objective::Function`: Objective function to be evaluated

# Constructor
    test_input(f::Function; kwargs...)

# Keyword Arguments
- `dim::Int=2`: Problem dimension
- `center::AbstractVector{Float64}=fill(0.0, dim)`: Center point
- `alpha::Float64=0.1`: First precision parameter
- `delta::Float64=0.5`: Second precision parameter
- `tolerance::Float64=2e-3`: Convergence tolerance
- `sample_range::Number=1.0`: Sampling range around center
- `reduce_samples::Float64=1.0`: Sample reduction factor
- `model=nothing`: Optional model parameter passed to objective function
- `outputs=nothing`: Optional outputs parameter passed to objective function
"""
struct test_input
    dim::Int
    center::Vector{Float64}
    GN::Union{Int,Nothing}
    prec::Union{Tuple{Float64,Float64},Nothing}
    tolerance::Union{Float64,Nothing}
    noise::Union{Tuple{Float64,Float64},Nothing}
    sample_range::Union{Float64,Nothing}
    reduce_samples::Union{Float64,Nothing}
    objective::Function

    # Enhanced constructor with all defaults built-in
    function test_input(
        f::Function;
        dim::Int=2,
        center::AbstractVector{Float64}=fill(0.0, dim),
        GN::Union{Int,Nothing}=nothing,
        alpha::Float64=0.1,
        delta::Float64=0.5,
        tolerance::Float64=2e-3,
        sample_range::Number=1.0,
        reduce_samples::Float64=1.0,
        model=nothing,
        outputs=nothing
    )
        # Validation
        length(center) == dim || throw(ArgumentError("center vector length must match dim"))

        # Create wrapped objective function
        objective = (x) -> f(x, model=model, measured_data=outputs)

        # Convert to concrete Vector type for storage
        center_vec = Vector{Float64}(center)

        # Create precision and noise tuples
        prec = (alpha, delta)
        noise = (0.0, 0.0)

        # Convert sample_range to Float64 if needed (handles Rational input)
        sample_range_float = Float64(sample_range)

        new(dim, center_vec, GN, prec, tolerance, noise, sample_range_float, reduce_samples, objective)
    end
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
    model=nothing,
    outputs=nothing
)::test_input
    return test_input(
        f;
        dim=n,
        center=center,
        tolerance=tolerance,
        alpha=alpha,
        delta=delta,
        sample_range=sample_range,
        reduce_samples=reduce_samples,
        model=model,
        outputs=outputs
    )
end