#!/usr/bin/env julia
"""
Generate illustrations for Globtim.jl documentation.

Run from the GlobalOptim directory:
    julia --project=globtimplots globtim/docs/scripts/generate_illustrations.jl

Or run specific functions:
    julia --project=globtimplots -e 'include("globtim/docs/scripts/generate_illustrations.jl"); generate_deuflhard()'
"""

using Globtim
using GlobtimPlots
using DynamicPolynomials
using DataFrames: nrow
CairoMakie.activate!()

# Chebyshev nodes on [-1, 1] for grid illustrations
chebyshev_nodes(n) = [cos(π * k / n) for k in 0:n]

"""
    find_critical_points(f, domain_center, domain_range; degree=10, GN=100)

Run Globtim pipeline to find critical points of function f.
Returns a DataFrame with critical point locations and types.
"""
function find_critical_points(f, domain_center, domain_range; degree=10, GN=100)
    TR = test_input(f, dim=2, center=domain_center, GN=GN, sample_range=domain_range)
    pol = Constructor(TR, degree, verbose=0)
    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, pol)
    df = process_crit_pts(solutions, f, TR)
    return df
end

# Ensure output directory exists
const OUTPUT_DIR = joinpath(@__DIR__, "..", "src", "assets", "plots")
mkpath(OUTPUT_DIR)

"""
    generate_grid_comparison()

Generate side-by-side comparison of isotropic vs anisotropic grids.
Saves to: docs/src/assets/plots/grid_comparison.pdf
"""
function generate_grid_comparison()
    fig = Figure(size=(900, 400), fontsize=14)

    # Isotropic grid (n=8 in each dimension)
    ax1 = Axis(fig[1, 1],
        title="Isotropic Grid (8×8 = 64 points)",
        xlabel="x", ylabel="y",
        aspect=1)

    nodes_iso = chebyshev_nodes(7)  # 0-indexed, so 7 gives 8 nodes
    xs_iso = [x for x in nodes_iso for _ in nodes_iso]
    ys_iso = [y for _ in nodes_iso for y in nodes_iso]
    scatter!(ax1, xs_iso, ys_iso, markersize=8, color=:steelblue)

    # Anisotropic grid (16 in x, 4 in y)
    ax2 = Axis(fig[1, 2],
        title="Anisotropic Grid (16×4 = 64 points)",
        xlabel="x", ylabel="y",
        aspect=1)

    nodes_x = chebyshev_nodes(15)  # 16 nodes
    nodes_y = chebyshev_nodes(3)   # 4 nodes
    xs_aniso = [x for x in nodes_x for _ in nodes_y]
    ys_aniso = [y for _ in nodes_x for y in nodes_y]
    scatter!(ax2, xs_aniso, ys_aniso, markersize=8, color=:coral)

    outpath = joinpath(OUTPUT_DIR, "grid_comparison.pdf")
    save(outpath, fig)
    @info "Saved grid comparison" path=outpath
    return fig
end

"""
    generate_multiscale_heatmap()

Generate heatmap showing a multiscale function that benefits from anisotropic grids.
Shows why x-direction needs more points than y-direction.
Saves to: docs/src/assets/plots/multiscale_function.pdf
"""
function generate_multiscale_heatmap()
    fig = Figure(size=(700, 500), fontsize=14)

    # Multiscale function: rapid oscillation in x, slow variation in y
    f(x, y) = sin(15x) * exp(-y^2)

    ax = Axis(fig[1, 1],
        title="Multiscale Function: sin(15x) × exp(-y²)",
        xlabel="x", ylabel="y",
        aspect=1)

    xs = range(-1, 1, length=200)
    ys = range(-1, 1, length=200)
    zs = [f(x, y) for x in xs, y in ys]

    hm = heatmap!(ax, xs, ys, zs, colormap=:viridis)
    Colorbar(fig[1, 2], hm, label="f(x,y)")

    # Add annotation
    text!(ax, -0.9, -0.85, text="High frequency in x\n→ needs more points",
        fontsize=11, color=:white, align=(:left, :bottom))

    outpath = joinpath(OUTPUT_DIR, "multiscale_function.pdf")
    save(outpath, fig)
    @info "Saved multiscale heatmap" path=outpath
    return fig
end

