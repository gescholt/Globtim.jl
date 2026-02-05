# profile_deuflhard4d_subdivision.jl
# Performance profiling of adaptive subdivision on Deuflhard_4d
#
# Run with: julia --project=. examples/profile_deuflhard4d_subdivision.jl
#
# Target runtime: 30-60 seconds total

using Globtim
using Printf
using LinearAlgebra
using Statistics

#==============================================================================#
#                         PROFILED FUNCTION WRAPPER                            #
#==============================================================================#

# Global counters (closure-based approach works with Function type constraint)
const EVAL_COUNT = Ref(0)
const EVAL_TIME = Ref(0.0)

function reset_counters!()
    EVAL_COUNT[] = 0
    EVAL_TIME[] = 0.0
end

"""
Create a profiled wrapper around a function that counts evaluations.
Returns a Function that adaptive_refine can accept.
"""
function make_profiled(f::Function)
    return function(x)
        EVAL_COUNT[] += 1
        t = @elapsed result = f(x)
        EVAL_TIME[] += t
        return result
    end
end

#==============================================================================#
#                              TIMING UTILITIES                                #
#==============================================================================#

"""
Run a single subdivision test with detailed timing breakdown.
"""
function run_profiled_subdivision(f_orig::Function, bounds, degree;
                                  l2_tolerance, max_depth, max_leaves=100,
                                  optimize_cuts=false, parallel=false)
    reset_counters!()
    f_profiled = make_profiled(f_orig)

    # Time the entire run
    total_time = @elapsed begin
        tree = adaptive_refine(f_profiled, bounds, degree,
            l2_tolerance=l2_tolerance,
            max_depth=max_depth,
            max_leaves=max_leaves,
            optimize_cuts=optimize_cuts,
            parallel=parallel,
            verbose=false)
    end

    return (
        tree = tree,
        total_time = total_time,
        eval_count = EVAL_COUNT[],
        eval_time = EVAL_TIME[],
        overhead_pct = 100.0 * (1.0 - EVAL_TIME[] / max(total_time, 1e-10))
    )
end

#==============================================================================#
#                              MAIN PROFILING                                  #
#==============================================================================#

function main()
    println("=" ^ 70)
    println("Adaptive Subdivision Profiling: Deuflhard 4D")
    println("=" ^ 70)
    println()

    # Domain for Deuflhard_4d
    bounds = [(-1.2, 1.2), (-1.2, 1.2), (-1.2, 1.2), (-1.2, 1.2)]

    # Configurations tuned for ~30-60s total runtime
    # Key: optimize_cuts=false drastically reduces runtime
    configs = [
        # Quick: degree 4, 9^4 = 6561 pts/subdomain, ~5-10s
        (name="quick",  degree=4, tol=1.0,  max_depth=2, max_leaves=8,  opt_cuts=false),
        # Medium: degree 4, more subdivisions, ~10-20s
        (name="medium", degree=4, tol=0.3,  max_depth=3, max_leaves=16, opt_cuts=false),
        # Full: degree 6, 13^4 = 28561 pts/subdomain, ~15-30s
        (name="full",   degree=6, tol=0.5,  max_depth=2, max_leaves=8,  opt_cuts=false),
    ]

    total_test_time = 0.0

    for cfg in configs
        n_pts = (2 * cfg.degree + 1)^4
        n_terms = binomial(4 + cfg.degree, cfg.degree)

        println("-" ^ 70)
        @printf("Config: %s\n", cfg.name)
        @printf("  Degree: %d, Grid pts/subdomain: %d, Polynomial terms: %d\n",
                cfg.degree, n_pts, n_terms)
        @printf("  Tolerance: %.2f, Max depth: %d, Max leaves: %d\n",
                cfg.tol, cfg.max_depth, cfg.max_leaves)
        println()

        # Run the test
        result = run_profiled_subdivision(Deuflhard_4d, bounds, cfg.degree,
            l2_tolerance=cfg.tol,
            max_depth=cfg.max_depth,
            max_leaves=cfg.max_leaves,
            optimize_cuts=cfg.opt_cuts,
            parallel=false)

        total_test_time += result.total_time

        # Results
        @printf("  Results:\n")
        @printf("    Total time:        %7.2f s\n", result.total_time)
        @printf("    Function evals:    %7d\n", result.eval_count)
        @printf("    Eval time:         %7.3f s  (%.1f%%)\n",
                result.eval_time, 100.0 * result.eval_time / result.total_time)
        @printf("    Overhead time:     %7.3f s  (%.1f%%)\n",
                result.total_time - result.eval_time, result.overhead_pct)
        @printf("    Avg eval time:     %7.1f μs\n",
                1e6 * result.eval_time / max(result.eval_count, 1))
        println()

        # Tree statistics
        tree = result.tree
        @printf("  Tree:\n")
        @printf("    Leaves: %d (converged: %d, active: %d)\n",
                n_leaves(tree), length(tree.converged_leaves), length(tree.active_leaves))
        @printf("    Max depth: %d\n", Globtim.get_max_depth(tree))
        @printf("    Total L2 error: %.4f\n", Globtim.total_error(tree))

        # Per-subdomain breakdown
        evals_per_subdomain = result.eval_count / max(n_leaves(tree), 1)
        time_per_subdomain = result.total_time / max(n_leaves(tree), 1)
        @printf("    Evals per leaf: %.0f (expected: %d)\n",
                evals_per_subdomain, n_pts)
        @printf("    Time per leaf: %.2f s\n", time_per_subdomain)
        println()
    end

    println("=" ^ 70)
    @printf("Total test runtime: %.1f s\n", total_test_time)
    println("=" ^ 70)

    # Detailed overhead analysis for the "full" config
    println()
    println("=" ^ 70)
    println("Detailed Overhead Analysis (degree=6, single subdomain)")
    println("=" ^ 70)

    analyze_single_subdomain_overhead(bounds, 6)
