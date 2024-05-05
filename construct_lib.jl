

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


function lambda_vandermonde(Lambda, S)
    # Generate Vandermonde like matrix in Chebyshev tensored basis. 
    n, N = size(S)
    print(n, N)
    m = length(Lambda)
    V = zeros(N, m)
    for i in eachindex(S)
        for j in eachindex(Lambda)
            P = 1.0
            for k in eachindex(S[i])
                print(Lambda[j][k], S[k][i])
                P *= chebyshev_poly(Lambda[j][k], S[k][i])
            end
            print(P)
            V[i, j] = P
        end
    end
    return V
end

function support_gen(n, d)
    # generate the monomial support of a dense polynomial approximant. 
    ranges = [0:d for _ in 1:n]
    iter = Iterators.product(ranges...) #cartesian product
    L = collect(iter)
    lambda = []
    for i in eachindex(L)
        if sum(L[i]) <= d
            push!(lambda, L[i])
        end
    end
    return lambda
end
