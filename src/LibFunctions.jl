
# Define a struct to hold the Gaussian parameters
@doc nothing struct GaussianParams
    centers::Matrix{Float64}
    variances::Vector{Float64}
    alt_signs::Union{Vector{Float64},Nothing}

    GaussianParams(centers::Matrix{Float64}, variances::Vector{Float64}) =
        new(centers, variances, nothing)
    GaussianParams(
        centers::Matrix{Float64},
        variances::Vector{Float64},
        alt_signs::Vector{Float64},
    ) = new(centers, variances, alt_signs)
end
# ======================================================= Random noise =======================================================
@doc nothing function random_noise(x::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Random noise function
    # =======================================================
    return rand()
end

@doc nothing function bivariate_gaussian_noise(params::GaussianParams)::Vector{Float64}
    # =======================================================
    #   Not Rescaled
    #   Bivariate Gaussian noise function
    #   params: GaussianParams struct containing centers and variances
    # =======================================================
    mean = params.centers[:, 1]
    cov = Diagonal(params.variances)
    dist = MvNormal(mean, cov)
    return rand(dist)
end

# ======================================================= 2D Functions =======================================================
@doc nothing function tref(x)
    return exp(sin(50 * x[1])) +
           sin(60 * exp(x[2])) +
           sin(70 * sin(x[1])) +
           sin(sin(80 * x[2])) - sin(10 * (x[1] + x[2])) + (x[1]^2 + x[2]^2) / 4
end

@doc nothing function Ackley(xx::AbstractVector; a = 20, b = 0.2, c = 2 * pi)
    n = length(xx)
    # Use map instead of broadcasting for better StaticArrays performance
    sum_sq = sum(x^2 for x in xx) / n
    sum_cos = sum(cos(c * x) for x in xx) / n
    return -a * exp(-b * sqrt(sum_sq)) - exp(sum_cos) + a + exp(1)
end

@doc nothing function camel_3(x)
    # =======================================================
    #   Not Rescaled
    #   Camel three humps function
    #   Domain: [-5, 5]^2.
    # =======================================================
    return 2 * x[1]^2 - 1.05 * x[1]^4 + x[1]^6 / 6 + x[1] * x[2] + x[2]^2
end

@doc nothing function camel(x)
    # =======================================================
    #   Not Rescaled
    #   Camel six humps function
    #   Domain: [-5, 5]^2.
    # =======================================================
    return (4 - 2.1 * x[1]^2 + x[1]^4 / 3) * x[1]^2 +
           x[1] * x[2] +
           (-4 + 4 * x[2]^2) * x[2]^2
end

@doc nothing function shubert(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   Shubert function
    #   Domain: [-10, 10]^2.
    # =======================================================
    sum1 = sum(ii * cos((xx[1] + 1) * xx[1] + ii) for ii = 1:5)
    sum2 = sum(ii * cos((ii + 1) * xx[2] + ii) for ii = 1:5)

    return sum1 * sum2
end

@doc nothing function dejong5(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   De Jong 5 function
    #   Domain: [-50, 50]^2.
    # =======================================================
    sum = 0.0
    a = [-32, -16, 0, 16, 32]
    A = zeros(2, 25)

    for i = 1:5
        for j = 1:5
            A[1, (i-1)*5+j] = a[j]
            A[2, (i-1)*5+j] = a[i]
        end
    end

    for ii = 1:25
        a1i = A[1, ii]
        a2i = A[2, ii]
        term1 = ii
        term2 = (xx[1] - a1i)^6
        term3 = (xx[2] - a2i)^6
        sum += 1 / (term1 + term2 + term3)
    end

    y = 1 / (0.002 + sum)
    return y
end

@doc nothing function easom(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   Easom function
    #   Domain: [-100, 100]^2.
    #   Cenetered at (pi, pi) !!!
    # =======================================================
    return -cos(xx[1]) * cos(xx[2]) * exp(-((xx[1] - pi)^2 + (xx[2] - pi)^2))
end


"""
    init_gaussian_params(n::Int, N::Int, scale::Float64, sep::Float64) -> GaussianParams

Initialize Gaussian parameters with random centers and variances, ensuring centers are
separated by at least `sep` distance.

# Arguments
- `n::Int`: Dimension of the domain.
- `N::Int`: Number of Gaussian functions.
- `scale::Float64`: Scaling factor for the variances.
- `sep::Float64`: Minimum separation distance between centers.

# Returns
- `GaussianParams`: A struct containing the centers, variances of
the Gaussian functions and a random boolean vector to make a signed sum
of the distributions.

# Example
```julia
params = init_gaussian_params(3, 5, 2.0, 0.1)
println(params.centers)  # Prints the centers of the Gaussian functions
println(params.variances)  # Prints the variances of the Gaussian functions
"""
function init_gaussian_params(n::Int, N::Int, scale::Float64, sep::Float64)::GaussianParams
    centers = zeros(N, n)
    variances = scale .* rand(N)
    alt_signs = [rand(Bool) ? 1.0 : -1.0 for _ = 1:N]

    # Generate first center
    centers[1, :] = 0.8 .* rand(n)
    for i = 1:n
        centers[1, i] *= rand(Bool) ? 1.0 : -1.0
    end

    # Generate remaining centers with separation constraint
    for i = 2:N
        max_attempts = 1000
        attempts = 0
        valid_point = false

        while !valid_point && attempts < max_attempts
            # Generate candidate point
            candidate = 0.8 .* rand(n)
            for j = 1:n
                candidate[j] *= rand(Bool) ? 1.0 : -1.0
            end

            # Check separation from all previously generated points
            valid_point = true
            for j = 1:(i-1)
                if norm(candidate - centers[j, :]) < sep
                    valid_point = false
                    break
                end
            end

            if valid_point
                centers[i, :] = candidate
            end

            attempts += 1
        end

        # If we couldn't find a valid point after max attempts, error out
        if !valid_point
            error(
                "Could not generate centers with minimum separation $sep after $max_attempts attempts. Try reducing N or sep.",
            )
        end
    end

    return GaussianParams(centers, variances, alt_signs)
end

@doc nothing function rand_gaussian(
    xx::AbstractVector,
    params::GaussianParams;
    verbose::Bool = false,
)::Float64
    # =======================================================
    #   Not Rescaled
    #   Sum of N Gaussian function centered at random points in the domain with random variance.
    #   Domain: [-1, 1]^2.
    #   params: include centers, variance and vector of random signs.
    # =======================================================

    if verbose
        println("Input vector x: ", xx)
        println("Dimension of x: ", ndims(xx))
        println("Gaussian centers: ", params.centers)
        println("Gaussian variances: ", params.variances)
        println("Gaussian alt_signs: ", params.alt_signs)
    end

    # Using firstindex:lastindex for more robust iteration bounds
    n_gaussians = firstindex(params.variances):lastindex(params.variances)
    n_centers = size(params.centers, 1)  # Keep size for matrix dimension

    @assert length(n_gaussians) == n_centers "Number of variances must match the number of rows in centers."
    @assert params.alt_signs === nothing ||
            firstindex(params.alt_signs):lastindex(params.alt_signs) == n_gaussians "Number of alt_signs must match the number of variances if alt_signs is not nothing."

    if verbose
        println("All dimension checks passed.")
    end

    total_sum = 0.0
    gaussian = zeros(Float64, length(n_gaussians))  # Pre-allocate with zeros instead of undef

    for i in n_gaussians
        diff = xx .- view(params.centers, i, :)  # Use view for better memory efficiency
        gaussian[i] = exp(-sum(diff .^ 2) / (2 * params.variances[i]^2))
    end

    if verbose
        println("Gaussian values: ", gaussian)
    end

    if params.alt_signs !== nothing
        total_sum = dot(params.alt_signs, gaussian)
    else
        total_sum = sum(gaussian)
    end

    if verbose
        println("Total sum: ", total_sum)
    end

    return total_sum
end

"""
    HolderTable(x::AbstractVector) -> Float64

Holder Table function - a 2D function with four symmetric global minima.

The function creates a table-like surface with four holes (global minima) arranged
symmetrically around the origin.

f(x,y) = -|sin(x)cos(y)exp(|1 - √(x² + y²)/π|)|

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: [-10, 10]²
- Four global minima at: (±8.05502, ±9.66459) with f = -19.2085

# Properties
- Four identical global minima
- Symmetric with respect to both axes
- Smooth except at the origin
- Good test for algorithms' ability to find multiple global optima

# Examples
```julia
# Evaluate at a point
f_val = HolderTable([8.0, 9.0])

# Find all four global minima
TR = test_input(HolderTable, dim=2, center=[0.0, 0.0], sample_range=10.0)
```
"""
function HolderTable(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   Holder Table function
    #   Domain: [-10, 10]^2.
    # =======================================================
    return -abs(sin(xx[1]) * cos(xx[2]) * exp(abs(1 - sqrt(xx[1]^2 + xx[2]^2) / pi)))
end

@doc nothing function CrossInTray(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   Cross-in-Tray function
    #   Domain: [-10, 10]^2.
    # =======================================================
    return -0.001 *
           (
        abs(sin(xx[1]) * sin(xx[2]) * exp(abs(100 - sqrt(xx[1]^2 + xx[2]^2) / pi))) + 1
    )^(1 / 10)
end

# @doc nothing function Deuflhard(xx::AbstractVector)::Float64
#     # =======================================================
#     #   Not Rescaled
#     #   Domain: [-1.2, 1.2]^2.
#     # =======================================================
#     term1 = (exp(xx[1]^2 + xx[2]^2) - 3)^2
#     term2 = (xx[1] + xx[2] - sin(3 * (xx[1] + xx[2])))^2
#     return term1 + term2
# end
"""
    Deuflhard(x::AbstractVector) -> Float64

Deuflhard test function - a challenging 2D optimization problem with multiple local minima.

The function combines exponential and trigonometric terms to create a complex landscape:
f(x,y) = (exp(x² + y²) - 3)² + (x + y - sin(3(x + y)))²

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Recommended: [-1.2, 1.2]²
- Can be extended for exploring additional minima

# Properties
- Multiple local minima with similar function values
- Smooth, differentiable everywhere
- Challenging for local optimization methods
- Good test case for verifying global optimization algorithms

# Examples
```julia
# Evaluate at origin
f_val = Deuflhard([0.0, 0.0])

# Use in optimization
TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.2)
```
"""
function Deuflhard(xx::AbstractVector)
    term1 = (exp(xx[1]^2 + xx[2]^2) - 3)^2
    term2 = (xx[1] + xx[2] - sin(3 * (xx[1] + xx[2])))^2
    return term1 + term2
end

@doc nothing function noisy_Deuflhard(
    xx::AbstractVector;
    mean::Float64 = 0.0,
    stddev::Float64 = 5.0,
)::Float64
    noise = rand(Distributions.Normal(mean, stddev))
    return Deuflhard(xx) + noise
end

# ======================================================= 3D Functions =======================================================
# Define the function on domain [-10, 10]^3.
old_alpine1 =
    (x) ->
        abs(x[1] * sin(x[1]) + 0.1 * x[1]) +
        abs(x[2] * sin(x[2]) + 0.1 * x[2]) +
        abs(x[3] * sin(x[3]) + 0.1 * x[3])

"""
    tref_3d(x::AbstractVector) -> Float64

3D test reference function with highly oscillatory behavior.

A complex 3D function combining multiple trigonometric and exponential terms
to create a challenging optimization landscape with many local minima.

f(x,y,z) = exp(sin(50x)) + sin(60exp(y))sin(60z) + sin(70sin(x))cos(10z) +
           sin(sin(80y)) - sin(10(x+z)) + (x²+y²+z²)/4

# Arguments
- `x::AbstractVector`: 3D point [x, y, z]

# Domain
- Recommended: [-1, 1]³
- Can be extended but oscillations become more extreme

# Properties
- Highly multimodal with numerous local minima
- Contains rapid oscillations due to high-frequency terms
- Mixed scales: both local oscillations and global structure
- Excellent test for polynomial approximation methods

# Examples
```julia
# Evaluate at origin
f_val = tref_3d([0.0, 0.0, 0.0])

# 3D optimization
TR = test_input(tref_3d, dim=3, center=[0.0, 0.0, 0.0], sample_range=1.0)
```
"""
function tref_3d(x::AbstractVector)
    return exp(sin(50x[1])) +
           sin(60exp(x[2])) * sin(60x[3]) +
           sin(70sin(x[1])) * cos(10x[3]) +
           sin(sin(80x[2])) - sin(10(x[1] + x[3])) + (x[1]^2 + x[2]^2 + x[3]^2) / 4
end

# ======================================================= 4D Functions =======================================================

@doc nothing function shubert_4d(xx::AbstractVector)::Float64
    # Sum of two Shubert 2D functions by coordinates
    # Domain: [-10, 10]^4.
    return shubert(xx[1:2]) + shubert(xx[3:4])
end

@doc nothing function camel_4d(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel six humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel(x[1:2]) + camel(x[3:4])
end

@doc nothing function camel_3_by_3(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel three humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel_3(x[1:2]) * camel_3(x[3:4])
end

@doc nothing function cosine_mixture(x)
    # =======================================================
    #   Not Rescaled
    #   Mixture of cosine functions
    #   Domain: [-1, 1]^4.
    # =======================================================
    return -0.1 * sum(5 * pi * cos(x[i]) for i = 1:4) - sum(x[i]^2 for i = 1:4)
end

@doc nothing function Deuflhard_4d(xx::AbstractVector)::Float64
    # =======================================================
    #   Not Rescaled
    #   Domain: [-1.2, 1.2]^4.
    # =======================================================
    return Deuflhard(xx[1:2]) + Deuflhard(xx[3:4])
end

# ======================================================= 6D Functions =======================================================
@doc nothing function camel_3_6d(x)
    # =======================================================
    #   Not Rescaled
    #   Triple copy of Camel three humps function
    #   Domain: [-5, 5]^6.
    # =======================================================
    return camel_3(x[1:2]) + camel_3(x[3:4]) + camel_3(x[5:6])
end

# ======================================================= nD Functions =======================================================
@doc nothing function Csendes(x, dims = 4)
    # =======================================================
    #   Not Rescaled
    #   Csendes function
    #   Domain: [-1, 1]^n.
    # =======================================================
    return sum(x[i]^6 * (2 + sin(1 / x[i])) for i = 1:dims)
end

@doc nothing function alpine1(
    xx::Union{Vector{Float64},StaticArraysCore.SVector{N,Float64}} where {N},
)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine1 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return sum(abs(xx[i] * sin(xx[i]) + 0.1 * xx[i]) for i in eachindex(xx))
end

@doc nothing function alpine2(
    xx::Union{Vector{Float64},StaticArraysCore.SVector{N,Float64}} where {N},
)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine2 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return prod(sqrt(xx[i]) * sin(xx[i]) for i in eachindex(xx))

end

"""
    Rastringin(x::AbstractVector) -> Float64

Rastrigin function - a highly multimodal n-dimensional test function.

The Rastrigin function is characterized by a large number of local minima arranged
in a regular grid pattern, with a unique global minimum at the origin.

f(x) = ∑_{i=1}^n [x_i² - 10cos(2πx_i)]

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-5.12, 5.12]^n
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Highly multimodal with ~10n local minima
- Regular structure of local minima
- Separable (can be optimized dimension by dimension)
- Classic benchmark for global optimization algorithms

# Examples
```julia
# 2D Rastrigin
f_val = Rastringin([1.0, 1.0])

# 10D optimization problem
TR = test_input(Rastringin, dim=10, center=zeros(10), sample_range=5.12)
```
"""
function Rastringin(x::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   Rastringin function
    #   Domain: [-5.12, 5.12]^ndim.
    # =======================================================
    ndim = length(x)
    return sum(x[i]^2 - 10 * cos(2 * pi * x[i]) for i = 1:ndim)
end
