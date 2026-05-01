module GlobtimHomotopyContinuationExt

using Globtim
using HomotopyContinuation: solve, real_solutions, System
using MultivariatePolynomials: differentiate

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

end # module
