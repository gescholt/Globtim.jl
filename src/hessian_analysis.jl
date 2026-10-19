# Phase 2: Hessian-Based Critical Point Classification
# Core functions for computing and analyzing Hessian matrices

using ForwardDiff
using LinearAlgebra
using DataFrames

"""
    compute_hessians(f, points::Matrix{Float64})::Vector{Matrix{Float64}}

Compute Hessian matrices at specified points using ForwardDiff automatic differentiation.

# Arguments
- f: Objective function to analyze (any callable)
- points: Matrix where each row is a point (n_points × n_dims)

# Returns
Vector{Matrix{Float64}}: Hessian matrix for each point
"""
function compute_hessians(f, points::Matrix{Float64})::Vector{Matrix{Float64}}
    n_points, n_dims = size(points)
    hessians = Vector{Matrix{Float64}}(undef, n_points)

    # Collect failures for summary reporting
    failed_points = Int[]
    failure_types = Set{String}()

    for i in 1:n_points
        try
            point = Vector{Float64}(points[i, :])
            @debug "Computing Hessian for point $i: $point"
            H = ForwardDiff.hessian(f, point)
            @debug "Point $i Hessian computed successfully: size=$(size(H)), det=$(det(H))"
            hessians[i] = H
        catch e
            push!(failed_points, i)
            push!(failure_types, string(typeof(e)))
            @debug "Point $i: Hessian computation failed with error: $e" exception =
                (e, catch_backtrace())
            # Fallback for points where Hessian computation fails
            hessians[i] = fill(NaN, n_dims, n_dims)
        end
    end

    # Report summary if any points failed
    if !isempty(failed_points)
        sample_points = first(failed_points, min(5, length(failed_points)))
        @warn "Hessian computation failed for $(length(failed_points))/$n_points points" failed_points =
            sample_points error_types = collect(failure_types)
    end

    return hessians
end

"""
    classify_critical_points(hessians::Vector{Matrix{Float64}}; 
                           tol_zero=1e-8, tol_pos=1e-8, tol_neg=1e-8)::Vector{Symbol}

Classify critical points based on Hessian eigenvalue structure.

# Arguments
- hessians: Vector of Hessian matrices
- tol_zero: Tolerance for zero eigenvalues (degeneracy detection)
- tol_pos: Tolerance for positive eigenvalues
- tol_neg: Tolerance for negative eigenvalues

# Returns
Vector{Symbol}: Classification for each point (:minimum, :maximum, :saddle, :degenerate, :error)
"""
function classify_critical_points(
    hessians::Vector{Matrix{Float64}};
    tol_zero = 1e-8,
    tol_pos = 1e-8,
    tol_neg = 1e-8,
)::Vector{Symbol}
    n_points = length(hessians)
    classifications = Vector{Symbol}(undef, n_points)

    for i in 1:n_points
        H = hessians[i]

        # Check for NaN matrices (computation failed)
        if any(isnan, H)
            @debug "Point $i: Hessian contains NaN values, classifying as :error"
            classifications[i] = :error
            continue
        end

        try
            eigenvals = eigvals(Symmetric(H))  # Use Symmetric for better numerical stability

            # Count eigenvalue signs
            n_positive = count(λ -> λ > tol_pos, eigenvals)
            n_negative = count(λ -> λ < -tol_neg, eigenvals)
            n_zero = count(λ -> abs(λ) < tol_zero, eigenvals)
            n_dims = length(eigenvals)

            @debug "Point $i: eigenvals=$eigenvals, n_pos=$n_positive, n_neg=$n_negative, n_zero=$n_zero, dims=$n_dims"

            if n_zero > 0
                @debug "Point $i: Classified as :degenerate (n_zero=$n_zero)"
                classifications[i] = :degenerate
            elseif n_positive == n_dims
                @debug "Point $i: Classified as :minimum (all positive)"
                classifications[i] = :minimum
            elseif n_negative == n_dims
                @debug "Point $i: Classified as :maximum (all negative)"
                classifications[i] = :maximum
            else
                @debug "Point $i: Classified as :saddle (mixed signs)"
                classifications[i] = :saddle
            end

        catch e
            @debug "Point $i: Exception in eigenvalue computation: $e, classifying as :error"
            classifications[i] = :error
        end
    end

    return classifications
