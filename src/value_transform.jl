# value_transform.jl
#
# Monotone reparametrisation of the objective before the polynomial fit.
#
# Critical points and Morse indices are invariant under f ↦ g∘f whenever g is strictly
# increasing: ∇(g∘f) = g'(f)∇f vanishes exactly where ∇f does, and at such a point
# ∇²(g∘f) = g'(f)∇²f (the g''∇f∇fᵀ term is zero), so the inertia of the Hessian is
# unchanged. The fit, however, is not invariant: an L² misfit landscape with values
# spanning 1e-2 … 1e6 has algebraic Chebyshev coefficient decay dominated by its peaks,
# while asinh((f − f_min)/s) is O(1) near the minima and only logarithmic on the peaks,
# so the same degree buys far more accuracy where the critical points live.
#
# The pipeline fits g∘f and solves the surrogate's critical points; objective values
# reported at those points are computed with the ORIGINAL f (see run_standard_experiment).
#
# Transforms are plain structs so ForwardDiff sees ordinary generic arithmetic.

"""
    AbstractValueTransform

A strictly increasing map `g : I → ℝ` on an interval `I ⊇ range(f)`. Subtypes implement
[`apply`](@ref), [`invert`](@ref), [`derivative`](@ref) and `domain_lower`.
"""
abstract type AbstractValueTransform end

"""
    IdentityTransform()

`g(v) = v`. Exists so a pipeline can carry a transform slot uniformly.
"""
struct IdentityTransform <: AbstractValueTransform end

"""
    AsinhTransform(scale; shift = 0.0)

`g(v) = asinh((v − shift)/scale)`: linear with slope `1/scale` for `|v − shift| ≲ scale`,
logarithmic beyond. Defined on all of ℝ, so `Inf` penalties and negative values pass
through, which makes it the default choice for misfit landscapes. `scale` must be
positive; pick it with [`fit_value_transform`](@ref) (median of `f − min f` on a pilot
sample) so the basin of the global minimum stays in the linear regime.
"""
struct AsinhTransform <: AbstractValueTransform
    scale::Float64
    shift::Float64
    function AsinhTransform(scale::Real; shift::Real = 0.0)
        scale > 0 || throw(ArgumentError("AsinhTransform: scale must be positive, got $scale"))
        isfinite(shift) || throw(ArgumentError("AsinhTransform: shift must be finite, got $shift"))
        new(Float64(scale), Float64(shift))
    end
end

"""
    LogTransform(shift; floor)

`g(v) = log(v − shift + floor)`, defined for `v > shift − floor`. `floor > 0` keeps the
argument away from zero at the global minimum `v = shift`; the transformed landscape is
then `log(floor)` at the minimum and grows like `log(v)` on the peaks. Harsher than
[`AsinhTransform`](@ref) and undefined below `shift − floor`, so it is only for
objectives known to be bounded below (an L² misfit with `shift = 0`).
"""
struct LogTransform <: AbstractValueTransform
    shift::Float64
    floor::Float64
    function LogTransform(shift::Real; floor::Real)
        floor > 0 || throw(ArgumentError("LogTransform: floor must be positive, got $floor"))
        isfinite(shift) || throw(ArgumentError("LogTransform: shift must be finite, got $shift"))
        new(Float64(shift), Float64(floor))
    end
end

"""
    SqrtTransform(shift)

`g(v) = sqrt(v − shift)` for `v ≥ shift`. Turns a sum of squares into a norm-like
quantity: a non-degenerate minimum of `f` at value `shift` becomes a cone (non-smooth)
in `g∘f`, so use it only when `shift` is strictly below the minimum of `f`.
"""
struct SqrtTransform <: AbstractValueTransform
    shift::Float64
    function SqrtTransform(shift::Real)
        isfinite(shift) || throw(ArgumentError("SqrtTransform: shift must be finite, got $shift"))
        new(Float64(shift))
    end
end

# ---- evaluation -------------------------------------------------------------------------

"""
    apply(t::AbstractValueTransform, v)

`g(v)`. Generic in `v` so ForwardDiff duals propagate.
"""
apply(::IdentityTransform, v) = v
apply(t::AsinhTransform, v) = asinh((v - t.shift) / t.scale)
apply(t::LogTransform, v) = log(v - t.shift + t.floor)
apply(t::SqrtTransform, v) = sqrt(v - t.shift)

"""
    invert(t::AbstractValueTransform, y)

`g⁻¹(y)`; `invert(t, apply(t, v)) ≈ v` on the domain of `t`.
"""
invert(::IdentityTransform, y) = y
invert(t::AsinhTransform, y) = t.scale * sinh(y) + t.shift
invert(t::LogTransform, y) = exp(y) + t.shift - t.floor
invert(t::SqrtTransform, y) = y^2 + t.shift

"""
    derivative(t::AbstractValueTransform, v)

`g'(v) > 0`. At a critical point of `f` the Hessian of `g∘f` is `g'(f)·∇²f`, so this
factor converts surrogate Hessian eigenvalues back to the scale of `f`.
"""
derivative(::IdentityTransform, v) = one(v)
derivative(t::AsinhTransform, v) = 1 / sqrt(t.scale^2 + (v - t.shift)^2)
derivative(t::LogTransform, v) = 1 / (v - t.shift + t.floor)
derivative(t::SqrtTransform, v) = 1 / (2 * sqrt(v - t.shift))

