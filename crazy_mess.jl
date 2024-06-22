using Plots, LinearAlgebra

#it's a mess but it does print something


# Constants and Parameters
const d1, d2, ds = 2, 30, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters
const N = 400  # Increased number of points for a denser grid

# Define the function tref
tref(x, y) = exp(sin(50 * x)) + sin(60 * exp(y)) + sin(70 * sin(x)) + sin(sin(80 * y)) - sin(10 * (x + y)) + (x^2 + y^2) / 4

# Create a grid over the domain [-C, C]^2
x_vals = range(-C, stop=C, length=N)
y_vals = range(-C, stop=C, length=N)

# Evaluate tref on the grid
Z = [tref(x, y) for y in y_vals, x in x_vals]

# Function to check if a point is a local extremum
function is_local_extremum(Z, i, j)
    neighbors = [
        Z[i-1, j-1], Z[i-1, j], Z[i-1, j+1],
        Z[i, j-1], Z[i, j+1],
        Z[i+1, j-1], Z[i+1, j], Z[i+1, j+1]
    ]
    center = Z[i, j]
    return all(center .> neighbors) || all(center .< neighbors)
end

# Find local maxima and minima
local_maxima = []
local_minima = []

for i in 2:(N-1)
    for j in 2:(N-1)
        if is_local_extremum(Z, i, j)
            if Z[i, j] > maximum(Z[i-1:i+1, j-1:j+1]) - Z[i, j]
                push!(local_maxima, (x_vals[j], y_vals[i]))
            elseif Z[i, j] < minimum(Z[i-1:i+1, j-1:j+1]) - Z[i, j]
                push!(local_minima, (x_vals[j], y_vals[i]))
            end
        end
    end
end

# Compute the minimum pairwise distance
function compute_min_distance(points)
    min_distance = Inf
    for i in 1:length(points)-1
        for j in i+1:length(points)
            dist = norm(points[i] .- points[j])
            if dist < min_distance
                min_distance = dist
            end
        end
    end
    return min_distance
end

all_extrema = vcat(local_maxima, local_minima)
min_distance = compute_min_distance(all_extrema)
radius = min_distance / 2

# Print results
println("Local Maxima:")
for (x, y) in local_maxima
    println("($x, $y)")
end

println("Local Minima:")
for (x, y) in local_minima
    println("($x, $y)")
end

println("Minimum pairwise distance: $min_distance")
println("Radius for disjoint balls: $radius")


# Draw transparent circles around local maxima and minima
function plot_filled_circles!(centers, radii, colors; marker_size=600)
    # Check input lengths (same as before)
    if length(centers) != length(radii) || length(centers) != length(colors)
        error("Lengths of centers, radii, and colors arrays must be equal.")
    end

    # Create a new plot or add to an existing one
    plot!()

    # Plot each circle directly
    for (center, radius, color) in zip(centers, radii, colors)
        scatter!([center[1]], [center[2]],             # Wrap center coordinates in arrays
            markersize=radius * marker_size,
            markercolor=color,
            markerstrokewidth=0,
            alpha= 0.5,
            label="")
    end
end

contour(x_vals, y_vals, Z, xlabel="x", ylabel="y", legend=false)

max_color = [:red for x in local_maxima]
min_color = [:blue for x in local_minima]
max_RD = [radius for x in local_maxima]
min_RD = [radius for x in local_minima]

plot_filled_circles!(local_maxima, max_RD, max_color)
plot_filled_circles!(local_minima, min_RD, min_color)
# Show the plot
# Create contour plot
# contour(x_vals, y_vals, Z, xlabel="x", ylabel="y", legend=false)
# scatter!(first.(local_maxima), last.(local_maxima), label="Local Maxima", color=:red, marker=:circle)
# scatter!(first.(local_minima), last.(local_minima), label="Local Minima", color=:blue, marker=:circle)
plot!()
