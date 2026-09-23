# =============================================================================
# audit_rational_phase1.jl — bead B3 of docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md
#
# Rational surrogates r = p/q (RationalConstructor + the lifted system solved
# by HC) against the polynomial pipeline (Constructor + solve_polynomial_system)
# on three closed-form objectives, at matched degrees of freedom:
#
#   A. pole pair, 2-D      f₂(x) = 1/((x₁−1.15)² + (x₂−0.30)² + 0.04) + sin(3x₁)cos(2x₂)
#   B. Lennard–Jones slice  softened LJ energy of a third atom between two fixed
#                           atoms at (∓0.6, 0): σ = 0.5, δ = 0.05 — already a
#                           rational function of x
#   C. Margules TPD, 1-D    the Clapeyron-free two-suffix Margules TPD in the
#                           logit chart (Globtim.MargulesTPD on [−5, 5]);
#                           pkg/ThermoObjectives is not in profiles/dev, so the
#                           mole-fraction chart is not run here
#
# Configurations: rational (M,N) ∈ {(4,2),(6,3),(8,4),(10,5),(12,6)},
# polynomial D ∈ {6,8,10,12,14,16,20}, one grid for all (GN = 24 → 25 nodes per
# dimension). Every surrogate critical point is refined on the TRUE objective by
# Newton with ForwardDiff derivatives ("standard refinement"), classified by the
# Hessian index of f at the refined point, and the Poincaré–Hopf sum is recorded.
#
# Gate (brief §3), per objective, with P* the best-nrm polynomial degree and R*
# the best-nrm rational configuration with dof ≤ dof(P*)/2:
#   1. nrm(R*) ≤ nrm(P*);
#   2. every R* critical point refines to |∇f| < 1e-6, and the refined R* and P*
#      point sets agree within 1e-3 (no polynomial-only spurious points and no
#      rational-only ones);
#   3. certify_positive_denominator(R*).ok;
#   4. lifted HC wall time at R* ≤ polynomial HC wall time at P*.
#
# Outputs (one timestamped directory): audit_full.jld2 (everything, with
# user_metadata), critical_points.csv, audit_table.csv, summary.md, and a
# ledger record (Globtim.emit_ledger_record; --no-ledger to skip).
#
# Run (smoke, ~1 min):
#   infra/tools/run_capped.sh -m 16G -- julia --project=profiles/dev \
#     pkg/globtim/scripts/audit_rational_phase1.jl --smoke --no-ledger --outdir /tmp/x
# Run (full):
#   infra/tools/run_capped.sh -m 16G -- julia --project=profiles/dev \
#     pkg/globtim/scripts/audit_rational_phase1.jl
# =============================================================================

using Globtim
using HomotopyContinuation          # activates the :hc solver and _solve_rational_hc
using DynamicPolynomials
using ForwardDiff
using LinearAlgebra
using Printf
using Dates
using JLD2
using CSV
using DataFrames

Base.get_extension(Globtim, :GlobtimHomotopyContinuationExt) === nothing &&
    error("GlobtimHomotopyContinuationExt did not load; the audit cannot run without HC")

# ── objectives ──────────────────────────────────────────────────────────────

f_pole(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])

const LJ_ATOMS = ([-0.6, 0.0], [0.6, 0.0])
const LJ_SIGMA = 0.5
const LJ_DELTA = 0.05
function f_lj(x)
    E = zero(eltype(x))
    for a in LJ_ATOMS
        s = LJ_SIGMA^2 / ((x[1] - a[1])^2 + (x[2] - a[2])^2 + LJ_DELTA)
        E += s^6 - s^3
    end
    return E
end

f_margules(x) = MargulesTPD(x)          # accepts a scalar or a length-1 vector

# Same two-suffix Margules TPD (A = 3, feed z = (0.4, 0.6)) as MargulesTPD, but in
# the mole-fraction coordinate y₁ instead of the logit w = ln(y₁/y₂).
function f_margules_y(y)
    y1 = y isa AbstractVector ? y[1] : y
    A = 3.0
    z1, z2 = 0.4, 0.6
    d1 = log(z1) + A * z2^2
    d2 = log(z2) + A * z1^2
    y2 = 1 - y1
    return y1 * (log(y1) + A * y2^2 - d1) + y2 * (log(y2) + A * y1^2 - d2)
end

"""
    Objective(key, name, f, dim, center, range; ad = :forwarddiff, gradtol = 1e-6)

An objective for the audit. `range` is the half-width (scalar or per-coordinate
vector). `ad` selects the derivatives used by the refinement on f: `:forwarddiff`
for closed-form objectives, `:finitediff` (central differences) for objectives that
do not accept dual numbers (ODE shooting). `gradtol` is the |∇f| threshold below
which a refined point counts as verified; with finite differences on an ODE
objective integrated at 1e-10 it cannot be 1e-6.
"""
struct Objective
    key::String
    name::String
    f::Function
    dim::Int
    center::Vector{Float64}
    range::Union{Float64,Vector{Float64}}
    ad::Symbol
    gradtol::Float64
