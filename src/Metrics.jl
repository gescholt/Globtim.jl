"""
    Metrics

Structured per-leaf / per-CP JSON-Lines writer for Globtim smoke experiments
and audit drivers. Sibling of [`EnhancedMetrics`](@ref) — `EnhancedMetrics`
collects post-hoc reproducibility metadata + polynomial quality summaries;
`Metrics` writes a streaming JSONL log over the course of a run, one row per
phase / leaf / critical point.

# Row kinds

Every row carries a `kind` field in `{"meta", "phase", "leaf", "cp"}`. The
remaining fields are kind-specific.

# Primitives

  - [`MetricsLogger`](@ref)`(path; run_id=...)` — open `path` (truncates),
    emit a `meta` row, return a logger handle. Thread-safe under a module-local
    lock.
  - [`log_phase!`](@ref)`(logger, phase; extra=Dict())` — phase-summary row.
  - [`log_leaf!`](@ref)`(logger, leaf_id; depth, bounds, degree, rel_l2,
    n_raw_cps, hc_solve_seconds=nothing, n_eval_failures=nothing,
    n_grid_evals=nothing, n_inbox_cps=nothing, extra=Dict())` — per-leaf row.
  - [`log_cp!`](@ref)`(logger, cp_kind; ...)` — per-critical-point row,
    `cp_kind ∈ ("raw", "refined")`.
  - [`dedup_with_groups`](@ref)`(pts, tol)` — clustering with parallel-output
    group attribution so the JSONL records every input + a canonical-rep flag,
    rather than dropping duplicates silently.

# Example

```julia
using Globtim: Metrics as MET
logger = MET.MetricsLogger("_generated/run_xyz/metrics.jsonl")
MET.log_phase!(logger, "start"; extra=Dict(:degree=>3, :l2_tol=>1e-2))
```

# JSONL queries via `jq`

```sh
jq -r 'select(.kind=="leaf") | [.leaf_id, .depth, .rel_l2, .n_raw_cps] | @tsv' metrics.jsonl
jq -r 'select(.kind=="cp" and .cp_kind=="refined" and .dedup_canonical) | .dv' metrics.jsonl
```
"""
module Metrics

using Dates

export MetricsLogger, log_phase!, log_leaf!, log_cp!, dedup_with_groups

const METRICS_LOCK = ReentrantLock()

mutable struct MetricsLogger
    path::String
    run_id::String
    n_rows::Int
end

"""
    MetricsLogger(path; run_id=auto)

Open `path` for writing (truncates any existing file), emit a `meta` row, and
return a logger handle. `run_id` defaults to a timestamp-based slug.
"""
function MetricsLogger(
    path::AbstractString;
    run_id::AbstractString = "run-" * Dates.format(now(), "yyyymmdd-HHMMSS"),
)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
    end
    logger = MetricsLogger(String(path), String(run_id), 0)
    _write_row!(
        logger,
        Dict{Symbol,Any}(
            :kind => "meta",
            :run_id => logger.run_id,
            :started_at => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
            :julia_version => string(VERSION),
            :hostname => gethostname(),
            :n_threads => Threads.nthreads(),
        ),
    )
    return logger
end

"""
    log_phase!(logger, phase; extra=Dict())

Append a phase-summary row.
"""
function log_phase!(
    logger::MetricsLogger,
    phase::AbstractString;
    extra::AbstractDict = Dict{Symbol,Any}(),
)
    row = Dict{Symbol,Any}(
        :kind => "phase",
        :run_id => logger.run_id,
        :phase => phase,
        :ts => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
    )
    _merge_extra!(row, extra)
    _write_row!(logger, row)
end

"""
    log_leaf!(logger, leaf_id; depth, bounds, degree, rel_l2, n_raw_cps,
              hc_solve_seconds=nothing, n_eval_failures=nothing,
              n_grid_evals=nothing, n_inbox_cps=nothing, extra=Dict())

Append a per-leaf row. `bounds` is serialized as a nested JSON array.
`n_eval_failures` is the count of post-hoc grid-evaluation failures on this
leaf (e.g. Lambert-solve failures for porkchop, ODE-solve failures for
rational-ODE workloads); `n_grid_evals` is the total grid-node count. Both
are nullable for drivers that don't compute them.
"""
function log_leaf!(
    logger::MetricsLogger,
    leaf_id::Integer;
    depth::Integer,
    bounds,
    degree::Integer,
    rel_l2::Real,
    n_raw_cps::Integer,
    hc_solve_seconds::Union{Real,Nothing} = nothing,
    n_eval_failures::Union{Integer,Nothing} = nothing,
    n_grid_evals::Union{Integer,Nothing} = nothing,
    n_inbox_cps::Union{Integer,Nothing} = nothing,
    extra::AbstractDict = Dict{Symbol,Any}(),
)
    row = Dict{Symbol,Any}(
        :kind => "leaf",
        :run_id => logger.run_id,
        :leaf_id => Int(leaf_id),
        :depth => Int(depth),
        :bounds => _normalize_bounds(bounds),
        :degree => Int(degree),
        :rel_l2 => Float64(rel_l2),
        :n_raw_cps => Int(n_raw_cps),
    )
    hc_solve_seconds !== nothing && (row[:hc_solve_seconds] = Float64(hc_solve_seconds))
    n_eval_failures !== nothing && (row[:n_eval_failures] = Int(n_eval_failures))
    n_grid_evals !== nothing && (row[:n_grid_evals] = Int(n_grid_evals))
    n_inbox_cps !== nothing && (row[:n_inbox_cps] = Int(n_inbox_cps))
    _merge_extra!(row, extra)
    _write_row!(logger, row)
