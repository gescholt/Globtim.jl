# test_rational_solver.jl — Phase 1 of the rational-surrogate brief
# (docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md, bead B2): the lifted system
# p − y q = 0, ∇p − y ∇q = 0 solved by HomotopyContinuation, the Hessian index
# without division, and the q > 0 certificate.
#
# Oracles are computed inside the test (multistart Newton on the TRUE objective
# with ForwardDiff derivatives) rather than hard-coded, so the assertions are
# about agreement, not about remembered digits. The brief's reference points
# are quoted in comments.
#
# If the HomotopyContinuation extension cannot load, every HC-dependent testset
# is SKIPPED loudly (`@test_skip`) — a missing extension must never look like
# "0 critical points" (see the `:hc_missing` note in tree_solve.jl).

using Test
using Globtim
using LinearAlgebra
using ForwardDiff
using Random
using DynamicPolynomials

const RATIONAL_HC_OK = try
    @eval using HomotopyContinuation
    Base.get_extension(Globtim, :GlobtimHomotopyContinuationExt) !== nothing
catch err
    @warn "HomotopyContinuation extension unavailable; skipping rational solver tests" err
    false
end

# ── objectives ───────────────────────────────────────────────────────────────
f_rat(x) = (1 + x[1] + x[2]^2) / (2 + x[1]^2 + x[2]^2)
f_pole(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])
f_pole3(x) =
    1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + (x[3] + 0.20)^2 + 0.06) +
    sin(3x[1]) * cos(2x[2]) + 0.5cos(3x[3])

# ── oracle: multistart damped Newton on ∇f = 0 inside [-1,1]^n ───────────────
function newton_critical_points(
    f,
    n;
    n_starts = 400,
    seed = 1,
    tol = 1e-11,
    maxit = 200,
    dedup = 1e-6,
)
    rng = MersenneTwister(seed)
    g(x) = ForwardDiff.gradient(f, x)
    H(x) = ForwardDiff.hessian(f, x)
    found = Vector{Vector{Float64}}()
    for _ in 1:n_starts
        x = 2 .* rand(rng, n) .- 1
        converged = false
        for _ in 1:maxit
            gx = g(x)
            if norm(gx) < tol
                converged = true
                break
            end
            dx = H(x) \ gx
            nd = norm(dx)
            nd > 0.2 && (dx .*= 0.2 / nd)
            x = x - dx
            any(abs.(x) .> 1.5) && break
        end
        if converged && all(-1 .<= x .<= 1) && !any(norm(x - y) < dedup for y in found)
            push!(found, x)
        end
    end
    return found
end

fd_index(f, x) = count(<(0), eigvals(Symmetric(ForwardDiff.hessian(f, x))))

# every point of A has a partner in B within tol, and conversely
function sets_match(A, B; tol)
    length(A) == length(B) || return false
    all(any(norm(a - b) < tol for b in B) for a in A) &&
        all(any(norm(a - b) < tol for a in A) for b in B)
end

nearest_dist(x, S) = isempty(S) ? Inf : minimum(norm(x - s) for s in S)

