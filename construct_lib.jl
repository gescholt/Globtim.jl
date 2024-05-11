

using LinearAlgebra
using Statistics


tref(x, y) = exp(sin(50x)) + sin(60exp(y)) + sin(70sin(x)) + sin(sin(80y)) - sin(10(x + y)) + (x^2 + y^2) / 4
zeta(x) = x + (1 - x) * log(1 - x)

function chebyshev_poly(d::Int, x::Float64)
    if d == 0
        return 1.0
    elseif d == 1
        return x
    else
        T_prev = 1.0
        T_curr = x
        for n in 2:d
            T_next = 2 * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

# Function to calculate the required number of samples
function calculate_samples(m, delta, alph)
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end


# Function to compute the support of polynomial of total degree at most $d$. 
function support_gen(n, d)
    ranges = [0:d for _ in 1:n]     # Generate ranges for each dimension
    iter = Iterators.product(ranges...) # Create the Cartesian product over the ranges
    # Initialize a list to hold valid tuples
    lambda_list = []
    # Loop through the Cartesian product, filtering valid tuples
    for tuple in iter
        if sum(tuple) <= d
            push!(lambda_list, collect(tuple))  # Convert each tuple to an array
        end
    end
    # Check if lambda_list is empty to handle edge cases
    if length(lambda_list) == 0
        lambda_matrix = zeros(0, n)  # Return an empty matrix with 0 rows and n columns
    else
        # Convert the list of arrays to an N x n matrix
        lambda_matrix = hcat(lambda_list...)'
    end
    # Return a NamedTuple containing the matrix and its size attributes
    return (data=lambda_matrix, size=size(lambda_matrix))
end

function lambda_vandermonde(Lambda, S)
    # Generate Vandermonde like matrix in Chebyshev tensored basis. 
    m, N = Lambda.size
    n, N = size(S)
    print("\n")
    print("dimension Vector space: ", m)
    print("\n")
    print("sample size: ", n)
    print("\n")
    print("Dimension samples: ", N)
    V = zeros(n, m)
    for i in 1:n # Number of samples
        for j in 1:m # Dimension of vector space of polynomials
            P = 1.0
            for k in 1:N # Dimension of each sample
                P *= chebyshev_poly(Lambda.data[j, k], S[i, k])
            end
            V[i, j] = P
        end
    end
    return V
end