end

"""
    IndexClassification

Per-point result of [`classify_with_index`](@ref).

- `class::Symbol` — `:minimum`, `:maximum`, `:saddle`, `:ambiguous`, `:nonstationary`
  or `:error`;
- `index_low::Int`, `index_high::Int` — bounds on the Morse index: eigenvalues below
  `-band` are certainly negative, eigenvalues inside `[-band, band]` may go either way;
  `index_low == index_high` iff the point is unambiguous;
- `n_band::Int` — number of eigenvalues inside the band;
- `band::Float64` — the tolerance that was applied, `max(abs_tol, rel_tol * ‖H‖₂)`;
- `min_abs_eig::Float64` — smallest `|λ|`, the margin by which the inertia is decided;
- `hessian_norm::Float64` — `‖H‖₂`;
- `grad_norm::Float64` — `‖∇f‖` when supplied, `NaN` otherwise.
"""
struct IndexClassification
    class::Symbol
    index_low::Int
    index_high::Int
    n_band::Int
    band::Float64
    min_abs_eig::Float64
    hessian_norm::Float64
    grad_norm::Float64
end

"""
    morse_index(c::IndexClassification) -> Int

The Morse index when it is decided (`index_low == index_high`); throws otherwise.
"""
function morse_index(c::IndexClassification)
    c.index_low == c.index_high || throw(
        ArgumentError(
            "morse_index: point is ambiguous (index in $(c.index_low):$(c.index_high))",
        ),
    )
    return c.index_low
end

"""
    classify_with_index(hessians; rel_tol = 1e-8, abs_tol = 0.0, grad_norms = nothing, grad_tol = Inf)
        -> Vector{IndexClassification}
    classify_with_index(f, points::Matrix{Float64}; kwargs...) -> Vector{IndexClassification}

Morse-index classification with a **scale-aware** zero band. `classify_critical_points`
compares eigenvalues with an absolute tolerance (default `1e-8`), so a Hessian with
`‖H‖ ~ 1e6` (a misfit landscape) never sees a degenerate direction, and a Hessian with
`‖H‖` at or below the tolerance (a flat trough) sees nothing else. Here an eigenvalue counts as decided only if it clears
`band = max(abs_tol, rel_tol * ‖H‖₂)`; eigenvalues inside the band leave the index
undecided and the point is reported `:ambiguous` with `index_low:index_high` bounds,
rather than being rounded to `:degenerate` or silently to a sign.

The second method computes the Hessians and gradient norms of `f` by ForwardDiff
(the true objective, not the surrogate), one row of `points` per point. A point with
`‖∇f‖ > grad_tol` is `:nonstationary` — its Hessian inertia is not an index of
anything — which is the refinement-on-a-box-face failure mode recorded in
`.claude/CLAUDE.md` (a `lam_min > 0` "minimum" with `‖∇f‖` of order one).

Use [`poincare_hopf_sum`](@ref) to turn the result into the index-sum check.
"""
function classify_with_index(
    hessians::AbstractVector{<:AbstractMatrix{<:Real}};
    rel_tol::Real = 1e-8,
    abs_tol::Real = 0.0,
    grad_norms::Union{Nothing,AbstractVector{<:Real}} = nothing,
    grad_tol::Real = Inf,
)::Vector{IndexClassification}
    rel_tol >= 0 || throw(ArgumentError("rel_tol must be ≥ 0, got $rel_tol"))
    abs_tol >= 0 || throw(ArgumentError("abs_tol must be ≥ 0, got $abs_tol"))
    grad_norms === nothing ||
        length(grad_norms) == length(hessians) ||
        throw(
            ArgumentError(
                "grad_norms has $(length(grad_norms)) entries for $(length(hessians)) Hessians",
            ),
        )
    out = Vector{IndexClassification}(undef, length(hessians))
    for (i, H) in enumerate(hessians)
        g = grad_norms === nothing ? NaN : Float64(grad_norms[i])
        if any(x -> !isfinite(x), H)
            out[i] =
                IndexClassification(:error, 0, size(H, 1), size(H, 1), NaN, NaN, NaN, g)
            continue
        end
        λ = eigvals(Symmetric(Matrix{Float64}(H)))
        hnorm = isempty(λ) ? 0.0 : maximum(abs, λ)
        band = max(Float64(abs_tol), Float64(rel_tol) * hnorm)
        n_neg = count(<(-band), λ)
        n_band = count(x -> abs(x) <= band, λ)
        min_abs = isempty(λ) ? NaN : minimum(abs, λ)
        n = length(λ)
        class = if grad_norms !== nothing && g > grad_tol
            :nonstationary
        elseif n_band > 0
            :ambiguous
        elseif n_neg == 0
            :minimum
        elseif n_neg == n
            :maximum
        else
            :saddle
        end
        out[i] = IndexClassification(
            class,
            n_neg,
            n_neg + n_band,
            n_band,
            band,
            min_abs,
            hnorm,
            g,
        )
    end
    return out
