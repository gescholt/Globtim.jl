# ── Positive denominators: linear constraints on q in the linearised fit ─────
#
# The linearised rational fit min ‖√w (p − y q)‖ lets q vanish in the box (spurious
# poles; docs/research/rational_surrogates_summary.md). Requiring q ≥ δ · mean(q) on
# a set of linear functionals of q keeps it a convex QP in the coefficients of q.
# Two sets of functionals:
#
# * Bernstein coefficients (`bernstein_matrix`). A polynomial of degree ≤ N in each
#   variable on [-1,1]^n is Σ_γ c_γ B_γ(x), B_γ(x) = Π_k binom(N, γ_k) t_k^γ_k
#   (1 − t_k)^(N − γ_k), t = (x + 1)/2, γ ∈ {0..N}^n. The B_γ are nonnegative and sum
#   to 1, so min_γ c_γ ≤ q(x) on the whole box: c ≥ δ is a certificate. It is
#   conservative: a q whose minimum in some variable is interior, e.g. (x₂ − 0.3)²,
#   has negative low-degree coefficients, and degree elevation tightens the bound only
#   as O(1/degree) with (degree + 1)^n rows. Measured 2026-09-25 on the pole target A2:
#   the constrained fit matches the free fit only at elevation 6N; on P5 (pole above
#   the interior) not even there. Use it as a certificate, not as the fit constraint.
#
# * Values at constraint points (`denominator = :points` in RationalConstructor):
#   q(x_j) ≥ δ · mean(q) at points that cost no evaluation of f, plus an exchange
#   step that minimises q over the box and adds the minimisers that violate the
#   bound. Not a certificate (certify afterwards), but it scales linearly in the
#   number of points and does not exclude the true denominator.

"""
    _bernstein_1d(N, basis) -> (C, degs)

`C[i+1, j]` is the i-th degree-N Bernstein coefficient on [-1,1] of the j-th
one-variable basis function of `SupportGen(1, (:one_d_for_all, N))`, whose degree is
`degs[j]`, in the normalisation `lambda_vandermonde_original` uses for `basis`.
Computed by interpolation at N + 1 Chebyshev points (exact up to rounding: both sides
are polynomials of degree ≤ N).
"""
function _bernstein_1d(N::Int, basis::Symbol)
    N >= 0 || throw(ArgumentError("degree must be ≥ 0, got $N"))
    L1 = SupportGen(1, (:one_d_for_all, N))
    degs = vec(L1.data[:, 1])
    x = [cos((2k - 1) * π / (2(N + 1))) for k in 1:(N+1)]
    Vb = lambda_vandermonde_original(L1, reshape(x, :, 1); basis = basis)
    t = (x .+ 1) ./ 2
    Bm = [binomial(N, i) * t[k]^i * (1 - t[k])^(N - i) for k in 1:(N+1), i in 0:N]
    return Bm \ Vb, degs
end

"""
    bernstein_matrix(Lambda, basis; degree = maximum(Lambda.data)) -> T

The linear map from coefficients `b` in the basis indexed by `Lambda.data` (the
columns of `lambda_vandermonde(Lambda, ·; basis)`) to the tensor Bernstein
coefficients on [-1,1]^n of degree `degree` in each variable: `T * b` lists all
`(degree + 1)^n` of them, and `minimum(T * b)` is a lower bound for the polynomial on
the box. A `degree` above the support's is degree elevation: the coefficients
converge to values of the polynomial, so the bound tightens, as O(1/degree).
"""
function bernstein_matrix(
    Lambda::NamedTuple,
    basis::Symbol;
    degree::Int = maximum(Lambda.data),
)
    data = Lambda.data
    m, n = size(data)
    degree >= maximum(data) || throw(
        ArgumentError(
            "bernstein_matrix: degree $degree is below the support's $(maximum(data))",
        ),
    )
    N = degree
    r = (N + 1)^n
    r <= 2_000_000 || throw(
        ArgumentError(
            "bernstein_matrix: $(N+1)^$n = $r Bernstein coefficients is too many to form densely",
        ),
    )
    C, degs = _bernstein_1d(N, basis)
    col = Dict(d => j for (j, d) in enumerate(degs))
    T = Matrix{Float64}(undef, r, m)
    for j in 1:m
        # γ enumerated with γ_1 fastest (column-major), hence kron over k = n, …, 1
        v = C[:, col[data[j, n]]]
        for k in (n-1):-1:1
            v = kron(v, C[:, col[data[j, k]]])
        end
        T[:, j] = v
    end
    return T
end

