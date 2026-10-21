# Bead hdgw.24 (DEP-AUDIT OPTIM-AD follow-up): the refiner in refine.jl is Optim's
# NelderMead. Its only stop is the spread of f over the simplex, which Optim reports in
# the g slot. That stop is a function-value stop (:f_tol), and a gradient tolerance has
# nothing to act on, so passing one is an error rather than a silently ignored setting.

using Test
using Globtim
using DataFrames
using Optim

@testset "refine.jl NelderMead labels and bfgs_g_tol (hdgw.24)" begin
    q(x) = (x[1] - 0.3)^2 + 2 * (x[2] + 0.2)^2
    cfg = Globtim.BFGSConfig()

    @testset "NelderMead spread stop is :f_tol, a gradient stop stays :gradient" begin
        r_nm = Optim.optimize(q, [0.7, 0.5], Optim.NelderMead(), Optim.Options(g_abstol = 1e-10))
        @test Optim.converged(r_nm) && Optim.g_converged(r_nm)
        @test Globtim.determine_convergence_reason(r_nm, 1e-10, cfg) == :f_tol

        r_lb = Optim.optimize(q, [0.7, 0.5], Optim.LBFGS(), Optim.Options(g_abstol = 1e-10))
        @test Optim.g_converged(r_lb)
        @test Globtim.determine_convergence_reason(r_lb, 1e-10, cfg) == :gradient
    end

    @testset "enhanced_bfgs_refinement reports the NelderMead stop as :f_tol" begin
        res = Globtim.enhanced_bfgs_refinement([[0.7, 0.5]], [q([0.7, 0.5])], ["o1"], q, cfg)
        @test only(res).converged
        @test only(res).convergence_reason == :f_tol
    end

    @testset "analyze_critical_points refuses bfgs_g_tol" begin
        TR = TestInput(q, dim = 2, center = [0.0, 0.0], GN = 4, sample_range = 1.0)
        df = DataFrame(x1 = [0.3], x2 = [-0.2], z = [q([0.3, -0.2])])
        @test_throws ArgumentError analyze_critical_points(q, df, TR; verbose = false, bfgs_g_tol = 1e-8)
        # The default (no bfgs_g_tol) still runs.
        enhanced, _ = analyze_critical_points(q, copy(df), TR; verbose = false, enable_hessian = false)
        @test nrow(enhanced) == 1
    end
end
