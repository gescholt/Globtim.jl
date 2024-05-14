# MyCode.jl
# Maybe generate a specific structure for some of the objects we generate (to keep track of data type.)
module MyCode

using DynamicPolynomials, MultivariatePolynomials, StaticArrays, LinearAlgebra, FastChebInterp

import Base: length, iterate

export MonomialContainer, createMonomialContainer, evaluate, EVAL, gen_mat_1, MyStruct, peaks, inbound, make_mat, length, comb_mat_vec, grid_mat_vec


struct MonomialContainer
    monomials::Vector
end

function createMonomialContainer(variables::Vector, degree::Int)
    monoms = monomials(variables, 0:degree)
    return MonomialContainer(monoms)
end

function length(mc::MonomialContainer)
    return length(mc.monomials)
end

function iterate(mc::MonomialContainer, state=1)
    return state > length(mc.monomials) ? nothing : (mc.monomials[state], state + 1)
end


function evaluate(p, v)
    p(variables(p) => v)
end

function EVAL(X, v)
    L::Vector{Float64} = map(x -> evaluate(x, v), X)
    return L
end

function gen_mat_1(S::Matrix{Float64}, M2::MonomialContainer)::Matrix{Float64} # Generate a matrix of evaluated monomials from the sample points #
    combined_matrix::Matrix{Float64} = Matrix{Float64}(undef, 0, 1) # initialize empty matrix
    for i in 1:size(S, 1) # loop over rows of S
        row::Vector{Float64} = vec(EVAL(M2, S[i, :]))
        combined_matrix = vcat(combined_matrix, row)  ## works now ##
    end
    combined_matrix = reshape(combined_matrix, size(S, 1), length(M2))
    return combined_matrix
end

function make_mat(K, M2::MonomialContainer, lb, ub)
    CH_pts = chebpoints([K, K], lb, ub)
    n = size(CH_pts, 1)
    S = Matrix{Float64}(undef, n^2, 2)
    # Fill S directly
    for i in 1:n
        for j in 1:n
            idx = (i - 1) * n + j
            S[idx, :] = CH_pts[i, j]
        end
    end
    A = gen_mat_1(S, M2)
    return S, A
end

function grid_mat_vec(K, func, M2::MonomialContainer, lb, ub)
    X = lb[1]:(ub[1]-lb[1])/K:ub[1]
    Y = lb[2]:(ub[2]-lb[2])/K:ub[2]
    S = Matrix{Float64}(undef, K^2, 2)
    V = Vector{Float64}(undef, K^2)

    # Fill S directly
    for i in 1:K
        for j in 1:K
            idx = (i - 1) * K + j
            S[idx, :] = [X[i], Y[j]]
            V[idx] = func([X[i], Y[j]])
        end
    end
    A = gen_mat_1(S, M2)
    return S, A, V
end

function comb_mat_vec(K, func, M2::MonomialContainer, lb, ub)
    CH_pts = chebpoints([K, K], lb, ub)
    n = size(CH_pts, 1)
    S = Matrix{Float64}(undef, n^2, 2)
    V = Vector{Float64}(undef, n^2)
    # Fill S directly
    for i in 1:n
        for j in 1:n
            idx = (i - 1) * n + j
            S[idx, :] = CH_pts[i, j]
            V[idx] = func(CH_pts[i, j])
        end
    end
    A = gen_mat_1(S, M2)
    return S, A, V
end

function inbound(L::Vector{Vector{Float64}}, lb, ub)
    filtered_vectors = [vec for vec in L if all(i -> lb[i] <= vec[i] <= ub[i], 1:length(vec))]
    return (filtered_vectors)
end


function peaks(v)
    x, y = v
    3 * (1 - x) .^ 2 .* exp.(-(x .^ 2) - (y + 1) .^ 2) -
    10 * (x / 5 - x .^ 3 - y .^ 5) .* exp.(-x .^ 2 - y .^ 2) -
    1 / 3 * exp.(-(x + 1) .^ 2 - y .^ 2)
end

end
