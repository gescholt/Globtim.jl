module GlobtimCairoMakieExt

using Globtim
using CairoMakie
using DataFrames

# Include CairoMakie-specific plotting functionality
include("../src/graphs_cairo.jl")

# Export plotting functions that require CairoMakie
export plot_convergence_analysis,
    capture_histogram,
    create_legend_figure,
    plot_discrete_l2,
    plot_convergence_captured,
    plot_filtered_y_distances,
    cairo_plot_polyapprox_levelset,
    plot_distance_statistics

end