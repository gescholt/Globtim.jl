@testset "relative_l2_error" begin
    # Use the same Deuflhard function from runtests.jl
    n = 2
    scale_factor = 7.0 / 5.0

    TR = test_input(
        Deuflhard,
        dim = n,
        center = [0.0, 0.0],
        GN = 20,
        sample_range = scale_factor
    )

    @testset "Basic properties" begin
        pol = Constructor(TR, 6, basis = :chebyshev, normalized = false)

        rel = Globtim.relative_l2_error(pol)

        # Must be a finite positive number
        @test !isnan(rel)
        @test !isinf(rel)
        @test rel > 0.0

        # For a reasonable approximation at degree 6, relative error should be < 1
        # (polynomial captures most of the function's energy)
        @test rel < 1.0

        # rel = nrm / norm_F, so rel * norm_F ≈ nrm
        # We can't easily access norm_F directly, but we can verify
        # that rel < 1 implies the polynomial is better than zero
        @test pol.nrm > 0.0
    end

    @testset "Decreases with degree" begin
        rel_errors = Float64[]
        for deg in [4, 8, 12, 16]
            pol = Constructor(TR, deg, basis = :chebyshev, normalized = false)
            push!(rel_errors, Globtim.relative_l2_error(pol))
        end

        # Relative error should generally decrease with degree
        # (convergence of polynomial approximation)
        @test rel_errors[end] < rel_errors[1]

        # At degree 16 on a smooth function with 20-point grid,
        # the relative error should be quite small
        @test rel_errors[end] < 0.1
    end

    @testset "Consistent with absolute norm" begin
        pol = Constructor(TR, 10, basis = :chebyshev, normalized = false)

        rel = Globtim.relative_l2_error(pol)
        abs_err = pol.nrm

        # If abs_err is small, rel should also be small
        # If abs_err > 0, rel should be > 0
        @test (abs_err > 0) == (rel > 0)

        # relative error <= 1 means polynomial is meaningful
        @test rel <= 1.0
    end
end
