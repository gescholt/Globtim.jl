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
# dimension). Every in-box surrogate critical point is refined on the TRUE
# objective by Newton ("standard refinement", `refine_on_f`) and classified by
# the Hessian index of f at the refined point.
#
# Census (`census`, the measure of a configuration): the verified rows are
# deduplicated into DISTINCT critical points of f (max-norm in box units, 1e-3);
# a distinct point is a TIGHT capture when some candidate reaching it started
# within 0.05 of it in box units, otherwise Newton on f carried a distant
# candidate there (transported). Every candidate that is not the tight seed of
# its own distinct point is spurious. PH = Σ(−1)^index over distinct points.
# With `truth = :multistart` an independent critical set of f is computed by
# Newton from a lattice of starts, and the census reports recall against it.
# A rational fit whose denominator is not certified positive on the box is
# INADMISSIBLE (pkg/globtim/docs/rational_surrogates.md): its census is
# reported and flagged, never selected by the gate.
#
# Sampling arms (--sampling grid,christoffel:<s> --replicates <r>): besides the
# grid, every configuration can be fitted on ⌈s · #unknowns⌉ Christoffel samples
# (RationalConstructor(...; sampling = :christoffel); the polynomial control
# uses the same sampler), one arm per seed 1..r. Each arm records its objective
# evaluations and its residual on the grid (--no-validate skips that for
# expensive objectives); the gate ranks grid fits only.
#
# Gate (brief §3), per objective, with P* the best-nrm polynomial degree and R*
# the best-nrm CERTIFIED rational configuration with dof ≤ dof(P*)/2:
#   1. nrm(R*) ≤ nrm(P*);
#   2. the R* census is clean (no spurious candidate; with a truth set, every
#      truth point tightly captured) and covers every distinct P* point;
#   3. a certified rational configuration exists at dof ≤ dof(P*)/2;
#   4. lifted HC wall time at R* ≤ polynomial HC wall time at P* (warm).
#
# Outputs (one timestamped directory): critical_points.csv, audit_table.csv,
# truth.csv (the multistart truth sets), summary.md, and a ledger record
# (Globtim.emit_ledger_record, carrying the bead given by the driver or --bead;
# --no-ledger to skip). audit_full.jld2 (everything, with user_metadata) is also
# written but is not a ledger artifact: globtim_results/.gitignore keeps it out
# of git (228 MB across the first 29 runs), so it stays on the machine that ran.
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
using Random: Xoshiro
using Statistics: median
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
    Objective(key, name, f, dim, center, range; ad = :forwarddiff, gradtol, truth = :none, truth_starts = 0)

An objective for the audit. `range` is the half-width (scalar or per-coordinate
vector). `ad` selects the derivatives used by the refinement on f: `:forwarddiff`
for closed-form objectives, `:finitediff` (central differences) for objectives that
do not accept dual numbers (ODE shooting).

`gradtol` is the |∇f| the Newton refinement must REACH inside the box for a point
to count as verified — the threshold applied, not a looser reporting one. Default
1e-8 with ForwardDiff (the census standard); 1e-6 with central differences, where
difference noise on an ODE objective sets the floor.

`truth = :multistart` computes an independent critical set of f on the box
(`truth_by_multistart`, Newton from a `truth_starts`^dim lattice), against which
every census reports recall; `:none` for objectives too expensive to scan.
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
    truth::Symbol
    truth_starts::Int
end
function Objective(
    key,
    name,
    f,
    dim,
    center,
    range;
    ad::Symbol = :forwarddiff,
    gradtol::Real = (ad == :forwarddiff ? 1e-8 : 1e-6),
    truth::Symbol = :none,
    truth_starts::Integer = 0,
)
    ad in (:forwarddiff, :finitediff) || error("$key: ad must be :forwarddiff or :finitediff, got $ad")
    truth in (:none, :multistart) || error("$key: truth must be :none or :multistart, got $truth")
    truth == :multistart && truth_starts < 2 &&
        error("$key: truth = :multistart needs truth_starts ≥ 2 starts per dimension")
    return Objective(key, name, f, dim, Vector{Float64}(center), range, ad, Float64(gradtol), truth, Int(truth_starts))
end

box(o::Objective) = (o.center .- o.range, o.center .+ o.range)

const OBJECTIVES = Dict(
    "A" => Objective("A", "pole pair 2-D", f_pole, 2, [0.0, 0.0], 1.0; truth = :multistart, truth_starts = 61),
    "B" => Objective("B", "Lennard-Jones slice 2-D", f_lj, 2, [0.0, 0.0], 1.0; truth = :multistart, truth_starts = 61),
    "C" => Objective("C", "Margules TPD 1-D (logit chart)", f_margules, 1, [0.0], 5.0; truth = :multistart, truth_starts = 401),
    # The same TPD in the MOLE-FRACTION chart y₁ ∈ [0.01, 0.99]: the y ln y edge
    # singularities sit just outside the box, so polynomial coefficients decay
    # only algebraically — the case the brief's objective C is meant to decide
    # (pkg/ThermoObjectives, which has the Clapeyron models, is not in profiles/dev).
    "D" => Objective("D", "Margules TPD 1-D (mole-fraction chart)", f_margules_y, 1, [0.5], 0.49; truth = :multistart, truth_starts = 401),
)

# ── CLI ─────────────────────────────────────────────────────────────────────

# "grid" or "christoffel:<samples per unknown>"
function parse_sampling_spec(s)
    s == "grid" && return (; sampling = :grid, per_dof = NaN)
    parts = split(s, ":")
    (length(parts) == 2 && parts[1] == "christoffel") ||
        error("sampling spec must be grid or christoffel:<samples per unknown>, got $s")
    per_dof = parse(Float64, parts[2])
    per_dof >= 1 || error("christoffel:$per_dof: at least one sample per unknown is needed")
    return (; sampling = :christoffel, per_dof = per_dof)
end

# every fitting arm of a configuration: the grid once, each Christoffel spec once per replicate seed
const GRID_ARM = (; sampling = :grid, per_dof = NaN, seed = -1)
function sampling_arms(cfg)
    arms = NamedTuple[]
    for spec in cfg["sampling"]
        if spec.sampling == :grid
            push!(arms, GRID_ARM)
        else
            append!(arms, [(; sampling = spec.sampling, per_dof = spec.per_dof, seed = r) for r in 1:cfg["replicates"]])
        end
    end
    return arms
end
arm_tag(arm) = arm.sampling == :grid ? "" : @sprintf(" %gm #%d", arm.per_dof, arm.seed)