end

function classify_with_index(f, points::Matrix{Float64}; kwargs...)
    n_points = size(points, 1)
    hessians = Vector{Matrix{Float64}}(undef, n_points)
    grad_norms = Vector{Float64}(undef, n_points)
    for i in 1:n_points
        x = points[i, :]
        hessians[i] = ForwardDiff.hessian(f, x)
        grad_norms[i] = norm(ForwardDiff.gradient(f, x))
    end
    return classify_with_index(hessians; grad_norms = grad_norms, kwargs...)
end

"""
    poincare_hopf_sum(classes::AbstractVector{IndexClassification}) -> NamedTuple

`Σ (−1)^index` over the decided points, with the range the ambiguous points could add.

Returns `(sum, lower, upper, n_decided, n_ambiguous, n_excluded, exact)`:
- `sum` — contribution of the decided points;
- `lower`/`upper` — `sum` plus the most negative / most positive contribution the
  ambiguous points can make (`±1` each — an ambiguous point with `n_band ≥ 1` can take
  either parity);
- `n_excluded` — `:nonstationary` and `:error` points, which contribute nothing and make
  the census non-exact;
- `exact` — `n_ambiguous == 0 && n_excluded == 0`.

On a contractible domain whose gradient points outward on the boundary the exact sum
must be `1`; a decided sum outside `[lower, upper]` of a reference value means points
are missing (or spurious). The sum is blind to a fold-created pair (indices `i` and
`i+1` cancel), so equality is necessary, not sufficient, for completeness.
"""
function poincare_hopf_sum(classes::AbstractVector{IndexClassification})
    s = 0
    n_amb = 0
    n_exc = 0
    for c in classes
        if c.class === :nonstationary || c.class === :error
            n_exc += 1
        elseif c.index_low == c.index_high
            s += iseven(c.index_low) ? 1 : -1
        else
            n_amb += 1
        end
    end
    return (
        sum = s,
        lower = s - n_amb,
        upper = s + n_amb,
        n_decided = length(classes) - n_amb - n_exc,
        n_ambiguous = n_amb,
        n_excluded = n_exc,
        exact = n_amb == 0 && n_exc == 0,
    )
end

