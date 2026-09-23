# =============================================================================
# recount_rational_census.jl — the audit's census, applied to committed runs
#
# The rational audit runs committed before the census (rational_phase1
# 20260922T195238; rational_trajectories 1035590 and 1035595) report
# `n_verified` and `ph_sum` over candidate ROWS and dedup "distinct" points at
# 1e-6 in original units (days on the porkchop), so they overcount. This script
# reads their critical_points.csv and audit_table.csv and applies
# `census` from audit_rational_phase1.jl — the same code the audit now runs — to
# the stored refinements (nothing is refitted or re-refined):
#
#   distinct verified points (1e-3 box units), tight captures (a candidate
#   within 0.05 box units), transported, unverified, redundant, spurious,
#   mistyped, PH over distinct points, admissibility (q certified).
#
# The box of each objective is recovered from the rows themselves
# (x_original = c + hw .* x_surrogate holds for every row), so no objective
# table is needed. Objectives of the audit's own table (A–D) also get the
# truth set of `truth_by_multistart`. `converged` is taken as stored: those
# runs applied |∇f| < 1e-10 (A–D, ForwardDiff) and < 1e-6 (trajectories,
# central differences), the census thresholds or stricter.
#
# Run (profiles/dev; seconds, plus the A–D truth sets):
#   julia --project=profiles/dev pkg/globtim/scripts/recount_rational_census.jl \
#     globtim_results/rational_phase1/20260922T195238 \
#     globtim_results/local/rational_trajectories/20260923T063048 \
#     globtim_results/local/rational_trajectories/20260923T071628
# Markdown goes to stdout (docs/research/rational_surrogates_census_recount.md
# quotes it); --out <file> writes it to a file instead.
# =============================================================================

include(joinpath(@__DIR__, "audit_rational_phase1.jl"))

parse_vec(s) = parse.(Float64, split(String(s), ";"))

"""
Centre and half-width per coordinate from the rows' (x_surrogate, x_original)
pairs, by least squares on x_original = c + hw .* x_surrogate; errors if the
rows do not determine them or do not satisfy the map.
"""
function recover_box(xs::Vector{Vector{Float64}}, xo::Vector{Vector{Float64}})
    n = length(first(xs))
    c = zeros(n)
    hw = zeros(n)
    for i in 1:n
        u = [x[i] for x in xs]
        v = [x[i] for x in xo]
        length(unique(u)) >= 2 || error("coordinate $i: fewer than two distinct surrogate values; box undetermined")
        A = hcat(ones(length(u)), u)
        c[i], hw[i] = A \ v
        maximum(abs.(A * [c[i], hw[i]] .- v)) <= 1e-9 * max(1.0, maximum(abs, v)) ||
            error("coordinate $i: rows do not satisfy x_original = c + hw * x_surrogate")
    end
    return c, hw
end

function recount(dirs; dedup_tol = 1e-3, capture_radius = 0.05, io = stdout)
    for dir in dirs
        cps = CSV.read(joinpath(dir, "critical_points.csv"), DataFrame)
        tab = CSV.read(joinpath(dir, "audit_table.csv"), DataFrame)
        println(io, "## ", dir, "\n")
        for key in unique(tab.objective)
            rowsk = cps[cps.objective .== key, :]
            println(io, "### ", key, "\n")
            if nrow(rowsk) == 0
                println(io, "No in-box candidate in any configuration: no census.\n")
                continue
            end
            c, hw = recover_box([parse_vec(s) for s in rowsk.x_surrogate], [parse_vec(s) for s in rowsk.x_original])
            lo, hi = c .- hw, c .+ hw
            truth = nothing
            base = replace(key, "_extended" => "")
            if haskey(OBJECTIVES, base) && OBJECTIVES[base].truth == :multistart
                o = OBJECTIVES[base]
                maximum(abs.(o.center .- c)) <= 1e-9 && maximum(abs.(o.range .- hw)) <= 1e-9 ||
                    error("$key: recovered box $c ± $hw is not the audit table's $(o.center) ± $(o.range)")
                truth = truth_by_multistart(o; dedup_tol = dedup_tol).points
            end
            println(io, "box ", round.(c; sigdigits = 6), " ± ", round.(hw; sigdigits = 6),
                truth === nothing ? "; no truth set" : "; truth set: $(length(truth)) critical points (Newton from a lattice)", "\n")
            println(io, "| config | admissible | cand | verified rows | distinct | tight | transported | unverified | redundant | **spurious** | mistyped | PH | truth tight/found/extra | old n_verified / PH |")
            println(io, "|---|:-:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|")
            for t in eachrow(tab[tab.objective .== key, :])
                sel = rowsk[rowsk.config .== t.config .&& rowsk.kind .== t.kind, :]
                rows = [(;
                    x_refined = parse_vec(r.x_refined),
                    converged = r.converged,
                    disp_norm = maximum(abs.((parse_vec(r.x_refined) .- parse_vec(r.x_original)) ./ hw)),
                    index_refined = r.index_refined,
                    index_surrogate = r.index_surrogate,
                ) for r in eachrow(sel)]
                z = census(rows, lo, hi; truth = truth, dedup_tol = dedup_tol, capture_radius = capture_radius)
                admissible = t.kind == "polynomial" || t.q_ok
                tr = z.truth === nothing ? "–" : "$(z.truth.n_found_tight)/$(z.truth.n_found)/$(z.truth.n_extra) of $(z.truth.n_truth)"
                # the row-count columns exist only in tables written before the census
                old = hasproperty(t, :n_verified) ? "$(t.n_verified) / $(t.ph_sum)" : "–"
                println(io, "| ", t.config, " | ", admissible ? "yes" : "✗", " | ", z.n_inbox, " | ", z.n_verified_rows, " | ",
                    z.n_distinct, " | ", z.n_tight, " | ", z.n_transported, " | ", z.n_unverified, " | ", z.n_redundant,
                    " | **", z.n_spurious, "** | ", z.n_mistyped, " | ", z.ph_distinct, " | ", tr, " | ", old, " |")
            end
            println(io)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = copy(ARGS)
    out = nothing
    k = findfirst(==("--out"), args)
    if k !== nothing
        out = args[k+1]
        deleteat!(args, k:k+1)
    end
    isempty(args) && error("usage: recount_rational_census.jl <run_dir>... [--out file.md]")
    if out === nothing
        recount(args)
    else
        open(io -> recount(args; io = io), out, "w")
        println("wrote ", out)
    end
end
