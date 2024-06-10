

using LinearAlgebra, LinearSolve, Statistics
# HomotopyContinuation, Plots
using Base: parse
using Printf

function read_and_parse_file(d, a, b)
    # Construct the file path
    file_path_pts = expanduser(@sprintf("data/pts_rat_msolve_d%d_C_%d_%d.txt", d, a, b))

    # Try to read and parse the file
    try
        # Read points from the file
        data_pts = read(file_path_pts, String)

        # Process the data
        trimmed_content = strip(data_pts, ['[', ']'])  # Trim brackets
        rows = split(trimmed_content, "], [")  # Split into rows

        # Collect the two arrays of msolve points
        data_array = [parse.(Float64, split(strip(row, ['[', ']']), ", ")) for row in rows]

        return data_array

    catch e
        if isa(e, SystemError) && occursin("No such file or directory", e.message)
            error("File $file_path_pts does not exist.")
        else
            rethrow(e)
        end
    end
end


zeta(x) = x + (1 - x) * log(1 - x)



# Create a grid over the domain [-C, C]^2
function create_grid(C, N)
    x_vals = range(-C, stop=C, length=N)
    y_vals = range(-C, stop=C, length=N)
    return x_vals, y_vals
end

# Evaluate tref on the grid
function evaluate_tref_on_grid(tref, x_vals, y_vals)
    Z = [tref(x, y) for y in y_vals, x in x_vals]
    return Z
end

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
function find_local_extrema(Z, x_vals, y_vals, N)
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
    return local_maxima, local_minima
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

# Compute the closest distances for each point in extrema_points to a given set of points
function compute_closest_distances(extrema_points, given_points)
    closest_distances = []
    for extremum in extrema_points
        min_distance = Inf
        for point in given_points
            dist = norm(extremum .- point)
            if dist < min_distance
                min_distance = dist
            end
        end
        push!(closest_distances, min_distance)
    end
    return closest_distances
end

# Draw transparent circles around local maxima and minima
function plot_filled_circles!(centers, radii, colors; marker_size=600)
    if length(centers) != length(radii) || length(centers) != length(colors)
        error("Lengths of centers, radii, and colors arrays must be equal.")
    end
    plot!()
    for (center, radius, color) in zip(centers, radii, colors)
        scatter!([center[1]], [center[2]], markersize=radius * marker_size, markercolor=color, markerstrokewidth=0, alpha=0.5, label="")
    end
end