"""
    store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}

Store all eigenvalues for each Hessian matrix for detailed analysis.

# Returns
Vector{Vector{Float64}}: All eigenvalues for each Hessian matrix
"""
function store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}
    n_points = length(hessians)
    all_eigenvalues = Vector{Vector{Float64}}(undef, n_points)

    for i in 1:n_points
        H = hessians[i]

        if any(isnan, H)
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
            continue
        end

        try
            eigenvals = eigvals(Symmetric(H))
            all_eigenvalues[i] = sort(eigenvals)  # Sort for consistency
        catch e
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
        end
    end

    return all_eigenvalues
end

"""
    extract_critical_eigenvalues(classifications::Vector{Symbol}, 
                                all_eigenvalues::Vector{Vector{Float64}})::
                                Tuple{Vector{Float64}, Vector{Float64}}

Extract critical eigenvalues for minima and maxima classification.

# Returns
Tuple{Vector{Float64}, Vector{Float64}}: 
- smallest_positive_eigenvals: For minima (smallest positive eigenvalue)
- largest_negative_eigenvals: For maxima (largest negative eigenvalue)
"""
function extract_critical_eigenvalues(
    classifications::Vector{Symbol},
    all_eigenvalues::Vector{Vector{Float64}},
)
    n_points = length(classifications)
    smallest_positive_eigenvals = Vector{Float64}(undef, n_points)
    largest_negative_eigenvals = Vector{Float64}(undef, n_points)

    for i in 1:n_points
        eigenvals = all_eigenvalues[i]
        classification = classifications[i]

        # Initialize with NaN
        smallest_positive_eigenvals[i] = NaN
        largest_negative_eigenvals[i] = NaN

        if any(isnan, eigenvals) || classification == :error
            continue
        end

        # For minima: find smallest positive eigenvalue
        if classification == :minimum
            positive_eigenvals = filter(λ -> λ > 1e-12, eigenvals)
            if !isempty(positive_eigenvals)
                smallest_positive_eigenvals[i] = minimum(positive_eigenvals)
            end
        end

        # For maxima: find largest negative eigenvalue
        if classification == :maximum
            negative_eigenvals = filter(λ -> λ < -1e-12, eigenvals)
            if !isempty(negative_eigenvals)
                largest_negative_eigenvals[i] = maximum(negative_eigenvals)
            end
        end
    end

    return smallest_positive_eigenvals, largest_negative_eigenvals
end

"""
    compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}

Compute L2 (Frobenius) norm of each Hessian matrix.

# Returns
Vector{Float64}: ||H||_F for each Hessian matrix
"""
function compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}
    n_points = length(hessians)
    hessian_norms = Vector{Float64}(undef, n_points)

    for i in 1:n_points
        H = hessians[i]

        if any(isnan, H)
            hessian_norms[i] = NaN
            continue
        end

        try
            hessian_norms[i] = norm(H, 2)  # Frobenius norm
        catch e
            hessian_norms[i] = NaN
        end
    end

    return hessian_norms
end

"""
    compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame

Compute detailed eigenvalue statistics for each Hessian matrix.

# Returns
DataFrame with columns:
- eigenvalue_min: Smallest eigenvalue
- eigenvalue_max: Largest eigenvalue  
- condition_number: Ratio of largest to smallest absolute eigenvalue
- determinant: Determinant of Hessian
- trace: Trace of Hessian
"""
function compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame
    n_points = length(hessians)

    eigenvalue_min = Vector{Float64}(undef, n_points)
    eigenvalue_max = Vector{Float64}(undef, n_points)
    condition_number = Vector{Float64}(undef, n_points)
    determinant = Vector{Float64}(undef, n_points)
    trace = Vector{Float64}(undef, n_points)

    for i in 1:n_points
        H = hessians[i]

        if any(isnan, H)
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
            continue
        end

        try
            eigenvals = eigvals(Symmetric(H))
            eigenvalue_min[i] = minimum(eigenvals)
            eigenvalue_max[i] = maximum(eigenvals)

            # Condition number (ratio of largest to smallest absolute eigenvalue)
            abs_eigenvals = abs.(eigenvals)
            condition_number[i] = maximum(abs_eigenvals) / minimum(abs_eigenvals)

            determinant[i] = det(H)
            trace[i] = tr(H)

        catch e
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
        end
    end

    return DataFrame(
        eigenvalue_min = eigenvalue_min,
        eigenvalue_max = eigenvalue_max,
        condition_number = condition_number,
        determinant = determinant,
        trace = trace,
    )
