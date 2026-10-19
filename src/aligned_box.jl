# aligned_box.jl
#
# N2 of docs/research/plans/EVIDENCE_MAP_2026-10.md: boxes aligned with the Hessian
# eigenbasis, and the boundary-outflow measurement that says whether a box is closed.
#
# Poincaré–Hopf forces Σ(−1)^index = 1 on a box only when the gradient points outward
# everywhere on its boundary. Measured on all 47 instances of the LV landscape atlas,
# no axis-aligned box is closed (outflow 0.668–0.934), and the reason is geometric,
# not a matter of size: near a minimum ∇f ≈ Hδ, so on the face δ_k = +a the normal
# derivative is H_kk·a + Σ_{j≠k} H_kj·δ_j, and when an off-diagonal dominates H_kk the
# sign flips at EVERY scale (0.8928 outflow at half-widths 1e0 … 1e-6 on a rotated
# quadratic with eigenvalues 1 and 1e4; 1.0000 for the box aligned with the
# eigenvectors; shaping the aspect ratio without rotating: 0.7529).
# experiments/sandbox/lv_landscape_atlas/README.md:53-93,
# experiments/sandbox/lv_landscape_atlas/BOUNDARY_AND_SUBDIVISION.md:44-74.
#
# So the certificate needs the rotation, and the rotation is cheap: one Hessian of f
# at the candidate minimum, and the pipeline run on g(y) = f(x* + Q y) instead of f.
# Critical points and Morse indices are invariant under the orthogonal change of
# variables; the surrogate is fitted on the aligned box, the strata census
# (box_strata_census.jl) and the open index sum are then statements about a box that
# can actually be closed.

