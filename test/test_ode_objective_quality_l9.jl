"""
Level-9 ODE objective quality tests (bead q9zc).

L0–L8 validated the pipeline on analytic objectives, where a critical point is
recovered to machine precision. L9 asks what changes when the objective is
defined by numerical integration — the regime every parameter-estimation problem
in this repo actually lives in.

The fixture is a parameter-estimation problem on a decoupled linear decay system:

    dyᵢ/dt = -pᵢ yᵢ,  yᵢ(0) = 1     ⇒  yᵢ(t) = exp(-pᵢ t)
    J(p) = Σ_k ‖y(t_k; p) - data_k‖²

integrated with fixed-step RK4. Two data modes, and the contrast between them is
the point of the file:

  EXACT   data generated with the SAME integrator ⇒ J(p_true) = 0 identically,
          and the only error is floating point. This is the best case, and it is
          not what real problems look like.
  BIASED  data generated from the ANALYTIC solution ⇒ J(p_true) > 0, set by the
          integrator's truncation error, and ∇J(p_true) ≠ 0. This is the honest
          case: the achievable gradient floor is a property of the SOLVER, not of
          machine epsilon or of the optimiser.

Self-contained: RK4 is 8 lines here rather than a dependency, which keeps globtim's
test environment unchanged (pre-push Layers 0.6/0.7) and makes the integrator's
accuracy an explicit, tunable parameter of the test rather than a hidden one.

SCOPE. The bead names PMPTrajectoryObjective, which lives in Opt_Traj — a private
package with a heavy ODE stack. Validating that specific objective belongs in
Opt_Traj's own suite. What is tested here is the property the ladder cares about:
how globtim's pipeline behaves when the objective carries integration noise.
"""

using Test
using Globtim
using DynamicPolynomials
using HomotopyContinuation
using DataFrames
using LinearAlgebra
using Optim
using ForwardDiff

# ── ODE fixture ──────────────────────────────────────────────────────────────

"""
Fixed-step RK4 on dy/dt = -p .* y, y(0) = 1. Returns the state at each step.

Element types follow `p` deliberately. Writing `ones(length(p))` and
`Vector{Vector{Float64}}()` — the obvious version — pins the state and the output
container to Float64, and ForwardDiff then dies with
`MethodError: no method matching Float64(::Dual)` the moment a Dual is pushed.
That is the same Float64-pinning trap already known from Opt_Traj's physics
forces, and it is silent here in a specific way: globtim's pipeline catches the
failure, warns "Hessian computation failed", and returns minimizers WITHOUT
classification. The run looks successful.
"""
function _rk4(p, T::Float64, nsteps::Int)
    S = eltype(p)
    y = ones(S, length(p))
    h = T / nsteps
    out = Vector{Vector{S}}()
    for _ in 1:nsteps
        f(v) = -p .* v
        k1 = f(y)
        k2 = f(y .+ h / 2 .* k1)
        k3 = f(y .+ h / 2 .* k2)
        k4 = f(y .+ h .* k3)
        y = y .+ (h / 6) .* (k1 .+ 2k2 .+ 2k3 .+ k4)
        push!(out, copy(y))
    end
    return out
end

const _PTRUE = [1.3, 0.7]
const _T = 2.0

"Least-squares objective. `mode = :exact` reuses the integrator for the data;
`:biased` uses the analytic solution, leaving the integrator's truncation error in."
function _ode_objective(; N::Int = 40, mode::Symbol = :exact)
    data = if mode === :exact
        _rk4(_PTRUE, _T, N)
    else
        [[exp(-_PTRUE[i] * k * _T / N) for i in 1:2] for k in 1:N]
    end
    return p -> sum(sum(abs2, y .- d) for (y, d) in zip(_rk4(p, _T, N), data))
end

_e(i) = Float64.(1:2 .== i)

"Central-difference gradient with step `h`."
_fd_grad(J, p, h) = [(J(p .+ h .* _e(i)) - J(p .- h .* _e(i))) / (2h) for i in 1:2]

"Central-difference Hessian with step `h`."
function _fd_hess(J, p, h)
    H = zeros(2, 2)
    for i in 1:2, j in 1:2
        H[i, j] =
            (
                J(p .+ h .* _e(i) .+ h .* _e(j)) - J(p .+ h .* _e(i) .- h .* _e(j)) -
                J(p .- h .* _e(i) .+ h .* _e(j)) + J(p .- h .* _e(i) .- h .* _e(j))
            ) / (4h^2)
    end
    return Symmetric(H)
