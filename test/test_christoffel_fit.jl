# Bead hdgw.5 (DEP-AUDIT LINEARSOLVE-DROP): the Christoffel weighted least squares
# is solved by QR on the weighted Vandermonde, not by LU on the normal equations.
# Checks: the coefficients agree with the normal-equations solve to rounding on a
# well-conditioned fit, the QR residual is never worse (and is better once the
# Gram matrix is ill-conditioned), the reported κ is κ(√W·V) and not its square
# κ(VᵀWV) (bead hdgw.25: checked on fits conditioned enough that κ and κ² differ),
# and Globtim no longer loads LinearSolve (checked in a fresh process, so the result
# does not depend on which test files ran first).

using Test
using Globtim
using LinearAlgebra
using Random

# Rebuild what the fit builds, to form the normal-equations solve it replaced.
function _weighted_system(n, d, K, rng, f)
    Λ = Globtim.SupportGen(n, (:one_d_for_all, d))
    S, sqrt_w = Globtim.christoffel_random_sample_chebyshev(n, Λ.data, K; rng = rng)
    V = Globtim.lambda_vandermonde_original(Λ, S; basis = :chebyshev)
    F = [f(@view S[i, :]) for i in 1:K]
    return sqrt_w .* V, sqrt_w .* F
end

@testset "Christoffel fit solves by QR (hdgw.5)" begin
    @testset "well-conditioned: QR == normal equations to rounding, κ is κ(√W·V)" begin
        n, d = 2, 6
        f = x -> exp(-(x[1]^2 + 0.5 * x[2]^2)) + 0.3 * x[1] * x[2]
        K = Globtim.christoffel_K_default(binomial(n + d, d); oversampling_c = 3.0)
        rng = MersenneTwister(11)
        res = Globtim.christoffel_fit_chebyshev(f, n, d; K = K, rng = MersenneTwister(11))
        Vw, Fw = _weighted_system(n, d, K, rng, f)
        @test length(res.coeffs) == size(Vw, 2)
        c_ne = (Vw' * Vw) \ (Vw' * Fw)          # the replaced normal-equations solve
        @test res.coeffs ≈ c_ne rtol = 1e-8
        @test res.coeffs ≈ Vw \ Fw rtol = 1e-12  # the same draw gives the same QR solve
        # hdgw.25: the fit factors once (qr(Vw, ColumnNorm()), κ from R); that is
        # exactly what `\` does on a tall matrix, so the coefficients are bitwise equal.
        @test res.coeffs == Vw \ Fw
        @test res.kappa ≈ cond(Vw) rtol = 1e-10
        @test res.kappa < 100                   # Cohen–Migliorati regime, not its square
        @test !hasproperty(res, :kappa_G)
    end

    # The bound `kappa < 100` above cannot tell κ ≈ 3 from κ² ≈ 10 (bead hdgw.25).
    # Pin κ against the Gram κ instead: κ(√W·V)² = κ(VᵀWV) holds to rounding while
    # κ(VᵀWV) ≪ 1/eps, and on a fit with κ ≳ 5 the two candidates sit far apart, so a
    # regression to reporting the Gram κ fails both assertions.
    @testset "κ is κ(√W·V), not κ(VᵀWV) = κ² (hdgw.25)" begin
        # Moderately conditioned: low oversampling (c = 0.6, K ≈ 2.3 m) on a 2-D
        # degree-8 fit gives κ ≈ 12 (fit) and ≈ 17 (subdomain fit), κ² ≈ 150-300.
        n, d = 2, 8
        f = x -> exp(-(x[1]^2 + 0.5 * x[2]^2)) + 0.3 * x[1] * x[2]
        K = Globtim.christoffel_K_default(binomial(n + d, d); oversampling_c = 0.6)
        res = Globtim.christoffel_fit_chebyshev(f, n, d; K = K, rng = MersenneTwister(23))
        Vw, _ = _weighted_system(n, d, K, MersenneTwister(23), f)
        κG = cond(Vw' * Vw)
        @test res.kappa > 5                      # κ and κ² separated by > 5x
        @test res.kappa^2 ≈ κG rtol = 1e-6
        @test !(res.kappa ≈ κG)                  # would hold for a Gram-κ regression

        # The subdomain fit is what a Christoffel leaf writes into cond_vandermonde,
        # the quantity the p-refinement cond_threshold gate reads.
        sd = Globtim.Subdomain([0.3, -0.2], [0.5, 0.8])
        g = x -> sin(2 * x[1]) * cos(x[2]) + x[1] * x[2]^2
        rs = Globtim.christoffel_subdomain_fit(
            g,
            sd,
            d;
            oversampling_c = 0.6,
            rng = MersenneTwister(7),
        )
        Λ = Globtim.SupportGen(n, (:one_d_for_all, d))
        m = Λ.size[1]
        sw = [
            sqrt(m / Globtim.christoffel_kernel_chebyshev(Λ.data, rs.samples[i, :])) for
            i in 1:rs.K_used
        ]
        Vs = sw .* Globtim.lambda_vandermonde_original(Λ, rs.samples; basis = :chebyshev)
        @test rs.kappa ≈ cond(Vs) rtol = 1e-10
        @test rs.kappa > 5
        @test rs.kappa^2 ≈ cond(Vs' * Vs) rtol = 1e-6
    end

    @testset "ill-conditioned: QR residual ≤ normal-equations residual" begin
        # Undersample so the weighted Vandermonde is nearly rank-deficient; the Gram
        # matrix then carries κ² and LU on it loses digits the QR keeps.
        n, d = 2, 14
        m = binomial(n + d, d)
        f = x -> cos(3 * x[1]) * sin(2 * x[2]) + x[1]^3
        K = m + 2
        Vw, Fw = _weighted_system(n, d, K, MersenneTwister(5), f)
        @test cond(Vw) > 1e4
        c_qr = Vw \ Fw
        c_ne = (Vw' * Vw) \ (Vw' * Fw)
        r_qr = norm(Vw * c_qr - Fw)
        r_ne = norm(Vw * c_ne - Fw)
        @test r_qr <= r_ne * (1 + 1e-6)
        res = Globtim.christoffel_fit_chebyshev(f, n, d; K = K, rng = MersenneTwister(5))
        @test isfinite(res.l2_residual)
        @test norm(res.coeffs - c_qr) <= 1e-8 * max(1.0, norm(c_qr))
    end

    @testset "LinearSolve is not loaded by Globtim (fresh process)" begin
        # In this process any earlier test file that imports a SciML package would
        # load LinearSolve, so check `using Globtim` alone in a subprocess with the
        # same project and load path.
        code = "using Globtim; print(any(p.name == \"LinearSolve\" for p in keys(Base.loaded_modules)))"
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $code`
        out = readchomp(cmd)
        @test out == "false"
    end
end