"""
    AlignedBox(center, Q, half_widths, eigenvalues)

A box `{center + Q·y : |y_k| ≤ half_widths[k]}` whose axes are the columns of the
orthogonal matrix `Q` (ascending Hessian eigenvalues when built by
[`eigen_aligned_box`](@ref); `eigenvalues` records them). `Q = I` is an ordinary
axis-aligned box, so every function here also serves the unrotated case.
"""
struct AlignedBox
    center::Vector{Float64}
    Q::Matrix{Float64}
    half_widths::Vector{Float64}
    eigenvalues::Vector{Float64}
    function AlignedBox(
        center::AbstractVector{<:Real},
        Q::AbstractMatrix{<:Real},
        half_widths::AbstractVector{<:Real},
        eigenvalues::AbstractVector{<:Real} = fill(NaN, length(center)),
    )
        n = length(center)
        size(Q) == (n, n) || throw(DimensionMismatch("Q must be $n×$n, got $(size(Q))"))
        length(half_widths) == n || throw(
            DimensionMismatch("half_widths has $(length(half_widths)) entries for n = $n"),
        )
        all(>(0), half_widths) || throw(ArgumentError("half_widths must be positive"))
        isapprox(Q' * Q, I; atol = 1e-10) ||
            throw(ArgumentError("Q is not orthogonal (‖QᵀQ − I‖ = $(norm(Q' * Q - I)))"))
        new(
            Vector{Float64}(center),
            Matrix{Float64}(Q),
            Vector{Float64}(half_widths),
            Vector{Float64}(eigenvalues),
        )
    end
end

Base.ndims(b::AlignedBox) = length(b.center)

"""
    axis_aligned_box(bounds::Vector{Tuple{Float64,Float64}}) -> AlignedBox

The ordinary box of `run_standard_experiment` (`Q = I`), for measuring its outflow with
the same code as the rotated one.
"""
function axis_aligned_box(bounds::AbstractVector{<:Tuple{<:Real,<:Real}})
    n = length(bounds)
    c = [(lo + hi) / 2 for (lo, hi) in bounds]
    h = [(hi - lo) / 2 for (lo, hi) in bounds]
    return AlignedBox(c, Matrix{Float64}(I, n, n), h)
end

"""
    eigen_aligned_box(f, x_star; half_widths, hessian = nothing, shape = :isotropic) -> AlignedBox

Box about the candidate minimum `x_star` whose axes are the eigenvectors of the Hessian
of `f` there (`ForwardDiff.hessian`, or `hessian` when supplied, e.g. from the audit).

- `half_widths`: a scalar (same half-width along every eigen-axis) or a vector in the
  eigen-frame, ordered by ascending eigenvalue.
- `shape = :isotropic` keeps the half-widths as given; `:eigen` scales them by
  `sqrt(λ_max / |λ_k|)` (clipped at a 1e3 ratio), i.e. wider along the flat directions,
  so the box is a level-set-shaped window rather than a cube. The atlas measurement says
  alignment is what closes a box and shape is secondary; `:eigen` is the option for
  sloppy landscapes whose flat directions would otherwise leave the box immediately.

The Hessian must be finite; an indefinite Hessian (x_star is not a minimum) is allowed
— the eigenvectors still define a frame — and is reported through `eigenvalues`.
"""
function eigen_aligned_box(
    f,
    x_star::AbstractVector{<:Real};
    half_widths::Union{Real,AbstractVector{<:Real}},
    hessian::Union{Nothing,AbstractMatrix{<:Real}} = nothing,
    shape::Symbol = :isotropic,
)
    shape in (:isotropic, :eigen) ||
        throw(ArgumentError("shape must be :isotropic or :eigen, got :$shape"))
    x0 = Vector{Float64}(x_star)
    n = length(x0)
    H = hessian === nothing ? ForwardDiff.hessian(f, x0) : Matrix{Float64}(hessian)
    all(isfinite, H) || error("eigen_aligned_box: Hessian of f at $(x0) is not finite")
    E = eigen(Symmetric(H))
    λ = E.values            # ascending
    Q = Matrix{Float64}(E.vectors)
    h = half_widths isa Real ? fill(Float64(half_widths), n) : Vector{Float64}(half_widths)
    length(h) == n ||
        throw(DimensionMismatch("half_widths has $(length(h)) entries for n = $n"))
    if shape == :eigen
        λmax = maximum(abs, λ)
        λmax > 0 || error("eigen_aligned_box: zero Hessian, cannot shape by eigenvalues")
        scale = [sqrt(λmax / max(abs(λk), λmax / 1e6)) for λk in λ]
        scale = min.(scale, 1e3)
        h = h .* scale
    end
    return AlignedBox(x0, Q, h, λ)
end

"""
    to_physical(b::AlignedBox, y) -> x
    to_aligned(b::AlignedBox, x) -> y

`x = center + Q·y` and its inverse `y = Qᵀ(x − center)`. Generic in the element type
(Dual-friendly).
"""
to_physical(b::AlignedBox, y::AbstractVector) = b.center .+ b.Q * y
to_aligned(b::AlignedBox, x::AbstractVector) = b.Q' * (x .- b.center)

"""
    aligned_bounds(b::AlignedBox) -> Vector{Tuple{Float64,Float64}}

The box in its own frame: `[(−h_k, h_k)]`. This is what `run_standard_experiment`
receives as `bounds` when it runs in the aligned frame.
"""
aligned_bounds(b::AlignedBox) = [(-h, h) for h in b.half_widths]

"""
    AlignedObjective(f, box)

Callable `y ↦ f(to_physical(box, y))`: the objective in the aligned frame. Critical
points and Morse indices correspond one-to-one with those of `f` under
`to_physical`/`to_aligned` (orthogonal change of variables: `∇g = Qᵀ∇f`,
`∇²g = Qᵀ ∇²f Q`).
"""
struct AlignedObjective{F}
    f::F
    box::AlignedBox
end
(o::AlignedObjective)(y::AbstractVector) = o.f(to_physical(o.box, y))

"""
    box_outflow(f, b::AlignedBox; n_samples = 64, rng = MersenneTwister(0)) -> NamedTuple

Fraction of the boundary of `b` on which the gradient of `f` points outward, sampled
with `n_samples` points per face (`2n` faces). In the box's own frame the outward normal
of face `y_k = ±h_k` is `±e_k` and `⟨∇f, n⟩ = ±(Qᵀ∇f)_k`.

Returns `(fraction, min_cos, n_faces_closed, samples)`: `fraction` is the outflow
(`1.0` ⇔ closed, the Poincaré–Hopf precondition); `min_cos` the most inward
`⟨∇f, n⟩/‖∇f‖` seen; `n_faces_closed` the number of faces with no inward sample.
Deterministic for a given `rng`. Same definition as `measure_outflow.jl` /
`BioObjectives.boundary_outflow`, extended to rotated boxes.
"""
function box_outflow(
    f,
    b::AlignedBox;
    n_samples::Int = 64,
    rng::Random.AbstractRNG = Random.MersenneTwister(0),
)
    n_samples >= 1 || throw(ArgumentError("n_samples must be ≥ 1"))
    n = ndims(b)
    total = 0
    outward = 0
    min_cos = Inf
    faces_closed = 0
    for k in 1:n, sgn in (-1.0, 1.0)
        face_inward = 0
        for _ in 1:n_samples
            y = (2 .* rand(rng, n) .- 1) .* b.half_widths
            y[k] = sgn * b.half_widths[k]
            g = ForwardDiff.gradient(f, to_physical(b, y))
            all(isfinite, g) ||
                error("box_outflow: gradient of f is not finite at $(to_physical(b, y))")
            gy = b.Q' * g
            dot_n = sgn * gy[k]
            total += 1
            if dot_n > 0
                outward += 1
            else
                face_inward += 1
            end
            ng = norm(g)
            ng > 0 && (min_cos = min(min_cos, dot_n / ng))
        end
        face_inward == 0 && (faces_closed += 1)
    end
    return (
        fraction = outward / total,
        min_cos = min_cos,
        n_faces_closed = faces_closed,
        samples = total,
    )
end

"""
    box_summary(b::AlignedBox) -> Dict{String,Any}

Serialisable description (center, Q by columns, half_widths, eigenvalues) for run
metadata and `aligned_box.json`.
"""
box_summary(b::AlignedBox) = Dict{String,Any}(
    "center" => b.center,
    "Q_columns" => [b.Q[:, k] for k in 1:ndims(b)],
    "half_widths" => b.half_widths,
    "eigenvalues" => b.eigenvalues,
)