end

"""
Analyze where time goes for a single subdomain at given degree.
"""
function analyze_single_subdomain_overhead(bounds, degree)
    n_dim = length(bounds)
    n_samples_per_dim = 2 * degree + 1
    n_pts = n_samples_per_dim^n_dim
    n_terms = binomial(n_dim + degree, degree)

    @printf("\nGrid: %d^%d = %d points\n", n_samples_per_dim, n_dim, n_pts)
    @printf("Polynomial: %d terms (degree %d in %dD)\n", n_terms, degree, n_dim)
    println()

    # Time each component
    sd = Globtim.Subdomain(bounds)

    # 1. Grid generation
    t_grid = @elapsed begin
        grid = Globtim.generate_grid(n_dim, n_samples_per_dim - 1, basis=:chebyshev)
        grid_matrix = Globtim.grid_to_matrix(grid)
    end

    # 2. Function evaluation
    t_eval = @elapsed begin
        f_values = [Deuflhard_4d(sd.center .+ grid_matrix[i, :] .* sd.half_widths)
                    for i in 1:size(grid_matrix, 1)]
    end

    # 3. Support generation
    t_support = @elapsed begin
        Lambda = Globtim.SupportGen(n_dim, (:one_d_for_all, degree))
    end

    # 4. Vandermonde matrix construction
    t_vander = @elapsed begin
        V = Globtim.lambda_vandermonde(Lambda, grid_matrix, basis=:chebyshev)
    end

    # Regenerate for LS solve (V was used above)
    Lambda = Globtim.SupportGen(n_dim, (:one_d_for_all, degree))
    V = Globtim.lambda_vandermonde(Lambda, grid_matrix, basis=:chebyshev)

    # 5. Least squares solve
    t_ls = @elapsed begin
        coeffs = V \ f_values
    end

    # 6. Error computation
    t_error = @elapsed begin
        poly_values = V * coeffs
        errors = f_values .- poly_values
        weight = (2.0 / n_samples_per_dim)^n_dim
        l2_error = sqrt(sum(abs2.(errors)) * weight)
    end

    t_total = t_grid + t_eval + t_support + t_vander + t_ls + t_error

    println("Time Breakdown (single subdomain):")
    @printf("  Grid generation:     %7.3f s  (%5.1f%%)\n", t_grid, 100*t_grid/t_total)
    @printf("  Function evaluation: %7.3f s  (%5.1f%%)\n", t_eval, 100*t_eval/t_total)
    @printf("  Support generation:  %7.3f s  (%5.1f%%)\n", t_support, 100*t_support/t_total)
    @printf("  Vandermonde build:   %7.3f s  (%5.1f%%)\n", t_vander, 100*t_vander/t_total)
    @printf("  Least squares solve: %7.3f s  (%5.1f%%)\n", t_ls, 100*t_ls/t_total)
    @printf("  Error computation:   %7.3f s  (%5.1f%%)\n", t_error, 100*t_error/t_total)
    println("  " * "-" ^ 40)
    @printf("  Total:               %7.3f s\n", t_total)
    println()

    # Matrix sizes
    @printf("Matrix sizes:\n")
    @printf("  Vandermonde V: %d × %d (%.1f MB)\n",
            n_pts, n_terms, sizeof(Float64) * n_pts * n_terms / 1e6)
    @printf("  V condition number: %.2e\n", cond(V))
end

