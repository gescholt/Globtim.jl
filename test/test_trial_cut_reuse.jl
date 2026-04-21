using Test
using Globtim

# Helper: count how many times the objective is called.
mutable struct CallCounter
    n::Int
    f::Function
end
(c::CallCounter)(x) = (c.n += 1; c.f(x))

@testset "Trial-cut reuse (eqk)" begin
    f_quad = x -> sum(x.^2)

    @testset "estimate_subdomain_error uses cache on repeat call" begin
        sd = Globtim.Subdomain([0.0, 0.0], [1.0, 1.0]; degree=4)
        counter = CallCounter(0, f_quad)

        l2_first = Globtim.estimate_subdomain_error(counter, sd, 4, basis=:chebyshev)
        first_calls = counter.n
        @test first_calls > 0
        @test sd.polynomial !== nothing
        @test sd.samples !== nothing

        # Second call with cache enabled: no new evaluations
        l2_second = Globtim.estimate_subdomain_error(counter, sd, 4, basis=:chebyshev)
        @test counter.n == first_calls
        @test l2_first == l2_second

        # Opting out forces re-evaluation
        Globtim.estimate_subdomain_error(counter, sd, 4, basis=:chebyshev, use_cache=false)
        @test counter.n > first_calls
    end

    @testset "find_optimal_cut_sparse returns trial children" begin
        parent = Globtim.Subdomain([0.0, 0.0], [1.0, 1.0]; degree=4)
        opt_pos, trial_left, trial_right, trial_cut_pos =
            Globtim.find_optimal_cut_sparse(f_quad, parent, 1, 4; basis=:chebyshev)

        @test opt_pos isa Float64
        @test trial_cut_pos in (-0.5, 0.0, 0.5)
        @test trial_left.polynomial !== nothing
        @test trial_right.polynomial !== nothing
        @test trial_left.samples !== nothing
        @test trial_right.samples !== nothing
        @test isfinite(trial_left.l2_error)
        @test isfinite(trial_right.l2_error)
    end

    @testset "update_tree! reuses trial children when cut is close" begin
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree=4)
        parent_id = 1
        parent = tree.subdomains[parent_id]

        # Pre-populate parent as if process_subdomain had already run on it.
        Globtim.estimate_subdomain_error(f_quad, parent, 4, basis=:chebyshev)

        # Build trial children the way find_optimal_cut_sparse does.
        trial_left, trial_right = Globtim.subdivide_domain(parent, 1, 0.0)
        Globtim.estimate_subdomain_error(f_quad, trial_left, 4, basis=:chebyshev)
        Globtim.estimate_subdomain_error(f_quad, trial_right, 4, basis=:chebyshev)

        # Construct a ProcessResult with cut_position matching trial_cut_pos exactly.
        result = Globtim.ProcessResult(
            parent_id, Globtim.ActionSplit, true, 1, 0.0, parent.l2_error,
            nothing, (trial_left, trial_right), 0.0,
        )

        Globtim.update_tree!(tree, result, parent)
        left_id, right_id = parent.children
        @test tree.subdomains[left_id] === trial_left
        @test tree.subdomains[right_id] === trial_right
        @test tree.subdomains[left_id].polynomial !== nothing
        @test tree.subdomains[right_id].polynomial !== nothing
    end

    @testset "update_tree! falls back to fresh subdivide when cut drifts" begin
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree=4)
        parent_id = 1
        parent = tree.subdomains[parent_id]
        Globtim.estimate_subdomain_error(f_quad, parent, 4, basis=:chebyshev)

        trial_left, trial_right = Globtim.subdivide_domain(parent, 1, 0.0)
        Globtim.estimate_subdomain_error(f_quad, trial_left, 4, basis=:chebyshev)
        Globtim.estimate_subdomain_error(f_quad, trial_right, 4, basis=:chebyshev)

        # cut_position 0.6 is more than 0.1 away from trial_cut_pos 0.0 → no reuse.
        result = Globtim.ProcessResult(
            parent_id, Globtim.ActionSplit, true, 1, 0.6, parent.l2_error,
            nothing, (trial_left, trial_right), 0.0,
        )

        Globtim.update_tree!(tree, result, parent)
        left_id, right_id = parent.children
        @test tree.subdomains[left_id] !== trial_left
        @test tree.subdomains[right_id] !== trial_right
        # Freshly subdivided children have no cached polynomial yet
        @test tree.subdomains[left_id].polynomial === nothing
        @test tree.subdomains[right_id].polynomial === nothing
    end
end
