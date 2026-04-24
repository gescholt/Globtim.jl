"""
Tests for solve_tree_leaves per-leaf status observability (bead bacg).

Regression guards:
- solve_tree_leaves returns a NamedTuple (; critical_points, leaf_status).
- Missing HomotopyContinuation maps to :hc_missing, distinct from a legitimate
  zero-CP outcome.
- An empty tree (no polynomials fitted) reports :skipped for every leaf.
- A solved polynomial tree reports :ran.
"""

using Test
using Globtim

# Sentinel that reproduces the message emitted when the HC extension isn't
# loaded. `_classify_solve_failure` inspects the message via `sprint(showerror,
# e)`, so any Exception whose `showerror` prints the phrase works — we don't
# need to simulate the whole un-load path, which Julia disallows anyway.
struct _TestHCMissingErr <: Exception end
Base.showerror(io::IO, ::_TestHCMissingErr) = print(io,
    "solver=:hc requires HomotopyContinuation.jl. Add `using HomotopyContinuation` ...")

@testset "solve_tree_leaves observability" begin
    @testset "NamedTuple return shape" begin
        tree = Globtim.SubdivisionTree([(-1.0, 1.0), (-1.0, 1.0)]; degree = 0)
        r = Globtim.solve_tree_leaves(tree)
        @test hasproperty(r, :critical_points)
        @test hasproperty(r, :leaf_status)
        @test r.leaf_status isa Dict{Int,Symbol}
    end

    @testset ":skipped when polynomial is nothing" begin
        tree = Globtim.SubdivisionTree([(-1.0, 1.0), (-1.0, 1.0)]; degree = 0)
        r = Globtim.solve_tree_leaves(tree)
        @test isempty(r.critical_points)
        @test all(v == :skipped for v in values(r.leaf_status))
    end

    @testset ":ran when HC loaded and leaf has a polynomial" begin
        # runtests.jl loads HomotopyContinuation, so the HC extension is active.
        f(x) = (x[1] - 0.3)^2 + (x[2] - 0.1)^2
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.adaptive_refine(f, bounds, 4;
            max_depth = 1, max_leaves = 4, parallel = false)
        r = Globtim.solve_tree_leaves(tree; solver = :hc)
        @test !isempty(r.leaf_status)
        @test all(v == :ran for v in values(r.leaf_status))
    end

    @testset "_classify_solve_failure distinguishes :hc_missing" begin
        @test Globtim._classify_solve_failure(_TestHCMissingErr()) == :hc_missing
        @test Globtim._classify_solve_failure(ErrorException("unrelated")) == :exception
    end
end