end

"""
    log_cp!(logger, cp_kind; leaf_id=nothing, dep_day, tof_day, dv,
            type_label=nothing, is_boundary=nothing,
            dedup_group=nothing, dedup_canonical=nothing, extra=Dict())

Append a per-CP row. `cp_kind` is "raw" or "refined".

Field names `dep_day` / `tof_day` are porkchop-flavoured but the writer is
agnostic — pass any 2D coordinate pair. For higher-dimensional CPs, supply
the additional coordinates via `extra`.
"""
function log_cp!(
    logger::MetricsLogger,
    cp_kind::AbstractString;
    leaf_id::Union{Integer,Nothing} = nothing,
    dep_day::Real,
    tof_day::Real,
    dv::Real,
    type_label::Union{AbstractString,Nothing} = nothing,
    is_boundary::Union{Bool,Nothing} = nothing,
    dedup_group::Union{Integer,Nothing} = nothing,
    dedup_canonical::Union{Bool,Nothing} = nothing,
    extra::AbstractDict = Dict{Symbol,Any}(),
)
    row = Dict{Symbol,Any}(
        :kind => "cp",
        :cp_kind => String(cp_kind),
        :run_id => logger.run_id,
        :dep_day => Float64(dep_day),
        :tof_day => Float64(tof_day),
        :dv => Float64(dv),
    )
    leaf_id !== nothing && (row[:leaf_id] = Int(leaf_id))
    type_label !== nothing && (row[:type_label] = String(type_label))
    is_boundary !== nothing && (row[:is_boundary] = Bool(is_boundary))
    dedup_group !== nothing && (row[:dedup_group] = Int(dedup_group))
    dedup_canonical !== nothing && (row[:dedup_canonical] = Bool(dedup_canonical))
    _merge_extra!(row, extra)
    _write_row!(logger, row)
end

"""
    dedup_with_groups(pts, tol) -> (; group_ids, canonical, rep_indices)

Cluster `pts` by ball-of-radius-`tol` containment, in input order. Two
points land in the same group iff their Euclidean distance is `< tol` and at
least one of them is the cluster's representative (first observed point).

Returns three parallel arrays:
- `group_ids[i]`     : 1-based group id of `pts[i]`
- `canonical[i]`     : `true` iff `pts[i]` is the rep of its group
- `rep_indices[g]`   : index in `pts` of the rep of group `g`
"""
function dedup_with_groups(pts::Vector{<:AbstractVector{<:Real}}, tol::Real)
    n = length(pts)
    group_ids = zeros(Int, n)
    canonical = falses(n)
    rep_indices = Int[]
    for (i, pt) in enumerate(pts)
        matched = 0
        for (gid, ri) in enumerate(rep_indices)
            if _euclid(pt, pts[ri]) < tol
                matched = gid
                break
            end
        end
        if matched == 0
            push!(rep_indices, i)
            group_ids[i] = length(rep_indices)
            canonical[i] = true
        else
            group_ids[i] = matched
        end
    end
    return (; group_ids, canonical, rep_indices)
end

# ── Internals ────────────────────────────────────────────────────────────────

function _euclid(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    s = 0.0
    @inbounds for i in eachindex(a)
        d = a[i] - b[i]
        s += d * d
    end
    return sqrt(s)
end

function _merge_extra!(row::AbstractDict, extra::AbstractDict)
    for (k, v) in extra
        row[Symbol(k)] = v
    end
end

function _normalize_bounds(b)
    out = Vector{Vector{Float64}}(undef, length(b))
    @inbounds for i in eachindex(b)
        bi = b[i]
        out[i] = [Float64(bi[1]), Float64(bi[2])]
    end
    return out
end

function _write_row!(logger::MetricsLogger, row::AbstractDict)
    lock(METRICS_LOCK) do
        open(logger.path, "a") do io
            println(io, _to_json(row))
        end
        logger.n_rows += 1
    end
end

function _to_json(x)
    if x isa AbstractDict
        parts = String[]
        for k in sort(collect(keys(x)); by = string)
            push!(parts, _json_str(string(k)) * ":" * _to_json(x[k]))
        end
        return "{" * join(parts, ",") * "}"
    elseif x isa AbstractVector
        return "[" * join((_to_json(v) for v in x), ",") * "]"
    elseif x isa Tuple
        return "[" * join((_to_json(v) for v in x), ",") * "]"
    elseif x isa Bool
        return x ? "true" : "false"
    elseif x isa Integer
        return string(x)
    elseif x isa AbstractFloat
        if isnan(x)
            return "null"
        elseif isinf(x)
            return x > 0 ? "\"+Inf\"" : "\"-Inf\""
        else
            return string(x)
        end
    elseif x isa AbstractString || x isa Symbol
        return _json_str(string(x))
    elseif x === nothing
        return "null"
    else
        return _json_str(string(x))
    end
end

function _json_str(s::AbstractString)
    escaped = replace(
        s,
        "\\" => "\\\\",
        "\"" => "\\\"",
        "\n" => "\\n",
        "\t" => "\\t",
        "\r" => "\\r",
    )
    return "\"" * escaped * "\""
end

end  # module Metrics