"""
    generate_critical_point_example()

Generate example showing critical points on a 2D function surface.
Saves to: docs/src/assets/plots/critical_points_example.pdf
"""
function generate_critical_point_example()
    fig = Figure(size=(800, 400), fontsize=14)

    # Simple function with multiple critical points
    f(x, y) = x^4 + y^4 - 2x^2 - 2y^2 + 0.5

    xs = range(-1.8, 1.8, length=100)
    ys = range(-1.8, 1.8, length=100)
    zs = [f(x, y) for x in xs, y in ys]

    # Contour plot
    ax1 = Axis(fig[1, 1],
        title="Level Sets with Critical Points",
        xlabel="x", ylabel="y",
        aspect=1)

    contour!(ax1, xs, ys, zs, levels=15, colormap=:Blues)

    # Mark critical points
    # Minima at (±1, ±1), saddles at (±1, 0) and (0, ±1), max at (0,0)
    scatter!(ax1, [1, -1, 1, -1], [1, 1, -1, -1],
        color=:green, markersize=12, marker=:circle, label="Minima")
    scatter!(ax1, [1, -1, 0, 0], [0, 0, 1, -1],
        color=:orange, markersize=12, marker=:diamond, label="Saddles")
    scatter!(ax1, [0], [0],
        color=:red, markersize=12, marker=:star5, label="Maximum")

    axislegend(ax1, position=:rt)

    # Surface plot
    ax2 = Axis3(fig[1, 2],
        title="Function Surface",
        xlabel="x", ylabel="y", zlabel="f(x,y)",
        azimuth=-0.4π)

    surface!(ax2, xs, ys, zs, colormap=:viridis, alpha=0.8, rasterize=5)

    outpath = joinpath(OUTPUT_DIR, "critical_points_example.pdf")
    save(outpath, fig)
    @info "Saved critical points example" path=outpath
    return fig
end

# Shared data for hero illustrations (Himmelblau-like function)
function _hero_data()
    f(x, y) = (x^2 + y - 11)^2 + (x + y^2 - 7)^2
    xs = range(-5, 5, length=150)
    ys = range(-5, 5, length=150)
    zs = [f(x, y) for x in xs, y in ys]
    return xs, ys, zs
end

"""
    generate_hero_step1()

Generate Step 1 of hero illustration: Sample the original function.
Saves to: docs/src/assets/plots/hero_step1_sample.pdf
"""
function generate_hero_step1()
    xs, ys, zs = _hero_data()
    fig = Figure(size=(600, 550), fontsize=16)

    ax = Axis(fig[1, 1],
        title="1. Sample Function",
        xlabel="x", ylabel="y",
        aspect=DataAspect())
    contourf!(ax, xs, ys, zs, levels=20, colormap=:viridis)
    text!(ax, 0, 4.2, text="f(x,y)", fontsize=18, align=(:center, :center), color=:white)

    outpath = joinpath(OUTPUT_DIR, "hero_step1_sample.pdf")
    save(outpath, fig)
    @info "Saved hero step 1" path=outpath
    return fig
end

"""
    generate_hero_step2()

Generate Step 2 of hero illustration: Polynomial approximation with sampling grid.
Saves to: docs/src/assets/plots/hero_step2_polynomial.pdf
"""
function generate_hero_step2()
    xs, ys, zs = _hero_data()
    fig = Figure(size=(600, 550), fontsize=16)

    ax = Axis(fig[1, 1],
        title="2. Polynomial Approximation",
        xlabel="x", ylabel="y",
        aspect=DataAspect())
    contourf!(ax, xs, ys, zs, levels=20, colormap=:viridis)

    # Show sampling grid (Chebyshev-like)
    grid_n = 8
    grid_pts = [cos(π * k / grid_n) * 5 for k in 0:grid_n]
    gx = [x for x in grid_pts for _ in grid_pts]
    gy = [y for _ in grid_pts for y in grid_pts]
    scatter!(ax, gx, gy, markersize=8, color=:white, alpha=0.7)
    text!(ax, 0, 4.2, text="p(x,y) ≈ f", fontsize=18, align=(:center, :center), color=:white)

    outpath = joinpath(OUTPUT_DIR, "hero_step2_polynomial.pdf")
    save(outpath, fig)
    @info "Saved hero step 2" path=outpath
    return fig
end

