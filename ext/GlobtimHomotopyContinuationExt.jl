module GlobtimHomotopyContinuationExt

using Globtim
using HomotopyContinuation: solve, real_solutions, System, solutions, nsolutions, @var
import HomotopyContinuation   # for HomotopyContinuation.differentiate (parametric path)
using MultivariatePolynomials: differentiate   # cold path: differentiate DynamicPolynomials

function Globtim._solve_hc(
    x,
    n,
    d,
    coeffs;
    basis,
    precision,
    normalized,
    power_of_two_denom,
    return_system,
    start_system,
)
    pol = Globtim.main_nd(
        x,
        n,
        d,
        coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
    )

    # :auto picks :polyhedral for n >= 3 (mixed volume << Bezout bound for sparse systems)
    actual_start = if start_system == :auto
        n >= 3 ? :polyhedral : :total_degree
    else
        start_system
    end

    grad = differentiate.(pol, x)
    sys = System(grad)
    hc_result = solve(sys, start_system = actual_start, show_progress = false)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)

    if return_system
        return rl_sol, (pol, sys, Int(length(hc_result)))
    else
        return rl_sol
    end
end

function Globtim._solve_hc_parametric(
    support::AbstractMatrix,
    n::Int,
    cell_coeffs::Vector{Vector{Float64}},
)
    m = size(support, 1)
    @var x[1:n]
    @var a[1:m]
    xv = collect(x)
    av = collect(a)

    # p(x; a) = Σ_k a_k · x^support[k,:]  (monomial basis; coefficients are the parameters)
    monos = [prod(xv[i]^Int(support[k, i]) for i in 1:n) for k in 1:m]
    p = sum(av[k] * monos[k] for k in 1:m)
    grad = [HomotopyContinuation.differentiate(p, xv[i]) for i in 1:n]
    F = System(grad; variables = xv, parameters = av)

    # Generic-complex anchor: required (a real anchor is measure-zero and can be
    # path-deficient). Gives the full Bezout solution set to track from.
    a0 = randn(ComplexF64, m)
    R0 = solve(F; target_parameters = a0, show_progress = false)
    S0 = solutions(R0)
    anchor_n = length(S0)

    per_cell = Vector{Tuple{Vector{Vector{Float64}},NTuple{3,Int}}}()
    for cc in cell_coeffs
        Rj = solve(
            F,
            S0;
            start_parameters = a0,
            target_parameters = cc,
            show_progress = false,
        )
        rl = real_solutions(Rj; only_real = true, multiple_results = false)
        push!(per_cell, (rl, (length(S0), nsolutions(Rj), length(rl))))
    end

    return (; anchor_n = anchor_n, per_cell = per_cell)
end

end # module
