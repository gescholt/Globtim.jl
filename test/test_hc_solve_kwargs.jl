@testset "HC solve kwargs (sparsify + polyhedral)" begin
    # Test the sparsify_threshold and start_system kwargs added in bead zs7q.
    # Uses 3D Rosenbrock to exercise :polyhedral and sparsification code paths
    # that are NOT hit by the default 2D tests (which resolve to :total_degree).

    n = 3
    d = 4
    TR = TestInput(Rosenbrock, dim = n, center = zeros(n), GN = 10, sample_range = 1.0)
    pol = Constructor(TR, d, basis = :chebyshev, normalized = true)
    @polyvar x[1:n]

    # ── 1. :auto resolves to :polyhedral for 3D
    cps_auto = solve_polynomial_system(x, pol)
    @test length(cps_auto) >= 1

    # ── 2. Explicit :polyhedral
    cps_poly = solve_polynomial_system(
        x,
        n,
        d,
        pol.coeffs;
        basis = :chebyshev,
        normalized = true,
        start_system = :polyhedral,
    )
    @test length(cps_poly) >= 1

    # ── 3. Sparsification + polyhedral
    cps_sparse = solve_polynomial_system(
        x,
        n,
        d,
        pol.coeffs;
        basis = :chebyshev,
        normalized = true,
        sparsify_threshold = 1e-6,
        start_system = :polyhedral,
    )
    @test length(cps_sparse) >= 1

    # ── 4. Explicit :total_degree still works for 3D
    cps_td = solve_polynomial_system(
        x,
        n,
        d,
        pol.coeffs;
        basis = :chebyshev,
        normalized = true,
        start_system = :total_degree,
    )
    @test length(cps_td) >= 1

    # ── 5. solve_polynomial_system_from_approx forwards kwargs
    cps_approx = Globtim.solve_polynomial_system_from_approx(
        x,
        pol;
        sparsify_threshold = 1e-6,
        start_system = :polyhedral,
    )
    @test length(cps_approx) >= 1
end