end
Objective(key, name, f, dim, center, range; ad::Symbol = :forwarddiff, gradtol::Real = 1e-6) =
    Objective(key, name, f, dim, center, range, ad, Float64(gradtol))

const OBJECTIVES = Dict(
    "A" => Objective("A", "pole pair 2-D", f_pole, 2, [0.0, 0.0], 1.0),
    "B" => Objective("B", "Lennard-Jones slice 2-D", f_lj, 2, [0.0, 0.0], 1.0),
    "C" => Objective("C", "Margules TPD 1-D (logit chart)", f_margules, 1, [0.0], 5.0),
    # The same TPD in the MOLE-FRACTION chart y₁ ∈ [0.01, 0.99]: the y ln y edge
    # singularities sit just outside the box, so polynomial coefficients decay
    # only algebraically — the case the brief's objective C is meant to decide
    # (pkg/ThermoObjectives, which has the Clapeyron models, is not in profiles/dev).
    "D" => Objective("D", "Margules TPD 1-D (mole-fraction chart)", f_margules_y, 1, [0.5], 0.49),
)

# ── CLI ─────────────────────────────────────────────────────────────────────

function parse_args(argv; root = "rational_phase1", default_objectives = ["A", "B", "C", "D"])
    cfg = Dict{String,Any}(
        "objectives" => default_objectives,
        "supersedes" => String[],
        "rational" => [(4, 2), (6, 3), (8, 4), (10, 5), (12, 6)],
        "polynomial" => [6, 8, 10, 12, 14, 16, 20],
        "gn" => 24,
        # objective B only (full runs): the σ-collapse search for the (24,24) LJ
        # slice, on a grid that determines degree 24 (GN ≥ 24, oversampled)
        "rational_extended" => [(12, 12), (16, 16), (20, 20), (24, 24)],
        "gn_extended" => 30,
        "outdir" => nothing,
        "ledger" => true,
        "smoke" => false,
    )
    i = 1
    while i <= length(argv)
        a = argv[i]
        if a == "--smoke"
            cfg["smoke"] = true
            cfg["rational"] = [(4, 2), (8, 4)]
            cfg["polynomial"] = [6, 12]
            cfg["rational_extended"] = [(6, 6)]
            cfg["gn_extended"] = 12
        elseif a == "--no-ledger"
            cfg["ledger"] = false
        elseif a == "--objectives"
            cfg["objectives"] = String.(split(argv[i+1], ","))
            i += 1
        elseif a == "--gn"
            cfg["gn"] = parse(Int, argv[i+1])
            i += 1
        elseif a == "--outdir"
            cfg["outdir"] = argv[i+1]
            i += 1
        elseif a == "--supersedes"
            cfg["supersedes"] = String.(split(argv[i+1], ","))
            i += 1
        elseif a == "--rational"            # e.g. --rational 12:7,14:6,20:10
            cfg["rational"] = [(parse(Int, split(s, ":")[1]), parse(Int, split(s, ":")[2])) for s in split(argv[i+1], ",")]
            i += 1
        elseif a == "--polynomial"          # e.g. --polynomial 20,24
            cfg["polynomial"] = parse.(Int, split(argv[i+1], ","))
            i += 1
        else
            error("unknown argument $a")
        end
        i += 1
    end
    if cfg["outdir"] === nothing
        stamp = Dates.format(now(), "yyyymmddTHHMMSS")
        cfg["outdir"] = joinpath(
            "globtim_results",
            root,
            stamp * (cfg["smoke"] ? "_smoke" : ""),
        )
    end
    return cfg
end

# ── refinement on the true objective ────────────────────────────────────────

"""
Central-difference gradient and Hessian for objectives that do not take dual
numbers. Steps are relative to the box half-width `hw` (1e-4 for the gradient,
1e-3 for the Hessian, which differences the FD gradient).
"""
function fd_gradient(f, x, hw)
    n = length(x)
    g = zeros(n)
    for i in 1:n
        h = 1e-4 * hw[i]
        e = zeros(n)
        e[i] = h
        g[i] = (f(x + e) - f(x - e)) / (2h)
    end
    return g
end

