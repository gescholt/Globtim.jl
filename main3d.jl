using DynamicPolynomials, MultivariatePolynomials, HomotopyContinuation, PlotlyJS, DataFrames

# gr()  # Set the backend to GR

include("hom_solve.jl")
include("optim_lib.jl")
include("lib_func.jl")

# Constants and Parameters
const d1, d2, ds = 2, 6, 1  # Degree range and step
const n, a, b = 3, 10, 1
const C = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alph = .9 , 2 / 10  # Sampling parameters
f = alpine1 # Function to optimize

# Construct approximants #
results = main_gen(f, n, d1, d2, ds, delta, alph, C, 0.5)


# Define your main function
@polyvar(x[1:n]) # Define polynomial ring 
function main()
    # @polyvar x[1:n] # Define polynomial ring

    h_x = Float64[]
    h_y = Float64[]
    h_z = Float64[]

    col = Int[]  # Initialize the color vector

    for (i, d) in enumerate(d1:ds:d2)
        local lambda = support_gen(n, d)[1] # Take support  
        local R = generateApproximant(lambda, results[i], :BigFloat) # Compute the approximant

        # Generate the system for HomotopyContinuation
        local P1 = differentiate(R, x[1])
        local P2 = differentiate(R, x[2])
        local P3 = differentiate(R, x[3])

        local S = RRsolve(n, [P1, P2, P3]) # HomotopyContinuation

        # Define the condition for filtering
        condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1 && -1 < point[3] < 1

        # Filter points using the filter function
        filtered_points = filter(condition, S)
        println("Degree: ", d)
        println("Number of solutions: ", length(filtered_points))

        append!(h_x, [point[1] for point in filtered_points]) # For plotting
        append!(h_y, [point[2] for point in filtered_points])
        append!(h_z, [point[3] for point in filtered_points])
        append!(col, fill(i, length(filtered_points)))
    end
    return h_x, h_y, h_z, col
end

h_x, h_y, h_z, col = main()
df = DataFrame(x=C * h_x, y=C * h_y, z=C * h_z, col=col)
df[!, :result] = [f([df.x[i], df.y[i], df.z[i]]) for i in 1:nrow(df)]


associated_x = []
associated_y = []
associated_z = []
# Loop through each unique value in the 'col' column
for i in unique(df.col)
    println("Col: ", i)
    # Filter DataFrame for rows where 'col' equals i
    df_filtered = df[df.col.==i, :]

    # Find the smallest value in the 'col' column of the filtered DataFrame
    min_value = minimum(df_filtered.result)

    # Find the row index of the smallest value in the filtered DataFrame
    local min_index = findfirst(df_filtered.result .== min_value)

    # Grab the associated x, y, z values
    append!(associated_x, df_filtered.x[min_index])
    append!(associated_y, df_filtered.y[min_index])
    append!(associated_z, df_filtered.z[min_index])

    # Print the results
    println("Smallest critical point for col = $i: [", associated_x, ", ", associated_y, ", ", associated_z, "]")
    println("Minimum value for col = $i: ", min_value)
end

# Create a grid of points for contour plot
x_range = range(minimum(df.x), stop=maximum(df.x), length=80)
y_range = range(minimum(df.y), stop=maximum(df.y), length=80)
z_range = range(minimum(df.z), stop=maximum(df.z), length=100)

plots = []
for i in eachindex(associated_x)
    println("associated_z: ", associated_z[i])
    local z_values = [f([x, y, associated_z[i]]) for x in x_range, y in y_range]
    z_matrix = reshape(z_values, length(y_range), length(x_range))  # Reshape z_values to match x and y dimensions

    contour_plot = contour(
        x=x_range,
        y=y_range,
        z=z_matrix,
        contours_coloring="heatmap",
        colorscale="Viridis",
        showscale=true,
        opacity=0.8
    )
    # push!(plots, contour_plot)
    plt = plot(contour_plot)
    display(plt)
end

# plot(plots...)