"""
    domain_lower(t::AbstractValueTransform) -> Float64

Infimum of the interval on which `t` is defined (`-Inf` for `Identity`/`Asinh`).
"""
domain_lower(::IdentityTransform) = -Inf
domain_lower(::AsinhTransform) = -Inf
domain_lower(t::LogTransform) = t.shift - t.floor
domain_lower(t::SqrtTransform) = t.shift

# ---- wrapper ----------------------------------------------------------------------------

"""
    TransformedObjective(f, t::AbstractValueTransform)

Callable `x ↦ apply(t, f(x))`. `f` is any 1-argument objective (scalar or vector input,
AD-compatible); the wrapper is itself AD-compatible. Recover the pieces with
[`original_objective`](@ref) and [`value_transform`](@ref).

A value of `f` below `domain_lower(t)` is an error, never a silent clamp: it means the
transform was fitted on a pilot sample that missed the true range of `f`.
"""
struct TransformedObjective{F,T<:AbstractValueTransform}
    f::F
    t::T
end

# Strip (possibly nested) ForwardDiff duals down to the primal value.
_primal(v::ForwardDiff.Dual) = _primal(ForwardDiff.value(v))
_primal(v) = v

function (o::TransformedObjective)(x)
    v = o.f(x)
    lo = domain_lower(o.t)
    if isfinite(lo)
        vv = _primal(v)
        vv >= lo || error(
            "TransformedObjective: objective value $(vv) is below the transform domain " *
            "lower bound $(lo); refit the transform on a pilot sample covering the range of f",
        )
    end
    return apply(o.t, v)
end

original_objective(o::TransformedObjective) = o.f
original_objective(f) = f
value_transform(o::TransformedObjective) = o.t
value_transform(::Any) = IdentityTransform()

# ---- fitting ----------------------------------------------------------------------------

"""
    fit_value_transform(values; kind = :asinh, quantile = 0.5, floor_quantile = 0.05) -> AbstractValueTransform

Choose a transform from a pilot sample of objective values (a coarse grid, or the `z`
field of a low-degree `ApproxPoly`). Non-finite values are ignored; if fewer than two
finite values remain, or they are all equal, an `IdentityTransform` is returned.

- `:asinh` — `shift = min(values)`, `scale = quantile(values − shift, quantile)`, so the
  lowest `quantile` fraction of the pilot sample lies in the linear regime and the rest is
  compressed logarithmically. This is the recommended default for misfit landscapes.
- `:log` — `shift = min(values)`, `floor = quantile(values − shift, floor_quantile)`,
  clamped to a positive value. Requires the pilot minimum to be the global minimum, since
  `log` is undefined below `shift − floor`.
- `:sqrt` — `shift = min(values) − floor` with the same `floor`.
- `:identity` — no transform.
"""
function fit_value_transform(
    values::AbstractVector{<:Real};
    kind::Symbol = :asinh,
    quantile::Real = 0.5,
    floor_quantile::Real = 0.05,
)
    kind in (:asinh, :log, :sqrt, :identity) || throw(
        ArgumentError("fit_value_transform: kind must be :asinh, :log, :sqrt or :identity, got :$kind"),
    )
    0 < quantile <= 1 || throw(ArgumentError("quantile must lie in (0, 1], got $quantile"))
    0 < floor_quantile <= 1 ||
        throw(ArgumentError("floor_quantile must lie in (0, 1], got $floor_quantile"))
    kind === :identity && return IdentityTransform()

    finite = Float64[Float64(v) for v in values if isfinite(v)]
    length(finite) >= 2 || return IdentityTransform()
    vmin = minimum(finite)
    excess = sort!(finite .- vmin)
    excess[end] > 0 || return IdentityTransform()   # constant pilot sample

    # quantile of the positive excesses (zero excess at the minimum would give scale 0)
    positive = filter(>(0), excess)
    q(p) = positive[clamp(ceil(Int, p * length(positive)), 1, length(positive))]

    if kind === :asinh
        return AsinhTransform(q(quantile); shift = vmin)
    elseif kind === :log
        return LogTransform(vmin; floor = q(floor_quantile))
    else
        fl = q(floor_quantile)
        return SqrtTransform(vmin - fl)
    end
end

"""
    transform_summary(t::AbstractValueTransform) -> Dict{String,Any}

Serialisable description for run metadata.
"""
transform_summary(::IdentityTransform) = Dict{String,Any}("kind" => "identity")
transform_summary(t::AsinhTransform) =
    Dict{String,Any}("kind" => "asinh", "scale" => t.scale, "shift" => t.shift)
transform_summary(t::LogTransform) =
    Dict{String,Any}("kind" => "log", "shift" => t.shift, "floor" => t.floor)
transform_summary(t::SqrtTransform) = Dict{String,Any}("kind" => "sqrt", "shift" => t.shift)