end

"""
    extract_all_eigenvalues_for_visualization(f::Function, df::DataFrame)::Vector{Vector{Float64}}

Extract all eigenvalues for each critical point for enhanced visualization purposes.
This function recomputes Hessians to provide complete eigenvalue information.

# Arguments
- f: Objective function 
- df: DataFrame with critical point coordinates (x1, x2, x3, etc.)

# Returns
Vector{Vector{Float64}}: All eigenvalues for each critical point, sorted by magnitude
"""
function extract_all_eigenvalues_for_visualization(
    f::Function,
    df::DataFrame,
)::Vector{Vector{Float64}}
    n_points = nrow(df)

    # Determine dimensionality from DataFrame columns
    x_cols = [col for col in names(df) if startswith(string(col), "x")]
    n_dims = length(x_cols)

    # Extract point coordinates
    points = Matrix{Float64}(undef, n_points, n_dims)
    for i in 1:n_points
        for j in 1:n_dims
            points[i, j] = df[i, Symbol("x$j")]
        end
    end

    # Compute Hessians
    @debug "Computing Hessians for $n_points critical points"
    hessians = compute_hessians(f, points)

    # Extract all eigenvalues
    all_eigenvalues = store_all_eigenvalues(hessians)

    return all_eigenvalues
end

"""
    match_raw_to_refined_points(df_raw::DataFrame, df_refined::DataFrame)::Vector{Tuple{Int,Int,Float64}}

Match raw polynomial critical points to BFGS-refined points based on minimal Euclidean distance.

# Arguments
- df_raw: Raw critical points from polynomial system solving
- df_refined: BFGS-refined critical points

# Returns
Vector{Tuple{Int,Int,Float64}}: (raw_index, refined_index, distance) pairs sorted by distance
"""
function match_raw_to_refined_points(
    df_raw::DataFrame,
    df_refined::DataFrame,
)::Vector{Tuple{Int,Int,Float64}}
    # Determine dimensionality
    x_cols = [col for col in names(df_raw) if startswith(string(col), "x")]
    n_dims = length(x_cols)

    n_raw = nrow(df_raw)
    n_refined = nrow(df_refined)

    # Extract coordinates
    raw_coords = Matrix{Float64}(undef, n_raw, n_dims)
    refined_coords = Matrix{Float64}(undef, n_refined, n_dims)

    for i in 1:n_raw
        for j in 1:n_dims
            raw_coords[i, j] = df_raw[i, Symbol("x$j")]
        end
    end

    for i in 1:n_refined
        for j in 1:n_dims
            refined_coords[i, j] = df_refined[i, Symbol("x$j")]
        end
    end

    # Find best matches using Hungarian-style greedy matching
    matches = Tuple{Int,Int,Float64}[]
    used_refined = Set{Int}()

    for i in 1:n_raw
        best_distance = Inf
        best_refined_idx = 0

        for j in 1:n_refined
            if j in used_refined
                continue
            end

            # Compute Euclidean distance
            distance = norm(raw_coords[i, :] - refined_coords[j, :])

            if distance < best_distance
                best_distance = distance
                best_refined_idx = j
            end
        end

        if best_refined_idx > 0
            push!(matches, (i, best_refined_idx, best_distance))
            push!(used_refined, best_refined_idx)
        end
    end

    # Sort by distance (closest pairs first)
    sort!(matches, by = x -> x[3])

    return matches
end

