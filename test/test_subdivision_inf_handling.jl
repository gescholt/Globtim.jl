using Test
using Globtim

@testset "Subdivision with Inf-returning objectives" begin
    # Simulate an ODE objective that returns Inf in parts of the domain
    # (e.g., ODE integration failure at certain parameter values)

    # 2D quadratic that returns Inf in upper-right corner
    function objective_with_inf(x)
        if x[1] > 0.8 && x[2] > 0.8
            return Inf
        end
        return x[1]^2 + x[2]^2
    end

    bounds = [(-1.0, 1.0), (-1.0, 1.0)]

    @testset "estimate_subdomain_error handles Inf gracefully" begin
        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        sd = tree.subdomains[1]
        l2 = Globtim.estimate_subdomain_error(objective_with_inf, sd, 4, basis = :chebyshev)

        # Should get a finite (possibly large) L2 error, not Inf
        @test isfinite(l2)
        @test isfinite(sd.l2_error)
        # Should have constructed a polynomial
        @test sd.polynomial !== nothing
    end

    @testset "two_phase_refine handles Inf-returning objective" begin
        tree = Globtim.two_phase_refine(
            objective_with_inf,
            bounds,
            4;
            coarse_tolerance = 1e-2,
            fine_tolerance = 1e-4,
            tolerance_mode = :absolute,
            max_depth = 3,
            max_leaves = 50,
            parallel = false,
            basis = :chebyshev,
            verbose = false,
        )

        # Should produce a tree with leaves (not all failed)
        n_total = length(tree.converged_leaves) + length(tree.active_leaves)
        @test n_total > 1  # Should have subdivided

        # Leaves away from the Inf region should have low error
        for id in tree.converged_leaves
            sd = tree.subdomains[id]
            @test isfinite(sd.l2_error)
            @test sd.polynomial !== nothing
        end
    end

    @testset "subdivision isolates Inf region" begin
        # Objective that's smooth except in a small corner
        function corner_inf(x)
            if x[1] > 0.9 && x[2] > 0.9
                return Inf
            end
            return sin(x[1]) * cos(x[2])
        end

        tree = Globtim.two_phase_refine(
            corner_inf,
            bounds,
            6;
            coarse_tolerance = 1e-4,
            fine_tolerance = 1e-6,
            tolerance_mode = :absolute,
            max_depth = 4,
            max_leaves = 100,
            parallel = false,
            basis = :chebyshev,
            verbose = false,
        )

        # Most leaves should converge (the function is smooth almost everywhere)
        n_converged = length(tree.converged_leaves)
        n_total = n_converged + length(tree.active_leaves)
        @test n_converged > 0
        # At least some fraction should converge
        @test n_converged / n_total > 0.2
    end

    @testset "all-Inf subdomain still gets Inf error" begin
        # If every grid point is Inf, there's nothing to fit
        all_inf(x) = Inf

        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        sd = tree.subdomains[1]
        l2 = Globtim.estimate_subdomain_error(all_inf, sd, 4, basis = :chebyshev)

        @test l2 == Inf
        @test sd.l2_error == Inf
    end

    @testset "monolithic ODE-like objective produces finite L2" begin
        # Realistic scenario: ODE objective with failures at domain boundaries
        function ode_like(x)
            # Fails when parameters are extreme (common in ODE models)
            if abs(x[1]) > 1.5 || abs(x[2]) > 1.5
                return Inf
            end
            return exp(-(x[1] - 0.5)^2 - (x[2] + 0.3)^2) + 0.1 * x[1] * x[2]
        end

        bounds_wide = [(-2.0, 2.0), (-2.0, 2.0)]
        tree = Globtim.SubdivisionTree(bounds_wide; degree = 6)
        sd = tree.subdomains[1]
        l2 = Globtim.estimate_subdomain_error(ode_like, sd, 6, basis = :chebyshev)

        # Should produce a finite L2 even though some grid points are Inf
        @test isfinite(l2)
        @test sd.polynomial !== nothing
    end
end
