using Pkg
using Revise 
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using GLMakie
using CairoMakie
CairoMakie.activate!()  # Activate Cairo backend


# Constants and Parameters
const n, a, b = 2, 1, 3
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder
f = tref # Objective function

SMPL = 120 # Number of samples
center = [0.0, 0.0]
TR = test_input(f,
dim=n,
center=[0.0, 0.0],
GN=SMPL,
sample_range=scale_factor,
tolerance=tol_l2,
)

@polyvar(x[1:n]); # Define polynomial ring 

d = 32 # Initial Degree 
pol_cheb = Constructor(TR, d, basis=:chebyshev);
df_cheb = solve_and_parse(pol_cheb, x, f, TR)
df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=.01)

pol_lege = Constructor(TR, d, basis=:legendre);
df_lege = solve_and_parse(pol_lege, x, f, TR, basis=:legendre)
df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=1.0)

sort!(df_cheb, :z, rev=true)
sort!(df_lege, :z, rev=true)

fig5 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb, chebyshev_levels=false, num_levels=30)

include("../compare_matlab.jl")
using CSV

df_matlab = CSV.read("data/valid_points_trefethen_3_8.csv", DataFrame, delim=",")

df_cheb2, df_min2, df_ext = comp_matlab(f, df_cheb, TR, df_matlab)

# fig7 = plot_comparison_levelset(pol_cheb, TR, df_ext)

"""
Comparison contourplot with the data from MATLAB.
"""
function plot_comparison_levelset(
    pol::ApproxPoly,
    TR::test_input,
    comparison::DataFrame;
    figure_size::Tuple{Int,Int}=(1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
    num_levels::Int=30
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=figure_size)
        ax = Axis(fig[1, 1], title="")

        # Calculate z_limits if not provided
        if isnothing(z_limits)
            z_values = comparison.value
            z_limits = (minimum(z_values), maximum(z_values))
        end

        # Create the contour plot
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        contourf!(ax, x_unique, y_unique, Z,
            colormap=:inferno,
            levels=num_levels)

        # Plot points with MATLAB matches in green
        matlab_match_idx = comparison.matlab_match .& comparison.captured
        if any(matlab_match_idx)
            scatter!(ax, comparison.x1[matlab_match_idx], comparison.x2[matlab_match_idx],
                markersize=10,
                color=:green,
                strokecolor=:black,
                strokewidth=1,
                label="Common points")
        end

        # Plot Julia-only points in white
        julia_only_idx = .!comparison.matlab_match
        if any(julia_only_idx)
            scatter!(ax, comparison.x1[julia_only_idx], comparison.x2[julia_only_idx],
                markersize=10,
                color=:white,
                strokecolor=:black,
                strokewidth=1,
                label="Julia only")
        end

        # Plot MATLAB-only points in blue diamonds
        matlab_only_idx = comparison.matlab_match .& .!comparison.captured
        if any(matlab_only_idx)
            scatter!(ax, comparison.x1[matlab_only_idx], comparison.x2[matlab_only_idx],
                markersize=15,
                marker=:diamond,
                color=:blue,
                strokecolor=:black,
                strokewidth=1,
                label="MATLAB only")
        end

        Legend(fig[1, 2], ax, "Critical Points",
            tellwidth=true)

        Colorbar(fig[1, 3], limits=z_limits,
            colormap=:inferno,
            label="Function value")

        display(fig)
        return fig
    end
end