#==============================================================================#
#                   ODE-BASED OBJECTIVE: TOLERANCE COMPARISON                   #
#==============================================================================#

"""
Compare adaptive subdivision performance on an ODE objective function (LV 2D)
at coarse (1e-4) vs tight (1e-10) ODE tolerances.

This demonstrates the p5j feature: coarse tolerances during early subdivision
phases provide significant speedup with minimal accuracy loss.
"""
function ode_tolerance_comparison()
    println()
    println("=" ^ 70)
    println("ODE Tolerance Comparison: Adaptive Subdivision on LV 2D")
    println("=" ^ 70)
    println()

    using Dynamic_objectives
    using OrdinaryDiffEq: Vern9, Tsit5

    # Set up LV 2D model
    model, params, states, outputs = define_lotka_volterra_2D_model_v3_two_outputs()
    p_true = [1.0, 0.5]
    ic = [1.0, 0.5]
    bounds_2d = [(0.0, 3.0), (0.0, 2.0)]

    # Tolerance regimes to compare
    tolerance_configs = [
        (name="tight",  abstol=1e-10, reltol=1e-10),
        (name="medium", abstol=1e-8,  reltol=1e-8),
        (name="coarse", abstol=1e-6,  reltol=1e-6),
        (name="loose",  abstol=1e-4,  reltol=1e-4),
    ]

    for cfg in tolerance_configs
        println("-" ^ 70)
        @printf("ODE Tolerance: %s (abstol=%.0e, reltol=%.0e)\n",
                cfg.name, cfg.abstol, cfg.reltol)

        # Create objective at this tolerance
        obj = make_error_distance(
            model, outputs, ic, p_true,
            [0.0, 20.0], 30,
            L2_norm;
            return_inf_on_error=true,
            abstol=cfg.abstol,
            reltol=cfg.reltol
        )

        reset_counters!()
        f_profiled = make_profiled(obj)

        total_time = @elapsed begin
            tree = adaptive_refine(f_profiled, bounds_2d, 4,
                l2_tolerance=1e-4,
                max_depth=3,
                max_leaves=32,
                optimize_cuts=false,
                parallel=false,
                verbose=false)
        end

        @printf("  Total time:     %7.2f s\n", total_time)
        @printf("  ODE evals:      %7d\n", EVAL_COUNT[])
        @printf("  Eval time:      %7.3f s  (%.1f%%)\n",
                EVAL_TIME[], 100.0 * EVAL_TIME[] / max(total_time, 1e-10))
        @printf("  Avg eval time:  %7.1f ms\n",
                1e3 * EVAL_TIME[] / max(EVAL_COUNT[], 1))
        @printf("  Leaves: %d (converged: %d, active: %d)\n",
                n_leaves(tree), length(tree.converged_leaves), length(tree.active_leaves))
        @printf("  Total L2 error: %.6f\n", Globtim.total_error(tree))
        println()
    end

    # Demonstrate TolerantObjective with phase_callback
    println("-" ^ 70)
    println("TolerantObjective + phase_callback demo:")
    println()

    tol_obj = TolerantObjective(
        model, outputs, ic, p_true,
        [0.0, 20.0], 30,
        L2_norm;
        return_inf_on_error=true,
        abstol=1e-10,
        reltol=1e-10
    )

    function tol_phase_callback(f, phase, iter)
        if phase == :coarse
            set_tolerance!(f, 1e-4)
            println("  [phase_callback] Phase 1 (coarse): switched to tol=1e-4")
        elseif phase == :fine
            set_tolerance!(f, 1e-10)
            println("  [phase_callback] Phase 2 (fine): switched to tol=1e-10")
        end
    end

    reset_counters!()
    f_profiled_tol = make_profiled(tol_obj)

    total_time = @elapsed begin
        tree = two_phase_refine(f_profiled_tol, bounds_2d, 4,
            coarse_tolerance=1e-3,
            fine_tolerance=1e-5,
            max_depth=3,
            max_leaves=32,
            parallel=false,
            verbose=true,
            phase_callback=tol_phase_callback)
    end

    @printf("\n  Two-phase with adaptive tolerances:\n")
    @printf("    Total time:     %7.2f s\n", total_time)
    @printf("    ODE evals:      %7d\n", EVAL_COUNT[])
    @printf("    Eval time:      %7.3f s\n", EVAL_TIME[])
    @printf("    Leaves: %d (converged: %d, active: %d)\n",
            n_leaves(tree), length(tree.converged_leaves), length(tree.active_leaves))
    @printf("    Total L2 error: %.6f\n", Globtim.total_error(tree))
    println()
end

# Run
main()

# Run ODE tolerance comparison
ode_tolerance_comparison()
