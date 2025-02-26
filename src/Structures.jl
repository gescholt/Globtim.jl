# # src/Structures.jl

# """
#     struct ApproxPoly

# A structure to represent the polynomial approximation and related data.

# # Fields
# - `coeffs::Vector`: The coefficients of the polynomial approximation. Could be floats or Big
# rationals. 
# _ `degree::Int`: The degree of the polynomial approximation.
# - `nrm::Float64`: The norm of the polynomial approximation.
# - `N::Int`: The number of grid points used in the approximation.
# - `scale_factor::Float64`: The scaling factor applied to the domain.
# - `grid::Matrix{Float64}`: The grid of points used in the approximation.
# - `z::Vector{Float64}`: The values of the function objective at the grid points.

# # Description
# The `ApproxPoly` struct is used to store the results of a polynomial approximation, including the coefficients of the polynomial, the norm of the approximation, the number of grid points, the scaling factor, the grid of points, and the values of the function at the grid points.
# """
# struct ApproxPoly{T<:Number}
#     coeffs::Vector{T}
#     degree::Int
#     nrm::Float64
#     N::Int
#     scale_factor::Float64
#     grid::Matrix{Float64}
#     z::Vector{Float64}
# end

# """
#    struct test_input

# Container for test parameters and objective function.

# Fields:
# - `dim::Int`: Problem dimension
# - `center::Vector{Float64}`: Center point of search region
# - `GN::Union{Int,Nothing}`: Grid size (optional)
# - `prec::Union{Tuple{Float64,Float64},Nothing}`: Precision parameters (α,δ) 
# - `tolerance::Union{Float64,Nothing}`: Convergence tolerance
# - `noise::Union{Tuple{Float64,Float64},Nothing}`: Noise parameters
# - `sample_range::Union{Float64,Nothing}`: Sampling radius around center
# - `reduce_samples::Union{Float64,Nothing}`: Sample reduction factor
# - `degree_max::Union{Int, Nothing}`: Maximum polynomial degree
# - `objective::Function`: Function to optimize
# """
# struct test_input
#     dim::Int
#     center::Vector{Float64}
#     GN::Union{Int,Nothing}
#     prec::Union{Tuple{Float64,Float64},Nothing}
#     tolerance::Union{Float64,Nothing}
#     noise::Union{Tuple{Float64,Float64},Nothing}
#     sample_range::Union{Float64,Nothing}
#     reduce_samples::Union{Float64,Nothing}
#     degree_max::Union{Int,Nothing}
#     objective::Function

#     function test_input(
#         f::Function;
#         dim::Int = 2,
#         center::AbstractVector{<:Real} = fill(0.0, dim),
#         GN::Union{Int,Nothing} = nothing,
#         alpha::Union{Real,Nothing} = 0.1,
#         delta::Union{Real,Nothing} = 0.5,
#         tolerance::Union{Real,Nothing} = 2e-3,
#         sample_range::Union{Real,Nothing} = 1.0,
#         reduce_samples::Union{Real,Nothing} = 1.0,
#         degree_max::Int = 6,
#         model::Union{Nothing,Any} = nothing,  # Changed from ODESystem
#         outputs::Union{Nothing,AbstractVector{<:Real}} = nothing,
#     )
#         # Type conversions
#         center_vec = Vector{Float64}(float.(center))
#         sample_range_float = isnothing(sample_range) ? nothing : Float64(sample_range)
#         reduce_samples_float = isnothing(reduce_samples) ? nothing : Float64(reduce_samples)

#         # Create precision tuple if alpha and delta are provided
#         prec = if !isnothing(alpha) && !isnothing(delta)
#             (Float64(alpha), Float64(delta))
#         else
#             nothing
#         end

#         # Convert tolerance if provided
#         tolerance_float = isnothing(tolerance) ? nothing : Float64(tolerance)

#         # Validation
#         length(center_vec) == dim ||
#             throw(ArgumentError("center vector length must match dim"))

#         # Create objective function
#         objective = if isnothing(model) && isnothing(outputs)
#             f
#         elseif !isnothing(model) && !isnothing(outputs)
#             (x) -> f(x, model = model, measured_data = outputs)
#         elseif !isnothing(model)
#             (x) -> f(x, model = model)
#         else
#             (x) -> f(x, measured_data = outputs)
#         end

#         noise = (0.0, 0.0)

#         new(
#             dim,
#             center_vec,
#             GN,
#             prec,
#             tolerance_float,
#             noise,
#             sample_range_float,
#             reduce_samples_float,
#             degree_max,
#             objective,
#         )
#     end
# end