end

@testset "L9 ODE Objective Quality (q9zc)" begin

    # ========================================================================
    # 9a — the fixture has the ground truth it claims
    # ========================================================================

    @testset "ground truth: exact mode vanishes at p_true, biased mode does not" begin
        Je = _ode_objective(mode = :exact)
        Jb = _ode_objective(mode = :biased)

        @test Je(_PTRUE) == 0.0                 # same integrator both sides
        @test Je(_PTRUE .+ 0.01) > 1e-6         # and it is a genuine minimum
        @test Je(_PTRUE .- 0.01) > 1e-6

        # Biased mode: p_true is no longer an exact zero. J(p_true) is the
        # integrator's truncation error, squared and summed.
        @test 0 < Jb(_PTRUE) < 1e-10
    end

    @testset "the objective is ForwardDiff-able (and the pinning trap is real)" begin
        # Pinned here as a regression: an ODE objective whose state or output
        # container is typed Float64 cannot carry Duals, and globtim does not fail
        # loudly on it — analyze_critical_points warns "Hessian computation
        # failed" and returns minimizers with no classification. The first draft
        # of this file had exactly that bug and still passed 39/39.
        J = _ode_objective(mode = :exact)
        g = ForwardDiff.gradient(J, _PTRUE)
        H = ForwardDiff.hessian(J, _PTRUE)

        @test all(isfinite, g)
        @test norm(g) < 1e-12                    # exact mode: analytically zero
        @test all(eigvals(Symmetric(H)) .> 0)
        # AD and finite differences agree, which is the cross-check that the
        # gradient floor in 9b is a property of differencing, not of the model.
        @test norm(H .- _fd_hess(J, _PTRUE, 1e-4)) < 1e-4
    end

    # ========================================================================
    # 9b — finite-difference noise floor
    # ========================================================================

    @testset "exact mode: FD gradient decays as h² down to a roundoff floor" begin
        J = _ode_objective(mode = :exact)
        # ∇J(p_true) = 0 analytically, so any nonzero FD value is pure error —
        # an exact reference, no approximation needed.
        g(h) = norm(_fd_grad(J, _PTRUE, h))

        @test g(1e-2) > g(1e-4) > g(1e-6)        # truncation-dominated regime
        # Measured ~1e-3, 1e-7, 1e-11: two orders per two orders of h, i.e. h².
        @test g(1e-4) / g(1e-2) < 1e-3
        # Floor: below h ≈ 1e-8 nothing improves, at ~1e-15.
        @test g(1e-8) < 1e-13
        @test g(1e-12) > 1e-17                   # it floors rather than vanishing
    end

    @testset "biased mode: the gradient floor is set by the SOLVER, not by eps" begin
        # This is the finding that matters for parameter estimation. With the data
        # coming from the true solution, ∇J(p_true) is NOT zero — it is whatever
        # the integrator's error makes it, and refining the integrator is the only
        # thing that lowers it. Measured ‖∇J(p_true)‖ at h = 1e-6:
        #     N =  10 → 6.4e-5      N =  40 → 8.4e-7
        #     N =  20 → 7.2e-6      N = 160 → 1.3e-8
        floors = [
            norm(_fd_grad(_ode_objective(N = N, mode = :biased), _PTRUE, 1e-6)) for
            N in (10, 20, 40, 160)
        ]

        @test all(diff(floors) .< 0)             # refining the solver lowers it
        @test floors[1] > 1e-6                   # coarse solver: far above eps
        @test floors[end] < 1e-6                 # fine solver: much better
        # Orders of magnitude, not a rounding effect.
        @test floors[1] / floors[end] > 1e3
    end

    # ========================================================================
    # 9c — Hessian reliability
    # ========================================================================

    @testset "the Hessian is well conditioned and step-insensitive at the minimum" begin
        J = _ode_objective(mode = :exact)
        specs = [eigvals(_fd_hess(J, _PTRUE, h)) for h in (1e-2, 1e-3, 1e-4, 1e-5, 1e-6)]

        for ev in specs
            @test all(ev .> 0)                   # positive definite at a minimum
            @test maximum(ev) / minimum(ev) < 100
        end
        # Measured [4.078, 15.71] at every step size from 1e-2 to 1e-6. The useful
        # asymmetry: second-order structure is robust over four orders of h, in a
        # regime where first-order information has a hard floor (9b). Curvature
        # survives noise that swamps the gradient.
        spread = maximum(maximum.(specs)) - minimum(maximum.(specs))
        @test spread < 0.1
    end

    # ========================================================================
    # 9d — penalty regions
    # ========================================================================

    @testset "growth region: J stays finite but explodes" begin
        # p < 0 makes the system grow instead of decay. Nothing throws and nothing
        # returns Inf — J simply becomes enormous (4.8e34 at p₁ = -20). Worth
        # pinning: an optimiser is not protected here by NaN/Inf handling, only by
        # the magnitude.
        J = _ode_objective(mode = :exact)
        @test isfinite(J([0.0, 0.7]))
        @test isfinite(J([-20.0, 0.7]))
        @test J([-1.0, 0.7]) > J([0.0, 0.7]) > J(_PTRUE)
        @test J([-20.0, 0.7]) > 1e30
    end

    @testset "Inf-masked objective: p_true must be finite, or the run is vacuous" begin
        # Objectives that mask failures as Inf (the TolerantObjective pattern) have
        # a specific failure mode: a misconfigured domain makes the objective
        # constant-Inf, and the optimiser then "succeeds" on nothing. The guard is
        # to check the true parameter is finite BEFORE optimising.
        base = _ode_objective(mode = :exact)
        guarded(box) = p -> all(abs.(p .- _PTRUE) .<= box) ? base(p) : Inf

        good = guarded(0.5)
        @test isfinite(good(_PTRUE))             # the sanity check that must pass
        @test isinf(good(_PTRUE .+ 10.0))        # and it does mask outside

        # A box that excludes p_true: every evaluation at and around truth is Inf.
        bad = guarded(-1.0)
        @test !isfinite(bad(_PTRUE))             # exactly what the guard catches
        @test all(isinf(bad(_PTRUE .+ d)) for d in (0.0, 0.1, -0.1))
    end

    # ========================================================================
    # 9e — the full pipeline on an ODE objective
    # ========================================================================

    @testset "pipeline recovers p_true, but ~10 orders worse than the analytic case" begin
        J = _ode_objective(mode = :exact)
        TR = TestInput(J, dim = 2, center = _PTRUE, GN = 14, sample_range = 0.3)
        pol = Constructor(TR, 6, basis = :chebyshev, normalized = false)
        @polyvar x[1:2]
        cps = solve_polynomial_system(
            x,
            2,
            6,
            pol.coeffs;
            basis = :chebyshev,
            normalized = false,
        )
        df = process_crit_pts(cps, J, TR)
        _, minimizers = analyze_critical_points(J, df, TR; verbose = false)

        # The ODE objective is not polynomial, so unlike L6/L8 the fit is
        # approximate — measured L2 ≈ 7.5e-6 at degree 6.
        @test 0 < pol.nrm < 1e-3
        @test nrow(minimizers) == 1

        # Classification now runs: with an AD-clean objective the Hessian path
        # succeeds, where a Float64-pinned one would silently skip it.
        @test minimizers.critical_point_type[1] == :minimum

        recovered = [minimizers.x1[1], minimizers.x2[1]]
        err = norm(recovered .- _PTRUE)
        @test err < 1e-3                          # it does find the right point
        # ...but nowhere near L8's 5.6e-16 on the analytic fixture. Measured ~1e-5.
        # That gap is the cost of integration noise and is the headline of L9:
        # the pipeline is not the limiting factor, the objective is.
        @test err > 1e-12
    end

    # ========================================================================
    # 9f — method comparison on the ODE objective
    # ========================================================================

    @testset "gradient-free and gradient-based both reach p_true from spread starts" begin
        J = _ode_objective(mode = :exact)
        starts = [[1.0, 0.5], [1.6, 0.9], [1.1, 0.95], [1.5, 0.55]]

        for (name, method) in (("NelderMead", Optim.NelderMead()), ("LBFGS", Optim.LBFGS()))
            @testset "$name" begin
                errs = Float64[]
                for s in starts
                    res = Optim.optimize(J, s, method, Optim.Options(iterations = 2000))
                    push!(errs, norm(Optim.minimizer(res) .- _PTRUE))
                end
                # Both recover the true parameters from every start — this
                # objective is unimodal near truth, so the comparison is about
                # attainable accuracy rather than recall.
                @test all(errs .< 1e-2)
                @test count(<(1e-4), errs) >= 2
            end
        end
    end
end
