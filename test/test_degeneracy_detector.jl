using Test
using Globtim
using LinearAlgebra

# Stage 0: per-leaf degeneracy detector. Each synthetic function has a KNOWN
# phenomenon; the detector must produce the matching verdict from cheap signals
# (active-subspace spectrum + fold coherence on polynomial gradients, plus the
# Hessian/cluster signals when critical points are supplied). The detector is an
# opt-in annotator: with degeneracy_opts off it changes nothing and costs no
# extra objective evaluations.

const _B = [(-1.0, 1.0), (-1.0, 1.0)]  # center 0, half 1 ⇒ normalized == physical

# Fit a fresh leaf on f and return it (polynomial + cached samples populated).
function _fit_leaf(f, degree)
    sd = Subdomain(_B)
    Globtim.estimate_subdomain_error(f, sd, degree; basis = :chebyshev)
    return sd
end

@testset "degeneracy detector (Stage 0)" begin

    @testset "_poly_hessian_signature n_zero rule" begin
        # f flat along x₂ ⇒ Hessian ≈ diag(2, 0): exactly one ≈0 eigenvalue.
        sd = _fit_leaf(x -> x[1]^2, 2)
        sig = Globtim._poly_hessian_signature(sd.polynomial, [0.0, 0.0]; tol = 1e-3)
        @test sig.n_zero == 1
        @test sig.n_pos == 1
        @test sig.n_neg == 0

        # f = x₁²+x₂² ⇒ Hessian ≈ diag(2,2): no zero eigenvalues, well-conditioned.
        sd2 = _fit_leaf(x -> x[1]^2 + x[2]^2, 2)
        sig2 = Globtim._poly_hessian_signature(sd2.polynomial, [0.0, 0.0]; tol = 1e-3)
        @test sig2.n_zero == 0
        @test sig2.n_pos == 2
        @test isfinite(sig2.cond)
    end

    @testset "verdict: isolated_morse (full-rank, smooth)" begin
        sd = _fit_leaf(x -> x[1]^2 + x[2]^2, 4)
        diag = detect_degeneracy!(sd)
        @test diag.verdict == :isolated_morse
        @test diag.active_dim_95 == 2          # both directions carry energy
        @test diag.effective_dim == 2          # adaptive (participation) rank == 2
        @test sd.degeneracy === diag           # stored on the leaf
    end

    @testset "verdict: sloppy_valley (active subspace collapses, smooth)" begin
        sd = _fit_leaf(x -> x[1]^2 + 1e-4 * x[2]^2, 4)
        diag = detect_degeneracy!(sd)
        @test diag.verdict == :sloppy_valley
        @test diag.active_dim_95 == 1
        # active-subspace energy is almost all in one direction (D3)
        @test diag.active_eigenvalues[1] > 0.99
        # the adaptive effective dimension agrees and the estimators are surfaced
        @test diag.effective_dim == 1
        @test diag.signals[:eff_dim_pr] < 1.5
        @test haskey(diag.signals, :eff_dim_entropy)
        @test haskey(diag.signals, :gap_dominance)
        @test diag.signals[:dim_ambiguous] in (0.0, 1.0)
    end

    @testset "verdict: fold_caustic (poor fit + coherent non-axis sheet)" begin
        # A crease along x₁+x₂=0 (normal [1,1]/√2). |·| is non-polynomial ⇒ the fit
        # Gibbs-oscillates (poor rel_L2) and the gradient is coherent along a.
        a = normalize([1.0, 1.0])
        sd = _fit_leaf(x -> abs(x[1] + x[2]), 5)
        diag = detect_degeneracy!(sd)
        @test diag.verdict == :fold_caustic
        @test abs(dot(normalize(diag.fold_normal), a)) > 0.85
        @test diag.signals[:rel_l2] >= 0.05    # the fit really is poor
    end

    @testset "verdict: positive_dim_argmin (degenerate CP + necklace)" begin
        # Minimizers of (‖x‖²-1)² are the unit circle (a 1-manifold). Supplying CPs
        # on the circle gives a rank-deficient Hessian (kernel = tangent) and a
        # multi-point cluster ⇒ the post-solve verdict.
        circle(x) = (x[1]^2 + x[2]^2 - 1.0)^2
        sd = _fit_leaf(circle, 4)              # (r²-1)² is degree-4 exact
        θ = range(0, 2π; length = 7)[1:6]
        cps = [[cos(t), sin(t)] for t in θ]
        diag = detect_degeneracy!(sd; cps = cps, hessian_tol = 1e-4)
        @test diag.verdict == :positive_dim_argmin
        @test diag.hessian_n_zero == 1         # one flat (tangential) direction
        @test diag.cluster_intrinsic_dim >= 1
    end

    @testset "non-finite gradient rows are dropped (hardening)" begin
        # A gradient matrix with two clean rows and two non-finite rows: the active
        # subspace must average over the finite rows ONLY (eigen must not choke), and
        # report the drop counts.
        G = [1.0 0.0; 0.0 1.0; Inf 0.0; NaN NaN]
        frac, _, _, _, used, dropped = Globtim._active_subspace(G, 0.95, 0.99)
        @test used == 2
        @test dropped == 2
        @test all(isfinite, frac)
        @test isapprox(sum(frac), 1.0; atol = 1e-10)

        # fold coherence skips the non-finite rows and returns the FINITE norms only
        # (a NaN norm would otherwise sort to the top under rev=true and poison M).
        coh, _, normg = Globtim._fold_coherence(G, 1.0)
        @test length(normg) == 2
        @test all(isfinite, normg)
        @test isfinite(coh)

        # all rows non-finite ⇒ raises (no usable signal, no silent fallback)
        @test_throws ErrorException Globtim._active_subspace([Inf 0.0; NaN 1.0], 0.95, 0.99)
    end

    @testset "opt-in safety: default off ⇒ no annotation, no extra f calls" begin
        # adaptive_refine with degeneracy_opts=nothing leaves every leaf unannotated.
        tree = Globtim.adaptive_refine(
            x -> x[1]^2 + x[2]^2,
            _B,
            4;
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 4,
            max_leaves = 16,
            parallel = false,
            verbose = false,
        )
        for id in vcat(tree.active_leaves, tree.converged_leaves, tree.pruned_leaves)
            @test tree.subdomains[id].degeneracy === nothing
        end

        # The :polynomial gradient source makes ZERO extra objective evaluations.
        calls = Ref(0)
        counted(x) = (calls[] += 1; x[1]^2 + 1e-4 * x[2]^2)
        sd = _fit_leaf(counted, 4)
        before = calls[]
        detect_degeneracy!(sd)                 # default :polynomial source
        @test calls[] == before
    end

    @testset "opt-in on: adaptive_refine annotates leaves" begin
        tree = Globtim.adaptive_refine(
            x -> x[1]^2 + 1e-4 * x[2]^2,
            _B,
            4;
            degeneracy_opts = (;),             # on, with defaults
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 4,
            max_leaves = 16,
            parallel = false,
            verbose = false,
        )
        annotated = [
            tree.subdomains[id].degeneracy for
            id in vcat(tree.active_leaves, tree.converged_leaves) if
            tree.subdomains[id].degeneracy !== nothing
        ]
        @test !isempty(annotated)
        @test all(d -> d.verdict != :undetermined, annotated)
    end
end
