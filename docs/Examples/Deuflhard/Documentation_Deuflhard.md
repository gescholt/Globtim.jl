What we need is a small parcel to work on, with a nice contourplot with critical points and minima found after initiating local method and then a 3d plot.


```julia
using Globtim
using DynamicPolynomials, DataFrames
using PlotlyJS, Colors


include("../src/lib_func.jl")

# Constants and Parameters
d = 1 # Initial Degree
const n, a, b = 2, 11, 10
const scale_factor = a / b       # Scaling factor appears in `main_computation`, maybe it should be a parameter.
const delta, alpha = .5 , 1 / 10  # Sampling parameters # Delta used to be too big
const tol_l2 = 1e-4            # Define the tolerance for the L2-norm
const sample_scale = 1.0

f = Deuflhard # Objective function
```

One may assume that when we have access to exact evaluations, we would want to have a small $L^2$-norm tolerance `tol_l2 = 5e-4` and high probability of computing an accurate discrete $L^2$-norm `alpha= 1/10`.

We need to also return the number of samples used to generate the sample set. It is annoying that the error goes up while the degree has increased.


```julia
while true # Potential infinite loop
    global poly_approx = MainGenerate(f, 2, d, delta, alpha, scale_factor, sample_scale) # computes the approximant in Chebyshev basis
    if poly_approx.nrm < tol_l2
        println("attained the desired L2-norm: ", poly_approx.nrm)
        println("Degree :$d ")
        break
    else
        println("current L2-norm: ", poly_approx.nrm)
        println("Number of samples: ", poly_approx.N)
        global d += 1
    end
end
println("current L2-norm: ", poly_approx.nrm)
println("Number of samples: ", poly_approx.N)
```

We now expand the approximant computed in the tensorized Chebyshev basis into standard monomial basis and construct the system of partials for MSolve.


```julia
loc = "inputs.ms"
# File path of the output file
file_path_output = "outputs.ms";

ap = main_nd(n, d, poly_approx.coeffs)
@polyvar(x[1:n]) # Define polynomial ring
# Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x
names = [x[i].name for i in 1:length(x)]
open(loc, "w") do file
    println(file, join(names, ", "))
    println(file, 0)
end
# Define the polynomial approximant
PolynomialApproximant = sum(ap .* MonomialVector(x, 0:d))
for i in 1:n
    partial = differentiate(PolynomialApproximant, x[i])
    partial_str = replace(string(partial), "//" => "/")
    open(loc, "a") do file
        if i < n
            println(file, string(partial_str, ","))
        else
            println(file, partial_str)
        end
    end
end
```

Solve the system of partial derivatives using `Msolve`.


```julia
run(`msolve -v 1 -f inputs.ms -o outputs.ms`)
```

Sort through the critical points, make sure they fall into the domain of definition. Make them into a Dataframe.


```julia
function average(X::Vector{Int})::Float64
    return sum(X) / length(X)
end

# Process the file and get the points
evaled = process_output_file(file_path_output)

# Parse the points into correct format
real_pts = []
for pts in evaled
    if typeof(pts) == Vector{Vector{Vector{BigInt}}}
        X = parse_point(pts)
    else
        X = average.(pts)
    end
    push!(real_pts, Float64.(X))
end

condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function
# Colllect the critical points of the approximant
h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector
h_z = map(p -> f([p[1], p[2]]), zip(scale_factor * h_x, scale_factor * h_y))
df = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y, z= h_z); # Create a DataFrame
```

We proceed to generate the plot of the critical points over the sample set $\mathcal{S}$.


```julia
# Extract coordinates and function values
coords = poly_approx.scale_factor * poly_approx.grid
z_coords = poly_approx.z

# Plot the 3D scatter plot if the dimensions are 2
if size(coords)[2] == 2
    scatter_trace = scatter3d(
        x=coords[:, 1],
        y=coords[:, 2],
        z=z_coords,
        mode="markers",
        marker=attr(
            size=1,
            color=z_coords,
            colorscale="Viridis"
        ),
        name="Sampled Data"
    )
    println("Plotting 3D scatter plot")

    # Create the scatter3d trace
    # Had to switch the coordinates of the critical points to match the surface plot for some reason.
    crit_pts = scatter3d(
        x=df.y,
        y=df.x,
        z=df.z,
        mode="markers",
        marker=attr(
            size=10,
            color="red"
        ),
        name="Critical Points"
    )

    layout = Layout(
        title="3D Scatter Plot of Sample Points",
        scene=attr(
            xaxis=attr(title="X-axis"),
            yaxis=attr(title="Y-axis"),
            zaxis=attr(title="Z-axis")),
        height=1200
    )
    # plt1 = Plot([scatter_trace, crit_pts],layout)
    # display(plt1)
end

```


