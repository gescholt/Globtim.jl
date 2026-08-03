# Regression test for bug 7vug.
#
# `lambda_vandermonde` fits the Chebyshev Vandermonde in the PLAIN T_n basis (no √(2/π)
# weights), so a Chebyshev fit's stored `coeffs` are plain-T_n coefficients. But `evaluate`,
# the HC solve (`solve_polynomial_system` → `symbolic_chebyshev(normalized)`), and
# `to_exact_monomial_basis` applied the orthonormal weights when `normalized=true` — so
# `evaluate` did NOT reproduce the fitted approximant (off by O(1) at the poly's own nodes)
# and HC solved a distorted polynomial. Fix: store `normalized=false` for Chebyshev
# (`_stored_normalized`), so every reconstruction path uses the same plain basis the
# coefficients live in.
using Test
using Globtim
using LinearAlgebra

@testset "evaluate reproduces the fitted approximant (7vug)" begin
    n = 2
    f = x -> exp(0.4 * x[1]) * sin(1.7 * x[2]) + 0.25 * x[1]^2 - 0.1 * x[2]
    TR = TestInput(f, dim = n, center = [0.15, -0.05], GN = 45, sample_range = 0.7)

    # Test the previously-buggy default (normalized=true) AND explicit false — both must give
    # a plain-basis poly whose `evaluate` reproduces the fit.
    for nrm_req in (true, false)
        pol = Constructor(TR, 12, basis = :chebyshev, normalized = nrm_req)

        # (1) Chebyshev coeffs are plain-T_n ⇒ stored flag is false regardless of the request.
        @test pol.normalized == false

        # (2) evaluate reproduces the fitted values at the polynomial's OWN grid nodes.
        #     Pre-fix this was off by O(1) (e.g. max |w-z| ≈ 99 while the fit residual ≈ 1e-6).
        #     Grid orientation differs by construction path (N×n_dim vs n_dim×N) — pick the axis
        #     whose length matches the number of stored values.
        np = length(pol.z)
        node(i) = size(pol.grid, 1) == np ? pol.grid[i, :] : pol.grid[:, i]
        zscale = max(1.0, maximum(abs, pol.z))
        node_err = maximum(
            abs(Globtim.evaluate(pol, pol.center .+ pol.scale_factor .* node(i)) - pol.z[i])
            for i in 1:np
        )
        @test node_err < 1e-4 * zscale

        # (3) evaluate approximates f at fresh interior points to fit accuracy.
        for t in ([0.1, 0.0], [0.5, 0.3], [-0.3, -0.4], [0.2, 0.6])
            x = TR.center .+ TR.sample_range .* t
            @test isapprox(Globtim.evaluate(pol, x), f(x); atol = 1e-3, rtol = 1e-3)
        end
    end

    # Legendre must be untouched: its Vandermonde normalizes, so normalized=true is correct there.
    pol_leg = Constructor(TR, 12, basis = :legendre, normalized = true)
    @test pol_leg.normalized == true
end
