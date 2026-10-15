# tensor_ranks.jl — SKELETON (not included by Globtim.jl yet)
#
# Numerical Tucker (HOSVD) and tensor-train (TT-SVD) ranks of the coefficient tensor
# of an ApproxPoly, for the rank audit of docs/research/plans/LOWRANK_SURROGATE_PLAN.md
# §2. LinearAlgebra only; no tensor package. This is diagnostic code — it never
# changes a surrogate — and belongs in globtim only because it reads ApproxPoly;
# the campaign script is experiments/sandbox/lowrank_audit/rank_audit.jl.

"""
    mode_unfolding(C::AbstractArray{T,n}, k::Int) -> Matrix{T}

The mode-`k` unfolding `C_{(k)}` of size `size(C, k) × Π_{j≠k} size(C, j)`
[delathauwer2000multilinear, Def. 1]: row index `i_k`, column index the
column-major linearisation of the remaining indices (`permutedims` + `reshape`).
"""
function mode_unfolding(C::AbstractArray, k::Int)
    error("not implemented: mode_unfolding")
end

"""
    tucker_spectra(C::AbstractArray{T,n}) -> Vector{Vector{Float64}}

Singular values of every mode unfolding (`svdvals(mode_unfolding(C, k))`,
`k = 1…n`). The HOSVD core's mode-`k` singular values; the Tucker rank at tolerance
`τ` is `count(>(τ * σ[1]), σ)` (relative) — see [`tucker_ranks`](@ref).
"""
function tucker_spectra(C::AbstractArray)
    error("not implemented: tucker_spectra")
end

"""
    tucker_ranks(spectra, τ::Real; relative = true) -> Vector{Int}
"""
function tucker_ranks(spectra, τ::Real; relative::Bool = true)
    error("not implemented: tucker_ranks")
end

"""
    tt_spectra(C::AbstractArray{T,n}; order = 1:n) -> Vector{Vector{Float64}}

Singular values at the `n − 1` TT-SVD splits [oseledets2011tensortrain, Alg. 1]
for the axis order `order`: reshape `C` (permuted) to `(d_1+1) × rest`, SVD, keep
**all** singular values (the audit truncates afterwards at several τ), carry
`Σ V'` forward reshaped to `(r_1 (d_2+1)) × rest`, and so on. The TT rank at
tolerance τ with the quasi-optimality guarantee is obtained by truncating each
split at `τ ‖C‖_F / √(n−1)` [oseledets2011tensortrain, Thm 2.2;
hackbusch2012tensor]. Ranks depend on `order`; the audit reports the given order and
the order sorting axes by Tucker rank.
"""
function tt_spectra(C::AbstractArray; order = 1:ndims(C))
    error("not implemented: tt_spectra")
end

"""
    tt_ranks(spectra, τ::Real, normC::Real, n::Int) -> Vector{Int}
"""
function tt_ranks(spectra, τ::Real, normC::Real, n::Int)
    error("not implemented: tt_ranks")
end

"""
    truncate_tucker(C, ranks) -> (C_τ, core, factors)
    truncate_tt(C, ranks; order) -> (C_τ, cores)

Reconstructions at the given ranks, used only for the audit's reconstruction and
critical-point-displacement checks (plan §2, last bullet). `C_τ` is the dense
truncated tensor — fine at audit sizes, never to be used for evaluation.
"""
function truncate_tucker(C::AbstractArray, ranks::AbstractVector{Int})
    error("not implemented: truncate_tucker")
end
function truncate_tt(C::AbstractArray, ranks::AbstractVector{Int}; order = 1:ndims(C))
    error("not implemented: truncate_tt")
end

"""
    rank_audit(pol::ApproxPoly; tolerances = (1e-4, 1e-6, 1e-8), chop_floor = nothing)
        -> Dict{String,Any}

Everything the audit table needs for one fit (plan §2): dims, per-axis degrees,
`fill_fraction` (nonzeros of the support over the padded box), Tucker and TT
spectra, ranks at each tolerance (plus `chop_floor` relative to `max|c|` when
given), Tucker/TT storage ratios, and the relative reconstruction errors on the
fit grid at each tolerance. Pure function of `pol`; the caller (campaign script)
adds the critical-point displacement check, which needs a solver.
"""
function rank_audit(pol; tolerances = (1e-4, 1e-6, 1e-8), chop_floor = nothing)
    error("not implemented: rank_audit (LOWRANK_SURROGATE_PLAN.md §2)")
end
