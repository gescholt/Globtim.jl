# admissibility.jl
#
# N3 of docs/research/plans/EVIDENCE_MAP_2026-10.md: the penalty-node admissibility gate
# on the single-domain fit. A grid value that is the objective's registered penalty, is
# not finite, or exceeds a dynamic-range cap is not a sample of the landscape: a
# least-squares fit through it is a fit of the wall, not of f. The record: 58 % penalty
# nodes on the PMP cone box stall the relative L2 at 0.19–0.28, 5.6 % at 0.18, 0 % at
# 0.015 (`pkg/Opt_Traj/.claude/CLAUDE.md`); LV2D_1 and FHN3D_1 draws reach f ~ 1e18 and
# 1e113 inside the box and "reported local minima there are plateau noise". The
# subdivision path masks such leaves (`barrier_mask.jl`); the single-domain path had no
# gate and the L2 norm was the only thing that failed, late and without a count.
#
# The gate counts and RAISES (`InadmissibleGridError`, counts in the message); it never
# substitutes a value. Non-finite values are always counted; the penalty and the cap are
# opt-in because Globtim has no registry of an objective's penalty value — callers pass
# `barrier_value(obj)` (Opt_Traj) or whatever sentinel their objective returns.

"""
    InadmissibleGridError(n_total, n_nonfinite, n_penalty, n_above_cap, penalty_value, max_abs_value)

Raised by [`check_grid_admissibility`](@ref) when a fit grid holds values that are not
samples of the landscape. The counts are the message.
"""
struct InadmissibleGridError <: Exception
    n_total::Int
    n_nonfinite::Int
    n_penalty::Int
    n_above_cap::Int
    penalty_value::Union{Nothing,Float64}
    max_abs_value::Float64
end

function Base.showerror(io::IO, e::InadmissibleGridError)
    parts = String[]
    e.n_nonfinite > 0 && push!(parts, "$(e.n_nonfinite) non-finite")
    e.n_penalty > 0 &&
        push!(parts, "$(e.n_penalty) at the penalty value $(e.penalty_value)")
    e.n_above_cap > 0 && push!(parts, "$(e.n_above_cap) with |f| > $(e.max_abs_value)")
    print(
        io,
        "InadmissibleGridError: $(join(parts, ", ")) of $(e.n_total) grid values; ",
        "the fit would be a fit of the penalty wall, not of the objective. ",
        "Shrink or move the box (the subdivision path masks such leaves with barrier_mask.jl), ",
        "or pass admissibility = false to fit anyway.",
    )
end

"""
    grid_admissibility(F; penalty_value = nothing, max_abs_value = Inf, rtol = 1e-3, atol = 1e-9)
        -> (; n_total, n_nonfinite, n_penalty, n_above_cap, admissible)

Count the grid values that are not samples of the landscape: non-finite ones, those equal
to `penalty_value` (`isapprox` with `rtol`/`atol`, the same match `penalty_barrier_detector`
uses), and those with `|f| > max_abs_value`. A value is counted once, in the first class
that applies. `admissible` is `true` iff every count is zero.
"""
function grid_admissibility(
    F::AbstractVector{<:Real};
    penalty_value::Union{Nothing,Real} = nothing,
    max_abs_value::Real = Inf,
    rtol::Real = 1e-3,
    atol::Real = 1e-9,
)
    max_abs_value > 0 ||
        throw(ArgumentError("max_abs_value must be > 0, got $max_abs_value"))
    pv = penalty_value === nothing ? nothing : Float64(penalty_value)
    cap = Float64(max_abs_value)
    n_nonfinite = 0
    n_penalty = 0
    n_above_cap = 0
    for v in F
        x = Float64(v)
        if !isfinite(x)
            n_nonfinite += 1
        elseif pv !== nothing && isapprox(x, pv; rtol = rtol, atol = atol)
            n_penalty += 1
        elseif abs(x) > cap
            n_above_cap += 1
        end
    end
    return (
        n_total = length(F),
        n_nonfinite = n_nonfinite,
        n_penalty = n_penalty,
        n_above_cap = n_above_cap,
        admissible = n_nonfinite == 0 && n_penalty == 0 && n_above_cap == 0,
    )
end

"""
    check_grid_admissibility(F; penalty_value = nothing, max_abs_value = Inf, kwargs...)

[`grid_admissibility`](@ref), raising [`InadmissibleGridError`](@ref) when any count is
nonzero. Returns the counts otherwise.
"""
function check_grid_admissibility(
    F::AbstractVector{<:Real};
    penalty_value::Union{Nothing,Real} = nothing,
    max_abs_value::Real = Inf,
    kwargs...,
)
    a = grid_admissibility(
        F;
        penalty_value = penalty_value,
        max_abs_value = max_abs_value,
        kwargs...,
    )
    a.admissible || throw(
        InadmissibleGridError(
            a.n_total,
            a.n_nonfinite,
            a.n_penalty,
            a.n_above_cap,
            penalty_value === nothing ? nothing : Float64(penalty_value),
            Float64(max_abs_value),
        ),
    )
    return a
end
