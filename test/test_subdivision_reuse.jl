# Tier-1 unit tests for y0j parent→child sample reuse pure helpers.
# Builds synthetic `Subdomain` values — does not run `adaptive_refine`.

using Test
using Globtim
using Globtim:
    Subdomain, remap_parent_to_child, points_inside_child, combine_inherited_and_fresh

@testset "subdivision_reuse" begin
    @testset "remap_parent_to_child — identity on non-split dims" begin
        # 3D parent centered at origin, unit half-widths in all dims.
        parent = Subdomain([0.0, 0.0, 0.0], [1.0, 1.0, 1.0])
        # Cut in dim 2 at position 0.0 → left child: center[2] = -0.5, half_widths[2] = 0.5.
        child = Subdomain([0.0, -0.5, 0.0], [1.0, 0.5, 1.0])

        for x in ([0.3, -1.0, 0.7], [-0.5, 0.0, 0.5], [0.0, 0.0, 0.0])
            mapped = remap_parent_to_child(x, parent, child)
            @test mapped[1] ≈ x[1] atol = 1e-14
            @test mapped[3] ≈ x[3] atol = 1e-14
            # Dim 2 is rescaled by the cut: x_parent=0.0 → x_child=1.0 (right edge of left child).
        end

        # Specific check on the split dim:
        @test remap_parent_to_child([0.0, 0.0, 0.0], parent, child)[2] ≈ 1.0
        @test remap_parent_to_child([0.0, -1.0, 0.0], parent, child)[2] ≈ -1.0
        @test remap_parent_to_child([0.0, -0.5, 0.0], parent, child)[2] ≈ 0.0
    end

    @testset "remap_parent_to_child — split positions ∈ {-0.75, -0.5, 0, 0.5, 0.75}" begin
        parent = Subdomain([0.0, 0.0], [1.0, 1.0])

        for cut in (-0.75, -0.5, 0.0, 0.5, 0.75)
            # Left child of parent cut at `cut` in dim 1:
            # center[1]_left = (-1 + cut)/2, half_widths[1]_left = (cut + 1)/2.
            c_l = (-1.0 + cut) / 2
            h_l = (cut + 1.0) / 2
            left = Subdomain([c_l, 0.0], [h_l, 1.0])
            # Right child:
            c_r = (cut + 1.0) / 2
            h_r = (1.0 - cut) / 2
            right = Subdomain([c_r, 0.0], [h_r, 1.0])

            # Parent sample at the cut maps to x=+1 in left child and x=-1 in right child.
            cut_pt = [cut, 0.3]
            @test remap_parent_to_child(cut_pt, parent, left)[1] ≈ 1.0 atol = 1e-13
            @test remap_parent_to_child(cut_pt, parent, right)[1] ≈ -1.0 atol = 1e-13
            # Non-split dim is identity.
            @test remap_parent_to_child(cut_pt, parent, left)[2] ≈ 0.3 atol = 1e-13
            @test remap_parent_to_child(cut_pt, parent, right)[2] ≈ 0.3 atol = 1e-13

            # A point at the parent's left edge lives inside the left child only.
            @test remap_parent_to_child([-1.0, 0.0], parent, left)[1] ≈ -1.0 atol = 1e-13
        end
    end

    @testset "points_inside_child — midpoint cut keeps ~half the points" begin
        parent = Subdomain([0.0, 0.0], [1.0, 1.0])
        left = Subdomain([-0.5, 0.0], [0.5, 1.0])
        right = Subdomain([0.5, 0.0], [0.5, 1.0])

        # 5×5 uniform grid in parent coords.
        coords = range(-1.0, 1.0; length = 5)
        samples = Matrix{Float64}(undef, 25, 2)
        k = 0
        for xv in coords, yv in coords
            k += 1
            samples[k, 1] = xv
            samples[k, 2] = yv
        end

        idx_left = points_inside_child(samples, parent, left)
        idx_right = points_inside_child(samples, parent, right)

        # On a symmetric midpoint cut, points with x_parent=0 sit exactly on the
        # boundary and are accepted into both children (that is the documented
        # boundary behaviour — de-duplication between children is not this
        # function's job).
        @test length(idx_left) == 15   # 3 columns × 5 rows (x ∈ {-1, -0.5, 0})
        @test length(idx_right) == 15   # 3 columns × 5 rows (x ∈ {0, 0.5, 1})

        # Every selected point, when remapped, must be inside [-1, 1]^2 up to tol.
        for i in idx_left
            mapped = remap_parent_to_child(samples[i, :], parent, left)
            @test all(abs.(mapped) .≤ 1.0 + 1e-10)
        end
    end

    @testset "points_inside_child — off-center cut is asymmetric" begin
        parent = Subdomain([0.0, 0.0], [1.0, 1.0])
        # cut at x=0.5 → left child covers 75 % of dim 1.
        left = Subdomain([-0.25, 0.0], [0.75, 1.0])
        right = Subdomain([0.75, 0.0], [0.25, 1.0])

        coords = range(-1.0, 1.0; length = 5)
        samples = Matrix{Float64}(undef, 25, 2)
        k = 0
        for xv in coords, yv in coords
            k += 1
            samples[k, 1] = xv
            samples[k, 2] = yv
        end

        idx_left = points_inside_child(samples, parent, left)
        idx_right = points_inside_child(samples, parent, right)

        # Points with x ∈ {-1, -0.5, 0, 0.5} lie in the left child = 4 cols × 5 rows.
        @test length(idx_left) == 20
        # Points with x ∈ {0.5, 1} lie in the right child = 2 cols × 5 rows.
        @test length(idx_right) == 10
    end

    @testset "combine_inherited_and_fresh — drops duplicates" begin
        inherited = [0.0 0.0; 0.5 0.5]
        fresh = [
            0.5 0.5  # duplicate of row 2 of inherited
            -0.5 -0.5
            0.0 0.0
        ]  # duplicate of row 1 of inherited
        combined, new_idx = combine_inherited_and_fresh(inherited, fresh)

        @test new_idx == [2]
        @test size(combined) == (3, 2)
        @test combined[1, :] == [0.0, 0.0]
        @test combined[2, :] == [0.5, 0.5]
        @test combined[3, :] == [-0.5, -0.5]
    end

    @testset "combine_inherited_and_fresh — no overlap, identity concat" begin
        inherited = reshape([0.1, 0.2], 1, 2)
        fresh = [0.9 0.9; -0.9 -0.9]
        combined, new_idx = combine_inherited_and_fresh(inherited, fresh)
        @test new_idx == [1, 2]
        @test size(combined) == (3, 2)
        # new_idx is monotonic increasing.
        @test issorted(new_idx)
    end

    @testset "combine_inherited_and_fresh — empty inherited passes through" begin
        inherited = zeros(0, 3)
        fresh = [0.0 0.0 0.0; 0.5 -0.5 0.25]
        combined, new_idx = combine_inherited_and_fresh(inherited, fresh)
        @test new_idx == [1, 2]
        @test combined == fresh
    end
end
