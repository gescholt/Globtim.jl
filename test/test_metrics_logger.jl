# test_metrics_logger.jl
#
# Exercises `Globtim.Metrics` directly + `adaptive_refine`'s logger kwarg.
# Confirms:
#   - MetricsLogger emits meta + phase + leaf rows with the right shape.
#   - `dedup_with_groups` returns parallel attribution arrays.
#   - adaptive_refine(logger=...) emits one leaf row per processed leaf with
#     core-known fields (depth, bounds, degree, rel_l2, status, split_dim,
#     parent_id, stage="tree-build").
#   - `leaf_extra_fn` is folded into each leaf row's extra.

using Test
using Globtim
import Globtim: Metrics as M

# ── Minimal JSONL reader for assertions ─────────────────────────────────────
# We don't want to add a JSON dep to the globtim test profile. The writer
# emits one row per line; pull out the kind via a regex and the integer/float
# fields we care about by literal substring match.

read_rows(path) = readlines(path)
row_kinds(rows) = [match(r"\"kind\":\"([^\"]+)\"", r).captures[1] for r in rows]

# Extract an integer or float field from a JSONL row by name. Returns nothing
# if not present. Quotes-stripped string fields fall through to string return.
function _extract(row::AbstractString, field::AbstractString)
    m = match(Regex("\"$(field)\":([^,}]+)"), row)
    m === nothing && return nothing
    raw = m.captures[1]
    if startswith(raw, "\"") && endswith(raw, "\"")
        return raw[2:end-1]
    elseif raw == "null"
        return nothing
    elseif raw == "true"
        return true
    elseif raw == "false"
        return false
    elseif occursin('.', raw) || occursin('e', raw)
        return parse(Float64, raw)
    else
        return parse(Int, raw)
    end
end

@testset "Metrics module — direct API" begin
    mktempdir() do dir
        path = joinpath(dir, "m.jsonl")
        logger = M.MetricsLogger(path; run_id = "test-run-1")

        M.log_phase!(logger, "start"; extra = Dict(:degree => 3, :note => "hello"))
        M.log_leaf!(logger, 7;
            depth = 2, bounds = [(0.0, 1.0), (-1.0, 1.0)],
            degree = 3, rel_l2 = 1.5e-2, n_raw_cps = 4,
            n_eval_failures = 1, n_grid_evals = 25,
            extra = Dict(:status => "active"),
        )
        M.log_cp!(logger, "raw";
            leaf_id = 7, dep_day = 100.0, tof_day = 250.0, dv = 5.6,
            type_label = "Type I", is_boundary = false,
            dedup_group = 1, dedup_canonical = true,
        )

        rows = read_rows(path)
        @test length(rows) == 4
        @test row_kinds(rows) == ["meta", "phase", "leaf", "cp"]

        # meta carries reproducibility fields
        meta = rows[1]
        @test _extract(meta, "run_id") == "test-run-1"
        @test _extract(meta, "julia_version") !== nothing
        @test _extract(meta, "n_threads") isa Int

        # phase row carries extra
        phase = rows[2]
        @test _extract(phase, "phase") == "start"
        @test _extract(phase, "degree") == 3
        @test _extract(phase, "note") == "hello"

        # leaf row carries renamed n_eval_failures (not n_lambert_failures)
        leaf = rows[3]
        @test _extract(leaf, "leaf_id") == 7
        @test _extract(leaf, "rel_l2") == 1.5e-2
        @test _extract(leaf, "n_eval_failures") == 1
        @test _extract(leaf, "n_grid_evals") == 25
        @test _extract(leaf, "status") == "active"
        @test occursin("\"bounds\":[[0.0,1.0],[-1.0,1.0]]", leaf)

        # cp row
        cp = rows[4]
        @test _extract(cp, "cp_kind") == "raw"
        @test _extract(cp, "dv") == 5.6
        @test _extract(cp, "type_label") == "Type I"
        @test _extract(cp, "is_boundary") == false
        @test _extract(cp, "dedup_canonical") == true

        @test logger.n_rows == 4
    end
end

@testset "Metrics.dedup_with_groups" begin
    pts = [[0.0, 0.0], [0.05, 0.0], [10.0, 10.0], [0.02, -0.03], [10.01, 10.0]]
    out = M.dedup_with_groups(pts, 0.5)
    @test length(out.group_ids) == 5
    @test out.group_ids == [1, 1, 2, 1, 2]
    @test out.canonical == [true, false, true, false, false]
    @test out.rep_indices == [1, 3]
end

@testset "adaptive_refine logger kwarg — core-side leaf emission" begin
    mktempdir() do dir
        path = joinpath(dir, "m.jsonl")
        logger = M.MetricsLogger(path)

        # Tiny 2D Deuflhard on a small box — exercises one or two splits at
        # default tolerance. We don't care about the optimization outcome here,
        # only that the JSONL shape is right.
        bounds = [(-1.2, 1.2), (-1.2, 1.2)]
        extra_calls = Ref(0)
        leaf_extra = (sd, idx) -> begin
            extra_calls[] += 1
            return Dict{Symbol,Any}(:fake_metric => 42 + idx)
        end

        tree = adaptive_refine(
            Deuflhard, bounds, 4;
            l2_tolerance = 0.05, max_depth = 2, max_leaves = 8,
            parallel = false, basis = :chebyshev,
            logger = logger, leaf_extra_fn = leaf_extra,
        )

        rows = read_rows(path)
        kinds = row_kinds(rows)

        # Must include start/done phase rows and ≥1 leaf row.
        @test "meta" in kinds
        @test "phase" in kinds
        @test "leaf" in kinds

        phases = [r for r in rows if occursin("\"kind\":\"phase\"", r)]
        phase_names = [_extract(p, "phase") for p in phases]
        @test "adaptive_refine_start" in phase_names
        @test "adaptive_refine_done"  in phase_names

        # adaptive_refine_done carries a positive wall + n_leaves
        done = phases[findfirst(==( "adaptive_refine_done"), phase_names)]
        @test _extract(done, "wall_s") > 0.0
        @test _extract(done, "n_leaves") >= 1
        @test _extract(done, "max_depth_reached") >= 0

        # Every leaf row carries stage=tree-build, the core-known fields, AND
        # the user-supplied fake_metric.
        leaves = [r for r in rows if occursin("\"kind\":\"leaf\"", r)]
        @test !isempty(leaves)
        for leaf in leaves
            @test _extract(leaf, "stage") == "tree-build"
            @test _extract(leaf, "depth") isa Int
            @test _extract(leaf, "degree") isa Int
            @test _extract(leaf, "rel_l2") isa Float64
            @test _extract(leaf, "status") in ("active", "converged", "pruned", "internal")
            @test _extract(leaf, "fake_metric") isa Int
        end
        @test extra_calls[] == length(leaves)

        # Root leaf has parent_id=null.
        root_rows = [r for r in leaves if _extract(r, "depth") == 0]
        @test !isempty(root_rows)
        @test _extract(first(root_rows), "parent_id") === nothing
    end
end

@testset "adaptive_refine without logger — no behavior change" begin
    # Sanity: omitting logger leaves no metrics file and produces a tree.
    bounds = [(-1.2, 1.2), (-1.2, 1.2)]
    tree = adaptive_refine(
        Deuflhard, bounds, 4;
        l2_tolerance = 0.05, max_depth = 1, max_leaves = 4,
        parallel = false, basis = :chebyshev,
    )
    @test tree isa Globtim.SubdivisionTree
end
