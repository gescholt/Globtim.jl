# N2 (EVIDENCE_MAP_2026-10.md): Hessian-eigenaligned boxes and the outflow measurement.
# Reproduces the atlas measurement (BOUNDARY_AND_SUBDIVISION.md §2): on a rotated
# quadratic with eigenvalues 1 and 1e4 at 30°, an axis-aligned box about the minimum has
# the same outflow fraction at every size, while the eigen-aligned box closes.

using Test
using Globtim
using LinearAlgebra
using Random
using ForwardDiff

@testset "aligned boxes" begin
    θ = π / 6
    R = [cos(θ) -sin(θ); sin(θ) cos(θ)]
    Λ = Diagonal([1.0, 1e4])
    H = R * Λ * R'
    xs = [0.3, -0.2]
    q(x) = 0.5 * dot(x - xs, H * (x - xs)) + 7.0           # minimum at xs

    @testset "construction, maps, bounds" begin
        b = eigen_aligned_box(q, xs; half_widths = 0.5)
        @test b.center == xs
        @test b.half_widths == [0.5, 0.5]
        @test b.eigenvalues ≈ [1.0, 1e4] rtol = 1e-10
        @test isapprox(b.Q' * b.Q, I; atol = 1e-12)
        # columns are eigenvectors (up to sign)
        @test abs(dot(b.Q[:, 1], R[:, 1])) ≈ 1 atol = 1e-10
        y = [0.1, -0.2]
        @test to_aligned(b, to_physical(b, y)) ≈ y atol = 1e-12
        @test aligned_bounds(b) == [(-0.5, 0.5), (-0.5, 0.5)]
        g = AlignedObjective(q, b)
        @test g(zeros(2)) ≈ q(xs)
        # critical point of g is at y = 0; Hessian of g is diagonal (Qᵀ H Q)
        @test norm(ForwardDiff.gradient(g, zeros(2))) < 1e-10
        Hg = ForwardDiff.hessian(g, zeros(2))
        @test Hg ≈ Diagonal(b.eigenvalues) atol = 1e-6
        # explicit Hessian and vector half-widths
        b2 = eigen_aligned_box(q, xs; half_widths = [0.2, 0.3], hessian = H)
        @test b2.half_widths == [0.2, 0.3]
        # :eigen shape widens the flat direction
        b3 = eigen_aligned_box(q, xs; half_widths = 0.1, shape = :eigen)
        @test b3.half_widths[1] > b3.half_widths[2]
        @test b3.half_widths[2] ≈ 0.1
        @test_throws ArgumentError eigen_aligned_box(q, xs; half_widths = 0.1, shape = :cube)
        @test_throws DimensionMismatch eigen_aligned_box(q, xs; half_widths = [1.0, 2.0, 3.0])
        @test_throws ArgumentError AlignedBox(xs, [1.0 1.0; 0.0 1.0], [1.0, 1.0])
        @test_throws ArgumentError AlignedBox(xs, Matrix(1.0I, 2, 2), [1.0, 0.0])
        ab = axis_aligned_box([(0.0, 1.0), (-2.0, 2.0)])
        @test ab.center == [0.5, 0.0] && ab.half_widths == [0.5, 2.0] && ab.Q == I
        @test box_summary(b)["eigenvalues"] == b.eigenvalues
    end

    @testset "outflow: axis-aligned is scale-invariant and leaky, eigen-aligned closes" begin
        fracs = Float64[]
        for h in (1e0, 1e-2, 1e-4, 1e-6)
            ab = AlignedBox(xs, Matrix(1.0I, 2, 2), [h, h])
            of = box_outflow(q, ab; n_samples = 256, rng = MersenneTwister(1))
            push!(fracs, of.fraction)
            @test of.samples == 4 * 256
        end
        @test all(f -> f < 0.95, fracs)                      # leaky at every scale
        @test maximum(fracs) - minimum(fracs) < 0.03          # and scale-invariant
        @test fracs[1] ≈ 0.8928 atol = 0.03                   # the atlas number
        for h in (1e0, 1e-3)
            eb = eigen_aligned_box(q, xs; half_widths = h)
            of = box_outflow(q, eb; n_samples = 256, rng = MersenneTwister(1))
            @test of.fraction == 1.0
            @test of.n_faces_closed == 4
            @test of.min_cos > 0
        end
        # shaped but not rotated does not close either
        sb = AlignedBox(xs, Matrix(1.0I, 2, 2), [1.0, 0.01])
        @test box_outflow(q, sb; n_samples = 256, rng = MersenneTwister(1)).fraction < 0.95
        # a box that does not contain the minimum is not closed
        far = eigen_aligned_box(q, xs .+ [2.0, 0.0]; half_widths = 0.5)
        @test box_outflow(q, far; n_samples = 64).fraction < 1.0
        @test_throws ArgumentError box_outflow(q, sb; n_samples = 0)
    end

    @testset "run_standard_experiment in the aligned frame" begin
        # Degree-2 surrogate of the quadratic is exact; one critical point, mapped back.
        dir = mktempdir()
        cfg = Globtim.ExperimentCLI.ExperimentParams(;
            domain_size = 0.5,
            GN = 6,
            degree_range = 2:2,
            max_time = 60.0,
        )
        res = withenv("GLOBTIM_LEDGER_APPEND" => "0") do   # no central-ledger row for a test
            run_standard_experiment(
                objective_function = q,
                objective_name = "rotated_quadratic",
                bounds = [(xs[1] - 0.5, xs[1] + 0.5), (xs[2] - 0.5, xs[2] + 0.5)],
                experiment_config = cfg,
                output_dir = dir,
                true_params = xs,
                align_box = xs,
                outflow_samples = 64,
            )
        end
        md = res[:user_metadata]
        @test md["box_outflow"]["given"]["fraction"] < 1.0
        @test md["box_outflow"]["aligned"]["fraction"] == 1.0
        @test haskey(md, "aligned_box") && length(md["aligned_box"]["Q_columns"]) == 2
        @test md["gate_metric"] == "rel_l2"
        @test isfile(joinpath(dir, "aligned_box.json"))
        r = only(res[:degree_results])
        @test r.status == "success"
        @test r.recovery_error < 1e-6                  # true_params mapped into the frame
        @test norm(r.best_estimate) < 1e-6             # aligned frame: minimum at y = 0
        @test isfile(joinpath(dir, "critical_points_physical_deg_2.csv"))
        phys = readlines(joinpath(dir, "critical_points_physical_deg_2.csv"))
        @test length(phys) == 2                        # header + one point
        vals = parse.(Float64, split(phys[2], ",")[2:3])
        @test norm(vals - xs) < 1e-6
    end
end