function parse_args(argv; root = "rational_phase1", default_objectives = ["A", "B", "C", "D"],
    bead = "globopt_merged-8f4p.7")
    cfg = Dict{String,Any}(
        "objectives" => default_objectives,
        # the ledger record's issue_id: the driver's bead, or --bead for a run
        # that belongs to another one
        "bead" => bead,
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
        # census, both in box units (max-norm of (x − c) ./ hw)
        "dedup_tol" => 1e-3,        # verified rows closer than this are one critical point
        "capture_radius" => 0.05,   # a candidate this close to its point captured it
        # how each configuration is fitted: the tensor grid, and/or Christoffel
        # samples at `per_dof` samples per unknown (one arm per replicate seed)
        "sampling" => [(; sampling = :grid, per_dof = NaN)],
        "replicates" => 1,
        # residual of every sampled fit on the grid (costs (gn+1)^n evaluations of f
        # per objective; --no-validate for expensive objectives)
        "validate" => true,
        # re-solve every system for the warm HC time of gate check 4; a sampling
        # campaign whose solves dominate the wall time can skip it (--no-warm)
        "warm" => true,
        # lattice points per face coordinate of the denominator certificate
        # (certify_positive_denominator); nothing = face_samples_for(dim)
        "face_samples" => nothing,
        # how the rational is fitted: "lin" (RationalConstructor's linearised LS) and/or
        # "lm" (rational_lm_refit on the same points), one cell per fit
        "rational_fit" => ["lin"],
        # drop rational candidates with q(x) < qfilter · median(q at the fit points)
        # before refinement (0 = keep all); n_qfiltered counts the dropped
        "qfilter" => 0.0,
        # HC start system of the polynomial arms: :auto (polyhedral for n ≥ 3) or
        # :total_degree — the polyhedral mixed-cell computation overflows at n = 12, degree 4
        "start_system" => :auto,
        # HC start system of the lifted rational solve (solve_rational_critical_points):
        # :polyhedral (its default) or :total_degree — the mixed cells overflow at n = 12
        "rational_start_system" => :polyhedral,
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
        elseif a == "--bead"                # e.g. --bead globopt_merged-8f4p.7.9
            cfg["bead"] = argv[i+1]
            i += 1
        elseif a == "--rational"            # e.g. --rational 12:7,14:6,20:10
            cfg["rational"] = [(parse(Int, split(s, ":")[1]), parse(Int, split(s, ":")[2])) for s in split(argv[i+1], ",")]
            i += 1
        elseif a == "--polynomial"          # e.g. --polynomial 20,24
            # "none": rational arms only
            cfg["polynomial"] = argv[i+1] == "none" ? Int[] : parse.(Int, split(argv[i+1], ","))
            i += 1
        elseif a == "--dedup-tol"
            cfg["dedup_tol"] = parse(Float64, argv[i+1])
            i += 1
        elseif a == "--capture-radius"
            cfg["capture_radius"] = parse(Float64, argv[i+1])
            i += 1
        elseif a == "--sampling"            # e.g. --sampling grid,christoffel:3,christoffel:6
            cfg["sampling"] = [parse_sampling_spec(s) for s in split(argv[i+1], ",")]
            i += 1
        elseif a == "--replicates"
            cfg["replicates"] = parse(Int, argv[i+1])
            cfg["replicates"] >= 1 || error("--replicates must be ≥ 1")
            i += 1
        elseif a == "--no-warm"
            cfg["warm"] = false
        elseif a == "--no-validate"
            cfg["validate"] = false
        elseif a == "--rational-start-system"   # polyhedral | total_degree
            cfg["rational_start_system"] = Symbol(argv[i+1])
            cfg["rational_start_system"] in (:polyhedral, :total_degree) ||
                error("--rational-start-system takes polyhedral or total_degree")
            i += 1
        elseif a == "--start-system"        # auto | polyhedral | total_degree
            cfg["start_system"] = Symbol(argv[i+1])
            cfg["start_system"] in (:auto, :polyhedral, :total_degree) ||
                error("--start-system takes auto, polyhedral or total_degree")
            i += 1
        elseif a == "--rational-fit"        # e.g. --rational-fit lin,lm
            cfg["rational_fit"] = String.(split(argv[i+1], ","))
            all(in(("lin", "lm", "pts")), cfg["rational_fit"]) || error("--rational-fit takes lin, lm and/or pts")
            i += 1
        elseif a == "--qfilter"             # e.g. --qfilter 0.1
            cfg["qfilter"] = parse(Float64, argv[i+1])
            cfg["qfilter"] >= 0 || error("--qfilter must be ≥ 0")
            i += 1
        elseif a == "--face-samples"        # e.g. --face-samples 11
            cfg["face_samples"] = parse(Int, argv[i+1])
            i += 1
        else
            error("unknown argument $a")
        end
        i += 1
    end
    if cfg["outdir"] === nothing
        stamp = Dates.format(now(), "yyyymmddTHHMMSS")
        # two jobs started in the same second must not share a directory (korok
        # 1035874/1035875 did, and one overwrote the other's artifacts)
        suffix = haskey(ENV, "SLURM_JOB_ID") ? "_job" * ENV["SLURM_JOB_ID"] : "_pid" * string(getpid())
        cfg["outdir"] = joinpath(
            "globtim_results",
            root,
            stamp * suffix * (cfg["smoke"] ? "_smoke" : ""),
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

# F(x), or `nothing` when F throws a DomainError there (a chart coordinate outside
# its domain, e.g. the log of a negative mole fraction one Newton step past a face)
function _eval_or_nothing(F, x)
    try
        return F(x)
    catch e
        e isa DomainError || rethrow()
        return nothing
    end
end

"""
    refine_on_f(f, x0, lo, hi; ad, tol, maxit = 100, margin = 0.05)

Newton on ∇f = 0 from `x0` (original coordinates) with ForwardDiff (`ad =
:forwarddiff`) or central-difference (`:finitediff`) derivatives, each step clipped
to 0.1 of the half-width in every coordinate. The iteration ends with `status`

- `:converged` — |∇f| < `tol` at an iterate;
- `:left_box`  — an iterate left the box enlarged by `margin` (f is not evaluated there);
- `:domain` / `:nonfinite` — f threw a DomainError, or f or a derivative was
  non-finite (a failed ODE solve returns Inf, whose ForwardDiff gradient is 0);
- `:singular`  — the Hessian was exactly singular;
- `:maxit`     — `maxit` steps without reaching `tol`.

`converged` is `status == :converged` with the final point inside the closed box:
only such points are verified critical points of f. Also returned, at the final
point: the Morse index and the smallest |eigenvalue| of the Hessian, `newton_step`
(max-norm in box units of H⁻¹∇f, the location error of the point), and the
displacement from `x0`, Euclidean in original coordinates (`displacement`) and
max-norm in box units (`disp_norm`).
"""
function refine_on_f(f, x0, lo, hi; ad::Symbol, tol::Real, maxit::Int = 100, margin::Real = 0.05)
    hw = (hi .- lo) ./ 2
    ad in (:forwarddiff, :finitediff) || error("ad must be :forwarddiff or :finitediff, got $ad")
    g(x) = ad == :forwarddiff ? ForwardDiff.gradient(f, x) : fd_gradient(f, x, hw)
    H(x) = ad == :forwarddiff ? ForwardDiff.hessian(f, x) : fd_hessian(f, x, hw)
    outside_margin(x) = any(x .< lo .- margin .* hw) || any(x .> hi .+ margin .* hw)
    x = Vector{Float64}(x0)
    status = :maxit
    for _ in 1:maxit
        fx = _eval_or_nothing(f, x)
        gx = fx === nothing ? nothing : _eval_or_nothing(g, x)
        if gx === nothing
            status = :domain
            break
        end
        if !(isfinite(fx) && all(isfinite, gx))
            status = :nonfinite
            break
        end
        if norm(gx) < tol
            status = :converged
            break
        end
        Hx = _eval_or_nothing(H, x)
        if Hx === nothing
            status = :domain
            break
        end
        if !all(isfinite, Hx)
            status = :nonfinite
            break
        end
        dx = try
            Hx \ gx
        catch e
            e isa LinearAlgebra.SingularException || rethrow()
            status = :singular
            break
        end
        s = maximum(abs.(dx ./ hw))
        s > 0.1 && (dx .*= 0.1 / s)
        x = x - dx
        if outside_margin(x)
            status = :left_box
            break
        end
    end
    inside = all(lo .<= x .<= hi)
    disp = norm(x .- x0)
    disp_norm = maximum(abs.((x .- x0) ./ hw))
    # f is not evaluated where the iteration left the margin or failed to evaluate
    gx = status in (:left_box, :domain, :nonfinite) ? nothing : _eval_or_nothing(g, x)
    Hx = gx === nothing ? nothing : _eval_or_nothing(H, x)
    if gx === nothing || Hx === nothing || !all(isfinite, gx) || !all(isfinite, Hx)
        return (; x = x, status = status, converged = false, inside = inside, gradnorm = NaN, index = -1,
            min_abs_eig = NaN, newton_step = NaN, displacement = disp, disp_norm = disp_norm)
    end
    ev = eigvals(Symmetric(Hx))
    step = try
        maximum(abs.((Hx \ gx) ./ hw))
    catch e
        e isa LinearAlgebra.SingularException || rethrow()
        Inf
    end
    return (;
        x = x,
        status = status,
        converged = status == :converged && inside,
        inside = inside,
        gradnorm = norm(gx),
        index = count(<(0), ev),
        min_abs_eig = minimum(abs, ev),
        newton_step = step,
        displacement = disp,
        disp_norm = disp_norm,
    )
end

"""
    truth_by_multistart(o::Objective; dedup_tol = 1e-3) -> (; points, index, n_starts, n_converged)

An independent critical set of f on the box of `o`, taken from no surrogate: the
audit's own verifier (`refine_on_f`) from every node of an `o.truth_starts`^dim
lattice spanning the closed box, converged points deduplicated at `dedup_tol` (box
units). It misses critical points whose Newton basin falls between lattice nodes; a
census point verified outside this set is reported as `truth_extra`, a statement
about the oracle, not about the surrogate.
"""
function truth_by_multistart(o::Objective; dedup_tol::Real = 1e-3)
    o.truth == :multistart || error("$(o.key): truth_by_multistart needs truth = :multistart")
    lo, hi = box(o)
    c = (lo .+ hi) ./ 2
    hw = (hi .- lo) ./ 2
    lat = range(-1.0, 1.0; length = o.truth_starts)
    pts = Vector{Vector{Float64}}()
    idx = Int[]
    # the starts are independent: refine them on all threads, then deduplicate in
    # lattice order (the same result as the serial loop)
    x0s = [c .+ hw .* collect(tup) for tup in Iterators.product((lat for _ in 1:o.dim)...)][:]
    res = Vector{Any}(undef, length(x0s))
    Threads.@threads for k in eachindex(x0s)
        res[k] = refine_on_f(o.f, x0s[k], lo, hi; ad = o.ad, tol = o.gradtol)
    end
    n_starts = length(x0s)
    n_conv = 0
    for r in res
        r.converged || continue
        n_conv += 1
        any(p -> maximum(abs.((p .- r.x) ./ hw)) < dedup_tol, pts) && continue
        push!(pts, r.x)
        push!(idx, r.index)
    end
    return (; points = pts, index = idx, n_starts = n_starts, n_converged = n_conv)
end

"""
    census(rows, lo, hi; dedup_tol = 1e-3, capture_radius = 0.05, truth = nothing)

The verified critical-point census of one configuration. Distances are max-norm in
box units, u = (x − c) ./ hw; `rows` are the in-box surrogate critical points, each
refined by `refine_on_f`.

- `n_inbox`: candidates (rows); `n_verified_rows`: rows that converged inside the box.
- `points`: the DISTINCT verified critical points of f (verified rows merged at
  `dedup_tol`), each with its index at the seed row, `index_stable` (all rows
  reaching it agree), `n_rows`, `seed_dist` (smallest `disp_norm` of a row reaching
  it), `tight` (`seed_dist ≤ capture_radius`: the surrogate located it), `typed` (the
  seed's surrogate index equals the index of f) and `face_dist`.
- `n_tight` / `n_transported`: distinct points located by the surrogate / reached
  only by Newton on f from a candidate farther than `capture_radius`.
- `n_spurious = n_inbox − n_tight`: candidates that are not the tight seed of their
  own point, i.e. `n_unverified + n_redundant + n_transported`.
- `n_mistyped`: tight seeds whose surrogate index is not the index of f.
- `ph_distinct`: Σ(−1)^index over the distinct points.
- `truth` (with a truth set): `n_truth`, `n_found`, `n_found_tight`, and `n_extra`
  (distinct points missing from the truth set).
- `clean`: no spurious candidate and, with a truth set, every truth point tightly
  captured.

`cp_id[k]` is the point row k verified to (0: not verified); `tight_seed[k]` marks
the row that captured its point.
"""
function census(rows, lo, hi; dedup_tol::Real = 1e-3, capture_radius::Real = 0.05, truth = nothing)
    c = (lo .+ hi) ./ 2
    hw = (hi .- lo) ./ 2
    dist(a, b) = maximum(abs.((a .- b) ./ hw))
    reps = Vector{Vector{Float64}}()
    members = Vector{Vector{Int}}()
    cp_id = zeros(Int, length(rows))
    for (k, r) in enumerate(rows)
        r.converged || continue
        j = findfirst(p -> dist(p, r.x_refined) < dedup_tol, reps)
        if j === nothing
            push!(reps, r.x_refined)
            push!(members, [k])
            cp_id[k] = length(reps)
        else
            push!(members[j], k)
            cp_id[k] = j
        end
    end
    tight_seed = fill(false, length(rows))
    points = NamedTuple[]
    for (j, ks) in enumerate(members)
        dn = [rows[k].disp_norm for k in ks]
        kseed = ks[argmin(dn)]
        tight = minimum(dn) <= capture_radius
        tight && (tight_seed[kseed] = true)
        idxs = [rows[k].index_refined for k in ks]
        push!(points, (;
            x = reps[j],
            u = (reps[j] .- c) ./ hw,
            index = rows[kseed].index_refined,
            index_stable = allequal(idxs),
            n_rows = length(ks),
            seed_dist = minimum(dn),
            tight = tight,
            typed = rows[kseed].index_surrogate == rows[kseed].index_refined,
            face_dist = minimum(1 .- abs.((reps[j] .- c) ./ hw)),
        ))
    end
    n_inbox = length(rows)
    n_ver = count(r -> r.converged, rows)
    n_distinct = length(points)
    n_tight = count(p -> p.tight, points)
    tr = nothing
    if truth !== nothing
        found = [any(p -> dist(p.x, t) < dedup_tol, points) for t in truth]
        found_tight = [any(p -> p.tight && dist(p.x, t) < dedup_tol, points) for t in truth]
        tr = (;
            n_truth = length(truth),
            n_found = count(found),
            n_found_tight = count(found_tight),
            n_extra = count(p -> !any(t -> dist(p.x, t) < dedup_tol, truth), points),
        )
    end
    n_spurious = n_inbox - n_tight
    return (;
        n_inbox = n_inbox,
        n_verified_rows = n_ver,
        n_distinct = n_distinct,
        n_tight = n_tight,
        n_transported = n_distinct - n_tight,
        n_unverified = n_inbox - n_ver,
        n_redundant = n_ver - n_distinct,
        n_spurious = n_spurious,
        n_mistyped = count(p -> p.tight && !p.typed, points),
        n_index_unstable = count(p -> !p.index_stable, points),
        ph_distinct = sum((-1)^p.index for p in points; init = 0),
        max_seed_dist = isempty(points) ? NaN : maximum(p.seed_dist for p in points),
        clean = n_spurious == 0 && (tr === nothing || tr.n_found_tight == tr.n_truth),
        truth = tr,
        points = points,
        cp_id = cp_id,
        tight_seed = tight_seed,
        dedup_tol = Float64(dedup_tol),
        capture_radius = Float64(capture_radius),
    )
end

# ── one configuration ───────────────────────────────────────────────────────

# one refined row per in-box surrogate critical point (the CSV row)
function refined_row(o::Objective, lo, hi, xs, xo, y, idx_s)
    r = refine_on_f(o.f, xo, lo, hi; ad = o.ad, tol = o.gradtol)
    return (;
        x_surrogate = xs,
        x_original = xo,
        y = y,
        index_surrogate = idx_s,
        x_refined = r.x,
        status = r.status,
        inside = r.inside,
        gradnorm = r.gradnorm,
        index_refined = r.index,
        min_abs_eig = r.min_abs_eig,
        newton_step = r.newton_step,
        converged = r.converged,
        displacement = r.displacement,
        disp_norm = r.disp_norm,
        # the objective at the refined point (hit test for miss²); not evaluated
        # where the refinement left the box or failed to evaluate
        f_refined = r.status in (:left_box, :domain, :nonfinite) ? NaN : o.f(r.x),
    )
end

"""
    validation_grid(o, GN) -> (; S, z, w)

The audit's tensor Chebyshev grid on the box of `o` (surrogate coordinates), the
objective on it, and the quadrature weights of `ApproxPoly.nrm`: the common set on
which fits from different sample sets are compared.
"""
function validation_grid(o::Objective, GN::Int)
    S = Globtim._grid_matrix(o.dim, GN, :chebyshev)
    z = Globtim._evaluate_objective_rows(o.f, S, o.range, o.center)
    all(isfinite, z) || error("$(o.key): objective not finite on the validation grid")
    return (; S = S, z = z, w = Globtim.compute_quadrature_weights(:chebyshev, GN, o.dim))
end

# L2 norm on [-1,1]^n (Lebesgue, the ApproxPoly.nrm convention) of s − f on the
# validation grid; s takes surrogate coordinates. NaN without a validation grid.
function validation_nrm(s, validation)
    validation === nothing && return NaN
    S, z, w = validation.S, validation.z, validation.w
    return sqrt(sum(w[i] * (s(S[i, :]) - z[i])^2 for i in 1:size(S, 1)))
end

"""
    face_samples_for(n) -> Int

Lattice points per face coordinate for the denominator certificate: the face
sampling costs 2n · face_samples^(n−1) evaluations of q, so the default 41 is
kept while that stays under 2·10⁶ (n ≤ 4) and reduced to fit that budget above
(n = 5: 21, n = 6: 11, n = 7: 7). A coarser lattice is a weaker certificate.
"""
face_samples_for(n::Int) = n == 1 ? 41 : min(41, max(3, floor(Int, (2e6 / (2n))^(1 / (n - 1)))))

"""
    run_rational(o, TR, M, N; arm = GRID_ARM, validation = nothing, truth = nothing, dedup_tol = 1e-3, capture_radius = 0.05)

One rational configuration: fit, lifted HC solve (cold and warm), denominator
certificate, refinement of every in-box candidate on f, and the `census` (keywords
passed through). `admissible` is the certificate: a fit whose q is not certified
positive on the box is reported, never used as the gate's R*. `arm` selects the
sample set: the grid of `TR`, or `per_dof · (α(M) + α(N))` Christoffel samples drawn
with seed `arm.seed`; `n_evals` counts the objective evaluations of the fit and
`nrm_grid` is its residual on `validation` (the grid fit's own `nrm` for the grid).
"""
function run_rational(o::Objective, TR, M, N; arm = GRID_ARM, validation = nothing, truth = nothing,
        dedup_tol = 1e-3, capture_radius = 0.05, warm::Bool = true, face_samples::Int = face_samples_for(o.dim),
        fit::String = "lin", start_system::Symbol = :polyhedral, qfilter::Real = 0.0)
    lo, hi = box(o)
    fit in ("lin", "lm", "pts") || error("rational fit must be lin, lm or pts, got $fit")
    # pts: q ≥ 0.01 · mean(q) at the fit points, box points and exchanged minimisers
    # of q (RationalConstructor(...; denominator = :points)); lin / lm: free linearised
    dkw = fit == "pts" ? (; denominator = :points, delta = 0.01) : (;)
    t_fit = @elapsed begin
        R = if arm.sampling == :grid
            RationalConstructor(TR, M, N; dkw...)
        else
            RationalConstructor(TR, M, N; sampling = arm.sampling, rng = Xoshiro(arm.seed),
                n_samples = ceil(Int, arm.per_dof * (binomial(o.dim + M, M) + binomial(o.dim + N, N))), dkw...)
        end
        # lm: refit on the same points by LM on the true residual (Globtim.rational_lm_refit)
        fit == "lm" && (R = rational_lm_refit(R))
    end
    ftag = fit == "lin" ? "" : fit
    # the conversion is repeated inside solve_rational_critical_points; it is
    # timed separately here because it is cheap and the brief asks for the split
    t_convert = @elapsed rational_critical_system(R)
    t_solve = @elapsed res = solve_rational_critical_points(R; start_system = start_system)
    t_solve -= t_convert
    # second solve of the same system: HC compiles a straight-line program per
    # new System, so the first call is JIT-dominated at these sizes; the warm
    # time is the path-tracking cost
    t_solve_warm = warm ? (@elapsed solve_rational_critical_points(R; start_system = start_system)) - t_convert : NaN
    stats = res.stats
    t_cert = @elapsed cert = certify_positive_denominator(R; face_samples = face_samples)
    # candidate filter: a critical point of p/q where q is small against its typical
    # size sits on a (near-)pole surface of the fit, not on a feature of f
    keep = trues(length(res.points))
    if qfilter > 0
        qmed = median([rational_denominator(R, R.grid[i, :]) for i in 1:size(R.grid, 1)])
        keep = [rational_denominator(R, x) >= qfilter * qmed for x in res.points]
    end
    t_refine = @elapsed rows = [refined_row(o, lo, hi, x, to_original_coordinates(R, x), y, idx)
                                for (x, y, idx, k) in zip(res.points, res.values, res.index, keep) if k]
    cz = census(rows, lo, hi; truth = truth, dedup_tol = dedup_tol, capture_radius = capture_radius)
    return (;
        kind = "rational",
        label = "($M,$N)" * ftag * arm_tag(arm),
        base_label = "($M,$N)" * ftag,
        sampling = String(arm.sampling),
        per_dof = arm.per_dof,
        seed = arm.seed,
        n_evals = size(R.grid, 1),
        nrm_grid = arm.sampling == :grid ? R.nrm : validation_nrm(u -> R(u), validation),
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
        admissible = cert.ok,
        n_paths = stats.n_paths,
        n_singular = stats.n_singular,
        n_real = stats.n_real,
        n_points = length(res.points),
        n_outside = res.n_outside,
        n_rejected_q = res.n_rejected_q,
        n_qfiltered = count(!, keep),
        n_inconsistent_y = res.n_inconsistent_y,
        gradtol = o.gradtol,
        census = cz,
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
A cell that raised: every numeric field NaN / -1, no rows, an empty census, the
message in `error`, so one failing configuration is reported instead of aborting
the audit. A failed cell is never admissible.
"""
function failed_cell(o::Objective, kind, label, M, N, msg; truth = nothing, arm = GRID_ARM, base_label = nothing)
    lo, hi = box(o)
    return (;
        kind = kind, label = label, base_label = base_label !== nothing ? base_label : kind == "rational" ? "($M,$N)" : "D=$M",
        sampling = String(arm.sampling), per_dof = arm.per_dof, seed = arm.seed, n_evals = -1, nrm_grid = NaN,
        M = M, N_requested = N, N = -1, dof = -1, GN = -1,
        nrm = NaN, rms = NaN, sigma_ratio = NaN, qmin_grid = NaN, qmin = NaN, q_ok = false, admissible = false,
        n_paths = -1, n_singular = -1, n_real = -1, n_points = -1, n_outside = -1,
        n_rejected_q = -1, n_qfiltered = -1, n_inconsistent_y = -1, gradtol = NaN,
        census = census(NamedTuple[], lo, hi; truth = truth),
        t_fit = NaN, t_convert = NaN, t_solve = NaN, t_solve_warm = NaN, t_cert = NaN, t_refine = NaN,
        rows = NamedTuple[], error = msg,
    )
end

"""
    christoffel_polynomial_fit(o, Λ, K, rng) -> (; coeffs, nrm, rms)

The polynomial control arm of a scattered-sample rational: least squares on `K`
arcsine samples of the box of `o`, weighted with the Christoffel weights of `Λ` —
the sampler and weights of `RationalConstructor(...; sampling = :christoffel)`,
solved by QR. Coefficients are in the plain Chebyshev basis of `Λ` (what
`solve_polynomial_system` takes with `normalized = false`); `nrm` is the in-sample
Monte Carlo L2 residual on the box, `rms` the plain one.
"""
function christoffel_polynomial_fit(o::Objective, Λ, K::Int, rng)
    n = o.dim
    S, sqrt_w = Globtim.christoffel_random_sample_chebyshev(n, Λ.data, K; rng = rng)
    z = Globtim._evaluate_objective_rows(o.f, S, o.range, o.center)
    all(isfinite, z) || error("$(o.key): objective not finite at $(count(!isfinite, z)) of $K samples")
    V = Globtim.lambda_vandermonde(Λ, S; basis = :chebyshev)
    coeffs = Vector{Float64}((sqrt_w .* V) \ (sqrt_w .* z))
    r = V * coeffs .- z
    mc = [prod(π * sqrt(1 - S[i, k]^2) for k in 1:n) for i in 1:K] ./ K
    return (; coeffs = coeffs, nrm = sqrt(sum(mc .* abs2.(r))), rms = sqrt(sum(abs2, r) / K))
end

"""
    run_polynomial(o, TR, D; arm = GRID_ARM, validation = nothing, truth = nothing, dedup_tol = 1e-3, capture_radius = 0.05)

One polynomial degree: the fit (`Constructor` on the grid of `TR`, or
`christoffel_polynomial_fit` on `per_dof · α(D)` samples for a Christoffel arm),
`solve_polynomial_system` (cold and warm), refinement of every in-box candidate
on f, and the `census`. Always admissible.
"""
function run_polynomial(o::Objective, TR, D; arm = GRID_ARM, validation = nothing, truth = nothing,
        dedup_tol = 1e-3, capture_radius = 0.05, warm::Bool = true, start_system::Symbol = :auto)
    lo, hi = box(o)
    n = o.dim
    Λ = SupportGen(n, (:one_d_for_all, D))
    if arm.sampling == :grid
        t_fit = @elapsed pol = Constructor(TR, D)
        coeffs, basis, normalized = pol.coeffs, pol.basis, pol.normalized
        surrogate = u -> Globtim.evaluate(pol, to_original_coordinates(u, TR.sample_range, TR.center))
        nrm, n_evals, GN = pol.nrm, length(pol.z), TR.GN
        rms = sqrt(sum(abs2, Globtim.evaluate(pol, pol.grid .* (TR.sample_range isa Number ? TR.sample_range : TR.sample_range') .+ TR.center') .- pol.z) / length(pol.z))
    else
        K = ceil(Int, arm.per_dof * Λ.size[1])
        t_fit = @elapsed fit = christoffel_polynomial_fit(o, Λ, K, Xoshiro(arm.seed))
        coeffs, basis, normalized = fit.coeffs, :chebyshev, false
        surrogate = u -> dot(coeffs, Globtim._tensor_basis_values(Λ, u, :chebyshev, false))
        nrm, rms, n_evals, GN = fit.nrm, fit.rms, K, -1
    end
    x, _ = Globtim._rational_polyvars(n)
    stats_ref = Ref{Any}(nothing)
    t_solve = @elapsed raw = solve_polynomial_system(
        x,
        n,
        D,
        coeffs;
        basis = basis,
        normalized = normalized,
        path_stats_ref = stats_ref,
        start_system = start_system,
    )
    st = stats_ref[]
    t_solve_warm = warm ? (@elapsed solve_polynomial_system(x, n, D, coeffs; basis = basis, normalized = normalized,
        start_system = start_system)) : NaN
    pts = [Vector{Float64}(real.(s)) for s in raw if all(-1 .<= real.(s) .<= 1)]
    # the surrogate's Morse index in surrogate coordinates: the affine map to the
    # box scales by positive factors, which leaves the inertia unchanged
    t_refine = @elapsed rows = map(pts) do xs
        xo = to_original_coordinates(xs, TR.sample_range, TR.center)
        refined_row(o, lo, hi, xs, xo, surrogate(xs),
            count(<(0), eigvals(Symmetric(ForwardDiff.hessian(surrogate, xs)))))
    end
    cz = census(rows, lo, hi; truth = truth, dedup_tol = dedup_tol, capture_radius = capture_radius)
    return (;
        kind = "polynomial",
        label = "D=$D" * arm_tag(arm),
        base_label = "D=$D",
        sampling = String(arm.sampling),
        per_dof = arm.per_dof,
        seed = arm.seed,
        n_evals = n_evals,
        nrm_grid = arm.sampling == :grid ? nrm : validation_nrm(surrogate, validation),
        M = D,
        N_requested = 0,
        N = 0,
        dof = binomial(n + D, D),
        GN = GN,
        nrm = nrm,
        rms = rms,
        sigma_ratio = NaN,
        qmin_grid = NaN,
        qmin = NaN,
        q_ok = true,
        admissible = true,
        n_paths = st === nothing ? -1 : st.paths_tracked,
        n_singular = st === nothing ? -1 : st.n_singular,
        n_real = length(raw),
        n_points = length(pts),
        n_outside = length(raw) - length(pts),
        n_rejected_q = 0,
        n_qfiltered = 0,
        n_inconsistent_y = 0,
        gradtol = o.gradtol,
        census = cz,
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

# one-line census: candidates → distinct / tight, spurious, and recall when a truth set exists
function census_line(cz)
    s = @sprintf("%d cand → %d distinct, %d tight, %d spurious", cz.n_inbox, cz.n_distinct, cz.n_tight, cz.n_spurious)
    cz.truth === nothing && return s
    return s * @sprintf(" (truth: %d/%d tight, %d found, %d extra)", cz.truth.n_found_tight, cz.truth.n_truth, cz.truth.n_found, cz.truth.n_extra)
end

"""
Gate of brief §3 on the census. `dof_frac = 0.5` is the official gate (R*
restricted to dof ≤ ½ dof(P*)); `dof_frac = Inf` is the informational
unconstrained comparison (best certified rational of any size against the best
polynomial). R* is chosen among ADMISSIBLE (q-certified) fits only; with none at
the dof bound, check 3 fails and R* is `nothing`.
"""
function gate_verdict(cells; dof_frac = 0.5)
    # the gate compares grid fits (nrm is one estimator there); sampled arms are
    # reported next to them, not ranked into P* / R*
    polys = [c for c in cells if c.kind == "polynomial" && c.sampling == "grid" && isfinite(c.nrm)]
    rats = [c for c in cells if c.kind == "rational" && c.sampling == "grid" && isfinite(c.nrm)]
    (isempty(polys) || isempty(rats)) && return (; evaluated = false, pass = false, checks = [], Pstar = nothing, Rstar = nothing)
    Pstar = polys[argmin([c.nrm for c in polys])]
    cands = [c for c in rats if c.dof <= Pstar.dof * dof_frac]
    if isempty(cands)
        return (; evaluated = false, pass = false, checks = [("no rational configuration at ≤ $(dof_frac)·dof($(Pstar.label)) = $(floor(Int, Pstar.dof * dof_frac))", false, "")], Pstar = Pstar, Rstar = nothing)
    end
    certified = [c for c in cands if c.admissible]
    if isempty(certified)
        detail = "q changes sign on the box in " * join((c.label for c in cands), ", ")
        return (; evaluated = true, pass = false,
            checks = [("3. a q-certified rational configuration exists at dof ≤ $(dof_frac)·dof(P*)", false, detail)],
            Pstar = Pstar, Rstar = nothing)
    end
    Rstar = certified[argmin([c.nrm for c in certified])]
    CR, CP = Rstar.census, Pstar.census
    near(a, b) = maximum(abs.(a.u .- b.u)) < CR.dedup_tol
    covered = count(p -> any(r -> near(r, p), CR.points), CP.points)
    checks = Tuple{String,Bool,String}[]
    push!(checks, ("1. nrm(R*) ≤ nrm(P*)", Rstar.nrm <= Pstar.nrm, @sprintf("%.3e vs %.3e", Rstar.nrm, Pstar.nrm)))
    # the rational must locate every critical point it reports (no spurious,
    # redundant or transported candidate) and every truth point, and must not miss
    # a point the polynomial's refinement verifies
    push!(checks, ("2. R* census clean, and every distinct P* point found by R*", CR.clean && covered == length(CP.points),
        "R*: " * census_line(CR) * "; P*: " * census_line(CP) * "; R* has $covered of $(length(CP.points)) P* points"))
    push!(checks, ("3. a q-certified rational configuration exists at dof ≤ $(dof_frac)·dof(P*)", true, @sprintf("R* qmin = %.3e", Rstar.qmin)))
    # evaluated on the WARM (second-solve) times: the first solve of a new HC
    # System is dominated by compiling its straight-line program at these sizes
    # warm (second-solve) times when measured; without them (--no-warm) the
    # cold times, compilation included, and the check says so
    if isnan(Rstar.t_solve_warm) || isnan(Pstar.t_solve_warm)
        push!(checks, ("4. HC wall lifted(R*) ≤ polynomial(P*) (cold; warm not measured)", Rstar.t_solve <= Pstar.t_solve,
            @sprintf("%.2fs vs %.2fs; R* certificate %.2fs", Rstar.t_solve, Pstar.t_solve, Rstar.t_cert)))
    else
        push!(checks, ("4. HC wall lifted(R*) ≤ polynomial(P*) (warm)", Rstar.t_solve_warm <= Pstar.t_solve_warm,
            @sprintf("%.2fs vs %.2fs; cold %.2fs vs %.2fs; R* certificate %.2fs", Rstar.t_solve_warm, Pstar.t_solve_warm, Rstar.t_solve, Pstar.t_solve, Rstar.t_cert)))
    end
    return (; evaluated = true, pass = all(c[2] for c in checks), checks = checks, Pstar = Pstar, Rstar = Rstar)
end

# ── reporting ───────────────────────────────────────────────────────────────

# NamedTuples (cells, rows, census, truth sets) as nested Dicts for JLD2
todict(nt::NamedTuple) = Dict{String,Any}(String(k) => todict(v) for (k, v) in pairs(nt))
todict(v::AbstractVector) = [todict(x) for x in v]
todict(s::Symbol) = String(s)
todict(x) = x

function cell_table(io, cells)
    println(io, "| config | dof | N | evals | nrm | nrm (grid) | σmin/σmax | qmin (cert) | paths | sing | in box | t_fit | t_conv | t_HC cold | t_HC warm | t_cert | t_refine |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for c in cells
        if !isempty(c.error)
            println(io, "| ", c.label, " | – | – | – | FAILED: ", replace(first(c.error, 160), "|" => "/"), " | | | | | | | | | | | | |")
            continue
        end
        @printf(io, "| %s | %d | %d | %d | %.2e | %s | %s | %s | %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n",
            c.label, c.dof, c.N, c.n_evals, c.nrm, isnan(c.nrm_grid) ? "–" : @sprintf("%.2e", c.nrm_grid),
            isnan(c.sigma_ratio) ? "–" : @sprintf("%.1e", c.sigma_ratio),
            isnan(c.qmin) ? "–" : @sprintf("%.2e%s", c.qmin, c.q_ok ? "" : " ✗"),
            c.n_paths, c.n_singular, c.n_points,
            c.t_fit, c.t_convert, c.t_solve, c.t_solve_warm, c.t_cert, c.t_refine)
    end
end

"""
    sampling_table(io, cells)

The sampled arms against the grid, one row per (configuration, sampling spec),
Christoffel replicates aggregated: objective evaluations of the fit, how many
replicates certify q > 0 and give a clean census, the tight captures and spurious
candidates of each replicate, and the residual on the common grid.
"""
function sampling_table(io, cells)
    any(c -> c.sampling != "grid", cells) || return
    keys_ = Tuple[]
    groups = Dict{Tuple,Vector}()
    for c in cells
        k = (c.kind, c.base_label, c.sampling, c.per_dof)
        haskey(groups, k) || (push!(keys_, k); groups[k] = [])
        push!(groups[k], c)
    end
    println(io, "| config | sampling | evals | replicates | certified | clean | tight / truth per replicate | spurious per replicate | nrm on the grid: median (min – max) |")
    println(io, "|---|---|---:|---:|---:|---:|---|---|---|")
    for k in keys_
        cs = groups[k]
        ok = [c for c in cs if isempty(c.error)]
        tt = join((c.census.truth === nothing ? string(c.census.n_tight) :
                   "$(c.census.truth.n_found_tight)/$(c.census.truth.n_truth)" for c in ok), ", ")
        sp = join((string(c.census.n_spurious) for c in ok), ", ")
        g = sort([c.nrm_grid for c in ok if isfinite(c.nrm_grid)])
        gs = isempty(g) ? "–" : @sprintf("%.2e (%.2e – %.2e)", g[cld(length(g), 2)], g[1], g[end])
        ev = isempty(ok) ? "–" : string(first(ok).n_evals)
        @printf(io, "| %s | %s | %s | %d | %d | %d | %s | %s | %s |\n",
            k[2], k[3] == "grid" ? "grid" : @sprintf("christoffel %gm", k[4]), ev, length(cs),
            count(c -> c.admissible, ok), count(c -> c.admissible && c.census.clean, ok),
            isempty(tt) ? "–" : tt, isempty(sp) ? "–" : sp, gs)
    end
    failed = length(cells) - count(c -> isempty(c.error), cells)
    failed > 0 && println(io, "\n", failed, " cell(s) failed; see the fit table.")
end

function census_table(io, cells)
    println(io, "| config | admissible | cand | verified rows | distinct | tight | transported | unverified | redundant | **spurious** | mistyped | index-unstable | PH | max seed dist | truth: tight / found / extra of n | clean |")
    println(io, "|---|:-:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|:-:|")
    for c in cells
        isempty(c.error) || continue
        z = c.census
        tr = z.truth === nothing ? "–" : @sprintf("%d / %d / %d of %d", z.truth.n_found_tight, z.truth.n_found, z.truth.n_extra, z.truth.n_truth)
        @printf(io, "| %s | %s | %d | %d | %d | %d | %d | %d | %d | **%d** | %d | %d | %d | %s | %s | %s |\n",
            c.label, c.admissible ? "yes" : "✗ (q not certified)", z.n_inbox, z.n_verified_rows, z.n_distinct,
            z.n_tight, z.n_transported, z.n_unverified, z.n_redundant, z.n_spurious, z.n_mistyped,
            z.n_index_unstable, z.ph_distinct, isnan(z.max_seed_dist) ? "–" : @sprintf("%.1e", z.max_seed_dist),
            tr, z.clean ? "yes" : "no")
    end
end

fmt_point(x) = "[" * join((@sprintf("%.6f", t) for t in x), ", ") * "]"

function verdict_lines(io, v)
    for (name, ok, detail) in v.checks
        println(io, "- [", ok ? "PASS" : "FAIL", "] ", name, " — ", detail)
    end
end

function write_summary(path, cfg, results, verdicts, verdicts_unconstrained, elapsed; objectives = OBJECTIVES, truths = Dict())
    open(path, "w") do io
        println(io, "# Rational surrogates, Phase 1 audit\n")
        println(io, "Generated ", now(), " by pkg/globtim/scripts/audit_rational_phase1.jl",
            cfg["smoke"] ? " (SMOKE)" : "", "; GN = ", cfg["gn"], "; elapsed ", @sprintf("%.0f", elapsed), " s.\n")
        println(io, "Brief: docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md. nrm is the quadrature-weighted L2 norm ",
            "of the residual on [-1,1]^n for both surrogate kinds (nonlinear residual p/q − f for the rational).\n")
        @printf(io, "**Census** (the measure of a configuration). Every in-box surrogate critical point (a candidate) is ")
        @printf(io, "refined on f by Newton; it is *verified* when the refinement reaches |∇f| < gradtol inside the box ")
        @printf(io, "(gradtol per objective, stated in its section; it is the threshold applied). Verified points closer than ")
        @printf(io, "%.0e in box units (max-norm of (x − c)./hw) are one *distinct* critical point. A distinct point is ", cfg["dedup_tol"])
        @printf(io, "*tight* when a candidate reaching it started within %.2g box units of it (the surrogate located it), ", cfg["capture_radius"])
        @printf(io, "*transported* otherwise (Newton on f carried a distant candidate there). *Spurious* = candidates that are ")
        @printf(io, "not the tight seed of their own point = unverified + redundant + transported. *Mistyped* = tight seeds ")
        @printf(io, "whose surrogate index differs from the index of f. PH = Σ(−1)^index over distinct points. ")
        @printf(io, "*Clean* = no spurious candidate and, with a truth set, every truth point tight. A rational fit whose q ")
        @printf(io, "is not certified positive on the box is not admissible: its census is shown, the gate never selects it.\n\n")
        if any(a -> a.sampling != :grid, sampling_arms(cfg))
            @printf(io, "**Sampling.** A Christoffel arm `(M,N) Km #r` fits on ⌈K · (α(M) + α(N))⌉ points (⌈K · α(D)⌉ for ")
            @printf(io, "`D=d Km #r`) drawn from the product arcsine measure with seed r, weighted least squares with the ")
            @printf(io, "Christoffel weights of the total-degree-max(M,N) Chebyshev space. Its nrm is the in-sample Monte ")
            @printf(io, "Carlo L2 residual; nrm (grid) is the residual on the audit grid, the common yardstick. The gate ranks ")
            @printf(io, "grid fits only.\n\n")
        end
        for key in cfg["objectives"]
            o = objectives[key]
            cells = results[key]
            v = verdicts[key]
            println(io, "## ", key, ". ", o.name, "\n")
            println(io, "dim ", o.dim, ", center ", o.center, ", half-width ", o.range,
                "; refinement derivatives: ", o.ad, ", verified at |∇f| < ", o.gradtol, ".\n")
            if haskey(truths, key)
                t = truths[key]
                println(io, "Truth set (Newton on f from a ", o.truth_starts, "^", o.dim, " lattice of starts, ",
                    t.n_converged, " of ", t.n_starts, " converged inside the box): ", length(t.points), " critical points\n")
                for (x, idx) in zip(t.points, t.index)
                    println(io, "- ", fmt_point(x), ", index ", idx)
                end
                println(io)
            else
                println(io, "No truth set for this objective: recall is not measured, only the census.\n")
            end
            println(io, "Fits and solves:\n")
            cell_table(io, cells)
            println(io, "\nCensus:\n")
            census_table(io, cells)
            println(io)
            if any(c -> c.sampling != "grid", cells)
                println(io, "Sampling arms (evals = objective evaluations of the fit; the grid residual is on the ",
                    "audit's GN = ", cfg["gn"], " grid, ", cfg["validate"] ? "computed for every arm" : "not computed (--no-validate)", "):\n")
                sampling_table(io, cells)
                println(io)
            end
            if v.evaluated
                println(io, "Gate: P* = ", v.Pstar.label, " (dof ", v.Pstar.dof, "), R* = ",
                    v.Rstar === nothing ? "none (no certified rational at the dof bound)" :
                    "$(v.Rstar.label) (dof $(v.Rstar.dof), post-reduction N = $(v.Rstar.N))",
                    " → **", v.pass ? "PASS" : "FAIL", "**\n")
            else
                println(io, "Gate: not evaluated\n")
            end
            verdict_lines(io, v)
            println(io)
            vu = verdicts_unconstrained[key]
            if vu.evaluated
                println(io, "Unconstrained comparison (informational, any dof): R* = ",
                    vu.Rstar === nothing ? "none" : "$(vu.Rstar.label) (dof $(vu.Rstar.dof))",
                    " vs P* = ", vu.Pstar.label, " (dof ", vu.Pstar.dof, ") → ", vu.pass ? "PASS" : "FAIL", "\n")
                verdict_lines(io, vu)
                println(io)
            end
            if haskey(results, key * "_extended")
                println(io, "Extended rational sweep (GN = ", cfg["gn_extended"], "):\n")
                cell_table(io, results[key*"_extended"])
                println(io)
                census_table(io, results[key*"_extended"])
                println(io)
            end
            println(io, "Candidates of R* and P* (original coordinates; cp = distinct point reached, 0 = not verified):\n")
            for c in (v.evaluated ? filter(!isnothing, [v.Rstar, v.Pstar]) : [])
                println(io, "- ", c.label, ":")
                for (k, r) in enumerate(c.rows)
                    @printf(io, "  - cp %d%s: from %s → %s, index %d → %d, |∇f| = %.1e, moved %.1e box units, %s\n",
                        c.census.cp_id[k], c.census.tight_seed[k] ? " (tight seed)" : "",
                        fmt_point(r.x_original), fmt_point(r.x_refined), r.index_surrogate, r.index_refined,
                        r.gradnorm, r.disp_norm, r.converged ? "verified" : "NOT verified ($(r.status), inside = $(r.inside))")
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

# ── ladder report (campaigns that put one objective family on a dial) ───────

# one census cell: tight captures / truth points (or distinct tight points without
# a truth set), +spurious candidates, ✗ when the rational fit is not admissible;
# bold when the census is clean and admissible
function ladder_cell(c)
    isempty(c.error) || return "failed"
    z = c.census
    s = (z.truth === nothing ? string(z.n_tight) : "$(z.truth.n_found_tight)/$(z.truth.n_truth)") * " +$(z.n_spurious)"
    c.admissible || return s * " ✗"
    return z.clean ? "**" * s * "**" : s
end

"""
    ladder_report(path, cfg, results; axis_name, axis, order) -> path

One row per objective of a ladder, in `order`, with the value `axis[key]` of the
dial (`axis_name`), the first clean admissible configuration of each kind, and the
census of every configuration in one cell (`ladder_cell`). Written by campaign
scripts through `main`'s `extra_report`.
"""
function ladder_report(path, cfg, results; axis_name::AbstractString, axis::AbstractDict, order)
    labels = vcat(["($M,$N)" for (M, N) in cfg["rational"]], ["D=$D" for D in cfg["polynomial"]])
    dof = Dict{String,Int}()
    for key in order, c in results[key]
        isempty(c.error) && (dof[c.label] = c.dof)
    end
    first_clean(cells, kind) = begin
        ok = [c for c in cells if c.kind == kind && isempty(c.error) && c.admissible && c.census.clean]
        isempty(ok) ? "none" : (c = ok[argmin([c.dof for c in ok])]; "$(c.label) ($(c.dof) dof)")
    end
    open(path, "w") do io
        println(io, "# Ladder census\n")
        println(io, "Cell: tight captures / truth points (distinct tight points when the objective has no truth set), ",
            "then +spurious candidates; ✗ = rational fit not admissible (q not certified positive); **bold** = clean. ",
            "Census definitions: summary.md.\n")
        println(io, "| key | ", axis_name, " | truth | first clean rational | first clean polynomial | ",
            join(("$l ($(get(dof, l, -1)))" for l in labels), " | "), " |")
        println(io, "|---|---:|---:|---|---|", join(("---" for _ in labels), "|"), "|")
        for key in order
            cells = results[key]
            byl = Dict(c.label => c for c in cells)
            z1 = first(cells).census
            ntruth = z1.truth === nothing ? "–" : string(z1.truth.n_truth)
            println(io, "| ", key, " | ", @sprintf("%.3f", axis[key]), " | ", ntruth, " | ",
                first_clean(cells, "rational"), " | ", first_clean(cells, "polynomial"), " | ",
                join((haskey(byl, l) ? ladder_cell(byl[l]) : "–" for l in labels), " | "), " |")
        end
    end
    return path
end

# ── main ────────────────────────────────────────────────────────────────────

"""
    main(argv; objectives, root, slug, bead, extended_keys, brief, extra_report) -> Bool

Run the audit over `objectives` (a `Dict{String,Objective}`; the default table is
the brief's A–D). A campaign script `include`s this file and calls `main` with its
own table, results root under `globtim_results/`, ledger slug, bead (the record's
`issue_id`; `--bead` overrides it per run) and the keys that get the extended
(M,N) sweep. `extra_report(cfg, results, outdir)`, if given, writes further
artifacts into `outdir` and returns their file names (hashed into the ledger
record with the rest).
"""
function main(
    argv;
    objectives = OBJECTIVES,
    root = "rational_phase1",
    slug = "rational_phase1_audit",
    bead = "globopt_merged-8f4p.7",
    extended_keys = ["B"],
    brief = "docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md",
    extra_report = nothing,
)
    cfg = parse_args(argv; root = root, default_objectives = sort(collect(keys(objectives))), bead = bead)
    outdir = normpath(cfg["outdir"])
    mkpath(outdir)
    t0 = time()
    println("output: ", outdir)

    # Warm-up: compile every code path once on a tiny configuration so the wall
    # times below (gate check 4) measure the solves, not first-call compilation.
    let o = objectives[first(cfg["objectives"])]
        TRw = TestInput(o.f; dim = o.dim, center = o.center, sample_range = o.range, GN = 8)
        t_w = @elapsed begin
            # without a grid arm (high dimension: (GN+1)^n evaluations of f are
            # what the Christoffel arms avoid), compile on a Christoffel arm
            warm_arm = any(a -> a.sampling == :grid, cfg["sampling"]) ? GRID_ARM :
                       (; sampling = :christoffel, per_dof = 2.0, seed = 0)
            run_rational(o, TRw, 3, 2; arm = warm_arm, face_samples = 3, start_system = cfg["rational_start_system"])
            # degree 2 above n = 8: the warm-up only compiles, and a degree-4 polyhedral
            # start system overflows at n = 12
            run_polynomial(o, TRw, o.dim > 8 ? 2 : 4; arm = warm_arm, start_system = cfg["start_system"])
        end
        @printf("warm-up (compilation): %.1f s\n", t_w)
    end

    results = Dict{String,Vector{NamedTuple}}()
    verdicts = Dict{String,Any}()
    verdicts_unconstrained = Dict{String,Any}()
    truths = Dict{String,Any}()
    for key in cfg["objectives"]
        o = objectives[key]
        println("\n== ", key, ". ", o.name)
        truth_pts = nothing
        if o.truth == :multistart
            t_truth = @elapsed truths[key] = truth_by_multistart(o; dedup_tol = cfg["dedup_tol"])
            truth_pts = truths[key].points
            @printf("  truth: %d critical points (%d of %d starts converged, %.1f s)\n",
                length(truth_pts), truths[key].n_converged, truths[key].n_starts, t_truth)
            flush(stdout)
        end
        ckw = (; truth = truth_pts, dedup_tol = cfg["dedup_tol"], capture_radius = cfg["capture_radius"], warm = cfg["warm"])
        fs = cfg["face_samples"] === nothing ? face_samples_for(o.dim) : cfg["face_samples"]
        @printf("  denominator certificate: %d lattice points per face coordinate\n", fs)
        TR = TestInput(o.f; dim = o.dim, center = o.center, sample_range = o.range, GN = cfg["gn"])
        arms = sampling_arms(cfg)
        validation = cfg["validate"] && any(a -> a.sampling != :grid, arms) ? validation_grid(o, cfg["gn"]) : nothing
        validation === nothing || @printf("  validation grid: %d evaluations (GN = %d)\n", length(validation.z), cfg["gn"])
        cells = NamedTuple[]
        for (M, N) in cfg["rational"], fit in cfg["rational_fit"], arm in arms
            ftag = fit == "lin" ? "" : fit
            label = "($M,$N)" * ftag * arm_tag(arm)
            @printf("  rational %-16s ... ", label)
            c = try
                run_rational(o, TR, M, N; arm = arm, validation = validation, face_samples = fs, fit = fit,
                    start_system = cfg["rational_start_system"], qfilter = cfg["qfilter"], ckw...)
            catch e
                failed_cell(o, "rational", label, M, N, sprint(showerror, e); truth = truth_pts, arm = arm,
                    base_label = "($M,$N)" * ftag)
            end
            push!(cells, c)
            if isempty(c.error)
                @printf("evals=%d N→%d nrm=%.2e (grid %.2e) σ=%.1e qmin=%.3f%s %s HC=%.2fs\n",
                    c.n_evals, c.N, c.nrm, c.nrm_grid, c.sigma_ratio, c.qmin, c.q_ok ? "" : "(neg)", census_line(c.census), c.t_solve)
            else
                println("FAILED: ", first(c.error, 200))
            end
            flush(stdout)          # progress is visible in a Slurm log (stdout to a file is block-buffered)
        end
        for D in cfg["polynomial"], arm in arms
            label = "D=$D" * arm_tag(arm)
            @printf("  polynomial %-14s ... ", label)
            c = try
                run_polynomial(o, TR, D; arm = arm, validation = validation, start_system = cfg["start_system"], ckw...)
            catch e
                failed_cell(o, "polynomial", label, D, 0, sprint(showerror, e); truth = truth_pts, arm = arm)
            end
            push!(cells, c)
            if isempty(c.error)
                @printf("evals=%d nrm=%.2e (grid %.2e) %s HC=%.2fs\n", c.n_evals, c.nrm, c.nrm_grid, census_line(c.census), c.t_solve)
            else
                println("FAILED: ", first(c.error, 200))
            end
            flush(stdout)
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
            println("  unconstrained (informational): R* = ", vu.Rstar === nothing ? "none certified" : vu.Rstar.label,
                " vs P* = ", vu.Pstar.label, " → ", vu.pass ? "PASS" : "FAIL")
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
                    run_rational(o, TRx, M, N; face_samples = fs, ckw...)
                catch e
                    failed_cell(o, "rational", "($M,$N)", M, N, sprint(showerror, e); truth = truth_pts)
                end
                push!(ext, c)
                if isempty(c.error)
                    @printf("N→%d nrm=%.2e σ=%.1e qmin=%.3f%s %s HC=%.2fs\n",
                        c.N, c.nrm, c.sigma_ratio, c.qmin, c.q_ok ? "" : "(neg)", census_line(c.census), c.t_solve)
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
        z = c.census
        t = z.truth
        push!(table, (; objective = key, kind = c.kind, config = c.label, base_config = c.base_label,
            sampling = c.sampling, per_dof = c.per_dof, seed = c.seed, n_evals = c.n_evals,
            M = c.M, N_requested = c.N_requested, N = c.N,
            dof = c.dof, GN = c.GN, nrm = c.nrm, nrm_grid = c.nrm_grid, rms = c.rms, sigma_ratio = c.sigma_ratio, qmin_grid = c.qmin_grid,
            qmin = c.qmin, q_ok = c.q_ok, admissible = c.admissible, n_paths = c.n_paths, n_singular = c.n_singular,
            n_real = c.n_real, n_points = c.n_points, n_outside = c.n_outside, n_rejected_q = c.n_rejected_q, n_qfiltered = c.n_qfiltered,
            n_inconsistent_y = c.n_inconsistent_y, gradtol = c.gradtol,
            n_verified_rows = z.n_verified_rows, n_distinct = z.n_distinct, n_tight = z.n_tight,
            n_transported = z.n_transported, n_unverified = z.n_unverified, n_redundant = z.n_redundant,
            n_spurious = z.n_spurious, n_mistyped = z.n_mistyped, n_index_unstable = z.n_index_unstable,
            ph_distinct = z.ph_distinct, max_seed_dist = z.max_seed_dist, clean = z.clean,
            n_truth = t === nothing ? -1 : t.n_truth, truth_found = t === nothing ? -1 : t.n_found,
            truth_found_tight = t === nothing ? -1 : t.n_found_tight, truth_extra = t === nothing ? -1 : t.n_extra,
            t_fit = c.t_fit, t_convert = c.t_convert, t_solve = c.t_solve, t_solve_warm = c.t_solve_warm,
            t_cert = c.t_cert, t_refine = c.t_refine, error = c.error); promote = true)
        for (k, r) in enumerate(c.rows)
            push!(cps, (; objective = key, kind = c.kind, config = c.label, point = k,
                x_surrogate = join(string.(r.x_surrogate), ";"), x_original = join(string.(r.x_original), ";"),
                x_refined = join(string.(r.x_refined), ";"), y = r.y, index_surrogate = r.index_surrogate,
                index_refined = r.index_refined, status = String(r.status), inside = r.inside,
                gradnorm = r.gradnorm, min_abs_eig = r.min_abs_eig, newton_step = r.newton_step,
                displacement = r.displacement, disp_norm = r.disp_norm, converged = r.converged,
                cp_id = z.cp_id[k], tight_seed = z.tight_seed[k], f_refined = r.f_refined); promote = true)
        end
    end
    CSV.write(joinpath(outdir, "audit_table.csv"), table)
    CSV.write(joinpath(outdir, "critical_points.csv"), cps)
    # the truth sets, in the tracked outputs: audit_full.jld2 stays local
    truth_rows = DataFrame(objective = String[], point = Int[], x = String[], index = Int[],
        n_starts = Int[], n_converged = Int[])
    for key in sort(collect(keys(truths))), (k, (x, ix)) in enumerate(zip(truths[key].points, truths[key].index))
        push!(truth_rows, (key, k, join(string.(x), ";"), ix, truths[key].n_starts, truths[key].n_converged))
    end
    CSV.write(joinpath(outdir, "truth.csv"), truth_rows)

    JLD2.jldsave(joinpath(outdir, "audit_full.jld2");
        config = Dict(k => (v isa Vector{Tuple{Int,Int}} ? [collect(t) for t in v] : todict(v)) for (k, v) in cfg),
        results = Dict(k => [todict(c) for c in v] for (k, v) in results),
        truths = Dict(k => todict(t) for (k, t) in truths),
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
            "brief" => brief, "bead" => cfg["bead"],
            "objectives" => Dict(k => Dict("name" => o.name, "dim" => o.dim, "center" => o.center, "range" => o.range,
                "ad" => String(o.ad), "gradtol" => o.gradtol, "truth" => String(o.truth), "truth_starts" => o.truth_starts)
                                 for (k, o) in objectives if k in cfg["objectives"]),
            "gn" => cfg["gn"], "basis" => "chebyshev", "solver" => "hc (lifted, polyhedral) / hc (polynomial, :auto)",
            "refinement" => "Newton on ∇f (ForwardDiff or central differences per objective), verified when |∇f| < gradtol is reached inside the box; steps ≤ 0.1 half-width per coordinate; box + 5% margin",
            "census" => "distinct verified points at dedup_tol, tight when a candidate started within capture_radius (box units, max-norm)",
            "dedup_tol" => cfg["dedup_tol"], "capture_radius" => cfg["capture_radius"],
            "sampling" => [a.sampling == :grid ? "grid" : "christoffel:$(a.per_dof)" for a in cfg["sampling"]],
            "replicates" => cfg["replicates"], "validate" => cfg["validate"],
            "face_samples" => cfg["face_samples"] === nothing ? "auto (face_samples_for(dim))" : cfg["face_samples"],
            "rational_fit" => cfg["rational_fit"],
            "qfilter" => cfg["qfilter"],
            "start_system" => String(cfg["start_system"]),
            "rational_start_system" => String(cfg["rational_start_system"]),
            "smoke" => cfg["smoke"],
        ))
    summary_path = write_summary(joinpath(outdir, "summary.md"), cfg, results, verdicts, verdicts_unconstrained, elapsed;
        objectives = objectives, truths = truths)
    extra_artifacts = extra_report === nothing ? String[] : String.(extra_report(cfg, results, outdir))

    if cfg["ledger"]
        headline = Dict{String,Any}(
            "objectives" => join(cfg["objectives"], ","),
            "gn" => cfg["gn"],
            "sampling" => join((a.sampling == :grid ? "grid" : "christoffel:$(a.per_dof)" for a in cfg["sampling"]), ","),
            "replicates" => cfg["replicates"],
            "n_cells" => sum(length(v) for v in values(results)),
        )
        for key in cfg["objectives"]
            v = verdicts[key]
            headline["gate_$key"] = v.evaluated ? (v.pass ? "pass" : "fail") : "not_evaluated"
            haskey(truths, key) && (headline["n_truth_$key"] = length(truths[key].points))
            for (tag, c) in (("Rstar", v.Rstar), ("Pstar", v.Pstar))
                c === nothing && continue
                headline["$(tag)_$key"] = c.label
                headline["nrm_$(tag)_$key"] = c.nrm
                headline["n_points_$(tag)_$key"] = c.n_points
                headline["n_distinct_$(tag)_$key"] = c.census.n_distinct
                headline["n_tight_$(tag)_$key"] = c.census.n_tight
                headline["n_spurious_$(tag)_$key"] = c.census.n_spurious
                c.census.truth === nothing || (headline["truth_found_tight_$(tag)_$key"] = c.census.truth.n_found_tight)
            end
        end
        all_pass = all(verdicts[k].evaluated && verdicts[k].pass for k in cfg["objectives"])
        # no try/catch: a run without its record is not citable, so a failed
        # emission fails the run (the results above are already on disk)
        rec = Globtim.emit_ledger_record(;
            slug = slug * (cfg["smoke"] ? "_smoke" : ""),
            outdir = outdir, headline = headline,
            artifacts = vcat(["audit_table.csv", "critical_points.csv", "truth.csv", "summary.md"], extra_artifacts),
            supersedes = cfg["supersedes"],
            issue_id = cfg["bead"],
            status = all_pass ? "completed" : "completed_gate_failed")
        println("ledger record: ", rec)
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