```julia
println("Degree: $d")
println("current L2-norm: ", poly_approx.nrm)
println("Number of samples: ", poly_approx.N)
```

### Add a Random Noise

We equip the evaluations of `CrossInTray` with a Gaussian noise. We set the standard deviation `stddev`to `5.0`.
Observation so far: low sensitivity to changing `alpha`, the probability on the discrete $L^2$-norm, we observe that the number of samples generated does not change drastically w.r.t. `alpha`.
In a first scenario, we only require a low probability `1 - alpha_noise` of the discrete $L^2$-norm reaching the tolerance set by `noisy_tol_l2`.


```julia
using Distributions
# Define the noisy version of the objective function
function noisy_Deuflhard(xx::Vector{Float64}; mean::Float64=0.0, stddev::Float64=5.0)::Float64
    noise = rand(Normal(mean, stddev))
    return Deuflhard(xx) + noise
end
```


```julia
noisy_tol_l2 = 5e-2        # Define the noise affected tolerance for the L2-norm

f_noisy = noisy_Deuflhard
d = 1

while true # Potential infinite loop
    global poly_approx_noisy = MainGenerate(f_noisy, 2, d, delta, alpha, scale_factor, sample_scale) # computes the approximant in Chebyshev basis
    if poly_approx_noisy.nrm < noisy_tol_l2
        println("attained the desired L2-norm: ", poly_approx_noisy.nrm)
        println("Degree: $d")
        break
    else
        println("current L2-norm: ", poly_approx_noisy.nrm)
        println("Number of samples: ", poly_approx_noisy.N)
        global d += 1
    end
end
println("Number of samples: ", poly_approx_noisy.N)

ap = main_nd(n, d, poly_approx_noisy.coeffs)

@polyvar(x[1:n]) # Define polynomial ring
# Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x
names = [x[i].name for i in 1:length(x)]
open(loc, "w") do file
    println(file, join(names, ", "))
    println(file, 0)
end
# Define the polynomial approximant
PolynomialApproximant = sum(ap .* MonomialVector(x, 0:d))
for i in 1:n
    partial = differentiate(PolynomialApproximant, x[i])
    partial_str = replace(string(partial), "//" => "/")
    open(loc, "a") do file
        if i < n
            println(file, string(partial_str, ","))
        else
            println(file, partial_str)
        end
    end
end
run(`msolve -v 0 -f inputs.ms -o outputs.ms`)
# Process the file and get the points
evaled = process_output_file(file_path_output)

# Parse the points into correct format
real_pts = []
for pts in evaled
    if typeof(pts) == Vector{Vector{Vector{BigInt}}}
        X = parse_point(pts)
    else
        X = average.(pts)
    end
    push!(real_pts, Float64.(X))
end


condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function
# Colllect the critical points of the approximant
h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector

# Here we should evaluate on the noiseless function to compare with previous results
h_z = map(p -> f([p[1], p[2]]), zip(scale_factor * h_x, scale_factor * h_y))

df_noisy = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y, z=h_z); # Create a DataFrame

coords = poly_approx_noisy.scale_factor * poly_approx_noisy.grid
z_coords = poly_approx_noisy.z

# Plot the 3D scatter plot if the dimensions are 2
if size(coords)[2] == 2
    scatter_trace = scatter3d(
        x=coords[:, 1],
        y=coords[:, 2],
        z=z_coords,
        mode="markers",
        marker=attr(
            size=1,
            color=z_coords,
            colorscale="Viridis"
        ),
        name="Sampled Noisy Data"
    )
    # Had to switch the coordinates of the critical points to match the surface plot for some reason.
    crit_pts_noisy = scatter3d(
        x=df_noisy.y,
        y=df_noisy.x,
        z=df_noisy.z,
        mode="markers",
        marker=attr(
            size=8,
            color="orange"
        ),
        name="Critical Points"
    )

    layout = Layout(
        title="3D Scatter Plot of Sample Points",
        scene=attr(
            xaxis=attr(title="X-axis"),
            yaxis=attr(title="Y-axis"),
            zaxis=attr(title="Z-axis")),
        height=1200
    )
end
```


