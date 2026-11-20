@testset "HC solve kwargs (sparsify + polyhedral)" begin
    # Test the sparsify_threshold and start_system kwargs.
    # Uses 3D Rosenbrock to exercise :polyhedral and sparsification code paths
    # that are NOT hit by the default 2D tests (which resolve to :total_degree).

    n = 3
    d = 4
    # Box [-1.5, 1.5]^3: the minimum (1, 1, 1) is interior. On [-1, 1]^3 it sat on the corner
    # and the in-box filter kept or dropped it on rounding at 1e-12 (a rare failure of the
    # `>= 1` checks below).
    TR = TestInput(Rosenbrock, dim = n, center = zeros(n), GN = 10, sample_range = 1.5)
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

@testset "HC solve: failed paths are retried and reported" begin
    # Σ yᵢ⁴ − yᵢ² on [-1, 1]^3: a degree-4 fit reproduces it, and its gradient system has
    # 27 real roots (each yᵢ ∈ {0, ±1/√2}), all inside the box. The polyhedral start loses
    # paths on this system in a few percent of solves (bead history: 25 of 300).
    n = 3
    f(y) = sum(y .^ 4 .- y .^ 2)
    TR = TestInput(f, dim = n, center = zeros(n), GN = 10, sample_range = 1.0)
    pol = Constructor(TR, 4, basis = :chebyshev, normalized = true)
    @polyvar x[1:n]

    ref = Base.RefValue{Any}(nothing)
    cps = solve_polynomial_system(x, pol; start_system = :total_degree, path_stats_ref = ref)
    st = ref[]
    for k in (:n_path_failures, :n_at_infinity, :n_solve_attempts, :paths_tracked)
        @test hasproperty(st, k)
    end
    @test st.start_system == :total_degree
    @test st.n_solve_attempts >= 1
    @test st.n_path_failures == 0
    @test length(cps) == 27

    # Polyhedral with retries: whenever no failed path is left, the census is complete.
    n_clean = 0
    for _ in 1:15
        r = Base.RefValue{Any}(nothing)
        c = solve_polynomial_system(
            x,
            pol;
            start_system = :polyhedral,
            hc_retries = 2,
            path_stats_ref = r,
        )
        @test 1 <= r[].n_solve_attempts <= 3
        if r[].n_path_failures == 0
            n_clean += 1
            @test length(c) == 27
        end
    end
    @test n_clean >= 13

    @test_throws ArgumentError solve_polynomial_system(x, pol; hc_retries = -1)
end
