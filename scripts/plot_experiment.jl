#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════════════
# plot_experiment.jl — Standard post-run figure generator
#
# Reads results from a completed (or partially completed) experiment output
# directory and generates a standard set of diagnostic figures:
#
#   1. convergence.png  — L² approx error + relative L² vs degree (log scale)
#   2. recovery.png     — ‖best_estimate − p_true‖ vs degree (if p_true known)
#   3. cps.png          — #CPs vs degree (with per-degree timing bar)
#
# Works with:
#   - Completed runs:  reads results_summary.jld2
#   - Partial runs:    reads checkpoint.jld2 (written after each degree)
#   - Fallback:        reads results_summary.json
#
# Usage:
#   julia --project=. globtim/scripts/plot_experiment.jl <results_dir>
#   julia --project=. globtim/scripts/plot_experiment.jl <results_dir> --out <plot_dir>
#   julia --project=. globtim/scripts/plot_experiment.jl --help
# ═══════════════════════════════════════════════════════════════════════════════

using CairoMakie
using JLD2
using JSON3
using Printf
using LinearAlgebra
using Globtim  # needed so JLD2 can reconstruct DegreeResult from saved JLD2 files

# ── Argument parsing ──────────────────────────────────────────────────────────

function print_usage()
    println("""
    plot_experiment.jl — Standard post-run figure generator

    Usage:
      julia --project=. globtim/scripts/plot_experiment.jl <results_dir>
      julia --project=. globtim/scripts/plot_experiment.jl <results_dir> --out <plot_dir>

    Arguments:
      results_dir   Experiment output directory (contains results_summary.jld2 etc.)

    Options:
      --out <dir>   Directory for output figures (default: <results_dir>/plots/)
      --help        Show this help message

    Output files:
      convergence.png   L² error and relative L² vs polynomial degree
      recovery.png      ‖best_estimate − p_true‖ vs degree (if p_true available)
      cps.png           #critical_points vs degree with timing breakdown
    """)
end

results_dir = ""
plot_dir = ""

let args = copy(ARGS), idx = 1
    while idx <= length(args)
        if args[idx] == "--help" || args[idx] == "-h"
            print_usage()
            exit(0)
        elseif args[idx] == "--out"
            idx += 1
            idx > length(args) && (println("ERROR: --out requires a directory argument"); exit(1))
            global plot_dir = args[idx]
        elseif !startswith(args[idx], "--")
            global results_dir = args[idx]
        else
            println("ERROR: Unknown option: $(args[idx])")
            print_usage()
            exit(1)
        end
        idx += 1
    end
end

if isempty(results_dir)
    println("ERROR: results_dir is required")
    print_usage()
    exit(1)
end

if !isdir(results_dir)
    println("ERROR: Directory not found: $results_dir")
    exit(1)
end

if isempty(plot_dir)
    plot_dir = joinpath(results_dir, "plots")
end
mkpath(plot_dir)

# ── Load degree results ───────────────────────────────────────────────────────

# Precedence: results_summary.jld2 > checkpoint.jld2 > results_summary.json
degree_results = nothing
source = ""
p_true = nothing
experiment_name = basename(results_dir)

jld2_path       = joinpath(results_dir, "results_summary.jld2")
checkpoint_path = joinpath(results_dir, "checkpoint.jld2")
json_path       = joinpath(results_dir, "results_summary.json")

if isfile(jld2_path)
    data = load(jld2_path)
    degree_results = get(data, "degree_results", nothing)
    p_true = get(get(data, "experiment_definition", Dict()), "true_params", nothing)
    experiment_name = get(data, "experiment_id", experiment_name)
    source = "results_summary.jld2"
elseif isfile(checkpoint_path)
    data = load(checkpoint_path)
    degree_results = get(data, "degree_results", nothing)
    source = "checkpoint.jld2 (partial run)"
