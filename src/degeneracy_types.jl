# degeneracy_types.jl
#
# Stage 0 of the "non-zero-dimensional minima" program. The TYPE only — this file
# is included BEFORE adaptive_subdivision.jl (the same ordering trick used for
# Metrics.jl) so the `Subdomain.degeneracy` field can reference it. The detector
# LOGIC lives in degeneracy_detector.jl, included after adaptive_subdivision.jl.
#
# A per-leaf diagnostic that classifies which of three distinct phenomena defeats
# the isolated-critical-point assumption on a leaf:
#   • :sloppy_valley       — isolated argmin, near-flat directions (active subspace
#                            collapses, smooth). Resolver: anisotropic degree /
#                            active-subspace rotation.
#   • :positive_dim_argmin — a genuine curve/surface of minimizers (Hessian
#                            rank-deficient, kernel = manifold tangent; CP necklace).
#                            Resolver: regularize-to-Morse / manifold report.
#   • :fold_caustic        — a measure-zero non-smooth crease (gradient spikes, a
#                            single coherent sheet, the fit Gibbs-oscillates).
#                            Resolver: oblique fold-aligned cut.
#   • :multi_sheet         — non-smooth but curved / multi-sheet (no single cut).
#   • :isolated_morse      — none of the above (control; full-rank, smooth).
#   • :undetermined        — no fit / samples to analyze yet.

"""
    DegeneracyDiagnostics

Per-leaf verdict + the raw signals it was derived from (bead: degeneracy detector).

# Fields
- `verdict::Symbol`: one of `:sloppy_valley`, `:positive_dim_argmin`,
  `:fold_caustic`, `:multi_sheet`, `:isolated_morse`, `:undetermined`.
- `active_eigenvalues::Vector{Float64}`: energy-normalized eigenvalues (descending)
  of the active-subspace matrix `C = mean(g̃ g̃ᵀ)` over box-normalized gradients
  `g̃ = ∇ₓp .* half_widths`. Sum to 1.
- `active_dim_95::Int`: number of leading directions holding ≥95% of gradient energy.
- `effective_dim::Int`: same at the (configurable, default 99%) cumulative threshold.
- `active_directions::Matrix{Float64}`: eigenvectors of `C` (columns, descending),
  in the box-normalized frame. The leading columns span the active subspace.
- `fold_coherence::Float64`: leading-eigenvalue fraction of `Σ ĝ ĝᵀ` over the
  top-`‖g̃‖` points (∈ [1/n, 1]; 1 = a single flat sheet, 1/n = isotropic).
- `fold_normal::Vector{Float64}`: dominant fold normal (box-normalized) — the
  leading eigenvector of the coherence matrix.
- `hessian_n_zero::Int`: number of ≈0 Hessian eigenvalues at the supplied critical
  point (the kernel dimension); `-1` when no CP was provided.
- `hessian_cond::Float64`: Hessian condition number `max|λ| / min|λ|` at that CP;
  `NaN` when not computed, `Inf` when `min|λ| ≈ 0`.
- `cluster_intrinsic_dim::Int`: PCA rank of the supplied critical-point cluster
  (a "necklace" along a curve → 1, a surface → 2); `-1` when <2 CPs were provided.
- `signals::Dict{Symbol,Float64}`: raw scores for audit (`:spike_ratio`,
  `:median_grad`, `:p99_grad`, `:rel_l2`, `:n_points`, …).
"""
struct DegeneracyDiagnostics
    verdict::Symbol
    active_eigenvalues::Vector{Float64}
    active_dim_95::Int
    effective_dim::Int
    active_directions::Matrix{Float64}
    fold_coherence::Float64
    fold_normal::Vector{Float64}
    hessian_n_zero::Int
    hessian_cond::Float64
    cluster_intrinsic_dim::Int
    signals::Dict{Symbol,Float64}
end