function fd_hessian(f, x, hw)
    n = length(x)
    H = zeros(n, n)
    for i in 1:n
        h = 1e-3 * hw[i]
        e = zeros(n)
        e[i] = h
        H[:, i] = (fd_gradient(f, x + e, hw) - fd_gradient(f, x - e, hw)) / (2h)
    end
    return (H + H') / 2
end

"""
Newton on ∇f = 0 from `x0` (original coordinates), ForwardDiff or central-difference
derivatives (`ad`), steps clipped to 0.1·halfwidth, at most `maxit` iterations, must
stay within the box enlarged by `margin`. Returns (x, gradnorm, index, converged,
displacement).
"""
function refine_on_f(f, x0, lo, hi; ad = :forwarddiff, maxit = 100, tol = 1e-10, margin = 0.05)
    hw = (hi .- lo) ./ 2
    ad in (:forwarddiff, :finitediff) || error("ad must be :forwarddiff or :finitediff, got $ad")
    g(x) = ad == :forwarddiff ? ForwardDiff.gradient(f, x) : fd_gradient(f, x, hw)
    H(x) = ad == :forwarddiff ? ForwardDiff.hessian(f, x) : fd_hessian(f, x, hw)
    x = copy(x0)
    converged = false
    for _ in 1:maxit
        gx = g(x)
        if norm(gx) < tol
            converged = true
            break
        end
        # a singular (finite-difference) Hessian at an iterate ends the refinement
        # of this point as "not converged"; it is reported per point, not fatal
        dx = try
            H(x) \ gx
        catch e
            e isa LinearAlgebra.SingularException || rethrow()
            break
        end
        cap = 0.1 * norm(hw)
        nd = norm(dx)
        nd > cap && (dx .*= cap / nd)
        x = x - dx
        any(x .< lo .- margin .* hw) || any(x .> hi .+ margin .* hw) && break
    end
    gn = norm(g(x))
    idx = count(<(0), eigvals(Symmetric(H(x))))
    inside = all(lo .<= x .<= hi)
    return (;
        x = x,
        gradnorm = gn,
        index = idx,
        converged = converged && inside,
        displacement = norm(x - x0),
    )
end

# ── one configuration ───────────────────────────────────────────────────────

function run_rational(o::Objective, TR, M, N)
    lo, hi = o.center .- o.range, o.center .+ o.range
    t_fit = @elapsed R = RationalConstructor(TR, M, N)
    # the conversion is repeated inside solve_rational_critical_points; it is
    # timed separately here because it is cheap and the brief asks for the split
    t_convert = @elapsed rational_critical_system(R)
    t_solve = @elapsed res = solve_rational_critical_points(R)
    t_solve -= t_convert
    # second solve of the same system: HC compiles a straight-line program per
    # new System, so the first call is JIT-dominated at these sizes; the warm
    # time is the path-tracking cost
    t_solve_warm = @elapsed solve_rational_critical_points(R)
    t_solve_warm -= t_convert
    stats = res.stats
    t_cert = @elapsed cert = certify_positive_denominator(R)
    t_refine = @elapsed rows = map(zip(res.points, res.values, res.index)) do (x, y, idx)
        xo = to_original_coordinates(R, x)
        r = refine_on_f(o.f, xo, lo, hi; ad = o.ad, tol = max(1e-10, 1e-2 * o.gradtol))
        (;
            x_surrogate = x,
            x_original = xo,
            y = y,
            index_surrogate = idx,
            x_refined = r.x,
            gradnorm = r.gradnorm,
            index_refined = r.index,
            converged = r.converged,
            displacement = r.displacement,
        )
    end
    ph = isempty(rows) ? 0 : sum((-1)^r.index_refined for r in rows if r.converged; init = 0)
    return (;
        kind = "rational",
        label = "($M,$N)",
        M = M,
        N_requested = N,
        N = R.N,
        dof = rational_dof(R),
        GN = R.GN,
        nrm = R.nrm,
        rms = R.rms,
        sigma_ratio = R.sigma_ratio,
        qmin_grid = R.qmin_grid,
        qmin = cert.qmin,
        q_ok = cert.ok,
        n_paths = stats.n_paths,
        n_singular = stats.n_singular,
        n_real = stats.n_real,
        n_points = length(res.points),
        n_outside = res.n_outside,
        n_rejected_q = res.n_rejected_q,
        n_inconsistent_y = res.n_inconsistent_y,
        n_verified = count(r -> r.converged && r.gradnorm < o.gradtol, rows),
        gradtol = o.gradtol,
        ph_sum = ph,
        t_fit = t_fit,
        t_convert = t_convert,
        t_solve = t_solve,
        t_solve_warm = t_solve_warm,
        t_cert = t_cert,
        t_refine = t_refine,
        rows = rows,
        error = "",
    )
end

"""
A cell that raised: every numeric field NaN / -1, no rows, the message in `error`,
so one failing configuration is reported instead of aborting the audit.
"""
function failed_cell(kind, label, M, N, msg)
    return (;
        kind = kind, label = label, M = M, N_requested = N, N = -1, dof = -1, GN = -1,
        nrm = NaN, rms = NaN, sigma_ratio = NaN, qmin_grid = NaN, qmin = NaN, q_ok = false,
        n_paths = -1, n_singular = -1, n_real = -1, n_points = -1, n_outside = -1,
        n_rejected_q = -1, n_inconsistent_y = -1, n_verified = -1, gradtol = NaN, ph_sum = 0,
        t_fit = NaN, t_convert = NaN, t_solve = NaN, t_solve_warm = NaN, t_cert = NaN, t_refine = NaN,
        rows = NamedTuple[], error = msg,
    )
end

function run_polynomial(o::Objective, TR, D)
    lo, hi = o.center .- o.range, o.center .+ o.range
    n = o.dim
    t_fit = @elapsed pol = Constructor(TR, D)
    x, _ = Globtim._rational_polyvars(n)
    stats_ref = Ref{Any}(nothing)
    t_solve = @elapsed raw = solve_polynomial_system(
        x,
        n,
        D,
        pol.coeffs;
        basis = pol.basis,
        normalized = pol.normalized,
        path_stats_ref = stats_ref,
    )
    st = stats_ref[]
    t_solve_warm = @elapsed solve_polynomial_system(
        x,
        n,
        D,
        pol.coeffs;
        basis = pol.basis,
        normalized = pol.normalized,
    )
    pts = [Vector{Float64}(real.(s)) for s in raw if all(-1 .<= real.(s) .<= 1)]
    t_refine = @elapsed rows = map(pts) do xs
        xo = to_original_coordinates(xs, TR.sample_range, TR.center)
        r = refine_on_f(o.f, xo, lo, hi; ad = o.ad, tol = max(1e-10, 1e-2 * o.gradtol))
        (;
            x_surrogate = xs,
            x_original = xo,
            y = Globtim.evaluate(pol, xo),
            index_surrogate = count(<(0), eigvals(Symmetric(ForwardDiff.hessian(u -> Globtim.evaluate(pol, u), xo)))),
            x_refined = r.x,
            gradnorm = r.gradnorm,
            index_refined = r.index,
            converged = r.converged,
            displacement = r.displacement,
        )
    end
    ph = isempty(rows) ? 0 : sum((-1)^r.index_refined for r in rows if r.converged; init = 0)
    return (;
        kind = "polynomial",
        label = "D=$D",
        M = D,
        N_requested = 0,
        N = 0,
        dof = binomial(n + D, D),
        GN = TR.GN,
        nrm = pol.nrm,
        rms = sqrt(sum(abs2, Globtim.evaluate(pol, pol.grid .* (TR.sample_range isa Number ? TR.sample_range : TR.sample_range') .+ TR.center') .- pol.z) / length(pol.z)),
        sigma_ratio = NaN,
        qmin_grid = NaN,
        qmin = NaN,
        q_ok = true,
        n_paths = st === nothing ? -1 : st.paths_tracked,
        n_singular = st === nothing ? -1 : st.n_singular,
        n_real = length(raw),
        n_points = length(pts),
        n_outside = length(raw) - length(pts),
        n_rejected_q = 0,
        n_inconsistent_y = 0,
        n_verified = count(r -> r.converged && r.gradnorm < o.gradtol, rows),
        gradtol = o.gradtol,
        ph_sum = ph,
        t_fit = t_fit,
        t_convert = 0.0,
        t_solve = t_solve,
        t_solve_warm = t_solve_warm,
        t_cert = 0.0,
        t_refine = t_refine,
        rows = rows,
        error = "",
    )
end

# ── gate ────────────────────────────────────────────────────────────────────

function dedup(points; tol = 1e-6)
    out = Vector{Vector{Float64}}()
    for p in points
        any(norm(p - q) < tol for q in out) || push!(out, p)
    end
    return out
end

# distinct verified critical points (refined to |∇f| < gradtol inside the box)
refined_set(c) = dedup([r.x_refined for r in c.rows if r.converged && r.gradnorm < c.gradtol])

function match_counts(A, B; tol = 1e-3)
    a_in_b = count(a -> any(norm(a - b) < tol for b in B), A)
    b_in_a = count(b -> any(norm(a - b) < tol for a in A), B)
    return (; a_in_b = a_in_b, b_in_a = b_in_a)
end

"""
Gate of brief §3. `dof_frac = 0.5` is the official gate (R* restricted to
dof ≤ ½ dof(P*)); `dof_frac = Inf` is the informational unconstrained comparison
(best rational configuration of any size against the best polynomial).
"""
function gate_verdict(cells; dof_frac = 0.5)
    polys = [c for c in cells if c.kind == "polynomial" && isfinite(c.nrm)]
    rats = [c for c in cells if c.kind == "rational" && isfinite(c.nrm)]
    (isempty(polys) || isempty(rats)) && return (; evaluated = false, pass = false, checks = [], Pstar = nothing, Rstar = nothing)
    Pstar = polys[argmin([c.nrm for c in polys])]
    cands = [c for c in rats if c.dof <= Pstar.dof * dof_frac]
    if isempty(cands)
        return (; evaluated = false, pass = false, checks = [("no rational configuration at ≤ $(dof_frac)·dof($(Pstar.label)) = $(floor(Int, Pstar.dof * dof_frac))", false, "")], Pstar = Pstar, Rstar = nothing)
    end
    Rstar = cands[argmin([c.nrm for c in cands])]
    SR = refined_set(Rstar)
    SP = refined_set(Pstar)
    m = match_counts(SR, SP)
    checks = Tuple{String,Bool,String}[]
    push!(checks, ("1. nrm(R*) ≤ nrm(P*)", Rstar.nrm <= Pstar.nrm, @sprintf("%.3e vs %.3e", Rstar.nrm, Pstar.nrm)))
    # every rational point is a true critical point, and nothing the polynomial
    # verifies is missed by the rational; polynomial-only points that do NOT
    # refine are the polynomial's spurious points and are reported, not penalised
    all_ver = Rstar.n_points == Rstar.n_verified
    nothing_missed = m.b_in_a == length(SP)
    push!(checks, ("2. all R* points refine to |∇f|<$(Rstar.gradtol), and every distinct verified P* point is matched by R* within 1e-3", all_ver && nothing_missed,
        "rational $(Rstar.n_points) pts / $(Rstar.n_verified) verified / $(length(SR)) distinct; polynomial $(Pstar.n_points) pts / $(Pstar.n_verified) verified / $(length(SP)) distinct ($(Pstar.n_points - Pstar.n_verified) spurious); matched $(m.b_in_a) of $(length(SP)) polynomial and $(m.a_in_b) of $(length(SR)) rational"))
    push!(checks, ("3. certify_positive_denominator(R*).ok", Rstar.q_ok, @sprintf("qmin = %.4f", Rstar.qmin)))
    # evaluated on the WARM (second-solve) times: the first solve of a new HC
    # System is dominated by compiling its straight-line program at these sizes
    push!(checks, ("4. HC wall lifted(R*) ≤ polynomial(P*) (warm; cold in parentheses)", Rstar.t_solve_warm <= Pstar.t_solve_warm,
        @sprintf("%.2fs vs %.2fs (cold %.2fs vs %.2fs)", Rstar.t_solve_warm, Pstar.t_solve_warm, Rstar.t_solve, Pstar.t_solve)))
    return (; evaluated = true, pass = all(c[2] for c in checks), checks = checks, Pstar = Pstar, Rstar = Rstar)
end

# ── reporting ───────────────────────────────────────────────────────────────

function cell_table(io, cells)
    println(io, "| config | dof | N | nrm | σmin/σmax | qmin (cert) | paths | sing | pts | verified | PH | t_fit | t_conv | t_HC cold | t_HC warm | t_refine |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for c in cells
        if !isempty(c.error)
            println(io, "| ", c.label, " | – | – | FAILED: ", replace(first(c.error, 160), "|" => "/"), " | | | | | | | | | | | | |")
            continue
        end
        @printf(io, "| %s | %d | %d | %.2e | %s | %s | %d | %d | %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f |\n",
            c.label, c.dof, c.N, c.nrm,
            isnan(c.sigma_ratio) ? "–" : @sprintf("%.1e", c.sigma_ratio),
            isnan(c.qmin) ? "–" : @sprintf("%.2e%s", c.qmin, c.q_ok ? "" : " ✗"),
            c.n_paths, c.n_singular, c.n_points, c.n_verified, c.ph_sum,
            c.t_fit, c.t_convert, c.t_solve, c.t_solve_warm, c.t_refine)
    end
end

function write_summary(path, cfg, results, verdicts, verdicts_unconstrained, elapsed; objectives = OBJECTIVES)
    open(path, "w") do io
        println(io, "# Rational surrogates, Phase 1 audit\n")
        println(io, "Generated ", now(), " by pkg/globtim/scripts/audit_rational_phase1.jl",
            cfg["smoke"] ? " (SMOKE)" : "", "; GN = ", cfg["gn"], "; elapsed ", @sprintf("%.0f", elapsed), " s.\n")
        println(io, "Brief: docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md. nrm is the quadrature-weighted L2 norm ",
            "of the residual on [-1,1]^n for both surrogate kinds (nonlinear residual p/q − f for the rational). ",
            "\"verified\" = refined on f by Newton to |∇f| < gradtol inside the box (gradtol = 1e-6 for closed-form ",
            "objectives with ForwardDiff derivatives; per-objective for finite-difference ones, stated in the objective's section). ",
            "PH = Σ(−1)^index over verified points.\n")
        for key in cfg["objectives"]
            o = objectives[key]
            cells = results[key]
            v = verdicts[key]
            println(io, "## ", key, ". ", o.name, "\n")
            println(io, "dim ", o.dim, ", center ", o.center, ", half-width ", o.range,
                "; refinement derivatives: ", o.ad, ", verified at |∇f| < ", o.gradtol, ".\n")
            cell_table(io, cells)
            println(io)
            if v.evaluated
                println(io, "Gate: P* = ", v.Pstar.label, " (dof ", v.Pstar.dof, "), R* = ", v.Rstar.label,
                    " (dof ", v.Rstar.dof, ", post-reduction N = ", v.Rstar.N, ") → **", v.pass ? "PASS" : "FAIL", "**\n")
            else
                println(io, "Gate: not evaluated\n")
            end
            for (name, ok, detail) in v.checks
                println(io, "- [", ok ? "PASS" : "FAIL", "] ", name, " — ", detail)
            end
            println(io)
            vu = verdicts_unconstrained[key]
            if vu.evaluated
                println(io, "Unconstrained comparison (informational, any dof): R* = ", vu.Rstar.label,
                    " (dof ", vu.Rstar.dof, ") vs P* = ", vu.Pstar.label, " (dof ", vu.Pstar.dof, ") → ", vu.pass ? "PASS" : "FAIL", "\n")
                for (name, ok, detail) in vu.checks
                    println(io, "- [", ok ? "PASS" : "FAIL", "] ", name, " — ", detail)
                end
                println(io)
            end
            if haskey(results, key * "_extended")
                println(io, "Extended rational sweep (GN = ", cfg["gn_extended"], "):\n")
                cell_table(io, results[key*"_extended"])
                println(io)
            end
            r84 = findfirst(c -> c.kind == "rational" && c.label == "(8,4)", cells)
            if r84 !== nothing
                c = cells[r84]
                @printf(io, "Wall-time split at (8,4): fit %.2f s, convert %.2f s, HC %.2f s cold / %.2f s warm, certificate %.2f s, refine %.2f s.\n\n",
                    c.t_fit, c.t_convert, c.t_solve, c.t_solve_warm, c.t_cert, c.t_refine)
            end
            println(io, "Refined critical points of R* and P* (original coordinates):\n")
            for c in (v.evaluated ? (v.Rstar, v.Pstar) : ())
                println(io, "- ", c.label, ":")
                for r in c.rows
                    @printf(io, "  - x = %s, index %d, |∇f| = %.1e, moved %.1e%s\n",
                        "[" * join((@sprintf("%.6f", t) for t in r.x_refined), ", ") * "]",
                        r.index_refined, r.gradnorm, r.displacement, r.converged ? "" : " (NOT converged)")
                end
            end
            println(io)
        end
        println(io, "## Verdict\n")
        for key in cfg["objectives"]
            v = verdicts[key]
            println(io, "- ", key, ": ", v.evaluated ? (v.pass ? "PASS" : "FAIL") : "not evaluated")
        end
    end
    return path
end

# ── main ────────────────────────────────────────────────────────────────────

"""
    main(argv; objectives, root, slug, extended_keys, brief) -> Bool

Run the audit over `objectives` (a `Dict{String,Objective}`; the default table is
the brief's A–D). A campaign script `include`s this file and calls `main` with its
own table, results root under `globtim_results/`, ledger slug and the keys that get
the extended (M,N) sweep.
"""
function main(
    argv;
    objectives = OBJECTIVES,
    root = "rational_phase1",
    slug = "rational_phase1_audit",
    extended_keys = ["B"],
    brief = "docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md",
)
    cfg = parse_args(argv; root = root, default_objectives = sort(collect(keys(objectives))))
    outdir = normpath(cfg["outdir"])
    mkpath(outdir)
    t0 = time()
    println("output: ", outdir)

    # Warm-up: compile every code path once on a tiny configuration so the wall
    # times below (gate check 4) measure the solves, not first-call compilation.
    let o = objectives[first(cfg["objectives"])]
        TRw = TestInput(o.f; dim = o.dim, center = o.center, sample_range = o.range, GN = 8)
        t_w = @elapsed begin
            run_rational(o, TRw, 3, 2)
            run_polynomial(o, TRw, 4)
        end
        @printf("warm-up (compilation): %.1f s\n", t_w)
    end

    results = Dict{String,Vector{NamedTuple}}()
    verdicts = Dict{String,Any}()
    verdicts_unconstrained = Dict{String,Any}()
    for key in cfg["objectives"]
        o = objectives[key]
        println("\n== ", key, ". ", o.name)
        TR = TestInput(o.f; dim = o.dim, center = o.center, sample_range = o.range, GN = cfg["gn"])
        cells = NamedTuple[]
        for (M, N) in cfg["rational"]
            @printf("  rational (%2d,%2d) ... ", M, N)
            c = try
                run_rational(o, TR, M, N)
            catch e
                failed_cell("rational", "($M,$N)", M, N, sprint(showerror, e))
            end
            push!(cells, c)
            if isempty(c.error)
                @printf("N→%d nrm=%.2e σ=%.1e qmin=%.3f%s pts=%d/%d PH=%d HC=%.2fs\n",
                    c.N, c.nrm, c.sigma_ratio, c.qmin, c.q_ok ? "" : "(neg)", c.n_verified, c.n_points, c.ph_sum, c.t_solve)
            else
                println("FAILED: ", first(c.error, 200))
            end
        end
        for D in cfg["polynomial"]
            @printf("  polynomial D=%2d  ... ", D)
            c = try
                run_polynomial(o, TR, D)
            catch e
                failed_cell("polynomial", "D=$D", D, 0, sprint(showerror, e))
            end
            push!(cells, c)
            if isempty(c.error)
                @printf("nrm=%.2e pts=%d/%d PH=%d HC=%.2fs\n", c.nrm, c.n_verified, c.n_points, c.ph_sum, c.t_solve)
            else
                println("FAILED: ", first(c.error, 200))
            end
        end
        results[key] = cells
        v = gate_verdict(cells)
        verdicts[key] = v
        println("  gate: ", v.evaluated ? (v.pass ? "PASS" : "FAIL") : "not evaluated")
        for (name, ok, detail) in v.checks
            println("    [", ok ? "PASS" : "FAIL", "] ", name, "  (", detail, ")")
        end
        vu = gate_verdict(cells; dof_frac = Inf)
        verdicts_unconstrained[key] = vu
        if vu.evaluated
            println("  unconstrained (informational): R* = ", vu.Rstar.label, " vs P* = ", vu.Pstar.label, " → ", vu.pass ? "PASS" : "FAIL")
        end
        # Objective B is a genuine rational function of type (24,24) (two atoms,
        # (d²+δ)^6 each), beyond the (12,6) sweep: extend the search for the
        # σ-collapse of W on a grid large enough to determine degree 24.
        if key in extended_keys
            TRx = TestInput(o.f; dim = o.dim, center = o.center, sample_range = o.range, GN = cfg["gn_extended"])
            ext = NamedTuple[]
            for (M, N) in cfg["rational_extended"]
                @printf("  extended rational (%2d,%2d) GN=%d ... ", M, N, cfg["gn_extended"])
                c = try
                    run_rational(o, TRx, M, N)
                catch e
                    failed_cell("rational", "($M,$N)", M, N, sprint(showerror, e))
                end
                push!(ext, c)
                if isempty(c.error)
                    @printf("N→%d nrm=%.2e σ=%.1e qmin=%.3f%s pts=%d/%d PH=%d HC=%.2fs\n",
                        c.N, c.nrm, c.sigma_ratio, c.qmin, c.q_ok ? "" : "(neg)", c.n_verified, c.n_points, c.ph_sum, c.t_solve)
                else
                    println("FAILED: ", first(c.error, 200))
                end
            end
            results[key*"_extended"] = ext
        end
    end
    elapsed = time() - t0

    # ── artifacts ─────────────────────────────────────────────────────────
    table = DataFrame()
    cps = DataFrame()
    for key in sort(collect(keys(results))), c in results[key]
        push!(table, (; objective = key, kind = c.kind, config = c.label, M = c.M, N_requested = c.N_requested, N = c.N,
            dof = c.dof, GN = c.GN, nrm = c.nrm, rms = c.rms, sigma_ratio = c.sigma_ratio, qmin_grid = c.qmin_grid,
            qmin = c.qmin, q_ok = c.q_ok, n_paths = c.n_paths, n_singular = c.n_singular, n_real = c.n_real,
            n_points = c.n_points, n_outside = c.n_outside, n_rejected_q = c.n_rejected_q,
            n_inconsistent_y = c.n_inconsistent_y, n_verified = c.n_verified, ph_sum = c.ph_sum,
            t_fit = c.t_fit, t_convert = c.t_convert, t_solve = c.t_solve, t_solve_warm = c.t_solve_warm,
            t_cert = c.t_cert, t_refine = c.t_refine, error = c.error); promote = true)
        for (k, r) in enumerate(c.rows)
            push!(cps, (; objective = key, kind = c.kind, config = c.label, point = k,
                x_surrogate = join(string.(r.x_surrogate), ";"), x_original = join(string.(r.x_original), ";"),
                x_refined = join(string.(r.x_refined), ";"), y = r.y, index_surrogate = r.index_surrogate,
                index_refined = r.index_refined, gradnorm = r.gradnorm, displacement = r.displacement,
                converged = r.converged); promote = true)
        end
    end
    CSV.write(joinpath(outdir, "audit_table.csv"), table)
    CSV.write(joinpath(outdir, "critical_points.csv"), cps)

    JLD2.jldsave(joinpath(outdir, "audit_full.jld2");
        config = Dict(k => (v isa Vector{Tuple{Int,Int}} ? [collect(t) for t in v] : v) for (k, v) in cfg),
        results = Dict(k => [Dict(String(f) => (f == :rows ? [Dict(String(g) => getfield(r, g) for g in keys(r)) for r in c.rows] : getfield(c, f)) for f in keys(c)) for c in v] for (k, v) in results),
        verdicts = Dict(k => Dict("evaluated" => v.evaluated, "pass" => v.pass,
            "checks" => [Dict("name" => n, "pass" => p, "detail" => d) for (n, p, d) in v.checks],
            "Pstar" => v.Pstar === nothing ? nothing : v.Pstar.label,
            "Rstar" => v.Rstar === nothing ? nothing : v.Rstar.label) for (k, v) in verdicts),
        verdicts_unconstrained = Dict(k => Dict("evaluated" => v.evaluated, "pass" => v.pass,
            "checks" => [Dict("name" => n, "pass" => p, "detail" => d) for (n, p, d) in v.checks],
            "Pstar" => v.Pstar === nothing ? nothing : v.Pstar.label,
            "Rstar" => v.Rstar === nothing ? nothing : v.Rstar.label) for (k, v) in verdicts_unconstrained),
        elapsed_seconds = elapsed,
        user_metadata = Dict{String,Any}(
            "package" => "Globtim", "script" => "pkg/globtim/scripts/audit_rational_phase1.jl",
            "brief" => brief, "bead" => "B3",
            "objectives" => Dict(k => Dict("name" => o.name, "dim" => o.dim, "center" => o.center, "range" => o.range) for (k, o) in objectives if k in cfg["objectives"]),
            "gn" => cfg["gn"], "basis" => "chebyshev", "solver" => "hc (lifted, polyhedral) / hc (polynomial, :auto)",
            "refinement" => "Newton on ∇f with ForwardDiff, |∇f| < 1e-6 verified, box + 5% margin",
            "smoke" => cfg["smoke"],
        ))
    summary_path = write_summary(joinpath(outdir, "summary.md"), cfg, results, verdicts, verdicts_unconstrained, elapsed; objectives = objectives)

    if cfg["ledger"]
        headline = Dict{String,Any}(
            "objectives" => join(cfg["objectives"], ","),
            "gn" => cfg["gn"],
            "n_cells" => sum(length(v) for v in values(results)),
        )
        for key in cfg["objectives"]
            v = verdicts[key]
            headline["gate_$key"] = v.evaluated ? (v.pass ? "pass" : "fail") : "not_evaluated"
            if v.evaluated
                headline["Rstar_$key"] = v.Rstar.label
                headline["Pstar_$key"] = v.Pstar.label
                headline["nrm_Rstar_$key"] = v.Rstar.nrm
                headline["nrm_Pstar_$key"] = v.Pstar.nrm
                headline["n_points_Rstar_$key"] = v.Rstar.n_points
                headline["n_points_Pstar_$key"] = v.Pstar.n_points
            end
        end
        all_pass = all(verdicts[k].evaluated && verdicts[k].pass for k in cfg["objectives"])
        try
            rec = Globtim.emit_ledger_record(;
                slug = slug * (cfg["smoke"] ? "_smoke" : ""),
                outdir = outdir, headline = headline,
                artifacts = ["audit_table.csv", "critical_points.csv", "audit_full.jld2", "summary.md"],
                supersedes = cfg["supersedes"],
                status = all_pass ? "completed" : "completed_gate_failed")
            println("ledger record: ", rec)
        catch e
            @warn "ledger record emission failed (results are still written)" exception = e
        end
    end

    @printf("\n%.0f s; wrote %s\n", elapsed, summary_path)
    for key in cfg["objectives"]
        v = verdicts[key]
        println("  ", key, ": ", v.evaluated ? (v.pass ? "PASS" : "FAIL") : "not evaluated")
    end
    return all(verdicts[k].evaluated && verdicts[k].pass for k in cfg["objectives"])
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = main(ARGS)
    # the gate verdict is a result (summary.md, ledger status), not a job
    # failure: a completed run exits 0 so Slurm does not report it as FAILED
    println("gate verdict over all objectives: ", ok ? "PASS" : "FAIL")
    exit(0)
end
