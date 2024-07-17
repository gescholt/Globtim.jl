using DynamicPolynomials, MultivariatePolynomials, HomotopyContinuation, ProgressLogging, DataFrames, PlotlyJS, Colors

include("optim_lib.jl")
include("lib_func.jl")
include("hom_solve.jl") # Include the homotopy solver and main function


# Constants and Parameters
d1, d2, ds = 3, 18, 1  # Degree range and step
const n, a, b = 2, 5, 1 
const C = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alph = .9 , 2 / 10  # Sampling parameters
f = camel # Objective function

coeffs_poly_approx = main_gen(f, n, d1, d2, ds, delta, alph, C, 0.1)

vars = @polyvar(x[1:n]) # Define polynomial ring 
h_x, h_y, col = main_2d(n, d1, d2, ds, coeffs_poly_approx) # main_2d is in hom_solve.jl
df = DataFrame(x=C * h_x, y=C * h_y, col=col)
df[!, :result] = [f([df.x[i], df.y[i]]) for i in 1:nrow(df)];

# Generate the grid and evaluate the function
N = 100  # resolution of the grid
x = range(-C, C, length=N)
y = range(-C, C, length=N)
z = [f([xi, yi]) for yi in y, xi in x]

# sc_plt = scatter(x=C* h_x, y=C* h_y, mode="markers", marker_color=col, marker_size=5);
# Generate a color palette based on the number of unique `col` values
unique_cols = unique(df.col)
num_colors = length(unique_cols)
color_palette = distinguishable_colors(num_colors)

# Map the `col` values to the corresponding colors
col_to_color = Dict(unique_cols .=> color_palette)

# Create individual scatter traces for each unique `col` value
scatter_traces = [scatter(x=df[df.col.==c, :x], y=df[df.col.==c, :y], mode="markers", marker=attr(color=col_to_color[c], size=5), name="Degree $c") for c in unique_cols]

# Create the contour plot
cp = contour(x=x, y=y, z=z, ncontours=80, colorscale="Viridis", showscale=false)

# Combine contour plot and scatter traces
all_traces = [cp; scatter_traces...]

# Customize layout to handle legend groups
layout = Layout(
    title="Scatter and Contour Plot",
    xaxis_title="X-axis",
    yaxis_title="Y-axis",
    legend=(tracegroupgap=10, groupclick="toggleitem")
)

# Display the combined plot with legend
display(plot(all_traces, layout))