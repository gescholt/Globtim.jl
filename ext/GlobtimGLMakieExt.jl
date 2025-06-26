module GlobtimGLMakieExt

using Globtim
using GLMakie

# Include GLMakie-specific plotting functionality
include("../src/graphs_makie.jl")
include("../src/LevelSetViz.jl")

# Export plotting functions that require GLMakie
export plot_polyapprox_3d,
    LevelSetData,
    VisualizationParameters,
    prepare_level_set_data,
    to_makie_format,
    plot_level_set,
    create_level_set_visualization,
    plot_polyapprox_rotate,
    plot_polyapprox_levelset,
    plot_polyapprox_flyover,
    plot_polyapprox_animate,
    plot_polyapprox_animate2

end