function chebyshev_poly(d::Int, x)
    if d == 0
        return rationalize(1.0)
    elseif d == 1
        return x
    else
        T_prev = rationalize(1.0)
        T_curr = x
        for n in 2:d
            T_next = rationalize(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

# Function to calculate the required number of samples
function calculate_samples(m, delta, alph)
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

# Function to generate the sampling grid
function generate_grid(n, GN)
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
end

# Function to compute the support of polynomial of total degree at most $d$. 
function support_gen(n, d)
    ranges = [0:d for _ in 1:n]     # Generate ranges for each dimension
    iter = Iterators.product(ranges...) # Create the Cartesian product over the ranges
    # Initialize a list to hold valid tuples
    lambda_list = []
    # Loop through the Cartesian product, filtering valid tuples
    for tuple in iter
        if sum(tuple) <= d
            push!(lambda_list, collect(tuple))  # Convert each tuple to an array
        end
    end
    # Check if lambda_list is empty to handle edge cases
    if length(lambda_list) == 0
        lambda_matrix = zeros(0, n)  # Return an empty matrix with 0 rows and n columns
    else
        # Convert the list of arrays to an N x n matrix
        lambda_matrix = hcat(lambda_list...)'
    end
    # Return a NamedTuple containing the matrix and its size attributes
    return (data=lambda_matrix, size=size(lambda_matrix))
end

function lambda_vandermonde(Lambda, S)
    # Generate Vandermonde like matrix in Chebyshev tensored basis. 
    m, N = Lambda.size
    n, N = size(S)
    print("\n")
    print("dimension Vector space: ", m)
    print("\n")
    print("sample size: ", n)
    print("\n")
    print("Dimension samples: ", N)
    print("\n")
    V = zeros(n, m)
    for i in 1:n # Number of samples
        for j in 1:m # Dimension of vector space of polynomials
            P = 1.0
            for k in 1:N # Dimension of each sample
                P *= chebyshev_poly(Lambda.data[j, k], S[i, k])
            end
            V[i, j] = P
        end
    end
    return V
end

# Main computation function, 
function main_computation(f, n::Int, d1::Int, d2::Int, ds::Int)
    symb_approx = []
    for d in d1:ds:d2
        m = binomial(n + d, d)  # Dimension of vector space
        K = calculate_samples(m, delta, alph)
        GN = round(K^(1/n)) + 1
        Lambda = support_gen(n, d)
        grid = generate_grid(n, GN)
        matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'

        VL = lambda_vandermonde(Lambda, matrix_from_grid)
        G_original = VL' * VL
        # F = [f(C * matrix_from_grid[Int(i), 1], C * matrix_from_grid[Int(i), 2]) for i in 1:(GN+1)^2]
        F = [f([C * matrix_from_grid[Int(i), :]...]) for i in 1:(GN+1)^n]
        RHS = VL' * F

        # Solve linear system using an appropriate LinearSolve function
        linear_prob = LinearProblem(G_original, RHS) # Define a linear problem
        # Now solve the problem with proper choice of compute method. 
        
        sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
        cheb_coeffs = sol.u

        push!(symb_approx, cheb_coeffs)
    end
    return symb_approx
end


# return the symbolic approxiamnt with expanded chebyshev polynomials in variables 1 through n 
function generateApproximant(Lambda, rat_sol_cheb, coeff_type::Symbol)
    ## Important note, the @polyvar variables should not be defined inside the function but in the main execution file.
    m, n = size(Lambda)
    # m: dimension of polynomial vector space we project onto. 
    # n: number of variables

    ## Validate input sizes and consistency
    if isempty(Lambda)
        error("Lambda must not be empty")
    end

    ## Ensure the number of coefficients matches the number of polynomial terms
    if length(rat_sol_cheb) != m
        print("\n")
        error("The length of rat_sol_cheb must match the dimension of the space we project onto")
    end
    
    S_rat = 0 * x[1]      # Initialize the sum S_rat
    # Iterate over each index of Lambda and rat_sol_cheb using only the length of rat_sol_cheb
    for i in 1:m # for each term of the orthonormal basis.        
        prd = 1 + 0 * x[1] # Initialize product prd for each i
        # Loop over each variable index in the row
        for j in 1:n
            # Multiply prd by the Chebyshev polynomial T evaluated at x[j]
            prd *= chebyshev_poly(Lambda[i, j], x[j])
        end
        # Add the product scaled by the corresponding rational solution coefficient to S_rat
        if coeff_type == :RationalBigInt
            S_rat += rationalize(BigInt, rat_sol_cheb[i]) * prd
        elseif coeff_type == :BigFloat
            S_rat += BigFloat(rat_sol_cheb[i]) * prd
        else
            error("Unsupported coefficient type. Use :RationalBigInt or :BigFloat.")
        end
    end
    return S_rat
end

# Maybe not needed for homotopy continuation anymore. 
function rational_bigint_to_int(r::Rational{BigInt}, tol::Float64=1e-12)
    # Convert Rational{BigInt} to Float64
    float_approximation = Float64(r)
    # Use rationalize to convert Float64 to Rational{Int}
    rational_approx = rationalize(float_approximation)
    return Rational{Int}(numerator(rational_approx), denominator(rational_approx))

end

# Homotopy continuation solves the polynomial system over the reals.
function RRsolve(n, p1, p2)
    p1_str = string(p1)
    p2_str = string(p2)
    @var(x[1:n])
    p1_converted = eval(Meta.parse(p1_str))
    p2_converted = eval(Meta.parse(p2_str))
    Z = System([p1_converted, p2_converted])
    Real_sol_lstsq = HomotopyContinuation.solve(Z)
    real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
    return real_pts
end 

# same as previous but only for 2d with x and y as variables
function RR_xy_solve(n, p1, p2) 
    p1_str = string(p1)
    p2_str = string(p2)
    @var(x, y)
    p1_converted = eval(Meta.parse(p1_str))
    p2_converted = eval(Meta.parse(p2_str))
    Z = System([p1_converted, p2_converted])
    Real_sol_lstsq = HomotopyContinuation.solve(Z)
    real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
    return real_pts
end

# Function to plot the data
function plot_data(data_array, h_x, h_y, title)
    plt = scatter(data_array[1], data_array[2], seriestype=:scatter, label="msolve points",
        xlabel="x", ylabel="y", color=:red, marker=(:diamond, 8), title=title)
    scatter!(plt, h_x, h_y, seriestype=:scatter, label="homotopy points",
        marker=(:circle, 4), markerstrokecolor=:blue, markerstrokewidth=1.5)
    display(plt)
end

# Generate the system of partials 
function gen_sys(Lambda, rat_sol_cheb, coeff_type::Symbol)
    P = generateApproximant(Lambda, rat_sol_cheb, coeff_type::Symbol)
    # Compute the partial derivatives
    partials = Vector{DynamicPolynomials.Polynomial}(undef, n)
    for i in 1:n
        partials[i] = differentiate(P, x[i])
    end
    # Convert each partial derivative to a string
    partials_as_strings = [string(p) for p in partials]

    return partials_as_strings
end


function For_Msolve(n, coeff, Lambda)
    @polyvar(x[1:n]) # Define polynomial ring 
    P = generateApproximant(Lambda, rat_sol_cheb, coeff_type::BigInt)
    # Compute the partial derivatives
    for i in 1:n
        partials[i] = differentiate(P, x[i])
    end

    


end 