elseif isfile(json_path)
    data = JSON3.read(read(json_path, String))
    # Build pseudo DegreeResult-like NamedTuples from the JSON results_summary
    rs = get(data, :results_summary, nothing)
    if rs !== nothing
        nts = NamedTuple[]
        for (key, val) in pairs(rs)
            deg_str = replace(string(key), "degree_" => "")
            deg = tryparse(Int, deg_str)
            deg === nothing && continue
            push!(nts, (
                degree                  = deg,
                status                  = get(val, :status, "unknown"),
                n_critical_points       = get(val, :n_critical_points, 0),
                l2_approx_error         = get(val, :l2_approx_error, NaN),
                relative_l2_error       = get(val, :relative_l2_error, NaN),
                recovery_error          = get(val, :recovery_error, nothing),
                best_objective          = get(val, :best_objective, NaN),
                total_computation_time  = get(val, :total_computation_time, NaN),
            ))
        end
        degree_results = sort(nts; by = x -> x.degree)
        # p_true from experiment_definition
        ed = get(data, :experiment_definition, nothing)
        ed !== nothing && (p_true = get(ed, :true_params, nothing))
        experiment_name = get(data, :experiment_id, experiment_name)
    end
    source = "results_summary.json"
end

if degree_results === nothing || isempty(degree_results)
    println("ERROR: No degree results found in $results_dir")
    println("  Looked for: results_summary.jld2, checkpoint.jld2, results_summary.json")
    exit(1)
end

println("Loaded from: $source")
println("Experiment:  $experiment_name")
println("Degrees:     $(length(degree_results)) ($(degree_results[1].degree)–$(degree_results[end].degree))")

# ── Helper: extract field safely ──────────────────────────────────────────────

_get(dr, field::Symbol, default) = hasproperty(dr, field) ? getproperty(dr, field) : get(dr, field, default)

# ── Collect per-degree series ─────────────────────────────────────────────────

degrees   = Int[_get(dr, :degree, 0) for dr in degree_results]
l2_errs   = Float64[_get(dr, :l2_approx_error, NaN) for dr in degree_results]
rel_l2    = Float64[_get(dr, :relative_l2_error, NaN) for dr in degree_results]
n_cps     = Int[_get(dr, :n_critical_points, 0) for dr in degree_results]
times     = Float64[_get(dr, :total_computation_time, NaN) for dr in degree_results]
statuses  = String[string(_get(dr, :status, "unknown")) for dr in degree_results]

# Recovery error — may be nothing per degree
rec_errs = Union{Float64,Nothing}[_get(dr, :recovery_error, nothing) for dr in degree_results]
has_recovery = any(!isnothing, rec_errs) && p_true !== nothing

# Success mask
success = [s == "success" for s in statuses]

# ── Figure 1: L² convergence ──────────────────────────────────────────────────

fig1 = Figure(size=(800, 450), fontsize=14)

ax1 = Axis(fig1[1, 1];
    title       = "$experiment_name — Approximation Error",
    xlabel      = "Polynomial Degree",
    ylabel      = "L² Approximation Error",
    yscale      = log10,
    xgridvisible = true, ygridvisible = true,
    xgridstyle  = :dash, ygridstyle = :dash,
    xticks      = degrees,
)

# L² error
valid_l2 = [(d, e) for (d, e, s) in zip(degrees, l2_errs, success) if s && isfinite(e) && e > 0]
if !isempty(valid_l2)
    scatterlines!(ax1, first.(valid_l2), last.(valid_l2);
        color=:royalblue, markersize=10, linewidth=2.5, label="L² error")
end

# Relative L²
valid_rel = [(d, e) for (d, e, s) in zip(degrees, rel_l2, success) if s && isfinite(e) && e > 0]
if !isempty(valid_rel)
    scatterlines!(ax1, first.(valid_rel), last.(valid_rel);
        color=:darkorange, markersize=10, linewidth=2.5, linestyle=:dash,
        label="Relative L²")
