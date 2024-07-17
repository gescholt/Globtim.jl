using Plots, LinearAlgebra, Statistics

include("construct_lib.jl")

# Constants and Parameters
const d1, d2, ds = 2, 30, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters
const N = 400  # Increased number of points for a denser grid

function main()
    # Create grid points
    x_vals, y_vals = create_grid(C, N)
    # Evaluate tref on grid
    Z = evaluate_tref_on_grid(tref, x_vals, y_vals)
    # Find local maxima and minima
    local_maxima, local_minima = find_local_extrema(Z, x_vals, y_vals, N)
    all_extrema = vcat(local_maxima, local_minima)
    println("Found $(length(all_extrema)) extrema.")

    # Compute minimum pairwise distance
    min_distance = compute_min_distance(all_extrema)
    radius = min_distance / 2

    println("Local Minima:")
    for (x, y) in local_minima
        println("($x, $y)")
    end

    println("Minimum pairwise distance: $min_distance")
    println("Radius for disjoint balls: $radius")

    degrees = d1:ds:d2
    avg_distances = []

    for d in degrees
        file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
        data_pts = read(file_path_pts, String)
        trimmed_content = strip(data_pts, ['[', ']']) # trim brackets
        rows = split(trimmed_content, "], [") # split into arrays
        # Collect the arrays of msolve points
        data_array = [parse.(Float64, split(strip(row, ['[', ']']), ", ")) for row in rows]
        pol_crit_pts = [[data_array[1][i], data_array[2][i]] for i in 1:length(data_array[1])]
        closest_distances = compute_closest_distances(all_extrema, pol_crit_pts)

        avg_closest_distance = mean(closest_distances)
        println("Average closest distance for degree $d: $avg_closest_distance")
        push!(avg_distances, avg_closest_distance)
    end

    # Plot the average distances
    plot(degrees, avg_distances, xlabel="Degree", ylabel="Average Closest Distance", title="Average Closest Distance vs. Degree", legend=false, marker=:o)

end

main()
