# active_subspace.jl
#
# Stage 2 of the "non-zero-dimensional minima" program: the active-subspace
# ROTATION resolver for the sloppy-valley case. Given an objective whose hard
# structure is not axis-aligned (the CR3BP L4 5-D box is effectively 2-3D, active
# plane ≈ (lv_x,lv_y)), compute the gradient-covariance eigenbasis, rotate the
# box's coordinate frame to it (`Subdomain.transform = Q`), and assign anisotropic
# per-axis degree from the spectrum (high on active axes, floored ≥2 on the sloppy
# tail — the lx_z "sloppy-but-essential" lesson). The fit then happens in the frame
# where the active subspace aligns with axes, so anisotropic degree pays off
# maximally and the dim-N tensor-grid cost collapses.
#
# The covariance math is the same Constantine active-subspace primitive prototyped
# in experiments/sandbox/fold_indicator_probe.jl. Gradients are box-normalized
# (∇_ẑ f) by forward differences on the objective over a cell-centered grid (cells
# are interior so perturbations stay in-box). The rotation enters f-evaluation only
# through box_to_physical! (so it composes with the current frame).

using LinearAlgebra
using Base.Threads

# Interior cell-centers of the normalized box [-1,1]ⁿ: nⁿ points, each strictly
# inside a cell so a small forward step stays in-box (no boundary clamping).
function _cell_centers(n_dim::Int, n_cells::Int)
    ax = [-1.0 + 2.0 * (i - 0.5) / n_cells for i in 1:n_cells]
    pts = Vector{Vector{Float64}}(undef, n_cells^n_dim)
    @inbounds for lin in 0:(n_cells^n_dim - 1)
        r = lin
        p = Vector{Float64}(undef, n_dim)
        for d in 1:n_dim
            p[d] = ax[r % n_cells + 1]
            r ÷= n_cells
        end
        pts[lin+1] = p
    end
    return pts
end

# Box-normalized objective gradients g̃ = ∇_ẑ f at the cell centers (in the box's
# CURRENT frame; box_to_physical! applies any existing transform). Returns an
# (N × n_dim) matrix. Rows are written independently → thread-safe with no
# threadid() accumulation pitfall. Costs (n_dim+1)·nⁿ objective evaluations.
function _objective_cell_gradients(f, sd::Subdomain, n_cells::Int, h::Float64)
    n_dim = length(sd.center)
    pts = _cell_centers(n_dim, n_cells)
    N = length(pts)
    G = Matrix{Float64}(undef, N, n_dim)
    Threads.@threads for i in 1:N
        ẑ = pts[i]
        x0 = Vector{Float64}(undef, n_dim)
        box_to_physical!(x0, ẑ, sd)
        f0 = f(x0)
        xk = Vector{Float64}(undef, n_dim)
        zk = similar(ẑ)
        @inbounds for k in 1:n_dim
            step = ẑ[k] > 0 ? -h : h          # toward interior (normalized)
            copyto!(zk, ẑ)
            zk[k] += step
            box_to_physical!(xk, zk, sd)
            G[i, k] = (f(xk) - f0) / step       # ∂f/∂ẑ_k
        end
    end
    return G
end