# """
#    create_test_input(f::Function; kwargs...)::test_input

# Convenience constructor for test_input with default values.

# # Arguments
# - `f::Function`: Objective function to optimize
# - `n=2`: Problem dimension 
# - `center=fill(0.0,n)`: Center point
# - `tolerance=2e-3`: Convergence tolerance
# - `alpha=0.1`: First precision parameter
# - `delta=0.5`: Second precision parameter
# - `sample_range=1.0`: Sampling radius
# - `reduce_samples=1.0`: Sample reduction
# - `degree_max=6`: Maximum polynomial degree
# - `model=nothing`: Optional model
# - `outputs=nothing`: Optional measured data
# """
# function create_test_input(
#     f::Function;
#     n::Int = 2,
#     center::AbstractVector{Float64} = fill(0.0, n),
#     tolerance::Float64 = 2e-3,
#     alpha::Float64 = 0.1,
#     delta::Union{Real,Nothing} = nothing,  # Made optional
#     sample_range::Float64 = 1.0,
#     reduce_samples::Union{Real,Nothing} = nothing,  # Made optional
#     degree_max::Int = 6,
#     model::Union{Nothing,Any} = nothing,  # Changed from ODESystem
#     outputs::Union{Nothing,AbstractVector{<:Real}} = nothing,
# )::test_input
#     return test_input(
#         f;
#         dim = n,
#         center = center,
#         tolerance = tolerance,
#         alpha = alpha,
#         delta = delta,
#         sample_range = sample_range,
#         reduce_samples = reduce_samples,
#         degree_max = degree_max,
#         model = model,
#         outputs = outputs,
#     )
# end

# src/Structures.jl

"""
    struct ApproxPoly

A structure to represent the polynomial approximation and related data.

# Fields
- `coeffs::Vector`: The coefficients of the polynomial approximation. Could be floats or Big rationals.
- `degree::Int`: The degree of the polynomial approximation.
- `nrm::Float64`: The norm of the polynomial approximation.
- `N::Int`: The number of grid points used in the approximation.
- `scale_factor::Float64`: The scaling factor applied to the domain.
- `grid::Matrix{Float64}`: The grid of points used in the approximation.
- `z::Vector{Float64}`: The values of the function objective at the grid points.
- `basis::Symbol`: Type of basis used (:chebyshev or :legendre).
- `precision::PrecisionType`: Precision type for coefficients.
- `normalized::Bool`: Whether normalized basis polynomials were used.
- `power_of_two_denom::Bool`: Whether power-of-2 denominators were used (for rational precision).

# Description
The `ApproxPoly` struct is used to store the results of a polynomial approximation, including the coefficients of the polynomial, the norm of the approximation, the number of grid points, the scaling factor, the grid of points, and the values of the function at the grid points. It also stores information about the basis used for the polynomial approximation.
"""
struct ApproxPoly{T<:Number}
    coeffs::Vector{T}
    degree::Int
    nrm::Float64
    N::Int
    scale_factor::Float64
    grid::Matrix{Float64}
    z::Vector{Float64}
    basis::Symbol
    precision::PrecisionType
    normalized::Bool
    power_of_two_denom::Bool

    # Original constructor (backward compatibility)
    function ApproxPoly{T}(
        coeffs::Vector{T},
        degree::Int,
        nrm::Float64,
        N::Int,
        scale_factor::Float64,
        grid::Matrix{Float64},
        z::Vector{Float64}
    ) where {T<:Number}
        new(
            coeffs, degree, nrm, N, scale_factor, grid, z,
            :chebyshev, RationalPrecision, true, false
        )
    end

    # Extended constructor with basis parameters
    function ApproxPoly{T}(
        coeffs::Vector{T},
        degree::Int,
        nrm::Float64,
        N::Int,
        scale_factor::Float64,
        grid::Matrix{Float64},
        z::Vector{Float64},
        basis::Symbol,
        precision::PrecisionType,
        normalized::Bool,
        power_of_two_denom::Bool
    ) where {T<:Number}
        new(
            coeffs, degree, nrm, N, scale_factor, grid, z,
            basis, precision, normalized, power_of_two_denom
        )
    end

    # Constructor from solver result
    function ApproxPoly{T}(
        sol,
        degree::Int,
        nrm::Float64,
        N::Int,
        scale_factor::Float64,
        grid::Matrix{Float64},
        z::Vector{Float64};
        basis::Symbol=:chebyshev,
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true,
        power_of_two_denom::Bool=false
    ) where {T<:Number}
        new(
            sol.u, degree, nrm, N, scale_factor, grid, z,
            basis, precision, normalized, power_of_two_denom
        )
    end
