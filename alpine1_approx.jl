include("optim_lib.jl")
include("lib_func.jl")
include("hom_solve.jl") # Include the homotopy solver and main function
using DynamicPolynomials, MultivariatePolynomials, HomotopyContinuation, ProgressLogging, DataFrames, PlotlyJS, Colors, Optim, CSV


# Constants and Parameters
d1, d2, ds = 6, 8, 1  # Degree range and step
const n, a, b = 2, 3, 1 
const C = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alph = .5 , 9 / 10  # Sampling parameters
const cntr = Vector([3.14, 3.14]) # Center of the domain
# const cntr = Vector(2*[-3.14, -3.14]) # Center of the domain
f = alpine1 # Objective function
# Compute the coefficients of the polynomial approximation

coeffs_poly_approx = main_gen(f, n, d1, d2, ds, delta, alph, C, 0.1, center=cntr)
# Solve the system of polynomial equations
vars = @polyvar(x[1:n]) # Define polynomial ring 
h_x, h_y, col = main_2d(n, d1, d2, ds, coeffs_poly_approx) # main_2d is in hom_solve.jl
# Store the outputs in a DataFrame
df = DataFrame(x=C * h_x .+ cntr[1], y=C * h_y .+ cntr[2], col=col)
df[!, :result] = [f([df.x[i], df.y[i]]) for i in 1:nrow(df)];
df[!, :local_minima] = zeros(nrow(df))
df[!, :distance_to_minima] = zeros(nrow(df))
df[!, :steps] = zeros(Int, nrow(df))
df[!, :converged] = falses(nrow(df))
# Generate the plots
N = 100  # resolution of the grid
x = range(-C, C, length=N) .+ cntr[1]
y = range(-C, C, length=N) .+ cntr[2]
z = [f([xi, yi]) for yi in y, xi in x]

# println(z)

# Generate a color palette based on the number of unique `col` values
unique_cols = unique(df.col)
num_colors = length(unique_cols)
color_palette = distinguishable_colors(num_colors)
# Map the `col` values to the corresponding colors
col_to_color = Dict(unique_cols .=> color_palette)
# Create individual scatter traces for each unique `col` value
scatter_traces = [scatter(x=df[df.col.==c, :x], y=df[df.col.==c, :y], mode="markers", marker=attr(color=col_to_color[c], size=5), name="Degree $c") for c in unique_cols]

# Define custom contour levels focusing on 0 < z < 10
clip_value = 1
z_clipped = map(x -> min(x, clip_value), z)  # clip values at 10
min_z_clipped = minimum(z_clipped)
max_z_clipped = maximum(z_clipped)
# Define custom contour levels for 0 < z < 10 and group values > 10
levels = exp10.(range(log10(max(min_z_clipped, 1e-10)), log10(clip_value), length=80))
# Create the contour plot with custom levels
cp = contour(x=x, y=y, z=z_clipped, levels=levels, ncontours=length(levels),
    colorscale="Viridis", showscale=false)

# Combine contour plot and scatter traces
all_traces = [cp; scatter_traces...]
# Customize layout to handle legend groups
layout = Layout(
    title="Scatter and Contour Plot",
    xaxis_title="X-axis",
    yaxis_title="Y-axis",
    legend=(tracegroupgap=10, groupclick="toggleitem"),
    height=600 # Increase the height to make room for the legend
)
# Display the combined plot with legend
display(plot(all_traces, layout))

# Optimize the collected entries 
for i in 1:nrow(df)
    println("Optimizing for point $i")
    x0 = [df.x[i], df.y[i]]
    res = Optim.optimize(f, x0, LBFGS(), Optim.Options(show_trace=true))
    minimizer = Optim.minimizer(res)
    min_value = Optim.minimum(res)
    steps = res.iterations
    converged = Optim.converged(res)
    distance = norm(x0 - minimizer)

    df.local_minima[i] = min_value
    df.distance_to_minima[i] = distance
    df.steps[i] = steps
    df.converged[i] = converged

    println(summary(res))
end

filtered_df = df[df.col.==6, :]
for i in d1:ds:d2
    filtered_df = vcat(filtered_df, df[df.col.==i, :])
    CSV.write("data/alpine1_d$i.csv", filtered_df)
end
