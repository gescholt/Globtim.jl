
# Define a struct to hold the Gaussian parameters
@doc nothing struct GaussianParams
    centers::Matrix{Float64}
    variances::Vector{Float64}
    alt_signs::Union{Vector{Float64}, Nothing}

    GaussianParams(centers::Matrix{Float64}, variances::Vector{Float64}) =
        new(centers, variances, nothing)
    GaussianParams(
        centers::Matrix{Float64},
        variances::Vector{Float64},
        alt_signs::Vector{Float64}
    ) = new(centers, variances, alt_signs)
end
# ======================================================= Random noise =======================================================
@doc nothing function random_noise(x::Vector{Float64})
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

@doc nothing function shubert(xx::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   Shubert function
    #   Domain: [-10, 10]^2.
    # =======================================================
    sum1 = sum(ii * cos((xx[1] + 1) * xx[1] + ii) for ii in 1:5)
    sum2 = sum(ii * cos((ii + 1) * xx[2] + ii) for ii in 1:5)

    return sum1 * sum2
end

@doc nothing function dejong5(xx::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   De Jong 5 function
    #   Domain: [-50, 50]^2.
    # =======================================================
    sum = 0.0
    a = [-32, -16, 0, 16, 32]
    A = zeros(2, 25)

    for i in 1:5
        for j in 1:5
            A[1, (i - 1) * 5 + j] = a[j]
            A[2, (i - 1) * 5 + j] = a[i]
        end
    end

    for ii in 1:25
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

@doc nothing function easom(xx::AbstractVector)
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
    alt_signs = [rand(Bool) ? 1.0 : -1.0 for _ in 1:N]

    # Generate first center
    centers[1, :] = 0.8 .* rand(n)
    for i in 1:n
        centers[1, i] *= rand(Bool) ? 1.0 : -1.0
    end

    # Generate remaining centers with separation constraint
    for i in 2:N
        max_attempts = 1000
        attempts = 0
        valid_point = false

        while !valid_point && attempts < max_attempts
            # Generate candidate point
            candidate = 0.8 .* rand(n)
            for j in 1:n
                candidate[j] *= rand(Bool) ? 1.0 : -1.0
            end

            # Check separation from all previously generated points
            valid_point = true
            for j in 1:(i - 1)
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
                "Could not generate centers with minimum separation $sep after $max_attempts attempts. Try reducing N or sep."
            )
        end
    end

    return GaussianParams(centers, variances, alt_signs)
end

@doc nothing function rand_gaussian(
    xx::AbstractVector,
    params::GaussianParams;
    verbose::Bool = false
)
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
function HolderTable(xx::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   Holder Table function
    #   Domain: [-10, 10]^2.
    # =======================================================
    return -abs(sin(xx[1]) * cos(xx[2]) * exp(abs(1 - sqrt(xx[1]^2 + xx[2]^2) / pi)))
end

@doc nothing function CrossInTray(xx::AbstractVector)
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
    stddev::Float64 = 5.0
)
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

@doc nothing function shubert_4d(xx::AbstractVector)
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
    return -0.1 * sum(5 * pi * cos(x[i]) for i in 1:4) - sum(x[i]^2 for i in 1:4)
end

@doc nothing function Deuflhard_4d(xx::AbstractVector)
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
    return sum(x[i]^6 * (2 + sin(1 / x[i])) for i in 1:dims)
end

@doc nothing function alpine1(xx::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   Alpine1 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return sum(abs(xx[i] * sin(xx[i]) + 0.1 * xx[i]) for i in eachindex(xx))
end

@doc nothing function alpine2(xx::AbstractVector)
    # =======================================================
    #   Not Rescaled
    #   Alpine2 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return prod(sqrt(xx[i]) * sin(xx[i]) for i in eachindex(xx))

end

"""
    Rastrigin(x::AbstractVector) -> Float64

Rastrigin function - a highly multimodal n-dimensional test function.

The Rastrigin function is characterized by a large number of local minima arranged
in a regular grid pattern, with a unique global minimum at the origin.

f(x) = 10n + ∑_{i=1}^n [x_i² - 10cos(2πx_i)]

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
f_val = Rastrigin([1.0, 1.0])

# 10D optimization problem
TR = test_input(Rastrigin, dim=10, center=zeros(10), sample_range=5.12)
```
"""
function Rastrigin(x::AbstractVector)
    # =======================================================
    #   Standard Rastrigin function
    #   f(x) = 10n + Σ [x_i² - 10cos(2πx_i)]
    #   Domain: [-5.12, 5.12]^ndim
    #   Global minimum: f(0, ..., 0) = 0
    # =======================================================
    ndim = length(x)
    return 10 * ndim + sum(x[i]^2 - 10 * cos(2 * pi * x[i]) for i in 1:ndim)
end

# ======================================================= Essential Benchmark Functions from Jamil & Yang 2013 =======================================================

"""
    Sphere(x::AbstractVector) -> Float64

Sphere function - the most basic and fundamental benchmark function for optimization.

The Sphere function is unimodal, convex, and separable. It represents the simplest
possible optimization landscape with a single global minimum at the origin.

f(x) = Σᵢ₌₁ⁿ xᵢ²

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-5.12, 5.12]ⁿ
- Alternative: [-100, 100]ⁿ for some studies
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Unimodal (single minimum)
- Convex everywhere
- Separable (can be optimized dimension by dimension)
- Smooth and differentiable everywhere
- Serves as baseline for algorithm performance

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# 2D Sphere
f_val = Sphere([1.0, 1.0])  # Returns 2.0

# 10D optimization problem
TR = test_input(Sphere, dim=10, center=zeros(10), sample_range=5.12)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Sphere end  # Declare as new generic function (not extension of Optim.Sphere)
function Sphere(x::AbstractVector)
    return sum(xi^2 for xi in x)
end

"""
    Rosenbrock(x::AbstractVector) -> Float64

Rosenbrock function - the famous "banana" or "valley" function.

The Rosenbrock function is a classic test case for optimization algorithms. While unimodal,
the global minimum lies in a narrow, parabolic valley that is easy to find but difficult
to converge to, making it an excellent test for algorithm robustness.

f(x) = Σᵢ₌₁ⁿ⁻¹ [100(xᵢ₊₁ - xᵢ²)² + (1 - xᵢ)²]

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-5, 10]ⁿ or [-2.048, 2.048]ⁿ
- Global minimum: f(1, 1, ..., 1) = 0

# Properties
- Unimodal but with narrow curved valley
- Non-convex with steep sides and flat valley floor
- Non-separable (variables are coupled)
- Smooth and differentiable everywhere
- Challenging for gradient-based methods due to ill-conditioning

# Known Minima
- **Global minimum**: x* = (1, 1, ..., 1) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# 2D Rosenbrock (classic case)
f_val = Rosenbrock([1.0, 1.0])  # Returns 0.0

# Higher dimensional case
TR = test_input(Rosenbrock, dim=5, center=ones(5), sample_range=2.048)
```

# References
- Rosenbrock, H.H. An automatic method for finding the greatest or least value of a function. Comput. J. 3, 175–184 (1960).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Rosenbrock(x::AbstractVector)
    n = length(x)
    if n < 2
        throw(ArgumentError("Rosenbrock function requires at least 2 dimensions"))
    end

    return sum(100 * (x[i + 1] - x[i]^2)^2 + (1 - x[i])^2 for i in 1:(n - 1))
end

"""
    Griewank(x::AbstractVector) -> Float64

Griewank function - a function with many widespread local minima.

The Griewank function has a product term that introduces correlations among the variables,
making it non-separable. It has many local minima regularly distributed, but becomes
more difficult as the dimension increases.

f(x) = 1 + (1/4000)Σᵢ₌₁ⁿ xᵢ² - Πᵢ₌₁ⁿ cos(xᵢ/√i)

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-600, 600]ⁿ
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Multimodal with many local minima
- Non-separable due to product term
- Smooth and differentiable everywhere
- Local minima become less significant in higher dimensions
- Good test for algorithms' ability to avoid local optima

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: Many regularly distributed local minima
- **Approximate local minima**: Near points where cos(xᵢ/√i) ≈ 1 for all i

# Examples
```julia
# 2D Griewank
f_val = Griewank([0.0, 0.0])  # Returns 0.0

# Higher dimensional case
TR = test_input(Griewank, dim=10, center=zeros(10), sample_range=600.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Griewank(x::AbstractVector)
    n = length(x)
    sum_term = sum(xi^2 for xi in x) / 4000
    prod_term = prod(cos(x[i] / sqrt(i)) for i in 1:n)
    return 1 + sum_term - prod_term
end

"""
    Schwefel(x::AbstractVector) -> Float64

Schwefel function - a deceptive multimodal function with distant global optimum.

The Schwefel function is characterized by its deceptive nature: the global minimum is
geometrically distant from the next best local minima, making it a challenging test
for optimization algorithms that can get trapped in local optima.

f(x) = 418.9829n - Σᵢ₌₁ⁿ xᵢ sin(√|xᵢ|)

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-500, 500]ⁿ
- Global minimum: f(420.9687, 420.9687, ..., 420.9687) ≈ 0

# Properties
- Highly multimodal with many local minima
- Deceptive: global minimum is far from other good local minima
- Non-separable and non-convex
- Smooth except at x = 0 (due to √|x| term)
- Excellent test for global search capability

# Known Minima
- **Global minimum**: x* ≈ (420.9687, 420.9687, ..., 420.9687) with f(x*) ≈ 0
- **Local minima**: Many local minima scattered throughout the domain
- **Second best minimum**: Around x ≈ (-420.9687, 420.9687, ..., 420.9687)

# Examples
```julia
# 2D Schwefel at global minimum
f_val = Schwefel([420.9687, 420.9687])  # ≈ 0.0

# Test optimization
TR = test_input(Schwefel, dim=5, center=fill(420.9687, 5), sample_range=500.0)
```

# References
- Schwefel, H.-P. Numerical Optimization of Computer Models. (Wiley, 1981).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Schwefel(x::AbstractVector)
    n = length(x)
    return 418.9829 * n - sum(xi * sin(sqrt(abs(xi))) for xi in x)
end

"""
    Levy(x::AbstractVector) -> Float64

Levy function - a multimodal function with steep ridges and many local minima.

The Levy function is characterized by its many local minima and steep ridges. It uses
a transformation wᵢ = 1 + (xᵢ - 1)/4 and combines sine functions to create a complex
landscape that challenges optimization algorithms.

f(x) = sin²(πw₁) + Σᵢ₌₁ⁿ⁻¹[(wᵢ-1)²(1 + 10sin²(πwᵢ + 1))] + (wₙ-1)²(1 + sin²(2πwₙ))
where wᵢ = 1 + (xᵢ - 1)/4

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-10, 10]ⁿ
- Global minimum: f(1, 1, ..., 1) = 0

# Properties
- Multimodal with many local minima
- Steep ridges and valleys
- Non-separable due to coupling between variables
- Smooth and differentiable everywhere
- Good test for algorithms' ability to navigate complex landscapes

# Known Minima
- **Global minimum**: x* = (1, 1, ..., 1) with f(x*) = 0
- **Local minima**: Many local minima throughout the domain
- **Pattern**: Local minima tend to occur near integer values

# Examples
```julia
# 2D Levy at global minimum
f_val = Levy([1.0, 1.0])  # Returns 0.0

# Higher dimensional case
TR = test_input(Levy, dim=5, center=ones(5), sample_range=10.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Levy(x::AbstractVector)
    n = length(x)
    w = [1 + (xi - 1) / 4 for xi in x]

    term1 = sin(π * w[1])^2

    term2 = sum((w[i] - 1)^2 * (1 + 10 * sin(π * w[i] + 1)^2) for i in 1:(n - 1))

    term3 = (w[n] - 1)^2 * (1 + sin(2 * π * w[n])^2)

    return term1 + term2 + term3
end

"""
    Zakharov(x::AbstractVector) -> Float64

Zakharov function - a plate-shaped unimodal function with increasing difficulty.

The Zakharov function is unimodal but becomes increasingly ill-conditioned as the
dimension increases. It combines quadratic and quartic terms to create a challenging
optimization landscape for higher dimensions.

f(x) = Σᵢ₌₁ⁿ xᵢ² + (Σᵢ₌₁ⁿ 0.5i·xᵢ)² + (Σᵢ₌₁ⁿ 0.5i·xᵢ)⁴

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-5, 10]ⁿ or [-10, 10]ⁿ
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Unimodal (single global minimum)
- Plate-shaped with increasing ill-conditioning
- Non-separable due to coupling terms
- Smooth and differentiable everywhere
- Difficulty increases significantly with dimension

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# 2D Zakharov
f_val = Zakharov([0.0, 0.0])  # Returns 0.0

# Higher dimensional case (becomes more challenging)
TR = test_input(Zakharov, dim=10, center=zeros(10), sample_range=5.0)
```

# References
- Zakharov, V.V. A class of global optimization algorithms. (1975).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Zakharov(x::AbstractVector)
    n = length(x)

    term1 = sum(xi^2 for xi in x)

    sum_weighted = sum(0.5 * i * x[i] for i in 1:n)
    term2 = sum_weighted^2
    term3 = sum_weighted^4

    return term1 + term2 + term3
end

# ======================================================= 2D Benchmark Functions =======================================================

"""
    Beale(x::AbstractVector) -> Float64

Beale function - a 2D multimodal function with a narrow global minimum.

The Beale function is a classic 2D test function with a narrow valley containing the
global minimum. It has several local minima and is often used to test the performance
of optimization algorithms on functions with narrow optima.

f(x,y) = (1.5 - x + xy)² + (2.25 - x + xy²)² + (2.625 - x + xy³)²

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: [-4.5, 4.5]²
- Global minimum: f(3, 0.5) = 0

# Properties
- Multimodal with narrow global minimum
- Non-separable
- Smooth and differentiable everywhere
- Challenging due to narrow valley structure

# Known Minima
- **Global minimum**: x* = (3, 0.5) with f(x*) = 0
- **Local minima**: Several local minima exist in the domain

# Examples
```julia
# At global minimum
f_val = Beale([3.0, 0.5])  # Returns 0.0

# Test optimization
TR = test_input(Beale, dim=2, center=[3.0, 0.5], sample_range=4.5)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Beale(x::AbstractVector)
    if length(x) != 2
        throw(ArgumentError("Beale function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]
    term1 = (1.5 - x1 + x1 * x2)^2
    term2 = (2.25 - x1 + x1 * x2^2)^2
    term3 = (2.625 - x1 + x1 * x2^3)^2

    return term1 + term2 + term3
end

"""
    Booth(x::AbstractVector) -> Float64

Booth function - a simple 2D plate-shaped function.

The Booth function is a relatively simple 2D function with a single global minimum.
It's plate-shaped and serves as a good test case for basic optimization algorithms.

f(x,y) = (x + 2y - 7)² + (2x + y - 5)²

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: [-10, 10]²
- Global minimum: f(1, 3) = 0

# Properties
- Unimodal (single global minimum)
- Plate-shaped
- Separable after rotation
- Smooth and differentiable everywhere
- Relatively easy optimization problem

# Known Minima
- **Global minimum**: x* = (1, 3) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# At global minimum
f_val = Booth([1.0, 3.0])  # Returns 0.0

# Test optimization
TR = test_input(Booth, dim=2, center=[1.0, 3.0], sample_range=10.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Booth(x::AbstractVector)
    if length(x) != 2
        throw(ArgumentError("Booth function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]
    return (x1 + 2 * x2 - 7)^2 + (2 * x1 + x2 - 5)^2
end

"""
    Branin(x::AbstractVector; a=1, b=5.1/(4π²), c=5/π, r=6, s=10, t=1/(8π)) -> Float64

Branin function - a classic 2D function with three global minima.

The Branin function (also known as Branin-Hoo function) is a well-known 2D test function
with three global minima. It's commonly used in Bayesian optimization and global
optimization benchmarks.

f(x,y) = a(y - bx² + cx - r)² + s(1-t)cos(x) + s

# Arguments
- `x::AbstractVector`: 2D point [x, y]
- `a, b, c, r, s, t`: Function parameters (default values as specified)

# Domain
- Standard: x₁ ∈ [-5, 10], x₂ ∈ [0, 15]
- Global minimum: f = 0.397887 at three locations

# Properties
- Three identical global minima
- Smooth and differentiable everywhere
- Non-separable
- Commonly used in Bayesian optimization

# Known Minima
- **Global minima**:
  - x₁* = (-π, 12.275) with f(x₁*) ≈ 0.397887
  - x₂* = (π, 2.275) with f(x₂*) ≈ 0.397887
  - x₃* = (9.42478, 2.475) with f(x₃*) ≈ 0.397887

# Examples
```julia
# At one global minimum
f_val = Branin([π, 2.275])  # ≈ 0.397887

# Test optimization
TR = test_input(Branin, dim=2, center=[π, 2.275], sample_range=7.5)
```

# References
- Branin, F.H. Widely convergent method for finding multiple solutions of simultaneous nonlinear equations. IBM J. Res. Dev. 16, 504–522 (1972).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Branin(
    x::AbstractVector;
    a = 1,
    b = 5.1 / (4 * π^2),
    c = 5 / π,
    r = 6,
    s = 10,
    t = 1 / (8 * π)
)
    if length(x) != 2
        throw(ArgumentError("Branin function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]
    return a * (x2 - b * x1^2 + c * x1 - r)^2 + s * (1 - t) * cos(x1) + s
end

"""
    GoldsteinPrice(x::AbstractVector) -> Float64

Goldstein-Price function - a 2D multimodal function with four local minima.

The Goldstein-Price function is a classic 2D test function with a complex structure
featuring four local minima. It's commonly used to test optimization algorithms'
ability to find the global minimum among several local optima.

f(x,y) = [1 + (x + y + 1)²(19 - 14x + 3x² - 14y + 6xy + 3y²)] ×
         [30 + (2x - 3y)²(18 - 32x + 12x² + 48y - 36xy + 27y²)]

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: [-2, 2]²
- Global minimum: f(0, -1) = 3

# Properties
- Multimodal with four local minima
- Non-separable and non-convex
- Smooth and differentiable everywhere
- Challenging due to multiple local optima

# Known Minima
- **Global minimum**: x* = (0, -1) with f(x*) = 3
- **Local minima**: Three additional local minima exist in the domain

# Examples
```julia
# At global minimum
f_val = GoldsteinPrice([0.0, -1.0])  # Returns 3.0

# Test optimization
TR = test_input(GoldsteinPrice, dim=2, center=[0.0, -1.0], sample_range=2.0)
```

# References
- Goldstein, A.A. & Price, J.F. On descent from local minima. Math. Comput. 25, 569–574 (1971).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function GoldsteinPrice(x::AbstractVector)
    if length(x) != 2
        throw(ArgumentError("Goldstein-Price function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]

    term1 =
        1 + (x1 + x2 + 1)^2 * (19 - 14 * x1 + 3 * x1^2 - 14 * x2 + 6 * x1 * x2 + 3 * x2^2)
    term2 =
        30 +
        (2 * x1 - 3 * x2)^2 *
        (18 - 32 * x1 + 12 * x1^2 + 48 * x2 - 36 * x1 * x2 + 27 * x2^2)

    return term1 * term2
end

"""
    Matyas(x::AbstractVector) -> Float64

Matyas function - a simple 2D plate-shaped function.

The Matyas function is a relatively simple 2D function with a single global minimum
at the origin. It's plate-shaped and serves as a basic test case for optimization
algorithms.

f(x,y) = 0.26(x² + y²) - 0.48xy

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: [-10, 10]²
- Global minimum: f(0, 0) = 0

# Properties
- Unimodal (single global minimum)
- Plate-shaped
- Non-separable due to cross term
- Smooth and differentiable everywhere
- Relatively easy optimization problem

# Known Minima
- **Global minimum**: x* = (0, 0) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# At global minimum
f_val = Matyas([0.0, 0.0])  # Returns 0.0

# Test optimization
TR = test_input(Matyas, dim=2, center=[0.0, 0.0], sample_range=10.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Matyas(x::AbstractVector)
    if length(x) != 2
        throw(ArgumentError("Matyas function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]
    return 0.26 * (x1^2 + x2^2) - 0.48 * x1 * x2
end

"""
    McCormick(x::AbstractVector) -> Float64

McCormick function - a 2D function with a single global minimum.

The McCormick function is a 2D test function with a unique global minimum.
It combines trigonometric and polynomial terms to create an interesting
optimization landscape.

f(x,y) = sin(x + y) + (x - y)² - 1.5x + 2.5y + 1

# Arguments
- `x::AbstractVector`: 2D point [x, y]

# Domain
- Standard: x ∈ [-1.5, 4], y ∈ [-3, 4]
- Global minimum: f(-0.54719, -1.54719) ≈ -1.9133

# Properties
- Unimodal (single global minimum)
- Non-separable
- Smooth and differentiable everywhere
- Asymmetric domain

# Known Minima
- **Global minimum**: x* ≈ (-0.54719, -1.54719) with f(x*) ≈ -1.9133
- **Local minima**: None (unimodal)

# Examples
```julia
# At global minimum
f_val = McCormick([-0.54719, -1.54719])  # ≈ -1.9133

# Test optimization
TR = test_input(McCormick, dim=2, center=[-0.54719, -1.54719], sample_range=2.75)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function McCormick(x::AbstractVector)
    if length(x) != 2
        throw(ArgumentError("McCormick function is only defined for 2D input"))
    end

    x1, x2 = x[1], x[2]
    return sin(x1 + x2) + (x1 - x2)^2 - 1.5 * x1 + 2.5 * x2 + 1
end

# ======================================================= n-D Benchmark Functions =======================================================

"""
    Michalewicz(x::AbstractVector; m=10) -> Float64

Michalewicz function - a multimodal function with steep ridges and many local minima.

The Michalewicz function is characterized by its steep ridges and many local minima.
The parameter m controls the steepness of the ridges (higher m = steeper ridges).
It becomes increasingly difficult as the dimension increases.

f(x) = -Σᵢ₌₁ⁿ sin(xᵢ) sin²ᵐ(i·xᵢ²/π)

# Arguments
- `x::AbstractVector`: n-dimensional point
- `m::Int`: Steepness parameter (default: 10)

# Domain
- Standard: [0, π]ⁿ
- Global minimum: Depends on dimension, approximately -1.8013 (2D), -4.687 (5D), -9.66 (10D)

# Properties
- Highly multimodal with many local minima
- Steep ridges (controlled by parameter m)
- Non-separable
- Smooth and differentiable everywhere
- Difficulty increases significantly with dimension

# Known Minima
- **Global minimum**: Location depends on dimension
  - 2D: x* ≈ (2.20, 1.57) with f(x*) ≈ -1.8013
  - 5D: f(x*) ≈ -4.687
  - 10D: f(x*) ≈ -9.66
- **Local minima**: Numerous local minima throughout the domain

# Examples
```julia
# 2D Michalewicz
f_val = Michalewicz([2.20, 1.57])  # ≈ -1.8013

# Higher dimensional case with custom steepness
f_val = Michalewicz(rand(5) * π, m=5)

# Test optimization
TR = test_input(Michalewicz, dim=5, center=fill(π/2, 5), sample_range=π/2)
```

# References
- Michalewicz, Z. Genetic Algorithms + Data Structures = Evolution Programs. (Springer-Verlag, 1996).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Michalewicz(x::AbstractVector; m = 10)
    n = length(x)
    return -sum(sin(x[i]) * sin(i * x[i]^2 / π)^(2 * m) for i in 1:n)
end

"""
    StyblinskiTang(x::AbstractVector) -> Float64

Styblinski-Tang function - a multimodal function with a known global minimum.

The Styblinski-Tang function is a scalable multimodal function where each dimension
contributes equally to the complexity. It has a single global minimum and many
local minima, making it a good test for global optimization algorithms.

f(x) = 0.5 Σᵢ₌₁ⁿ (xᵢ⁴ - 16xᵢ² + 5xᵢ)

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-5, 5]ⁿ
- Global minimum: f(-2.903534, -2.903534, ..., -2.903534) ≈ -39.16599n

# Properties
- Multimodal with many local minima
- Separable (can be optimized dimension by dimension)
- Smooth and differentiable everywhere
- Global minimum value scales linearly with dimension

# Known Minima
- **Global minimum**: x* ≈ (-2.903534, -2.903534, ..., -2.903534)
  with f(x*) ≈ -39.16599n
- **Local minima**: Many local minima exist, including at x ≈ (0.2, 0.2, ..., 0.2)

# Examples
```julia
# 2D Styblinski-Tang
f_val = StyblinskiTang([-2.903534, -2.903534])  # ≈ -78.33198

# Higher dimensional case
TR = test_input(StyblinskiTang, dim=5, center=fill(-2.903534, 5), sample_range=5.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function StyblinskiTang(x::AbstractVector)
    return 0.5 * sum(xi^4 - 16 * xi^2 + 5 * xi for xi in x)
end

"""
    SumOfDifferentPowers(x::AbstractVector) -> Float64

Sum of Different Powers function - a bowl-shaped function with increasing powers.

This function uses different powers for each dimension, creating an asymmetric
bowl-shaped landscape. The increasing powers make some dimensions more sensitive
than others, testing algorithms' ability to handle different scaling.

f(x) = Σᵢ₌₁ⁿ |xᵢ|^(i+1)

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-1, 1]ⁿ
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Unimodal (single global minimum)
- Bowl-shaped but asymmetric
- Non-separable due to different powers
- Smooth except at coordinate axes (due to absolute value)
- Increasing difficulty with higher dimensions

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# At global minimum
f_val = SumOfDifferentPowers([0.0, 0.0, 0.0])  # Returns 0.0

# Test optimization
TR = test_input(SumOfDifferentPowers, dim=5, center=zeros(5), sample_range=1.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function SumOfDifferentPowers(x::AbstractVector)
    n = length(x)
    return sum(abs(x[i])^(i + 1) for i in 1:n)
end

"""
    Trid(x::AbstractVector) -> Float64

Trid function - a bowl-shaped function with a known global minimum.

The Trid function is a scalable bowl-shaped function where the global minimum
depends on the dimension. It has a single global minimum and is relatively
easy to optimize, making it useful for testing basic algorithm performance.

f(x) = Σᵢ₌₁ⁿ (xᵢ - 1)² - Σᵢ₌₂ⁿ xᵢxᵢ₋₁

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-n², n²] for each dimension
- Global minimum: xᵢ* = i(n + 1 - i) with f(x*) = -n(n+4)(n-1)/6

# Properties
- Unimodal (single global minimum)
- Bowl-shaped
- Non-separable due to coupling terms
- Smooth and differentiable everywhere
- Global minimum value scales with dimension

# Known Minima
- **Global minimum**: x* = (i(n + 1 - i))ᵢ₌₁ⁿ with f(x*) = -n(n+4)(n-1)/6
  - For n=2: x* = (2, 2) with f(x*) = -2
  - For n=3: x* = (3, 4, 3) with f(x*) = -6
  - For n=4: x* = (4, 6, 6, 4) with f(x*) = -20
- **Local minima**: None (unimodal)

# Examples
```julia
# 3D Trid at global minimum
f_val = Trid([3.0, 4.0, 3.0])  # Returns -6.0

# Test optimization for dimension n
n = 5
x_opt = [i * (n + 1 - i) for i in 1:n]
f_val = Trid(x_opt)  # Should return -n(n+4)(n-1)/6

# Test optimization
TR = test_input(Trid, dim=4, center=[4.0, 6.0, 6.0, 4.0], sample_range=16.0)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Trid(x::AbstractVector)
    n = length(x)
    if n < 2
        throw(ArgumentError("Trid function requires at least 2 dimensions"))
    end

    term1 = sum((xi - 1)^2 for xi in x)
    term2 = sum(x[i] * x[i - 1] for i in 2:n)

    return term1 - term2
end

"""
    RotatedHyperEllipsoid(x::AbstractVector) -> Float64

Rotated Hyper-Ellipsoid function - a bowl-shaped function with increasing weights.

This function is similar to the Sphere function but with increasing weights for
each dimension, creating an elongated ellipsoidal shape. It tests algorithms'
ability to handle different scaling across dimensions.

f(x) = Σᵢ₌₁ⁿ (Σⱼ₌₁ⁱ xⱼ)²

# Arguments
- `x::AbstractVector`: n-dimensional point

# Domain
- Standard: [-65.536, 65.536]ⁿ
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Unimodal (single global minimum)
- Bowl-shaped but elongated
- Non-separable due to cumulative sums
- Smooth and differentiable everywhere
- Increasing ill-conditioning with dimension

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: None (unimodal)

# Examples
```julia
# At global minimum
f_val = RotatedHyperEllipsoid([0.0, 0.0, 0.0])  # Returns 0.0

# Test optimization
TR = test_input(RotatedHyperEllipsoid, dim=5, center=zeros(5), sample_range=65.536)
```

# References
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function RotatedHyperEllipsoid(x::AbstractVector)
    n = length(x)
    return sum((sum(x[j] for j in 1:i))^2 for i in 1:n)
end

"""
    Powell(x::AbstractVector) -> Float64

Powell function - a quartic function with many local minima.

The Powell function is a classic test function that becomes increasingly difficult
as the dimension increases. It's designed to test algorithms on functions with
many local minima and requires the dimension to be a multiple of 4.

f(x) = Σᵢ₌₁ⁿ/⁴ [(x₄ᵢ₋₃ + 10x₄ᵢ₋₂)² + 5(x₄ᵢ₋₁ - x₄ᵢ)² + (x₄ᵢ₋₂ - 2x₄ᵢ₋₁)⁴ + 10(x₄ᵢ₋₃ - x₄ᵢ)⁴]

# Arguments
- `x::AbstractVector`: n-dimensional point (n must be multiple of 4)

# Domain
- Standard: [-4, 5]ⁿ
- Global minimum: f(0, 0, ..., 0) = 0

# Properties
- Multimodal with many local minima
- Non-separable
- Smooth and differentiable everywhere
- Requires dimension to be multiple of 4
- Increasingly difficult with higher dimensions

# Known Minima
- **Global minimum**: x* = (0, 0, ..., 0) with f(x*) = 0
- **Local minima**: Many local minima exist throughout the domain

# Examples
```julia
# 4D Powell at global minimum
f_val = Powell([0.0, 0.0, 0.0, 0.0])  # Returns 0.0

# 8D case
f_val = Powell(zeros(8))

# Test optimization
TR = test_input(Powell, dim=8, center=zeros(8), sample_range=4.5)
```

# References
- Powell, M.J.D. An efficient method for finding the minimum of a function of several variables without calculating derivatives. Comput. J. 7, 155–162 (1964).
- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
"""
function Powell(x::AbstractVector)
    n = length(x)
    if n % 4 != 0
        throw(ArgumentError("Powell function requires dimension to be a multiple of 4"))
    end

    result = 0.0
    for i in 1:4:(n - 3)
        term1 = (x[i] + 10 * x[i + 1])^2
        term2 = 5 * (x[i + 2] - x[i + 3])^2
        term3 = (x[i + 1] - 2 * x[i + 2])^4
        term4 = 10 * (x[i] - x[i + 3])^4
        result += term1 + term2 + term3 + term4
    end

    return result
end

# ═══════════════════════════════════════════════════════════════════════════════
# Machine-readable function registry for benchmark experiments
# ═══════════════════════════════════════════════════════════════════════════════

"""
    FunctionRegistryEntry

Machine-readable metadata for a benchmark optimization function.

# Fields
- `name::String`: Display name for the function
- `default_bounds::Tuple{Float64,Float64}`: Default per-dimension bounds (same for all dims)
- `global_min_location::Function`: `n::Int -> Vector{Float64}` returning the global min location
- `global_min_value::Function`: `n::Int -> Float64` returning the global minimum value for
  dimension `n`. Returns `NaN` when no closed-form is known for that dimension.
- `properties::Vector{Symbol}`: Properties like `:multimodal`, `:separable`, `:non_separable`, etc.
- `min_dim::Int`: Minimum supported dimension
- `max_dim::Int`: Maximum supported dimension. Use `typemax(Int)` for no upper limit.
  Functions with `:fixed_dim` property should set this to enforce dimension constraints.

# Usage
```julia
entry = FUNCTION_REGISTRY[Levy]
bounds_3d = [entry.default_bounds for _ in 1:3]
x_star = entry.global_min_location(3)
f_star = entry.global_min_value(3)
```
"""
const FunctionRegistryEntry = @NamedTuple{
    name::String,
    default_bounds::Tuple{Float64,Float64},
    global_min_location::Function,
    global_min_value::Function,
    properties::Vector{Symbol},
    min_dim::Int,
    max_dim::Int,
}

"""
    FUNCTION_REGISTRY

Dict mapping benchmark function objects to their machine-readable metadata.
Covers all n-dimensional benchmark functions in LibFunctions.jl.

# Example
```julia
entry = FUNCTION_REGISTRY[Levy]
println(entry.name)                    # "Levy"
println(entry.default_bounds)          # (-10.0, 10.0)
println(entry.global_min_location(3))  # [1.0, 1.0, 1.0]
println(entry.global_min_value(3))     # 0.0
```
"""
const FUNCTION_REGISTRY = Dict{Function, FunctionRegistryEntry}(
    # ── Multimodal functions ──────────────────────────────────────────────
    Ackley => (
        name = "Ackley",
        default_bounds = (-5.0, 5.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Levy => (
        name = "Levy",
        default_bounds = (-10.0, 10.0),
        global_min_location = n -> ones(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Griewank => (
        name = "Griewank",
        default_bounds = (-600.0, 600.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Schwefel => (
        name = "Schwefel",
        default_bounds = (-500.0, 500.0),
        global_min_location = n -> fill(420.9687, n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :non_separable, :deceptive],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Rastrigin => (
        name = "Rastrigin",
        default_bounds = (-5.12, 5.12),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Michalewicz => (
        name = "Michalewicz",
        default_bounds = (0.0, Float64(π)),
        global_min_location = n -> begin
            # Approximate known locations per dimension (from literature)
            locs_1d = [2.20291, 1.57080, 1.28499, 1.10570, 0.98470,
                       0.89284, 0.82033, 0.76048, 0.70955, 0.66537]
            return [i <= length(locs_1d) ? locs_1d[i] : π / 2 for i in 1:n]
        end,
        # No closed-form for arbitrary dimension; tabulated from literature
        global_min_value = n -> get(
            Dict(2 => -1.8013, 5 => -4.6877, 10 => -9.6602),
            n, NaN
        ),
        properties = [:multimodal, :non_separable, :steep_ridges],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    StyblinskiTang => (
        name = "StyblinskiTang",
        default_bounds = (-5.0, 5.0),
        global_min_location = n -> fill(-2.903534, n),
        global_min_value = n -> -39.16599 * n,  # per-dimension contribution × n
        properties = [:multimodal, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    alpine1 => (
        name = "Alpine1",
        default_bounds = (-10.0, 10.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    alpine2 => (
        name = "Alpine2",
        default_bounds = (0.0, 10.0),
        global_min_location = n -> fill(7.917, n),
        # No closed-form for arbitrary dimension; tabulated from literature
        global_min_value = n -> get(
            Dict(2 => -6.1295, 3 => -18.4519),
            n, NaN
        ),
        properties = [:multimodal, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),

    # ── Bowl-shaped / unimodal functions ──────────────────────────────────
    Sphere => (
        name = "Sphere",
        default_bounds = (-5.12, 5.12),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :convex, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Rosenbrock => (
        name = "Rosenbrock",
        default_bounds = (-5.0, 10.0),
        global_min_location = n -> ones(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :non_convex, :non_separable, :narrow_valley],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Zakharov => (
        name = "Zakharov",
        default_bounds = (-5.0, 10.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    SumOfDifferentPowers => (
        name = "SumOfDifferentPowers",
        default_bounds = (-1.0, 1.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Trid => (
        name = "Trid",
        default_bounds = (-9.0, 9.0),  # n² for n=3; conservative default
        global_min_location = n -> [Float64(i * (n + 1 - i)) for i in 1:n],
        global_min_value = n -> -n * (n + 4) * (n - 1) / 6,
        properties = [:unimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    RotatedHyperEllipsoid => (
        name = "RotatedHyperEllipsoid",
        default_bounds = (-65.536, 65.536),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :non_separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
    Powell => (
        name = "Powell",
        default_bounds = (-4.0, 5.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:multimodal, :non_separable],
        min_dim = 4,  # requires dim % 4 == 0
        max_dim = typemax(Int),
    ),
    Csendes => (
        name = "Csendes",
        default_bounds = (-1.0, 1.0),
        global_min_location = n -> zeros(n),
        global_min_value = _ -> 0.0,
        properties = [:unimodal, :separable],
        min_dim = 2,
        max_dim = typemax(Int),
    ),
)

# ── Fixed-dimension benchmark functions ──

push!(FUNCTION_REGISTRY,
    Deuflhard => (
        name = "Deuflhard",
        default_bounds = (-5.0, 5.0),
        global_min_location = n -> error("Deuflhard global minimum is not closed-form; use Newton refinement"),
        global_min_value = _ -> NaN,  # multiple CPs, no closed-form global min
        properties = [:multimodal, :nonseparable, :fixed_dim],
        min_dim = 2,
        max_dim = 2,  # hardcoded 2D function (uses xx[1], xx[2] only)
    ),
)

"""
    get_benchmark_config(func::Function, dim::Int; bounds=nothing) -> NamedTuple

Build a benchmark configuration from the function registry for use in experiment scripts.

Returns a NamedTuple with: `name`, `objective`, `bounds`, `description`, `global_min`,
`global_min_value`. The `global_min_value` is always resolved to a `Float64` (or `NaN`
if no closed-form value is known for the given dimension).

Errors if `dim` is outside the `[min_dim, max_dim]` range for the function.

# Arguments
- `func::Function`: Benchmark function (must be in `FUNCTION_REGISTRY`)
- `dim::Int`: Problem dimension (must satisfy `min_dim <= dim <= max_dim`)
- `bounds`: Optional custom bounds as `Vector{Tuple{Float64,Float64}}`.
  If `nothing`, uses `default_bounds` from the registry replicated to `dim` dimensions.

# Example
```julia
bench = get_benchmark_config(Levy, 3)
# bench.name == "levy"
# bench.bounds == [(-10.0, 10.0), (-10.0, 10.0), (-10.0, 10.0)]
# bench.global_min == [1.0, 1.0, 1.0]
```
"""
function get_benchmark_config(func::Function, dim::Int; bounds = nothing)
    haskey(FUNCTION_REGISTRY, func) || error("Function $(func) not found in FUNCTION_REGISTRY")
    entry = FUNCTION_REGISTRY[func]
    dim >= entry.min_dim || error("$(entry.name) requires at least $(entry.min_dim) dimensions, got $dim")
    dim <= entry.max_dim || error("$(entry.name) supports at most $(entry.max_dim) dimensions, got $dim")

    actual_bounds = bounds !== nothing ? bounds : [entry.default_bounds for _ in 1:dim]
    return (
        name = lowercase(entry.name),
        objective = func,
        bounds = actual_bounds,
        description = "$(entry.name) $(dim)D",
        global_min = entry.global_min_location(dim),
        global_min_value = entry.global_min_value(dim),
    )
end

"""
    get_benchmark_config_by_name(name::String, dim::Int; bounds = nothing)

Look up a benchmark function by its string name (case-insensitive) and return
an experiment-ready config NamedTuple. This is the TOML pipeline entry point —
TOML configs specify functions as strings, not Julia function references.

Errors with the list of known function names if `name` is not found.

# Example
```julia
bench = get_benchmark_config_by_name("Levy", 3)
# bench.objective == Levy
# bench.bounds == [(-10.0, 10.0), (-10.0, 10.0), (-10.0, 10.0)]
```
"""
function get_benchmark_config_by_name(name::String, dim::Int; bounds = nothing)
    name_lower = lowercase(name)
    for (func, entry) in FUNCTION_REGISTRY
        if lowercase(entry.name) == name_lower
            return get_benchmark_config(func, dim; bounds = bounds)
        end
    end
    known = sort([entry.name for entry in values(FUNCTION_REGISTRY)])
    error("Analytical function \"$name\" not found in FUNCTION_REGISTRY. " *
          "Known functions: $(join(known, ", "))")
end

"""
    known_analytical_function_names() -> Vector{String}

Return sorted list of all function names in FUNCTION_REGISTRY.
Used by TOML validation to check analytical_function field.
"""
function known_analytical_function_names()
    return sort([entry.name for entry in values(FUNCTION_REGISTRY)])
end

# Export registry
export FUNCTION_REGISTRY, FunctionRegistryEntry, get_benchmark_config,
       get_benchmark_config_by_name, known_analytical_function_names