end

# Convenience accessor functions
get_basis(p::ApproxPoly) = p.basis
get_precision(p::ApproxPoly) = p.precision
is_normalized(p::ApproxPoly) = p.normalized
has_power_of_two_denom(p::ApproxPoly) = p.power_of_two_denom

"""
   struct test_input

Container for test parameters and objective function.

Fields:
- `dim::Int`: Problem dimension
- `center::Vector{Float64}`: Center point of search region
- `GN::Union{Int,Nothing}`: Grid size (optional)
- `prec::Union{Tuple{Float64,Float64},Nothing}`: Precision parameters (α,δ) 
- `tolerance::Union{Float64,Nothing}`: Convergence tolerance
- `noise::Union{Tuple{Float64,Float64},Nothing}`: Noise parameters
- `sample_range::Union{Float64,Nothing}`: Sampling radius around center
- `reduce_samples::Union{Float64,Nothing}`: Sample reduction factor
- `degree_max::Union{Int, Nothing}`: Maximum polynomial degree
- `objective::Function`: Function to optimize
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
    degree_max::Union{Int,Nothing}
    objective::Function

    function test_input(
        f::Function;
        dim::Int=2,
        center::AbstractVector{<:Real}=fill(0.0, dim),
        GN::Union{Int,Nothing}=nothing,
        alpha::Union{Real,Nothing}=0.1,
        delta::Union{Real,Nothing}=0.5,
        tolerance::Union{Real,Nothing}=2e-3,
        sample_range::Union{Real,Nothing}=1.0,
        reduce_samples::Union{Real,Nothing}=1.0,
        degree_max::Int=6,
        model::Union{Nothing,Any}=nothing,  # Changed from ODESystem
        outputs::Union{Nothing,AbstractVector{<:Real}}=nothing,
    )
        # Type conversions
        center_vec = Vector{Float64}(float.(center))
        sample_range_float = isnothing(sample_range) ? nothing : Float64(sample_range)
        reduce_samples_float = isnothing(reduce_samples) ? nothing : Float64(reduce_samples)

        # Create precision tuple if alpha and delta are provided
        prec = if !isnothing(alpha) && !isnothing(delta)
            (Float64(alpha), Float64(delta))
        else
            nothing
        end

        # Convert tolerance if provided
        tolerance_float = isnothing(tolerance) ? nothing : Float64(tolerance)

        # Validation
        length(center_vec) == dim ||
            throw(ArgumentError("center vector length must match dim"))

        # Create objective function
        objective = if isnothing(model) && isnothing(outputs)
            f
        elseif !isnothing(model) && !isnothing(outputs)
            (x) -> f(x, model=model, measured_data=outputs)
        elseif !isnothing(model)
            (x) -> f(x, model=model)
        else
            (x) -> f(x, measured_data=outputs)
        end

        noise = (0.0, 0.0)

        new(
            dim,
            center_vec,
            GN,
            prec,
            tolerance_float,
            noise,
            sample_range_float,
            reduce_samples_float,
            degree_max,
            objective,
        )
    end
end

"""
   create_test_input(f::Function; kwargs...)::test_input

Convenience constructor for test_input with default values.

# Arguments
- `f::Function`: Objective function to optimize
- `n=2`: Problem dimension 
- `center=fill(0.0,n)`: Center point
- `tolerance=2e-3`: Convergence tolerance
- `alpha=0.1`: First precision parameter
- `delta=0.5`: Second precision parameter
- `sample_range=1.0`: Sampling radius
- `reduce_samples=1.0`: Sample reduction
- `degree_max=6`: Maximum polynomial degree
- `model=nothing`: Optional model
- `outputs=nothing`: Optional measured data
"""
function create_test_input(
    f::Function;
    n::Int=2,
    center::AbstractVector{Float64}=fill(0.0, n),
    tolerance::Float64=2e-3,
    alpha::Float64=0.1,
    delta::Union{Real,Nothing}=nothing,  # Made optional
    sample_range::Float64=1.0,
    reduce_samples::Union{Real,Nothing}=nothing,  # Made optional
    degree_max::Int=6,
    model::Union{Nothing,Any}=nothing,  # Changed from ODESystem
    outputs::Union{Nothing,AbstractVector{<:Real}}=nothing,
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
        degree_max=degree_max,
        model=model,
        outputs=outputs,
    )
end