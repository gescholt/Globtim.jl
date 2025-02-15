using Pkg
Pkg.activate(joinpath(ENV["HOME"], "Globtim.jl"))
Pkg.instantiate()
using DynamicPolynomials, HomotopyContinuation, ProgressLogging, DataFrames
using Globtim
using GLMakie
using GLFW
GLMakie.activate!()

# Ensure GLFW is initialized
if !GLFW.Init()
    error("GLFW could not be initialized")
end

GLMakie.closeall()

T = create_test_input(Deuflhard, sample_range = 1.1, tolerance = 1e-4)
Pol = Constructor(T, 2)
# The polynomial approximant is constructed. 

@polyvar(x[1:T.dim]) # Define polynomial ring 
ap = main_nd(T.dim, Pol.degree, Pol.coeffs)
# Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x. 
PolynomialApproximant = sum(Float64.(ap) .* MonomialVector(x, 0:Pol.degree)) # Convert coefficients to Float64 for homotopy continuation
grad = differentiate.(PolynomialApproximant, x)
sys = System(grad)
Real_sol_lstsq = HomotopyContinuation.solve(sys)
real_pts = HomotopyContinuation.real_solutions(
    Real_sol_lstsq;
    only_real = true,
    multiple_results = false,
)
condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function
# Colllect the critical points of the approximant 
h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector
h_z = map(p -> T.objective([p[1], p[2]]), zip(T.sample_range * h_x, T.sample_range * h_y))
df = DataFrame(x = T.sample_range * h_x, y = T.sample_range * h_y, z = h_z); # Create a DataFrame

# Plotting # 
function peaks(; div = 49)
    x = LinRange(-1.0 * T.sample_range, 1.0 * T.sample_range, div)
    y = LinRange(-1.0 * T.sample_range, 1.0 * T.sample_range, div)
    z = [T.objective([i, j]) for i in x, j in y]
    return (x, y, z)
end

x, y, z = peaks()
with_theme(theme_dark()) do
    fig = Figure(size = (1200, 800))
    ax1 = Axis(fig[1, 1], aspect = 1)
    ax2 = Axis3(fig[1, 2]; aspect = (1, 1, 0.7), perspectiveness = 0.5)
    axs = [ax1, ax2]
    cmap = :diverging_bkr_55_10_c35_n256
    contourf!(axs[1], x, y, z; levels = -0:0.001:0.06, mode = :relative, colormap = cmap)
    # bug, colormap cannot be transparent
    contourf!(axs[2], x, y, z; levels = -0:0.01:4.8, colormap = cmap)
    contour3d!(
        axs[2],
        x,
        y,
        z;
        levels = -0:0.01:4.8,
        colormap = cmap,
        transparency = true,
        linewidth = 2,
    )

    # add the computed critical points
    scatter!(axs[1], df.x, df.y; color = :orange, markersize = 8)
    scatter!(axs[2], df.x, df.y, df.z; color = :orange, markersize = 8)

    limits!(
        axs[1],
        -1 * T.sample_range,
        1 * T.sample_range,
        -1 * T.sample_range,
        1 * T.sample_range,
    )
    hidedecorations!.(axs; grid = false)
    display(fig)
end
