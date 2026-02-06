"""
SparsificationExperiment Module — Polynomial sparsification analysis.

Sparsification operates on the **coefficients** of the polynomial approximant:
zeroing small coefficients produces a sparser polynomial that may solve faster
via HomotopyContinuation. The critical point solving and coordinate transformation
are the same standard pipeline as for full polynomials (via `solve_and_transform`).

The downstream quality assessment (capture analysis, gradient validation, refinement)
is identical to the standard post-processing pipeline in GlobtimPostProcessing —
sparsified polynomial variants produce critical points that go through the same
capture analysis as any other polynomial approximation.

Usage:
```julia
using Globtim

results = run_sparsification_experiment(
    objective = my_func,
    bounds = [(-1.0, 1.0), (-1.0, 1.0)],
    degree_range = 4:2:10,
    thresholds = [1e-5, 1e-4, 1e-3],
    threshold_labels = ["1e-5 (mild)", "1e-4 (moderate)", "1e-3 (aggressive)"],
    GN = 12,
)

# Each result contains full + sparsified critical points in domain coordinates.
# Feed these into GlobtimPostProcessing capture analysis as usual.
```
"""
module SparsificationExperiment

using Globtim
using DynamicPolynomials
using Printf

export SparsifiedVariant, SparsificationDegreeResult, run_sparsification_experiment

"""
    SparsifiedVariant

Result of solving one sparsified polynomial variant at a specific threshold.
Contains the critical points in original domain coordinates (same format as
`DegreeResult.critical_points` from the standard experiment pipeline).
"""
struct SparsifiedVariant
    threshold::Float64
    threshold_label::String
    critical_points::Vector{Vector{Float64}}  # in original domain coordinates
    n_nonzero_coeffs::Int
    l2_ratio::Float64
    solve_time::Float64
    sparsity_pct::Float64  # percentage of coefficients zeroed
end

"""
    SparsificationDegreeResult

Full + sparsified results for a single polynomial degree.
The `full_*` fields mirror what `run_standard_experiment` produces for that degree.
If `degree_results` from a prior experiment are provided, the full solve is reused.
"""
struct SparsificationDegreeResult
    degree::Int
    full_n_coeffs::Int
    full_critical_points::Vector{Vector{Float64}}  # in original domain coordinates
    full_solve_time::Float64
    l2_approx_error::Float64
    variants::Vector{SparsifiedVariant}
end

"""
    run_sparsification_experiment(;
        objective, bounds, degree_range, thresholds, threshold_labels,
        GN, basis=:chebyshev, degree_results=nothing, io=stdout
    ) -> Vector{SparsificationDegreeResult}

Run a sparsification experiment: for each degree, construct the polynomial approximation,
then solve both the full and sparsified polynomial systems via HomotopyContinuation.

Sparsification only modifies polynomial coefficients — the solving and coordinate
transformation pipeline is identical to `run_standard_experiment`.

# Arguments
- `objective::Function`: Objective function f(x) -> Float64
- `bounds::Vector{Tuple{Float64, Float64}}`: Domain bounds [(lb₁,ub₁), ...]
- `degree_range`: Polynomial degrees to analyze (e.g., `4:2:10`)
- `thresholds::Vector{Float64}`: Sparsification thresholds (e.g., `[1e-5, 1e-4, 1e-3]`)
- `threshold_labels::Vector{String}`: Human-readable labels for each threshold
- `GN::Int`: Grid size per dimension for polynomial construction

# Keyword Arguments
- `basis::Symbol = :chebyshev`: Polynomial basis
- `degree_results = nothing`: If provided (from `run_standard_experiment`), reuses the full
  solve results instead of re-solving. Must contain `DegreeResult` entries for all degrees
  in `degree_range`.
- `io::IO = stdout`: Output stream for progress messages

# Returns
Vector of `SparsificationDegreeResult`, one per degree. Each contains the full polynomial
results and a vector of `SparsifiedVariant` results (one per threshold).

Critical points are in original domain coordinates — ready for `compute_capture_analysis`
or any other post-processing from GlobtimPostProcessing.
"""
function run_sparsification_experiment(;
    objective::Function,
    bounds::Vector{Tuple{Float64, Float64}},
    degree_range,
    thresholds::Vector{Float64},
    threshold_labels::Vector{String},
    GN::Int,
    basis::Symbol = :chebyshev,
    degree_results = nothing,
    io::IO = stdout,
)
    @assert length(thresholds) == length(threshold_labels) "thresholds and threshold_labels must have same length"

    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]

    # Build degree_results lookup for reuse (if provided)
    dr_by_degree = Dict{Int, Any}()
    if degree_results !== nothing
        for dr in degree_results
            dr_by_degree[dr.degree] = dr
        end
    end

    # Build tensor representation ONCE (invariant across degrees)
    println(io, "  Building tensor representation ($(GN)^$(dimension) = $(GN^dimension) grid points)...")
    TR = Globtim.test_input(
        objective,
        dim = dimension,
        center = center,
        GN = GN,
        sample_range = sample_range,
    )

    results = SparsificationDegreeResult[]

    for deg in degree_range
        println(io, "\n  Degree $deg: constructing polynomial...")
        pol = Globtim.Constructor(TR, deg, basis=basis, normalized=false)
        n_total_coeffs = length(pol.coeffs)
        println(io, "  $n_total_coeffs coefficients, L2 approx error = $(@sprintf("%.2e", pol.nrm))")

        # Full solve: reuse from degree_results if available, otherwise solve now
        full_cps, full_solve_time = if haskey(dr_by_degree, deg) && dr_by_degree[deg].status == "success"
            dr = dr_by_degree[deg]
            println(io, "  Full solve: reusing $(dr.n_critical_points) CPs from standard experiment " *
                        "($((@sprintf("%.2f", dr.critical_point_solving_time)))s)")
            (dr.critical_points, dr.critical_point_solving_time)
        else
            println(io, "  Solving full polynomial system...")
            cps, st = Globtim.solve_and_transform(pol, bounds)
            println(io, "  Full: $(length(cps)) CPs, solve time = $(@sprintf("%.2f", st))s")
            (cps, st)
        end

        # Sparsified variants
        variants = SparsifiedVariant[]
        for (tidx, threshold) in enumerate(thresholds)
            label = threshold_labels[tidx]
            println(io, "  Sparsifying at threshold $(label)...")

            sparse_result = Globtim.sparsify_polynomial(pol, threshold, mode=:relative)
            sparse_cps, sparse_solve_time = Globtim.solve_and_transform(
                sparse_result.polynomial, bounds
            )

            sparsity_pct = 100.0 * (1.0 - sparse_result.sparsity)
            speedup = full_solve_time / max(sparse_solve_time, 1e-10)

            println(io, "    -> $(sparse_result.new_nnz)/$n_total_coeffs coeffs retained " *
                        "($(@sprintf("%.1f%%", sparsity_pct)) zeroed), " *
                        "$(length(sparse_cps)) CPs, " *
                        "solve = $(@sprintf("%.2f", sparse_solve_time))s ($(@sprintf("%.1f×", speedup)) speedup)")

            push!(variants, SparsifiedVariant(
                threshold, label,
                sparse_cps, sparse_result.new_nnz,
                sparse_result.l2_ratio, sparse_solve_time, sparsity_pct,
            ))
        end

        push!(results, SparsificationDegreeResult(
            deg, n_total_coeffs, full_cps, full_solve_time, pol.nrm, variants,
        ))
    end

    return results
end

end # module SparsificationExperiment
