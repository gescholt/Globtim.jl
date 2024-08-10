## Library of functions to approximate ##

# ======================================================= 2D Functions =======================================================
function tref(x)
    return exp(sin(50 * x[1])) + sin(60 * exp(x[2])) + sin(70 * sin(x[1])) + sin(sin(80 * x[2])) - sin(10 * (x[1] + x[2])) + (x[1]^2 + x[2]^2) / 4
end

function camel_3(x)
    # =======================================================
    #   Not Rescaled
    #   Camel three humps function
    #   Domain: [-5, 5]^2.
    # =======================================================  
    return 2*x[1]^2 - 1.05*x[1]^4 + x[1]^6/6 + x[1]*x[2] + x[2]^2
end

function camel(x) 
    # =======================================================
    #   Not Rescaled
    #   Camel six humps function
    #   Domain: [-5, 5]^2.
    # =======================================================
    return (4-2.1*x[1]^2 + x[1]^4/3)*x[1]^2 + x[1]*x[2] + (-4 + 4*x[2]^2)*x[2]^2
end

# Define the Schubert function
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

function easom(x::Vector{Float64})::Float64
    # =======================================================
    #   Not Rescaled
    #   Easom function
    #   Domain: [-100, 100]^2.
    #   Cenetered at (pi, pi) !!!
    # =======================================================
    return -cos(x[1]) * cos(x[2]) * exp(-((x[1] - pi)^2 + (x[2] - pi)^2))
end


# ======================================================= 3D Functions =======================================================
# Define the function on domain [-10, 10]^3.
old_alpine1 = (x) -> abs(x[1] * sin(x[1]) + 0.1 * x[1]) +
                 abs(x[2] * sin(x[2]) + 0.1 * x[2]) +
                 abs(x[3] * sin(x[3]) + 0.1 * x[3])

                 
# ======================================================= 4D Functions =======================================================

function shubert_4d(xx::Vector{Float64})::Float64
    # Sum of two Shubert 2D functions by coordinates 
    # Domain: [-10, 10]^4.
    return schubert(xx[1:2]) + schubert(xx[3:4])

end

function camel_4d(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel six humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel(x[1:2]) + camel(x[3:4])
end

function camel_3_by_3(x)
    # =======================================================
    #   Not Rescaled
    #   double copy of Camel six humps function
    #   Domain: [-5, 5]^4.
    # =======================================================
    return camel_3(x[1:2]) + camel_3(x[3:4])
end

function cosine_mixture(x)
    # =======================================================
    #   Not Rescaled
    #   Mixture of cosine functions
    #   Domain: [-1, 1]^4.
    # =======================================================
    return -0.1*sum(5*pi*cos(x[i]) for i in 1:4) - sum(x[i]^2 for i in 1:4)
end

# ======================================================= nD Functions =======================================================

function Csendes(x, dims=4)
    # =======================================================
    #   Not Rescaled
    #   Csendes function
    #   Domain: [-1, 1]^n.
    # =======================================================
    return sum(x[i]^6*(2+sin(1/x[i])) for i in 1:dims)    
end


function alpine1(x::Vector{Float64}; ndim::Int=2)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine1 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return sum(abs(x[i] * sin(x[i]) + 0.1 * x[i]) for i in 1:ndim)
end

function alpine2(x::Vector{Float64}, ndim::Int)::Float64
    # =======================================================
    #   Not Rescaled
    #   Alpine2 function
    #   Domain: [-10, 10]^n.
    # =======================================================
    return prod(sqrt(x[i]) * sin(x[i]) for i in 1:ndim)
    
end

# Example usage
# x = [1.0, 2.0, 3.0]
# result = alpine(x)
# println("Result: $result")

# x = [1.0, 2.0]
# result = schubert(x)
# println("Result: $result")