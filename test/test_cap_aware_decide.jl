"""
Test suite for the cap-aware `decide_action` / `decide_action_lsfit` methods
(bead 8f4p.5.4).

The rule under test: at `degree == max_degree` a `:bump` verdict cannot bump —
`adaptive_refine` falls through to the split path and chooses the axis with
`select_cut_dimension`, ignoring the per-axis verdicts. The cap-aware methods
return an explicit axis instead, so the predicate's evidence reaches that choice.

Below the cap, and whenever any axis votes `:split`, behaviour must be identical
to the verdicts-only methods — that equivalence is asserted directly.
"""

using Test
using Globtim
using Globtim: decide_action, decide_action_lsfit, LSFitAxisResult

# axis_shell_stats-shaped entry; only `total` and `decay` are read.
_stat(total, decay) =
    (shell_mass = Dict{Int,Float64}(), total = total, concentration = NaN, decay = decay)

@testset "cap-aware decide_action (8f4p.5.4)" begin
    @testset "below the cap — identical to the verdicts-only method" begin
        for verdicts in ([:bump, :bump, :bump], [:bump, :split, :bump], [:split, :split])
            stats = [_stat(1.0, 0.5) for _ in verdicts]
            @test decide_action(verdicts, stats; degree = 4, max_degree = 14) ==
                  decide_action(verdicts)
        end
    end

    @testset "a :split verdict still wins, cap or no cap" begin
        verdicts = [:bump, :split, :split]
        stats = [_stat(1.0, 0.1), _stat(1.0, 9.0), _stat(1.0, 9.0)]
        # Lowest-indexed :split, regardless of degree — the cap rule must not
        # hijack a leaf the predicate already wants split on a specific axis.
        @test decide_action(verdicts, stats; degree = 4, max_degree = 14) == (:split, 2)
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) == (:split, 2)
    end

    @testset "at the cap, all-:bump becomes a split on the weakest-decay axis" begin
        verdicts = [:bump, :bump, :bump]
        # axis 2 has the slowest decay ⇒ least resolved ⇒ the one to cut
        stats = [_stat(1.0, 2.0), _stat(1.0, 0.3), _stat(1.0, 1.5)]
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) == (:split, 2)
        # The verdicts-only method would have thrown this away:
        @test decide_action(verdicts) == (:bump, nothing)
    end

    @testset "over the cap behaves like at the cap" begin
        verdicts = [:bump, :bump]
        stats = [_stat(1.0, 5.0), _stat(1.0, 0.2)]
        @test decide_action(verdicts, stats; degree = 16, max_degree = 14) == (:split, 2)
    end

    @testset "decay ties break to the lowest index" begin
        verdicts = [:bump, :bump, :bump]
        stats = [_stat(1.0, 0.7), _stat(1.0, 0.7), _stat(1.0, 0.7)]
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) == (:split, 1)
    end

    @testset "massless and NaN-decay axes are skipped" begin
        verdicts = [:bump, :bump, :bump]
        # axis 1 has the smallest decay but no mass; axis 2's decay is unusable.
        stats = [_stat(0.0, 0.01), _stat(1.0, NaN), _stat(1.0, 3.0)]
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) == (:split, 3)
    end

    @testset "no usable decay — falls back to the heaviest axis" begin
        verdicts = [:bump, :bump, :bump]
        stats = [_stat(0.5, NaN), _stat(4.0, NaN), _stat(1.0, NaN)]
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) == (:split, 2)
    end

    @testset "no signal at all — split with no preference" begin
        verdicts = [:bump, :bump]
        stats = [_stat(0.0, NaN), _stat(0.0, NaN)]
        # `nothing` is deliberate: the caller falls back to select_cut_dimension
        # rather than us inventing an axis.
        @test decide_action(verdicts, stats; degree = 14, max_degree = 14) ==
              (:split, nothing)
        @test decide_action(verdicts, []; degree = 14, max_degree = 14) == (:split, nothing)
    end

    # ========================================================================
    # lsfit mirror
    # ========================================================================

    _ls(v, rho, mass) = LSFitAxisResult(v, rho, NaN, 3, mass)

    @testset "lsfit — below the cap matches the results-only method" begin
        for verdicts in ([:bump, :bump], [:bump, :split])
            rs = [_ls(v, 2.0, 1.0) for v in verdicts]
            @test decide_action_lsfit(rs; degree = 4, max_degree = 14) ==
                  decide_action_lsfit(rs)
        end
    end

    @testset "lsfit — at the cap, all-:bump splits on the smallest rho" begin
        rs = [_ls(:bump, 3.0, 1.0), _ls(:bump, 1.2, 1.0), _ls(:bump, 8.0, 1.0)]
        # smallest rho = slowest geometric convergence = least resolved
        @test decide_action_lsfit(rs; degree = 14, max_degree = 14) == (:split, 2)
        @test decide_action_lsfit(rs) == (:bump, nothing)
    end

    @testset "lsfit — a :split verdict still wins at the cap" begin
        rs = [_ls(:bump, 1.1, 1.0), _ls(:split, 9.0, 1.0)]
        @test decide_action_lsfit(rs; degree = 14, max_degree = 14) == (:split, 2)
    end

    @testset "lsfit — NaN rho and massless axes skipped, then mass fallback" begin
        rs = [_ls(:bump, NaN, 1.0), _ls(:bump, 1.0, 0.0), _ls(:bump, 5.0, 1.0)]
        @test decide_action_lsfit(rs; degree = 14, max_degree = 14) == (:split, 3)

        rs2 = [_ls(:bump, NaN, 0.5), _ls(:bump, NaN, 7.0)]
        @test decide_action_lsfit(rs2; degree = 14, max_degree = 14) == (:split, 2)
    end
end