"""
    generate_hero_step3()

Generate Step 3 of hero illustration: Find all critical points/minima.
Saves to: docs/src/assets/plots/hero_step3_minima.pdf
"""
function generate_hero_step3()
    xs, ys, zs = _hero_data()

    # Use Globtim to find critical points (Himmelblau function)
    f_vec(x) = (x[1]^2 + x[2] - 11)^2 + (x[1] + x[2]^2 - 7)^2
    domain_range = 5.0
    @info "Finding critical points for Himmelblau (hero step 3)..."
    df = find_critical_points(f_vec, [0.0, 0.0], domain_range, degree=12)

    fig = Figure(size=(600, 550), fontsize=16)

    ax = Axis(fig[1, 1],
        title="3. Find All Minima",
        xlabel="x", ylabel="y",
        aspect=DataAspect())
    contour!(ax, xs, ys, zs, levels=20, colormap=:Blues)

    # Plot minima found by Globtim
    scatter!(ax, df.x1, df.x2,
        color=:limegreen, markersize=24, marker=:star5,
        strokecolor=:black, strokewidth=2)
    text!(ax, 0, 4.2, text="∇p = 0 → BFGS", fontsize=18, align=(:center, :center), color=:black)

    outpath = joinpath(OUTPUT_DIR, "hero_step3_minima.pdf")
    save(outpath, fig)
    @info "Saved hero step 3" path=outpath n_critical_points=nrow(df)
    return fig
end

"""
    generate_deuflhard()

Generate Deuflhard function illustration (level sets + 3D surface).
Uses actual Globtim Deuflhard function and runs Globtim to find critical points.
Saves to: docs/src/assets/plots/deuflhard.pdf
"""
function generate_deuflhard()
    fig = Figure(size=(1000, 450), fontsize=14)

    # Use actual Globtim Deuflhard function
    f = Deuflhard
    domain_range = 1.2

    # Find critical points via Globtim
    @info "Finding critical points for Deuflhard..."
    df = find_critical_points(f, [0.0, 0.0], domain_range, degree=22)

    # Create evaluation grid
    xs = range(-domain_range, domain_range, length=150)
    ys = range(-domain_range, domain_range, length=150)
    zs = [f([x, y]) for x in xs, y in ys]

    # Contour plot with critical points
    ax1 = Axis(fig[1, 1],
        title="Deuflhard Function - Level Sets",
        xlabel="x", ylabel="y",
        aspect=1)

    contour!(ax1, xs, ys, zs, levels=20, colormap=:Blues)

    # Plot critical points from Globtim results
    if !isempty(df)
        scatter!(ax1, df.x1, df.x2,
            color=:green, markersize=12, marker=:circle, label="Critical Points ($(nrow(df)))")
        axislegend(ax1, position=:rt)
    end

    # 3D surface plot
    ax2 = Axis3(fig[1, 2],
        title="Deuflhard Function - Surface",
        xlabel="x", ylabel="y", zlabel="f(x,y)",
        azimuth=-0.4π)

    surface!(ax2, xs, ys, zs, colormap=:viridis, rasterize=5)

    outpath = joinpath(OUTPUT_DIR, "deuflhard.pdf")
    save(outpath, fig)
    @info "Saved Deuflhard illustration" path=outpath n_critical_points=nrow(df)
    return fig
end

"""
    generate_holder_table()

Generate Holder Table function illustration (level sets + 3D surface).
Uses actual Globtim HolderTable function and runs Globtim to find critical points.
Saves to: docs/src/assets/plots/holder_table.pdf
"""
function generate_holder_table()
    fig = Figure(size=(1000, 450), fontsize=14)

    # Use actual Globtim HolderTable function
    f = HolderTable
    domain_range = 10.0

    # Find critical points via Globtim
    @info "Finding critical points for HolderTable..."
    df = find_critical_points(f, [0.0, 0.0], domain_range, degree=18)

    # Create evaluation grid
    xs = range(-domain_range, domain_range, length=200)
    ys = range(-domain_range, domain_range, length=200)
    zs = [f([x, y]) for x in xs, y in ys]

    # Contour plot with critical points
    ax1 = Axis(fig[1, 1],
        title="Holder Table - Level Sets",
        xlabel="x", ylabel="y",
        aspect=1)

    contour!(ax1, xs, ys, zs, levels=25, colormap=:Blues)

    # Plot critical points from Globtim results
    if !isempty(df)
        scatter!(ax1, df.x1, df.x2,
            color=:green, markersize=12, marker=:circle, label="Critical Points ($(nrow(df)))")
        axislegend(ax1, position=:rt)
    end

    # 3D surface plot
    ax2 = Axis3(fig[1, 2],
        title="Holder Table - Surface",
        xlabel="x", ylabel="y", zlabel="f(x,y)",
        azimuth=-0.4π)

    surface!(ax2, xs, ys, zs, colormap=:viridis, rasterize=5)

    outpath = joinpath(OUTPUT_DIR, "holder_table.pdf")
    save(outpath, fig)
    @info "Saved Holder Table illustration" path=outpath n_critical_points=nrow(df)
    return fig
