# Construction of the approximant

# ======================================================= Structures ======================================================
struct ApproxPoly
    coeffs::Vector{Float64}
    nrm::Float64
    N::Int
end

# ======================================================= Functions =======================================================

function ChebyshevPoly(d::Int, x)
    # =======================================================
    # Function to generate Chebyshev polynomial of degree d in the variable x,
    # Float64 coefficients 
    # =======================================================
    if d == 0
        return rationalize(1.0)
    elseif d == 1
        return x
    else
        T_prev = rationalize(1.0)
        T_curr = x
        for n in 2:d
            T_next = rationalize(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

function ChebyshevPolyExact(d::Int)::Vector{Int}
    # =======================================================
    # Function to generate vector of integer coefficients of Chebyshev polynomial of degree d. 
    # In one variable. 
    # =======================================================
    if d == 0
        return [1]
    elseif d == 1
        return [0, 1]
    else
        Tn_1 = ChebyshevPolyExact(d - 1)
        Tn_2 = ChebyshevPolyExact(d - 2)
        Tn = [0; 2 * Tn_1] - vcat(Tn_2, [0, 0])
        return Tn
    end
end

function BigFloatChebyshevPoly(d::Int, x)
    # =======================================================
    # Function to generate Chebyshev polynomial with BigFLoat coefficients 
    # of degree d in the variable x 
    # =======================================================
    if d == 0
        return BigFloat(1.0)
    elseif d == 1
        return x
    else
        T_prev = BigFloat(1.0)
        T_curr = x
        for n in 2:d
            T_next = BigFloat(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

function RationalChebyshevPoly(d::Int, x)
    # =======================================================
    # Function to generate Chebyshev polynomial with Rational coefficients 
    # of degree d in the variable x 
    # =======================================================
    if d == 0
        return Rational(1.0)
    elseif d == 1
        return x
    else
        T_prev = Rational(1.0)
        T_curr = x
        for n in 2:d
            T_next = 2 * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

function SupportGen(n::Int, d::Int)::NamedTuple
    # =======================================================
    # Function to compute the support of polynomial of total degree at most $d$. 
    # =======================================================
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
    # =======================================================
    # Generate Vandermonde like matrix in Chebyshev tensored basis.
    # Lambda: matrix of the support of the polynomial space
    # =======================================================
    m, N = Lambda.size
    n, N = size(S)
    V = zeros(n, m)
    for i in 1:n # Number of samples
        for j in 1:m # Dimension of vector space of polynomials
            P = 1.0
            for k in 1:N # Dimension of each sample
                P *= ChebyshevPoly(Lambda.data[j, k], S[i, k])
            end
            V[i, j] = P
        end
    end
    return V
end