@testset "rational critical points (lifted system)" begin
    @testset "missing extension is an error, classified :hc_missing" begin
        # the stub `_solve_rational_hc(args...)` is what runs without the ext;
        # the ext's method is specific to (Vector, Vector), so calling with no
        # arguments reaches the stub regardless of what is loaded
        err = try
            Globtim._solve_rational_hc()
            nothing
        catch e
            e
        end
        @test err isa ErrorException
        @test Globtim._classify_solve_failure(err) == :hc_missing
    end

    if !RATIONAL_HC_OK
        @test_skip "HomotopyContinuation extension not loaded — lifted-system tests skipped"
    else
        @testset "1. exact rational: lifted solve = Newton oracle on f" begin
            TR = TestInput(f_rat; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
            R = RationalConstructor(TR, 2, 2)
            @test R.nrm < 1e-10
            sys = rational_critical_system(R)
            @test length(sys.eqs) == 3
            @test length(sys.vars) == 3
            res = solve_rational_critical_points(R)
            oracle = newton_critical_points(f_rat, 2)
            @test !isempty(oracle)                       # otherwise the comparison is vacuous
            @test sets_match(res.points, oracle; tol = 1e-8)
            @test res.n_rejected_q == 0
            @test res.n_inconsistent_y == 0
            @test res.n_singular == 0
            for (x, y, idx) in zip(res.points, res.values, res.index)
                @test y ≈ f_rat(x) atol = 1e-8
                @test idx == fd_index(f_rat, x)
                @test norm(ForwardDiff.gradient(f_rat, x)) < 1e-8
            end
        end

        @testset "2. pole pair (8,4): three critical points, polynomial degree 16 has more" begin
            TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
            R = RationalConstructor(TRp, 8, 4)
            res = solve_rational_critical_points(R)
            # brief reference (finite-difference Newton on f₂):
            #   (-0.563923, -0.016849) index 0, (-0.059668, 0.903933) index 1,
            #   (-0.049738, -0.838031) index 1
            oracle = newton_critical_points(f_pole, 2)
            @test length(oracle) == 3
            @test length(res.points) == 3
            @test res.n_rejected_q == 0
            @test res.n_singular == 0
            for (x, idx) in zip(res.points, res.index)
                d = nearest_dist(x, oracle)
                @test d < 2e-3
                xo = oracle[argmin([norm(x - o) for o in oracle])]
                @test idx == fd_index(f_pole, xo)
            end
            @test sort(res.index) == [0, 1, 1]
            # 5. the division-free index equals the FD Hessian index of R itself
            for x in res.points
                @test rational_hessian_index(R, x) == fd_index(R, x)
            end
            # 5b. the index does not depend on the sign of q: (−p)/(−q) is the same
            # function, H_r = (q·H_p − p·H_q)/q² with q² > 0 (a reflection for q < 0
            # used to flip it)
            Rneg = ApproxRational((
                f === :a ? -R.a : f === :b ? -R.b : getfield(R, f) for f in fieldnames(ApproxRational)
            )...)
            for x in res.points
                @test rational_denominator(Rneg, x) < 0
                @test Rneg(x) ≈ R(x)
                @test rational_hessian_index(Rneg, x) == rational_hessian_index(R, x)
            end
            # motivation: the degree-16 polynomial surrogate (153 dof vs 59)
            # reports more in-box critical points, several far from any true one
            pol = Constructor(TRp, 16)
            @polyvar xp[1:2]
            poly_raw = solve_polynomial_system(
                xp,
                2,
                16,
                pol.coeffs;
                basis = pol.basis,
                normalized = pol.normalized,
            )
            poly_pts = [Vector{Float64}(s) for s in poly_raw if all(-1 .<= s .<= 1)]
            @test length(poly_pts) > 3
            @test rational_dof(R) < binomial(2 + 16, 16) ÷ 2
        end

        @testset "3. 3-D pole: lifted solve recovers the three critical points" begin
            TR3 = TestInput(f_pole3; dim = 3, center = zeros(3), sample_range = 1.0)
            oracle = newton_critical_points(f_pole3, 3; n_starts = 600)
            # brief reference: (-0.562566, -0.016260, -0.008683) index 1,
            # (-0.056637, 0.898681, -0.021812) index 2,
            # (-0.047972, -0.836157, -0.010574) index 2, Σ(−1)^index = 1
            @test length(oracle) == 3
            @test sum((-1)^fd_index(f_pole3, x) for x in oracle) == 1
            # the oversample rule alone would give GN = 7 (8 nodes = zeros of T_8, on
            # which the degree-8 columns vanish); RationalConstructor raises it to 8.
            # Measured: GN = 9 and 11 both put every oracle point within 7.6e-4.
            R = RationalConstructor(TR3, 8, 4)
            @test R.GN == 8
            res = solve_rational_critical_points(R)
            @test res.n_singular == 0
            @test res.n_rejected_q == 0
            @test length(res.points) == 3
            @test all(nearest_dist(o, res.points) < 5e-3 for o in oracle)
            worst = maximum(nearest_dist(o, res.points) for o in oracle)
            @info "3-D (8,4) GN=$(R.GN): worst oracle-to-lifted distance $worst, $(length(res.points)) in-box points, nrm=$(R.nrm)"
            for o in oracle
                x = res.points[argmin([norm(o - p) for p in res.points])]
                @test rational_hessian_index(R, x) == fd_index(f_pole3, o)
            end

            @testset "product form is not zero-dimensional in 3D" begin
                # q∇p − p∇q = 0 vanishes on {p = q = 0}: HC must report singular /
                # non-isolated endpoints there, which is why the lifted form is used
                prod_sys = Globtim.rational_product_system(R)
                _, pstats = Globtim._solve_rational_hc(prod_sys.eqs, prod_sys.x)
                @info "product form: $(pstats.n_paths) paths, $(pstats.n_solutions) solutions, $(pstats.n_singular) singular"
                @test pstats.n_singular > 0
            end
        end

        @testset "4. certify_positive_denominator" begin
            TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
            R84 = RationalConstructor(TRp, 8, 4)
            c = certify_positive_denominator(R84)
            @test c.ok
            @test c.qmin > 0
            @test c.n_boundary_samples == 4 * 41
            @test c.qmin <= R84.qmin_grid + 1e-12
            # a deliberately poor fit: (6,3) on f₂ has min q ≈ −0.05 inside the box
            R63 = RationalConstructor(TRp, 6, 3)
            c63 = certify_positive_denominator(R63)
            @test !c63.ok
            @test c63.qmin < 0
            @test all(-1 .<= c63.argmin .<= 1)
            @test rational_denominator(R63, c63.argmin) ≈ c63.qmin
            # the reported argmin is a genuine candidate: either on a face or a
            # stationary point of q
            on_face = any(abs(abs(v) - 1) < 1e-12 for v in c63.argmin)
            grad_q = ForwardDiff.gradient(u -> rational_denominator(R63, u), c63.argmin)
            @test on_face || norm(grad_q) < 1e-6
        end

        @testset "polynomial special case N = 0 solves like the polynomial path" begin
            TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
            R = RationalConstructor(TRp, 10, 0)
            res = solve_rational_critical_points(R)
            pol = Constructor(TRp, 10)
            @polyvar xp[1:2]
            poly_raw = solve_polynomial_system(
                xp,
                2,
                10,
                pol.coeffs;
                basis = pol.basis,
                normalized = pol.normalized,
            )
            poly_pts = [Vector{Float64}(s) for s in poly_raw if all(-1 .<= s .<= 1)]
            @test sets_match(res.points, poly_pts; tol = 1e-6)
            c = certify_positive_denominator(R)
            @test c.ok && c.qmin ≈ 1.0
        end
    end
end
