# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, JSON
# AlgebraicSolving, HomotopyContinuation,, Plots

# Constants and Parameters
const d1, d2, ds = 2, 30, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters
const N = 40

x_vals = range(-C, C, length=N)
y_vals = range(-C, C, length=N)
@polyvar(x, y) # Define polynomial ring


# # Main loop
# for (i, d) in enumerate(d1:ds:d2)
#     ## Read and parse the files
#     file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
#     file_path_pol = expanduser("data/pol_rat_msolve_d$(d)_C_$(a)_$b.txt")

#     # Read points msolve
#     data_pts = read(file_path_pts, String)
#     trimmed_content = strip(data_pts, ['[', ']']) # trim brackets
#     rows = split(trimmed_content, "], [") # split into two arrays
#     # Collect the two arrays of msolve points
#     data_array = [parse.(Float64, split(strip(row, ['[', ']']), ", ")) for row in rows]

#     # Collect the polynomial
#     data_pol = read(file_path_pol, String)
#     # Read the polynomial approximant
#     polynomial = eval(Meta.parse(data_pol))

#     # Compute derivatives
#     P1 = differentiate(polynomial, x)
#     P2 = differentiate(polynomial, y)

#     # Compute Homotopy Continuation
#     homoto = RR_xy_solve(n, P1, P2)

#     # Define the condition for filtering
#     condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1

#     # Filter points using the filter function
#     filtered_points = filter(condition, homoto)
#     h_x = [point[1] for point in filtered_points] # for plotting
#     h_y = [point[2] for point in filtered_points]

#     println("Number of real solutions homotopy:", length(homoto))
#     println("Number of real solutions msolve:", length(data_array[1]))

#     # Plot the data
#     plot_data(data_array, h_x, h_y, "Degree $(d)")
# end


# Main L2-norm loop
for (i, d) in enumerate(d1:ds:d2)
    norm_values = Float64[]
    ## Read and parse the files
    # file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
    file_path_pol = expanduser("data/pol_rat_msolve_d$(d)_C_$(a)_$b.txt")

    # Collect the polynomial
    data_pol = read(file_path_pol, String)
    # Read the polynomial approximant
    polynomial = eval(Meta.parse(data_pol))
    print(polynomial)
    for x_val in x_vals, y_val in y_vals
        P_val = subs(polynomial, x=> x_val, y => y_val)
        f_val = tref(x_val, y_val)
        diff = P_val - f_val
        push!(norm_values, diff^2)
    end 
    # Sum the norm values and take the square root
    norm = sqrt(sum(norm_values) / (N^2))
    println("Discrete L2-norm:", norm)
end