```julia
plt2 = Plot([scatter_trace, crit_pts_noisy, crit_pts], layout)
```


```julia
println("L2 tolerance: $noisy_tol_l2")
println("Degree: $d")
println("current L2-norm: ", poly_approx_noisy.nrm)
println("Number of samples: ", poly_approx_noisy.N)
savefig(plt2, "../data/figures/noisy_3d_Deuflhard.html")
```


```julia
d = 1
noisy_tol_l2 = 2.0e-2        # Define the noise affected tolerance for the L2-norm
while true # Potential infinite loop
    global poly_approx_noisy = MainGenerate(f_noisy, 2, d, delta, alpha, scale_factor, sample_scale) # computes the approximant in Chebyshev basis
    if poly_approx_noisy.nrm < noisy_tol_l2
        println("attained the desired L2-norm: ", poly_approx_noisy.nrm)
        println("Degree: $d")
        break
    else
        println("current L2-norm: ", poly_approx_noisy.nrm)
        println("Number of samples: ", poly_approx_noisy.N)
        global d += 1
    end
end
println("Number of samples: ", poly_approx_noisy.N)

ap = main_nd(n, d, poly_approx_noisy.coeffs)

@polyvar(x[1:n]) # Define polynomial ring
# Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x
names = [x[i].name for i in 1:length(x)]
open(loc, "w") do file
    println(file, join(names, ", "))
    println(file, 0)
end
# Define the polynomial approximant
PolynomialApproximant = sum(ap .* MonomialVector(x, 0:d))
for i in 1:n
    partial = differentiate(PolynomialApproximant, x[i])
    partial_str = replace(string(partial), "//" => "/")
    open(loc, "a") do file
        if i < n
            println(file, string(partial_str, ","))
        else
            println(file, partial_str)
        end
    end
end
run(`msolve -v 0 -f inputs.ms -o outputs.ms`)
# Process the file and get the points
evaled = process_output_file(file_path_output)

# Parse the points into correct format
real_pts = []
for pts in evaled
    if typeof(pts) == Vector{Vector{Vector{BigInt}}}
        X = parse_point(pts)
    else
        X = average.(pts)
    end
    push!(real_pts, Float64.(X))
end

# Repeat, could be made ito a function.

condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function
# Colllect the critical points of the approximant
h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector

# Here we should evaluate on the noiseless function to compare with previous results
h_z = map(p -> f([p[1], p[2]]), zip(scale_factor * h_x, scale_factor * h_y))

df_noisy = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y, z=h_z); # Create a DataFrame

coords = poly_approx_noisy.scale_factor * poly_approx_noisy.grid
z_coords = poly_approx_noisy.z

# Plot the 3D scatter plot if the dimensions are 2
if size(coords)[2] == 2
    scatter_trace = scatter3d(
        x=coords[:, 1],
        y=coords[:, 2],
        z=z_coords,
        mode="markers",
        marker=attr(
            size=1,
            color=z_coords,
            colorscale="Viridis"
        ),
        name="Sampled Noisy Data"
    )
    # Had to switch the coordinates of the critical points to match the surface plot for some reason.
    crit_pts_noisy = scatter3d(
        x=df_noisy.y,
        y=df_noisy.x,
        z=df_noisy.z,
        mode="markers",
        marker=attr(
            size=8,
            color="orange"
        ),
        name="Critical Points"
    )

    layout = Layout(
        title="3D Scatter Plot of Sample Points",
        scene=attr(
            xaxis=attr(title="X-axis"),
            yaxis=attr(title="Y-axis"),
            zaxis=attr(title="Z-axis")),
        height=1200
    )
end
```


```julia
plt3 = Plot([scatter_trace, crit_pts_noisy, crit_pts], layout)
```


```julia
println("L2 tolerance: $noisy_tol_l2")
println("Degree: $d")
println("current L2-norm: ", poly_approx_noisy.nrm)
println("Number of samples: ", poly_approx_noisy.N)
savefig(plt3, "../data/figures/noisy_tol_up_3d_Deuflhard.html")
```


```julia
# plt_noisy = plot([sf, crit_pts_noisy], layout)
# savefig(plt, "../data/figures/Noisy_Deuflhard.html")
# savefig(plt1, "../data/figures/Deuflhard_surf_exact.html")
# savefig(plt_noisy, "../data/figures/Deuflhard_surf_noisy_pts.html")
```
