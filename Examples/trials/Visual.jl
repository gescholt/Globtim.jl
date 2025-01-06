struct LevelSetData{T<:Real}
    points::Vector{SVector{3,T}}
    values::Vector{T}
    level::T
end

function evaluate_on_grid(f::Function, grid::Array{SVector{3,Float64}})
    wrapped_f = f isa Function ? Error_distance_wrapper(f) : f
    return map(wrapped_f, grid)
end

function prepare_level_set_data(
    grid::Array{SVector{3, T}},
    values::Array{T},
    level::T;
    tolerance::T=1e-2
) where {T<:Real}
    # Flatten arrays for processing
    flat_grid = vec(grid)
    flat_values = vec(values)

    # Find points where function is close to the level value
    level_set_mask = abs.(flat_values .- level) .< tolerance

    # Create LevelSetData structure
    LevelSetData(
        flat_grid[level_set_mask],
        flat_values[level_set_mask],
        level
    )
end

function to_makie_format(level_set::LevelSetData)
    points = reduce(hcat, level_set.points)
    return (
        points=points,
        values=level_set.values,
        xyz=(points[1, :], points[2, :], points[3, :])
    )
end


function plot_level_set(formatted_data)
    fig = Figure(size=(800, 600))
    ax = Axis3(fig[1, 1], title="Trefethen Function",
        xlabel="X-axis", ylabel="Y-axis", zlabel="Z-axis")

    # Extract the coordinate vectors
    x = formatted_data.xyz[1]
    y = formatted_data.xyz[2]
    z = formatted_data.xyz[3]

    # Create scatter plot directly with vectors
    scatter!(ax, x, y, z, markersize=4)
    
    display(fig)


    return fig
end