"""
    bernstein_lower_bound(R::ApproxRational; degree = R.N) -> Float64

A certified lower bound for the denominator `q` of `R` on the whole box: the smallest
tensor Bernstein coefficient of `q` at `degree` per variable (≥ `R.N`; larger is
tighter and costs `(degree + 1)^n` coefficients). `> 0` proves `q > 0` on the box with
no solve and no sampling; `≤ 0` proves nothing.
"""
function bernstein_lower_bound(R::ApproxRational; degree::Int = R.N)
    R.N == 0 && return R.b[1]
    return minimum(bernstein_matrix(R.Lambda_N, R.basis; degree = degree) * R.b)
end

"""
    rational_ls_fit_positive(V_M, V_N, z, T; delta = 0.05, sqrt_w = nothing)
        -> (; a, b, singular_values, tmin, ipm_iterations)

The linearised rational least squares of `rational_ls_fit`,

    min ‖diag(√w)(V_M a − F V_N b)‖²,

normalised by mean(q) = 1 over the points (`q = V_N b`) and constrained by
`T b ≥ delta` elementwise. Each row of `T` is a linear functional of q: Bernstein
coefficients (`bernstein_matrix`), or the values of q at constraint points (rows of
a Vandermonde). Where the functionals bound q from below on a set, q ≥ delta there, so
`|p/q − y| ≤ |p − y q| / delta` on it.

`a` is eliminated by the projection of `rational_ls_fit` (a = R⁻¹Qᵀ F V_N b),
leaving a convex QP in the `size(V_N, 2)` coefficients of q, solved by a
Mehrotra predictor–corrector primal–dual interior-point method on the slacks
s = T b − delta · mean(q). The start q ≡ 1 is strictly feasible for delta < 1
(it requires every row of `T` to give 1 on the constant, true for both kinds of
rows). `tmin = minimum(T b)`; `singular_values` are those of the projected matrix
`(I − QQᵀ) F V_N` (diagnostics, as in `rational_ls_fit`).
"""
function rational_ls_fit_positive(
    V_M::AbstractMatrix,
    V_N::AbstractMatrix,
    z::AbstractVector,
    T::AbstractMatrix;
    delta::Real = 0.05,
    sqrt_w::Union{Nothing,AbstractVector{<:Real}} = nothing,
    tol::Real = 1e-9,
    max_iter::Int = 200,
)
    K, mM = size(V_M)
    K2, mN = size(V_N)
    (K == K2 && K == length(z)) || throw(
        ArgumentError(
            "rational_ls_fit_positive: V_M is $(K)×$(mM), V_N is $(K2)×$(mN), z has length $(length(z)); row counts must agree",
        ),
    )
    size(T, 2) == mN || throw(
        ArgumentError("rational_ls_fit_positive: T has $(size(T, 2)) columns, V_N has $mN"),
    )
    K >= mM + mN || throw(
        ArgumentError(
            "rational_ls_fit_positive: $(K) points cannot determine $(mM) + $(mN) coefficients",
        ),
    )
    0 < delta < 1 || throw(ArgumentError("delta must be in (0, 1), got $delta"))
    sw = sqrt_w === nothing ? ones(K) : Vector{Float64}(sqrt_w)
    (length(sw) == K && all(w -> isfinite(w) && w > 0, sw)) ||
        throw(ArgumentError("rational_ls_fit_positive: sqrt_w must be $K positive weights"))

    Qr = qr(Matrix{Float64}(sw .* V_M))
    Q = Matrix(Qr.Q)
    Rm = Qr.R
    dR = abs.(diag(Rm))
    minimum(dR) > 1e-13 * maximum(dR) || error(
        "rational_ls_fit_positive: the numerator Vandermonde is rank-deficient on this point set " *
        "(min |R_ii| / max |R_ii| = $(minimum(dR) / maximum(dR)))",
    )
    FVN = (sw .* z) .* V_N
    W = FVN - Q * (Q' * FVN)
    P = Symmetric(2 .* (W' * W))                  # objective ½ bᵀPb = ‖W b‖²
    mvec = vec(sum(V_N; dims = 1)) ./ K           # mean(q) = mvec ⋅ b
    C = T .- delta .* ones(size(T, 1)) * mvec'    # slack s = C b ≥ 0
    nr = size(C, 1)

    # start: q ≡ 1 (the constant basis column), mean 1, every slack 1 − delta
    j0 = findfirst(j -> all(V_N[:, j] .== V_N[1, j]) && V_N[1, j] != 0, 1:mN)
    j0 === nothing && error("rational_ls_fit_positive: V_N has no constant column")
    b = zeros(mN)
    b[j0] = 1 / V_N[1, j0]
    s = C * b
    minimum(s) > 0 || error(
        "rational_ls_fit_positive: q ≡ 1 is not strictly feasible (min slack $(minimum(s))); " *
        "every row of T must give 1 on the constant",
    )
    scale = max(dot(b, P * b), 1e-12 * tr(P), eps())
    lam = fill(scale / nr, nr) ./ s
    Pb = P * b
    nu = -dot(mvec, Pb .- C' * lam) / dot(mvec, mvec)
    iters = 0
    step_to_boundary(v, dv) = (neg = dv .< 0; any(neg) ? minimum(-v[neg] ./ dv[neg]) : Inf)
    for it in 1:max_iter
        iters = it
        Pb = P * b
        rd = Pb .- C' * lam .+ nu .* mvec
        mu = dot(s, lam) / nr
        obj = dot(b, Pb) / 2
        # relative to the objective, with an absolute floor at the starting objective's
        # scale: an exact rational drives the objective to 0, and without the floor
        # the KKT matrix degenerates before the relative test is met
        (
            mu <= tol * obj + 1e-13 * scale &&
            norm(rd) <= 1e-8 * (norm(Pb) + norm(C' * lam)) + 1e-12 * sqrt(scale)
        ) && break
        D = lam ./ s
        H = Matrix(P) .+ C' * (D .* C)
        KKT = [H mvec; mvec' 0.0]
        F = lu(KKT)
        # predictor (affine), then corrector with σ = (μ_aff / μ)³
        function direction(comp)
            # comp: target of s∘λ, i.e. Δλ = (comp − s∘λ − λ∘CΔb) / s
            rhs = vcat(-rd .+ C' * ((comp .- s .* lam) ./ s), 0.0)
            sol = F \ rhs
            all(isfinite, sol) || error(
                "rational_ls_fit_positive: non-finite Newton step at iteration $it (μ = $mu, objective $obj)",
            )
            db = sol[1:mN]
            dnu = sol[end]
            ds = C * db
            dlam = (comp .- s .* lam .- lam .* ds) ./ s
            return db, dnu, ds, dlam
        end
        db, dnu, ds, dlam = direction(zeros(nr))
        α = min(1.0, step_to_boundary(s, ds), step_to_boundary(lam, dlam))
        mu_aff = dot(s .+ α .* ds, lam .+ α .* dlam) / nr
        σ = (mu_aff / mu)^3
        db, dnu, ds, dlam = direction(σ * mu .- ds .* dlam)
        α = min(1.0, 0.99 * step_to_boundary(s, ds), 0.99 * step_to_boundary(lam, dlam))
        b = b .+ α .* db
        nu += α * dnu
        lam = lam .+ α .* dlam
        s = C * b
        minimum(s) > 0 ||
            error("rational_ls_fit_positive: slack left the interior (min $(minimum(s)))")
    end
    a = Rm \ (Q' * (FVN * b))
    return (
        a = a,
        b = b,
        singular_values = svdvals(W),
        tmin = minimum(T * b),
        ipm_iterations = iters,
    )
end

"""
    _box_constraint_points(n, count, rng) -> Matrix

Constraint points for `denominator = :points`: the 2^n corners (when 2^n ≤ 4096),
then uniform points of [-1,1]^n, `count` rows in all. The minimum of a denominator
whose pole lies outside the box sits on the boundary, so the corners are kept.
"""
function _box_constraint_points(n::Int, count::Int, rng::AbstractRNG)
    corners =
        n <= 12 ?
        reduce(
            vcat,
            [
                collect(Float64, c)' for
                c in Iterators.product(ntuple(_ -> (-1.0, 1.0), n)...)
            ],
        ) : zeros(0, n)
    nrand = max(count - size(corners, 1), 0)
    return vcat(corners, 2 .* rand(rng, nrand, n) .- 1)
end

"""
    _minimise_q(Lambda_N, basis, normalized, b, starts) -> (xs, qs)

Local minima of q = Σ b_j φ_j over [-1,1]^n by projected BFGS (Optim `Fminbox`),
from each row of `starts`. q is a polynomial of low degree, so this costs nothing
next to an evaluation of f.
"""
function _minimise_q(Lambda_N, basis, normalized, b, starts::AbstractMatrix)
    n = size(starts, 2)
    qf(x) = dot(_tensor_basis_values(Lambda_N, x, basis, normalized), b)
    lo = fill(-1.0, n)
    hi = fill(1.0, n)
    xs = Vector{Vector{Float64}}()
    qs = Float64[]
    for i in 1:size(starts, 1)
        x0 = clamp.(Vector{Float64}(starts[i, :]), -1 + 1e-12, 1 - 1e-12)
        res = Optim.optimize(
            qf,
            (G, x) -> ForwardDiff.gradient!(G, qf, x),
            lo,
            hi,
            x0,
            Fminbox(LBFGS()),
            Optim.Options(iterations = 200, outer_iterations = 10),
        )
        push!(xs, clamp.(Optim.minimizer(res), -1.0, 1.0))
        push!(qs, qf(xs[end]))
    end
    return xs, qs
end

"""
    rational_ls_fit_points(V_M, V_N, z, Lambda_N, basis; delta, sqrt_w, n_constraint,
                           n_probe, max_exchange, rng)
        -> (; a, b, singular_values, qmin_probe, n_constraint, n_exchange, ipm_iterations)

`rational_ls_fit_positive` with q ≥ delta · mean(q) imposed at the fit points and at
`n_constraint` box points (`_box_constraint_points`), followed by exchange rounds:
q is minimised over the box from the `n_starts` lowest of `n_probe` uniform probe
points; the local minimisers and probe points below the bound are added as constraint
points and the QP re-solved, until nothing found is below delta/2 · mean(q) (or
`max_exchange` rounds, which is an error: the constraint set did not close).
`qmin_probe` is the smallest q / mean(q) found by the last round. In 5-D, 8 starts
from 20,000 probe points missed minima that 50,000 points found (2026-09-25), hence
the defaults.
None of these points costs an evaluation of f. Not a certificate: certify the result
(`certify_positive_denominator`, or `bernstein_lower_bound` when it is positive).
"""
function rational_ls_fit_points(
    V_M::AbstractMatrix,
    V_N::AbstractMatrix,
    z::AbstractVector,
    Lambda_N::NamedTuple,
    basis::Symbol;
    delta::Real = 0.01,
    sqrt_w::Union{Nothing,AbstractVector{<:Real}} = nothing,
    n_constraint::Int = 20 * size(V_N, 2),
    n_probe::Int = max(50_000, 200 * size(V_N, 2)),
    n_starts::Int = 32,
    max_exchange::Int = 12,
    rng::AbstractRNG = Xoshiro(0x5eed),
)
    n = size(Lambda_N.data, 2)
    normalized = _stored_normalized(basis)
    Xc = _box_constraint_points(n, n_constraint, rng)
    Vc = lambda_vandermonde_original(Lambda_N, Xc; basis = basis)
    Xp = 2 .* rand(rng, n_probe, n) .- 1
    Vp = lambda_vandermonde_original(Lambda_N, Xp; basis = basis)
    local pf
    qmin = NaN
    ipm = 0
    for round in 0:max_exchange
        pf = rational_ls_fit_positive(
            V_M,
            V_N,
            z,
            vcat(V_N, Vc);
            delta = delta,
            sqrt_w = sqrt_w,
        )
        ipm += pf.ipm_iterations
        mean_q = sum(V_N * pf.b) / size(V_N, 1)
        qp = Vp * pf.b
        idx = partialsortperm(qp, 1:min(n_starts, length(qp)))
        xs, qs = _minimise_q(Lambda_N, basis, normalized, pf.b, Xp[idx, :])
        qmin = min(minimum(qs), minimum(qp))
        # closed when nothing found dips below delta/2 (the constraint is imposed at
        # delta, so points just below it are the exchange chasing a moving minimum)
        if qmin >= delta * mean_q / 2
            return (
                a = pf.a,
                b = pf.b,
                singular_values = pf.singular_values,
                qmin_probe = qmin / mean_q,
                n_constraint = size(Vc, 1),
                n_exchange = round,
                ipm_iterations = ipm,
            )
        end
        # add the violating local minimisers and the probe points below delta
        bad = [x for (x, q) in zip(xs, qs) if q < delta * mean_q]
        low = findall(<(delta * mean_q), qp)
        low = low[partialsortperm(qp[low], 1:min(64, length(low)))]
        Xb = vcat(isempty(bad) ? zeros(0, n) : reduce(vcat, [x' for x in bad]), Xp[low, :])
        Vc = vcat(Vc, lambda_vandermonde_original(Lambda_N, Xb; basis = basis))
    end
    error(
        "rational_ls_fit_points: q still dips below delta · mean(q) (min found $qmin) after " *
        "$max_exchange exchange rounds; raise max_exchange or n_constraint",
    )
end