end

"""
    generate_beale()

Generate Beale function illustration (level sets + 3D surface).
Uses actual Globtim Beale function and runs Globtim to find critical points.
Saves to: docs/src/assets/plots/beale.pdf
"""
function generate_beale()
    fig = Figure(size=(1000, 450), fontsize=14)

    # Use actual Globtim Beale function
    f = Beale
    domain_range = 4.5

    # Find critical points via Globtim
    @info "Finding critical points for Beale..."
    df = find_critical_points(f, [0.0, 0.0], domain_range, degree=12)

    # Create evaluation grid
    xs = range(-domain_range, domain_range, length=150)
    ys = range(-domain_range, domain_range, length=150)
    zs = [min(f([x, y]), 1e4) for x in xs, y in ys]  # Clip for visualization

    # Contour plot with critical points
    ax1 = Axis(fig[1, 1],
        title="Beale Function - Level Sets",
        xlabel="x", ylabel="y",
        aspect=1)

    contour!(ax1, xs, ys, log10.(zs .+ 1), levels=20, colormap=:Blues)

    # Plot critical points from Globtim results
    if !isempty(df)
        scatter!(ax1, df.x1, df.x2,
            color=:green, markersize=14, marker=:star5, label="Critical Points ($(nrow(df)))")
        axislegend(ax1, position=:lt)
    end

    # 3D surface plot (use log scale for visibility)
    ax2 = Axis3(fig[1, 2],
        title="Beale Function - Surface (log scale)",
        xlabel="x", ylabel="y", zlabel="log₁₀(f+1)",
        azimuth=-0.4π)

    surface!(ax2, xs, ys, log10.(zs .+ 1), colormap=:viridis, rasterize=5)

    outpath = joinpath(OUTPUT_DIR, "beale.pdf")
    save(outpath, fig)
    @info "Saved Beale illustration" path=outpath n_critical_points=nrow(df)
    return fig
end

"""
    generate_branin()

Generate Branin function illustration (level sets + 3D surface).
Uses actual Globtim Branin function and runs Globtim to find critical points.
Saves to: docs/src/assets/plots/branin.pdf
"""
function generate_branin()
    fig = Figure(size=(1000, 450), fontsize=14)

    # Use actual Globtim Branin function
    f = Branin

    # Branin has non-symmetric domain: [-5, 10] × [0, 15]
    # Center at (2.5, 7.5) with range (7.5, 7.5)
    center = [2.5, 7.5]
    domain_range = 7.5

    # Find critical points via Globtim
    @info "Finding critical points for Branin..."
    df = find_critical_points(f, center, domain_range, degree=12)

    # Create evaluation grid matching the standard Branin domain
    xs = range(-5, 10, length=150)
    ys = range(0, 15, length=150)
    zs = [f([x, y]) for x in xs, y in ys]

    # Contour plot with critical points
    ax1 = Axis(fig[1, 1],
        title="Branin Function - Level Sets",
        xlabel="x", ylabel="y",
        aspect=DataAspect())

    contour!(ax1, xs, ys, zs, levels=25, colormap=:Blues)

    # Plot critical points from Globtim results
    if !isempty(df)
        scatter!(ax1, df.x1, df.x2,
            color=:green, markersize=14, marker=:star5, label="Critical Points ($(nrow(df)))")
        axislegend(ax1, position=:rt)
    end

    # 3D surface plot
    ax2 = Axis3(fig[1, 2],
        title="Branin Function - Surface",
        xlabel="x", ylabel="y", zlabel="f(x,y)",
        azimuth=-0.4π)

    surface!(ax2, xs, ys, zs, colormap=:viridis, rasterize=5)

    outpath = joinpath(OUTPUT_DIR, "branin.pdf")
    save(outpath, fig)
    @info "Saved Branin illustration" path=outpath n_critical_points=nrow(df)
    return fig
end

"""
    generate_all()

Generate all documentation illustrations.
"""
function generate_all()
    @info "Generating documentation illustrations..."

    generate_grid_comparison()
    generate_multiscale_heatmap()
    generate_critical_point_example()
    generate_hero_step1()
    generate_hero_step2()
    generate_hero_step3()
    generate_deuflhard()
    generate_holder_table()
    generate_beale()
    generate_branin()

    @info "All illustrations generated in $OUTPUT_DIR"
end

# Run all if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    generate_all()
end