end

# Failed degree markers
failed_degs = [d for (d, s) in zip(degrees, statuses) if s == "failed"]
if !isempty(failed_degs)
    vlines!(ax1, failed_degs; color=(:red, 0.4), linestyle=:dot, linewidth=1.5)
end

axislegend(ax1; position=:rt, framevisible=true, backgroundcolor=(:white, 0.9))

conv_path = joinpath(plot_dir, "convergence.png")
save(conv_path, fig1; px_per_unit=2)
println("Saved: $conv_path")

# ── Figure 2: Recovery error ──────────────────────────────────────────────────

if has_recovery
    fig2 = Figure(size=(800, 450), fontsize=14)
    ax2 = Axis(fig2[1, 1];
        title       = "$experiment_name — Parameter Recovery",
        xlabel      = "Polynomial Degree",
        ylabel      = "‖best_estimate − p_true‖",
        yscale      = log10,
        xgridvisible = true, ygridvisible = true,
        xgridstyle  = :dash, ygridstyle = :dash,
        xticks      = degrees,
    )

    valid_rec = [(d, r) for (d, r, s) in zip(degrees, rec_errs, success)
                 if s && !isnothing(r) && isfinite(r) && r > 0]
    if !isempty(valid_rec)
        scatterlines!(ax2, first.(valid_rec), last.(valid_rec);
            color=:seagreen, markersize=10, linewidth=2.5, label="Recovery error")
    end

    # 5% relative threshold if p_true has a norm
    p_true_norm = norm(Float64.(p_true))
    if p_true_norm > 0
        hlines!(ax2, [0.05 * p_true_norm];
            color=(:red, 0.7), linestyle=:dash, linewidth=1.5,
            label="5% threshold")
    end

    if !isempty(failed_degs)
        vlines!(ax2, failed_degs; color=(:red, 0.4), linestyle=:dot, linewidth=1.5)
    end

    axislegend(ax2; position=:rt, framevisible=true, backgroundcolor=(:white, 0.9))

    rec_path = joinpath(plot_dir, "recovery.png")
    save(rec_path, fig2; px_per_unit=2)
    println("Saved: $rec_path")
else
    println("Skipped: recovery.png (no p_true or recovery errors available)")
end

# ── Figure 3: #CPs + timing ───────────────────────────────────────────────────

fig3 = Figure(size=(800, 500), fontsize=14)

ax3a = Axis(fig3[1, 1];
    title       = "$experiment_name — Critical Points & Timing",
    xlabel      = "Polynomial Degree",
    ylabel      = "# Critical Points",
    xgridvisible = true, ygridvisible = false,
    xgridstyle  = :dash,
    xticks      = degrees,
)

ax3b = Axis(fig3[1, 1];
    ylabel      = "Computation Time (s)",
    yaxisposition = :right,
    yticklabelcolor = :darkorange,
    ylabelcolor     = :darkorange,
)

# Hide ax3b spines / grid to avoid clutter
ax3b.xgridvisible = false
ax3b.ygridvisible = false
hidespines!(ax3b, :l, :t)
hidespines!(ax3a, :r)

barplot!(ax3a, degrees, n_cps;
    color=:steelblue, gap=0.2, label="#CPs")
scatterlines!(ax3b, degrees, times;
    color=:darkorange, markersize=9, linewidth=2, linestyle=:dash, label="Time (s)")

# Legend entries — manual since two axes
elem1 = PolyElement(color=:steelblue)
elem2 = LineElement(color=:darkorange, linestyle=:dash)
Legend(fig3[1, 2], [elem1, elem2], ["#CPs", "Time (s)"];
    framevisible=true, backgroundcolor=(:white, 0.9))

cps_path = joinpath(plot_dir, "cps.png")
save(cps_path, fig3; px_per_unit=2)
println("Saved: $cps_path")

println("\nDone. Figures in: $plot_dir")
