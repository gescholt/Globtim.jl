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

            @testset "a solve that loses a path is repeated and never silent" begin
                # ∇(Σ yᵢ⁴ − yᵢ²) = 0 has 27 real roots; the polyhedral start loses paths
                # on a few percent of solves (25 of 300 measured). Deterministic claims:
                # a solve either returns all 27 or reports failed paths, and it makes
                # between 1 and 1 + max_retries attempts.
                DynamicPolynomials.@polyvar yv[1:3]
                pv = sum(yi^4 - yi^2 for yi in yv)
                geqs = [DynamicPolynomials.differentiate(pv, yi) for yi in yv]
                for _ in 1:40
                    sols, st = Globtim._solve_rational_hc(geqs, collect(yv); start_system = :polyhedral, compile = false)
                    @test length(sols) == 27 || st.n_path_failures > 0
                    @test 1 <= st.n_solve_attempts <= 3
                    st.n_solve_attempts > 1 && st.n_path_failures == 0 && @test length(sols) == 27
                end
                _, st0 = Globtim._solve_rational_hc(geqs, collect(yv); start_system = :polyhedral, compile = false, max_retries = 0)
                @test st0.n_solve_attempts == 1
                @test_throws ArgumentError Globtim._solve_rational_hc(geqs, collect(yv); max_retries = -1)
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
            # face recursion (default; N = 4: one HC solve per face of the square)
            c = certify_positive_denominator(R84)
            @test c.method == :recursion && c.exact
            @test c.ok
            @test c.qmin > 0
            @test c.n_faces == 9
            @test c.n_failed_faces == 0   # exact requires every face solve to keep all its paths
            @test c.qmin <= R84.qmin_grid + 1e-12
            # the exact minimum lies below every sample and close to a dense lattice's
            lat = range(-1.0, 1.0; length = 401)
            qlat = minimum(rational_denominator(R84, [a, b]) for a in lat, b in lat)
            @test c.qmin <= qlat + 1e-12
            @test qlat - c.qmin < 1e-3 * qlat
            # the Phase-1 facet lattice, now opt-in: never below the exact minimum
            cs = certify_positive_denominator(R84; method = :sampling)
            @test cs.method == :sampling && !cs.exact
            @test cs.n_boundary_samples == 4 * 41
            @test c.qmin <= cs.qmin + 1e-12
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
            @test_throws ArgumentError certify_positive_denominator(R84; method = :nonsense)
        end

        @testset "4b. quadratic denominators: exact box minimum by linear solves" begin
            # hand-made quadratics with the minimum at a known place of the square
            function qmin_of(c, g, H)
                qm, am, _ = Globtim._box_min_quadratic(c, g, H)
                return qm, am
            end
            I2 = Matrix(1.0I, 2, 2)
            # interior: (x − (0.2, −0.3))², shifted by 0.5
            qm, am = qmin_of(0.5 + 0.13, -2 .* [0.2, -0.3], 2 .* I2)
            @test qm ≈ 0.5 && am ≈ [0.2, -0.3]
            # an edge: centre (1.5, 0.3), outside the box: minimum at (1, 0.3)
            qm, am = qmin_of(0.1 + 1.5^2 + 0.3^2, -2 .* [1.5, 0.3], 2 .* I2)
            @test am ≈ [1.0, 0.3] && qm ≈ 0.1 + 0.25
            # a vertex: centre (1.4, −1.6)
            qm, am = qmin_of(1.4^2 + 1.6^2, -2 .* [1.4, -1.6], 2 .* I2)
            @test am ≈ [1.0, -1.0] && qm ≈ 0.4^2 + 0.6^2
            # indefinite H: x₁² − x₂² has its box minimum −1 at x₁ = 0, x₂ = ±1
            qm, am = qmin_of(0.0, zeros(2), [2.0 0.0; 0.0 -2.0])
            @test qm ≈ -1 && am[1] ≈ 0 && abs(am[2]) ≈ 1
            # the case the facet lattice misses: q = (x₁ − 1.03)² + (x₂ − 0.5)² − 0.0109
            # dips to −0.01 on the face x₁ = 1 between the 3-point lattice's nodes
            c0 = 1.03^2 + 0.25 - 0.0109
            qm, am = qmin_of(c0, -2 .* [1.03, 0.5], 2 .* I2)
            @test qm ≈ -0.01 atol = 1e-12
            @test am ≈ [1.0, 0.5]
            qlat3 = minimum(c0 - 2 * (1.03a + 0.5b) + a^2 + b^2 for a in (-1.0, 0.0, 1.0), b in (-1.0, 0.0, 1.0))
            @test qlat3 > 0
            # 3-D, random indefinite forms: never above a dense lattice's minimum
            rng = Random.Xoshiro(3)
            lat3 = range(-1.0, 1.0; length = 41)
            for _ in 1:5
                A = randn(rng, 3, 3)
                H = A + A'
                g = randn(rng, 3)
                qm, _ = qmin_of(0.0, g, H)
                ql = minimum(dot(g, [a, b, d]) + dot([a, b, d], H * [a, b, d]) / 2 for a in lat3, b in lat3, d in lat3)
                @test qm <= ql + 1e-12
                @test ql - qm < 0.05 * max(1.0, abs(ql))
            end
            # on a fit: (4,2) in 3-D, q quadratic — exact minimum below a dense lattice's
            TR3 = TestInput(f_pole3; dim = 3, center = zeros(3), sample_range = 1.0, GN = 10)
            R42 = RationalConstructor(TR3, 4, 2)
            if R42.N == 2
                c42 = certify_positive_denominator(R42)
                @test c42.method == :recursion && c42.n_faces == 27
                q41 = minimum(rational_denominator(R42, [a, b, d]) for a in lat3, b in lat3, d in lat3)
                @test c42.qmin <= q41 + 1e-10
                @test q41 - c42.qmin < 1e-2 * max(1.0, abs(q41))
            else
                @test_skip "RationalConstructor reduced (4,2) to N = $(R42.N)"
            end
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

        # ── Phase-3 brief B1.2 / B1.3: parametric lifted solver ──────────────────
        # One compiled family and one generic anchor per shape (n, M, N); each fit
        # is a parameter homotopy tracking exactly C(n, M, N) paths. Assertions are
        # agreement with the from-scratch :polyhedral solve, the anchor count, the
        # cache, and zero failed paths (RATIONAL_PHASE3_BRIEF.md, B1.2 tests 1–5,
        # B1.3 unit test). The default anchor is :monodromy; the :polyhedral anchor
        # has its own testset below.
        @testset "B1.2 parametric lifted solver" begin
            anchor_dir = mktempdir()
            Globtim._rational_parametric_cache_clear!()
            C = rational_generic_path_count

            # the same accepted set, the same rejection counts, under both methods
            function same_census(R; tol)
                # the counts are compared on a from-scratch solve that lost no path: HC's
                # polyhedral tracker gives up on one now and then (7 of 8 outside roots in
                # one CI run), the solve retries inside, and a third layer here keeps the
                # comparison off that event
                rp = solve_rational_critical_points(R; method = :polyhedral)
                for _ in 1:2
                    rp.n_path_failures == 0 && break
                    rp = solve_rational_critical_points(R; method = :polyhedral)
                end
                @test rp.n_path_failures == 0
                rq = solve_rational_critical_points(R; method = :parametric, anchor_dir = anchor_dir)
                @test sets_match(rp.points, rq.points; tol = tol)
                @test rp.n_rejected_q == rq.n_rejected_q
                @test rp.n_outside == rq.n_outside
                @test rp.n_inconsistent_y == rq.n_inconsistent_y
                @test sort(rp.index) == sort(rq.index)
                @test rq.n_path_failures == 0
                @test rq.n_singular == 0
                @test rq.stats.start_system == :parametric
                return rp, rq
            end

            TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
            @testset "1. A2 at (8,4), GN 24: agrees with :polyhedral to 1e-10" begin
                R = RationalConstructor(TRp, 8, 4)
                @test (R.M, R.N) == (8, 4)
                rp, rq = same_census(R; tol = 1e-10)
                @test length(rq.points) == 3
                @testset "2. anchor has C(2,8,4) = 89 solutions; the track reports 89 paths" begin
                    @test C(2, 8, 4) == 89
                    @test rq.stats.C == 89
                    @test rq.n_paths == 89
                    @test rq.stats.cache_hit == false
                    @test rq.stats.anchor == :monodromy      # the default anchor
                    info = Globtim._rational_parametric_cache_info()
                    @test info.misses == 1
                    @test info.n_shapes == 1
                    @test isfile(Globtim._rational_anchor_path(anchor_dir, 2, 8, 4))
                end
                @testset "4. a second fit of the same shape does not recompile" begin
                    TRs = TestInput(f_pole; dim = 2, center = [0.1, -0.05], sample_range = 0.9, GN = 24)
                    R2 = RationalConstructor(TRs, 8, 4)
                    @test (R2.M, R2.N) == (8, 4)
                    hits0 = Globtim._rational_parametric_cache_info().hits
                    r2 = solve_rational_critical_points(R2; method = :parametric, anchor_dir = anchor_dir)
                    @test r2.stats.cache_hit == true
                    @test Globtim._rational_parametric_cache_info().hits == hits0 + 1
                    @test Globtim._rational_parametric_cache_info().misses == 1
                    @test r2.n_paths == 89
                    @test r2.n_path_failures == 0
                    # and the census is the from-scratch one
                    r2p = solve_rational_critical_points(R2; method = :polyhedral)
                    @test sets_match(r2.points, r2p.points; tol = 1e-10)
                    # the warm track is far cheaper than the cold compile + anchor:
                    # the compile cost is paid once per shape, which is the point
                    t_warm = @elapsed solve_rational_critical_points(R2; method = :parametric, anchor_dir = anchor_dir)
                    @test t_warm < 5.0
                end
            end

            @testset "5. (6,3) misfit of A2 (q has a zero in the box): same accepted set" begin
                R63 = RationalConstructor(TRp, 6, 3)
                @test (R63.M, R63.N) == (6, 3)
                @test certify_positive_denominator(R63).qmin < 0
                rp, rq = same_census(R63; tol = 1e-8)
                @test rq.n_paths == C(2, 6, 3)
            end

            @testset "3. f₃ at (8,4): agrees with :polyhedral" begin
                TR3 = TestInput(f_pole3; dim = 3, center = zeros(3), sample_range = 1.0)
                R3 = RationalConstructor(TR3, 8, 4)
                @test (R3.M, R3.N) == (8, 4)
                rp, rq = same_census(R3; tol = 1e-8)
                @test length(rq.points) == 3
                @test rq.n_paths == C(3, 8, 4) == 659
                @test rq.stats.cache_hit == false
            end

            @testset "polynomial special case N = 0 under :parametric" begin
                R0 = RationalConstructor(TRp, 10, 0)
                rp, rq = same_census(R0; tol = 1e-8)
                @test rq.n_paths == C(2, 10, 0) == 81
            end

            @testset "disk store: a cold cache reloads the anchor and gives the same census" begin
                R = RationalConstructor(TRp, 8, 4)
                r_mem = solve_rational_critical_points(R; method = :parametric, anchor_dir = anchor_dir)
                Globtim._rational_parametric_cache_clear!()
                @test Globtim._rational_parametric_cache_info().n_shapes == 0
                out = Globtim._solve_rational_hc_parametric(
                    2, 8, 4, [(Globtim._rational_monomial_coefficients(R).a, Globtim._rational_monomial_coefficients(R).b)];
                    anchor_dir = anchor_dir,
                )
                @test out.anchor.source == :disk
                @test out.anchor.n_solutions == 89
                sols, st = out.per_fit[1]
                pts = [Vector{Float64}(s[1:2]) for s in sols if all(-1 .<= s[1:2] .<= 1)]
                @test sets_match(pts, r_mem.points; tol = 1e-10)
                @test st.n_path_failures == 0
                # a stored anchor of the wrong count is refused, not used
                bad_dir = mktempdir()
                # 45 + 15 monomial coefficients for (2,8,4); 88 ≠ 89 solutions
                Globtim._rational_anchor_save(bad_dir, 2, 8, 4; params = randn(ComplexF64, 60),
                    solutions = [randn(ComplexF64, 3) for _ in 1:88], anchor = :polyhedral, t_anchor = 0.0)
                Globtim._rational_parametric_cache_clear!()
                @test_throws ErrorException solve_rational_critical_points(R; method = :parametric, anchor_dir = bad_dir)
            end

            @testset "B1.3 monodromy anchor: exactly C solutions, agrees with :polyhedral" begin
                mono_dir = mktempdir()
                Globtim._rational_parametric_cache_clear!()
                R = RationalConstructor(TRp, 8, 4)
                rp = solve_rational_critical_points(R; method = :polyhedral)
                rq = solve_rational_critical_points(R; method = :parametric, anchor = :monodromy, anchor_dir = mono_dir)
                @test rq.stats.anchor == :monodromy
                @test rq.stats.C == 89
                @test rq.n_paths == 89
                @test rq.n_path_failures == 0
                @test sets_match(rp.points, rq.points; tol = 1e-10)
                @test rp.n_rejected_q == rq.n_rejected_q
                @test rp.n_outside == rq.n_outside
                stored = Globtim._rational_anchor_load(mono_dir, 2, 8, 4)
                @test stored.n_solutions == 89
                @test stored.anchor == :monodromy
                # monodromy is the default: the same call without `anchor` gives the same anchor
                Globtim._rational_parametric_cache_clear!()
                rq_def = solve_rational_critical_points(R; method = :parametric, anchor_dir = mktempdir())
                @test rq_def.stats.anchor == :monodromy
                @test sets_match(rq.points, rq_def.points; tol = 1e-10)

                TR3 = TestInput(f_pole3; dim = 3, center = zeros(3), sample_range = 1.0)
                R63 = RationalConstructor(TR3, 6, 3)
                (M3, N3) = (R63.M, R63.N)
                rp3 = solve_rational_critical_points(R63; method = :polyhedral)
                rq3 = solve_rational_critical_points(R63; method = :parametric, anchor = :monodromy, anchor_dir = mono_dir)
                @test rq3.stats.anchor == :monodromy
                @test rq3.stats.C == C(3, M3, N3)
                @test rq3.n_paths == C(3, M3, N3)
                @test rq3.n_path_failures == 0
                @test sets_match(rp3.points, rq3.points; tol = 1e-8)
                @test rp3.n_rejected_q == rq3.n_rejected_q
                @test rp3.n_outside == rq3.n_outside
            end

            @testset "polyhedral anchor (the independent check of C): exactly C solutions, same census" begin
                poly_dir = mktempdir()
                Globtim._rational_parametric_cache_clear!()
                R = RationalConstructor(TRp, 8, 4)
                rp = solve_rational_critical_points(R; method = :polyhedral)
                rq = solve_rational_critical_points(R; method = :parametric, anchor = :polyhedral, anchor_dir = poly_dir)
                # :polyhedral_completed when the polyhedral tracker lost a path and monodromy filled it
                @test rq.stats.anchor in (:polyhedral, :polyhedral_completed)
                @test rq.stats.C == 89
                @test rq.n_paths == 89
                @test rq.n_path_failures == 0
                @test sets_match(rp.points, rq.points; tol = 1e-10)
                @test rp.n_rejected_q == rq.n_rejected_q
                @test rp.n_outside == rq.n_outside
                stored = Globtim._rational_anchor_load(poly_dir, 2, 8, 4)
                @test stored.n_solutions == 89
                @test stored.anchor == rq.stats.anchor
            end

            @testset "interpreted family (compile = false): same census, same anchor count" begin
                int_dir = mktempdir()
                Globtim._rational_parametric_cache_clear!()
                R = RationalConstructor(TRp, 8, 4)
                rp = solve_rational_critical_points(R; method = :polyhedral)
                rq = solve_rational_critical_points(R; method = :parametric, compile = false, anchor_dir = int_dir)
                @test rq.stats.compile == false
                @test rq.stats.anchor == :monodromy
                @test rq.n_paths == 89
                @test rq.n_path_failures == 0
                @test sets_match(rp.points, rq.points; tol = 1e-10)
                @test rp.n_rejected_q == rq.n_rejected_q
                # the interpreted representation is cached with the shape: a second fit reuses it
                R2 = RationalConstructor(TestInput(x -> f_pole(x .+ 0.1); dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24), 8, 4)
                rq2 = solve_rational_critical_points(R2; method = :parametric, compile = false, anchor_dir = int_dir)
                @test rq2.stats.cache_hit == true
                @test rq2.stats.compile == false
                # the polyhedral anchor under an interpreted family
                Globtim._rational_parametric_cache_clear!()
                rq3 = solve_rational_critical_points(R; method = :parametric, compile = false, anchor = :polyhedral, anchor_dir = mktempdir())
                @test rq3.stats.anchor in (:polyhedral, :polyhedral_completed)
                @test rq3.n_paths == 89
                @test sets_match(rp.points, rq3.points; tol = 1e-10)
                # :auto compiles a 60-parameter family
                Globtim._rational_parametric_cache_clear!()
                rq4 = solve_rational_critical_points(R; method = :parametric, anchor_dir = int_dir)
                @test rq4.stats.compile == :mixed
                @test_throws ArgumentError solve_rational_critical_points(R; method = :parametric, compile = :fast)
            end

            @testset "argument checks" begin
                R = RationalConstructor(TRp, 8, 4)
                @test_throws ArgumentError solve_rational_critical_points(R; method = :newton)
                @test_throws ArgumentError solve_rational_critical_points(R; method = :parametric, anchor = :random)
                @test_throws ArgumentError Globtim._solve_rational_hc_parametric(2, 8, 4, [(zeros(3), zeros(2))]; anchor_dir = nothing)
            end
            Globtim._rational_parametric_cache_clear!()
        end
    end
end
