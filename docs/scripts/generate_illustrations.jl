#!/usr/bin/env julia
"""
Generate illustrations for Globtim.jl documentation.

Run from the GlobalOptim directory:
    julia --project=globtimplots docs/scripts/generate_illustrations.jl

Or run specific functions:
    julia --project=globtimplots -e 'include("globtim/docs/scripts/generate_illustrations.jl"); generate_grid_comparison()'
"""

using GlobtimPlots  # Brings in CairoMakie
CairoMakie.activate!()

# Chebyshev nodes on [-1, 1] - defined locally to avoid Globtim dependency
# Returns n+1 nodes for input n (Chebyshev-Gauss-Lobatto points)
chebyshev_nodes(n) = [cos(π * k / n) for k in 0:n]

# Ensure output directory exists
const OUTPUT_DIR = joinpath(@__DIR__, "..", "src", "assets", "plots")
mkpath(OUTPUT_DIR)

"""
    generate_grid_comparison()

Generate side-by-side comparison of isotropic vs anisotropic grids.
Saves to: docs/src/assets/plots/grid_comparison.png
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

    outpath = joinpath(OUTPUT_DIR, "grid_comparison.png")
    save(outpath, fig, px_per_unit=2)
    @info "Saved grid comparison" path=outpath
    return fig
end

"""
    generate_multiscale_heatmap()

Generate heatmap showing a multiscale function that benefits from anisotropic grids.
Shows why x-direction needs more points than y-direction.
Saves to: docs/src/assets/plots/multiscale_function.png
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

    outpath = joinpath(OUTPUT_DIR, "multiscale_function.png")
    save(outpath, fig, px_per_unit=2)
    @info "Saved multiscale heatmap" path=outpath
    return fig
end

"""
    generate_critical_point_example()

Generate example showing critical points on a 2D function surface.
Saves to: docs/src/assets/plots/critical_points_example.png
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

    surface!(ax2, xs, ys, zs, colormap=:viridis, alpha=0.8)

    outpath = joinpath(OUTPUT_DIR, "critical_points_example.png")
    save(outpath, fig, px_per_unit=2)
    @info "Saved critical points example" path=outpath
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

    @info "All illustrations generated in $OUTPUT_DIR"
end

# Run all if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    generate_all()
end