# Visualization function declarations - implementations provided by Makie extensions
"""
    plot_hessian_norms(df::DataFrame)

Plot L2 norms of Hessian matrices by critical point type.
Requires CairoMakie or GLMakie to be loaded.

This function is implemented by the CairoMakie and GLMakie extensions.
"""
function plot_hessian_norms end

"""
    plot_condition_numbers(df::DataFrame)

Plot condition numbers of Hessian matrices by critical point type.
Requires CairoMakie or GLMakie to be loaded.

This function is implemented by the CairoMakie and GLMakie extensions.
"""
function plot_condition_numbers end

"""
    plot_critical_eigenvalues(df::DataFrame)

Plot critical eigenvalues for minima and maxima validation.
Requires CairoMakie or GLMakie to be loaded.

This function is implemented by the CairoMakie and GLMakie extensions.
"""
function plot_critical_eigenvalues end

"""
    plot_all_eigenvalues(f::Function, df::DataFrame; sort_by=:magnitude)

Plot all eigenvalues for each critical point with enhanced visualization.
Shows complete eigenvalue spectrum (3 eigenvalues for 3D problems).
Requires CairoMakie or GLMakie to be loaded.

# Arguments
- f: Objective function (needed to recompute Hessians)
- df: DataFrame with critical point information
- sort_by: Sorting criterion (:magnitude, :abs_magnitude, :smallest, :largest, :spread, :index)

# Features
- Separate subplots for each critical point type (minimum, saddle, maximum)
- Colors distinguish eigenvalue order: Red (λ₁), Blue (λ₂), Green (λ₃)
- Stroke colors distinguish critical point types: Green (minimum), Orange (saddle), Red (maximum)
- Shows complete eigenvalue spectrum with vertical alignment per critical point
- Dotted lines connect eigenvalues for the same critical point
- Includes zero reference line for mathematical validation
- Sorting applied within each critical point type separately
- Recommended sort_by=:magnitude for best visual clarity

# Examples
```julia
using CairoMakie
# Standard magnitude plot (preserves sign)
fig1 = plot_all_eigenvalues(f, df_enhanced, sort_by=:magnitude)

# Absolute magnitude plot (compares magnitudes only)
fig2 = plot_all_eigenvalues(f, df_enhanced, sort_by=:abs_magnitude)

# Eigenvalue spread plot (orders by largest - smallest eigenvalue)
fig3 = plot_all_eigenvalues(f, df_enhanced, sort_by=:spread)
```

This function is implemented by the CairoMakie and GLMakie extensions.
"""
function plot_all_eigenvalues end

"""
    plot_raw_vs_refined_eigenvalues(f::Function, df_raw::DataFrame, df_refined::DataFrame; 
                                   sort_by=:euclidean_distance)

Compare eigenvalues between raw polynomial critical points and BFGS-refined points.
Shows pairwise comparison with distance-based ordering and vertical alignment.
Requires CairoMakie or GLMakie to be loaded.

# Arguments
- f: Objective function (needed to compute Hessians)
- df_raw: Raw critical points from polynomial system solving
- df_refined: BFGS-refined critical points with enhanced analysis
- sort_by: Sorting criterion (:euclidean_distance, :function_value_diff, :eigenvalue_change)

# Features
- Pairwise matching based on minimal Euclidean distance
- Distance-based left-to-right ordering (closest pairs first)
- Vertical columns show raw (top) vs refined (bottom) eigenvalues
- Connecting lines show eigenvalue evolution during refinement
- Color coding: Raw points (lighter), Refined points (darker)
- Separation distance annotations for each pair
- Side-by-side subplots for different critical point types

# Examples
```julia
using CairoMakie
# Distance-ordered comparison (default)
fig1 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced)

# Function value difference ordering
fig2 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced, sort_by=:function_value_diff)
```

This function is implemented by the CairoMakie and GLMakie extensions.
"""
function plot_raw_vs_refined_eigenvalues end
