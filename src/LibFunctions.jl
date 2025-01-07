
# Define a struct to hold the Gaussian parameters
@doc nothing
struct GaussianParams
    centers::Matrix{Float64}
    variances::Vector{Float64}
    alt_signs::Union{Vector{Float64},Nothing}

    GaussianParams(centers::Matrix{Float64}, variances::Vector{Float64}) = new(centers, variances, nothing)
    GaussianParams(centers::Matrix{Float64}, variances::Vector{Float64}, alt_signs::Vector{Float64}) = new(centers, variances, alt_signs)
end
# ======================================================= Random noise =======================================================
@doc nothing
function random_noise(x::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Random noise function
    # =======================================================
    return rand()
end

@doc nothing
function bivariate_gaussian_noise(params::GaussianParams)::Vector{Float64}
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
@doc nothing
function tref(x)
    return exp(sin(50 * x[1])) + sin(60 * exp(x[2])) + sin(70 * sin(x[1])) + sin(sin(80 * x[2])) - sin(10 * (x[1] + x[2])) + (x[1]^2 + x[2]^2) / 4
end

@doc nothing
function Ackley(xx::AbstractVector; a=20, b=0.2, c=2 * pi)
    n = length(xx)
    # Use map instead of broadcasting for better StaticArrays performance
    sum_sq = sum(x^2 for x in xx) / n
    sum_cos = sum(cos(c * x) for x in xx) / n
    return -a * exp(-b * sqrt(sum_sq)) - exp(sum_cos) + a + exp(1)
end

@doc nothing
function camel_3(x)
    # =======================================================
    #   Not Rescaled
    #   Camel three humps function
    #   Domain: [-5, 5]^2.
    # =======================================================  
    return 2*x[1]^2 - 1.05*x[1]^4 + x[1]^6/6 + x[1]*x[2] + x[2]^2
end

@doc nothing
function camel(x) 
    # =======================================================
    #   Not Rescaled
    #   Camel six humps function
    #   Domain: [-5, 5]^2.
    # =======================================================
    return (4-2.1*x[1]^2 + x[1]^4/3)*x[1]^2 + x[1]*x[2] + (-4 + 4*x[2]^2)*x[2]^2
end

@doc nothing
function shubert(xx::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Shubert function
    #   Domain: [-10, 10]^2.
    # =======================================================
    x1 = xx[1]
    x2 = xx[2]

    sum1 = sum(ii * cos((ii + 1) * x1 + ii) for ii in 1:5)
    sum2 = sum(ii * cos((ii + 1) * x2 + ii) for ii in 1:5)

    return sum1 * sum2
end

@doc nothing
function dejong5(xx::Vector{Float64})::Float64
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
            A[1, (i-1)*5+j] = a[j]
            A[2, (i-1)*5+j] = a[i]
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

@doc nothing
function easom(x::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Easom function
    #   Domain: [-100, 100]^2.
    #   Cenetered at (pi, pi) !!!
    # =======================================================
    return -cos(x[1]) * cos(x[2]) * exp(-((x[1] - pi)^2 + (x[2] - pi)^2))
end


"""
    init_gaussian_params(n::Int, N::Int, scale::Float64) -> GaussianParams

Initialize Gaussian parameters with random centers and variances.

# Arguments
- `n::Int`: Dimension of the domain.
- `N::Int`: Number of Gaussian functions.
- `scale::Float64`: Scaling factor for the variances.

# Returns
- `GaussianParams`: A struct containing the centers, variances of 
the Gaussian functions and a random boolean vector to make a signed sum 
of the distributions. 

# Example
```julia
params = init_gaussian_params(3, 5, 2.0)
println(params.centers)  # Prints the centers of the Gaussian functions
println(params.variances)  # Prints the variances of the Gaussian functions
"""
function init_gaussian_params(n::Int, N::Int, scale::Float64)::GaussianParams
    centers = .8 .* rand(N, n)  # Preallocate random center points
    variances = scale.*rand(N)  # Preallocate random variances
    alt_signs = [rand(Bool) ? 1.0 : -1.0 for _ in 1:N]
    # Apply random sign to each coordinate of the center points
    for i in 1:N
        for j in 1:n
            sign = rand(Bool) ? 1.0 : -1.0
            centers[i, j] *= sign
        end
    end
    return GaussianParams(centers, variances, alt_signs)
end

@doc nothing
function rand_gaussian(x::Vector{Float64}, params::GaussianParams; verbose::Bool=false)::Float64
    # =======================================================
    #   Not Rescaled
    #   Sum of N Gaussian function centered at random points in the domain with random variance.
    #   Domain: [-1, 1]^2.
    #   params: include centers, variance and vector of random signs.  
    # =======================================================

    if verbose
        println("Input vector x: ", x)
        println("Length of x: ", length(x))
        println("Gaussian centers: ", params.centers)
        println("Gaussian variances: ", params.variances)
        println("Gaussian alt_signs: ", params.alt_signs)

    end

    @assert length(params.variances) == size(params.centers, 1) "Length of variances must match the number of rows in centers."
    @assert params.alt_signs === nothing || length(params.alt_signs) == length(params.variances) "Length of alt_signs must match the length of variances if alt_signs is not nothing."

    if verbose
        println("All dimension checks passed.")
    end

    total_sum = 0.0
    gaussian = Vector{Float64}(undef, length(params.variances))
    for i in 1:length(params.variances)
        diff = x .- params.centers[i, :]
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

@doc nothing
function HolderTable(xx::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Holder Table function
    #   Domain: [-10, 10]^2.
    # =======================================================
    return -abs(sin(xx[1]) * cos(xx[2]) * exp(abs(1 - sqrt(xx[1]^2 + xx[2]^2) / pi)))
end

@doc nothing
function CrossInTray(xx::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Cross-in-Tray function
    #   Domain: [-10, 10]^2.
    # =======================================================
    return -0.001 * (abs(sin(xx[1]) * sin(xx[2]) * exp(abs(100 - sqrt(xx[1]^2 + xx[2]^2) / pi))) + 1)^(1 / 10)
end

@doc nothing
function Deuflhard(xx::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Domain: [-1.2, 1.2]^2.
    # =======================================================
    term1 = (exp(xx[1]^2 + xx[2]^2) - 3)^2
    term2 = (xx[1] + xx[2] - sin(3 * (xx[1] + xx[2])))^2
    return term1 + term2
end

@doc nothing
function noisy_Deuflhard(xx::Vector{Float64}; mean::Float64=0.0, stddev::Float64=5.0)::Float64
    noise = rand(Distributions.Normal(mean, stddev))
    return Deuflhard(xx) + noise
end

# ======================================================= 3D Functions =======================================================
# Define the function on domain [-10, 10]^3.
old_alpine1 = (x) -> abs(x[1] * sin(x[1]) + 0.1 * x[1]) +
                 abs(x[2] * sin(x[2]) + 0.1 * x[2]) +
                 abs(x[3] * sin(x[3]) + 0.1 * x[3])

                 
# ======================================================= 4D Functions =======================================================

@doc nothing
function shubert_4d(xx::Vector{Float64})::Float64
    # Sum of two Shubert 2D functions by coordinates 
    # Domain: [-10, 10]^4.
    return schubert(xx[1:2]) + schubert(xx[3:4])
end

@doc nothing
function camel_4d(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel six humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel(x[1:2]) + camel(x[3:4])
end

@doc nothing
function camel_3_by_3(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel three humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel_3(x[1:2]) * camel_3(x[3:4])
end

@doc nothing
function cosine_mixture(x)
    # =======================================================
    #   Not Rescaled
    #   Mixture of cosine functions
    #   Domain: [-1, 1]^4.
    # =======================================================
    return -0.1*sum(5*pi*cos(x[i]) for i in 1:4) - sum(x[i]^2 for i in 1:4)
end

# ======================================================= 6D Functions =======================================================
@doc nothing
function camel_3_6d(x)
    # =======================================================
    #   Not Rescaled
    #   Triple copy of Camel three humps function
    #   Domain: [-5, 5]^6.
    # =======================================================
    return camel_3(x[1:2]) + camel_3(x[3:4]) + camel_3(x[5:6])
end

# ======================================================= nD Functions =======================================================
@doc nothing
function Csendes(x, dims=4)
    # =======================================================
    #   Not Rescaled
    #   Csendes function
    #   Domain: [-1, 1]^n.
    # =======================================================
    return sum(x[i]^6*(2+sin(1/x[i])) for i in 1:dims)    
end

@doc nothing
function alpine1(x::Vector{Float64}; ndim::Int=2)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine1 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return sum(abs(x[i] * sin(x[i]) + 0.1 * x[i]) for i in 1:ndim)
end

@doc nothing
function alpine2(x::Vector{Float64}, ndim::Int)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine2 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return prod(sqrt(x[i]) * sin(x[i]) for i in 1:ndim)
    
end

@doc nothing
function Rastringin(x::AbstractVector; ndim::Int=3)::Float64
    # =======================================================
    #   Not Rescaled
    #   Rastringin function
    #   Domain: [-5.12, 5.12]^ndim.
    # =======================================================
    return sum(x[i]^2 - 10 * cos(2 * pi * x[i]) for i in 1:ndim)
end