"""
    gradient_covariance(f, sd::Subdomain; n_cells=5, h=0.01) -> Matrix{Float64}

The active-subspace matrix `C = mean(g̃ g̃ᵀ)` over box-normalized objective gradients
on a cell-centered grid of the leaf's box (Constantine). Its eigen-decomposition is
the active-subspace spectrum.
"""
function gradient_covariance(f, sd::Subdomain; n_cells::Int = 5, h::Float64 = 0.01)
    G = _objective_cell_gradients(f, sd, n_cells, h)
    return (G' * G) ./ size(G, 1)
end

"""
    active_subspace(C::AbstractMatrix{Float64}) -> (Q, eigenvalues, cum)

Eigen-decomposition of the active-subspace matrix `C`. Returns the eigenvectors `Q`
(columns, descending eigenvalue), the energy-normalized eigenvalues `eigenvalues`
(sum 1), and their cumulative sum `cum`. `Q[:,1]` is the dominant active direction;
using `Q` as `Subdomain.transform` makes normalized axis 1 align with it.
"""
function active_subspace(C::AbstractMatrix{Float64})
    n = size(C, 1)
    ev = eigen(Symmetric(Matrix(C)))
    ord = sortperm(ev.values; rev = true)
    λ = max.(ev.values[ord], 0.0)
    Q = Matrix(ev.vectors[:, ord])
    tot = sum(λ)
    frac = tot > 0 ? λ ./ tot : fill(0.0, n)
    return (Q, frac, cumsum(frac))
end

"""
    anisotropic_degree_from_spectrum(eigenvalues, deg_max; floor_deg=2, active_cum=0.95)
        -> Vector{Int}

Per-axis degree from the (energy-normalized, descending) active-subspace spectrum,
in the ROTATED frame. Directions are kept at `deg_max` until the cumulative energy
of the preceding directions reaches `active_cum`; the remaining sloppy tail drops to
`floor_deg`. The FLOOR is load-bearing — a sloppy axis is NOT degree 0/1 (lx_z carries
0.3% of the energy yet still needs d≥2 to place the optimum), so `floor_deg` defaults
to 2. Lower `active_cum` ⇒ a more aggressive rotation (fewer high-degree axes); e.g.
on the CR3BP spectrum `[72,21,6,…]%`, `active_cum=0.90` ⇒ `[6,6,2,2,2]` (the proven
pattern) and `0.95` ⇒ `[6,6,6,2,2]`.
"""
function anisotropic_degree_from_spectrum(
    eigenvalues::AbstractVector{<:Real},
    deg_max::Int;
    floor_deg::Int = 2,
    active_cum::Float64 = 0.95,
)
    floor_deg >= 0 || error("floor_deg must be ≥ 0, got $floor_deg")
    floor_deg <= deg_max || error("floor_deg=$floor_deg exceeds deg_max=$deg_max")
    cum = cumsum(eigenvalues)
    degs = Vector{Int}(undef, length(eigenvalues))
    @inbounds for k in eachindex(eigenvalues)
        prev = k == 1 ? 0.0 : cum[k-1]
        degs[k] = prev < active_cum ? deg_max : floor_deg
    end
    return degs
end

"""
    rotate_to_active_frame!(f, sd::Subdomain; n_cells=5, h=0.01, deg_max=6,
                            floor_deg=2, active_cum=0.95)
        -> (transform, eigenvalues, degrees)

Stage 2 root-first resolver: measure the active subspace of `f` on `sd`, set
`sd.transform` to its eigenbasis (composed with any existing frame), and set
`sd.per_dim_degree` to the spectrum-derived anisotropic degrees. After this the fit
on `sd` (and its inheriting children) happens in the rotated, anisotropic frame.
Raises if the eigenbasis is not orthonormal (no silent fallback).
"""
function rotate_to_active_frame!(
    f,
    sd::Subdomain;
    n_cells::Int = 5,
    h::Float64 = 0.01,
    deg_max::Int = 6,
    floor_deg::Int = 2,
    active_cum::Float64 = 0.95,
)
    n = length(sd.center)
    C = gradient_covariance(f, sd; n_cells = n_cells, h = h)
    Q, frac, _ = active_subspace(C)
    # Eigenvectors are in the box's CURRENT frame; compose with it to land in the
    # original physical frame: physical = center + (T·Q)·(ẑ .* half_widths).
    Qtot = sd.transform === nothing ? Q : sd.transform * Q
    _validate_transform(Qtot, n)
    sd.transform = Qtot
    degs = anisotropic_degree_from_spectrum(
        frac, deg_max; floor_deg = floor_deg, active_cum = active_cum,
    )
    sd.per_dim_degree = degs
    return (transform = Qtot, eigenvalues = frac, degrees = degs)
end

"""
    fold_normal_coherence(f, sd::Subdomain; n_cells=5, h=0.01, top_q=0.05)
        -> (coherence, normal)

Stage 3 primitive: among the top-`‖g̃‖` cell centers, the leading-eigenvalue fraction
of `Σ ĝ ĝᵀ` (∈ [1/n, 1]; ≈1 ⇒ a single coherent non-axis sheet — a fold) and the
dominant fold normal (box-normalized). Reuses the detector's `_fold_coherence`.
"""
function fold_normal_coherence(
    f,
    sd::Subdomain;
    n_cells::Int = 5,
    h::Float64 = 0.01,
    top_q::Float64 = 0.05,
)
    G = _objective_cell_gradients(f, sd, n_cells, h)
    coh, normal, _ = _fold_coherence(G, top_q)
    return (coh, normal)
end
