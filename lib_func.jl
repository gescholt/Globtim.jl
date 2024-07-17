## Library of functions to approximate ##

# ======================================================= 2D Functions =======================================================
function tref(x)
    return exp(sin(50 * x[1])) + sin(60 * exp(x[2])) + sin(70 * sin(x[1])) + sin(sin(80 * x[2])) - sin(10 * (x[1] + x[2])) + (x[1]^2 + x[2]^2) / 4
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
function schubert(xx)
    #   Domain: [-10, 10]^2.
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


# ======================================================= 3D Functions =======================================================
# Define the function on domain [-10, 10]^3.
alpine1 = (x) -> abs(x[1] * sin(x[1]) + 0.1 * x[1]) +
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


# Example usage
# x = [1.0, 2.0, 3.0]
# result = alpine(x)
# println("Result: $result")

# x = [1.0, 2.0]
# result = schubert(x)
# println("Result: $result")