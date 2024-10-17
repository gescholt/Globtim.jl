using Pkg
Pkg.activate(joinpath(ENV["HOME"], "Globtim.jl"))
# Pkg.instantiate()
using Globtim, ModelingToolkit, DifferentialEquations, DataStructures, LinearAlgebra, DataFrames, DynamicPolynomials


function sample_data(model::ModelingToolkit.ODESystem,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval::Vector{T},
    p_true::Vector{T},
    u0::Vector{T},
    num_points::Int;
    uneven_sampling=false,
    uneven_sampling_times=Vector{T}(),
    solver=Vern9(), inject_noise=false, mean_noise=0,
    stddev_noise=1, abstol=1e-14, reltol=1e-14) where {T<:Number}
    if uneven_sampling
        if length(uneven_sampling_times) == 0
            error("No uneven sampling times provided")
        end
        if length(uneven_sampling_times) != num_points
            error("Uneven sampling times must be of length num_points")
        end
        sampling_times = uneven_sampling_times
    else
        sampling_times = range(time_interval[1], time_interval[2], length=num_points)
    end
    problem = ODEProblem(ModelingToolkit.complete(model), u0, time_interval, Dict(ModelingToolkit.parameters(model) .=> p_true))
    solution_true = ModelingToolkit.solve(problem, solver,
        saveat=sampling_times;
        abstol, reltol)
    data_sample = DataStructures.OrderedDict{Any,Vector{T}}(Num(v.lhs) => solution_true[Num(v.rhs)]
                                             for v in measured_data)
    if inject_noise
        for (key, sample) in data_sample
            data_sample[key] = sample + randn(num_points) .* stddev_noise .+ mean_noise
        end
    end
    data_sample["t"] = sampling_times
    return data_sample
end

#########################################
################   RUN   ################
#########################################

@info "Lotka-Volterra"

# Define a dynamic model using an ODE system.
# x1' = a x1 + b x1 x2,
# x2' = b x1 x2 + c x2
# y1  = x1
#
# The goal is to determine the unknown values of parameters a,b,c
# using the known data for y1 = x1.
@independent_variables t
@variables t x1(t) x2(t) y1(t)
@parameters a b c
D = Differential(t)
params = [a, b, c]
states = [x1, x2]
@named model = ODESystem(
    [D(x1) ~ a * x1 + b * x1 * x2,
        D(x2) ~ b * x1 * x2 + c * x2], t, states, params)
outputs = [y1 ~ x1]

time_interval = [0.0, 1.0]
datasize = 5
p_true = [0.1, 0.22, 0.33]   # true values of a,b,c
ic = [0.11, 0.15]            # true values of x1(0),x2(0)


```
Evaluate the Euclidean distance between the vector of evaluations of the true parameters model and the test parameters.  
This takes a vector of test parameters p_test as input and assumes the Lotka-Volterra model with parameters set by by 
Alexander and Alexey.
In particular, it assumes 5 time points for t in 0.0 to 1.0, and the vector of observations Y_true, that was computed ahead of time 
using the true parameters p_true.
It returns the Euclidean distance between the new vector of observations Y_test and the vector of observations Y_true.
```

function Error_distance(p_test::Vector{Float64};
    model=model,
    Y_true=[0.11, 0.11376181935472697, 0.11774652882518055, 0.12197777166050001, 0.1264826249688384],
    measured_data=[y1 ~ x1],
    time_interval=[0.0, 1.0],
    datasize=5)
    if datasize != length(Y_true)
        error("The length of the test parameters must be equal to the length of the true parameters")
    end
    data_sample = sample_data(model, measured_data, time_interval, p_test, ic, datasize)
    Y_test = data_sample[first(keys(data_sample))]
    return norm(Y_true - Y_test, 1)
end

```Polynomial system solving functions```
function average(X::Vector{Int})::Float64
    return sum(X) / length(X)
end

function symbolic_solve(TR::test_input, Pol::ApproxPoly)::DataFrame
    loc = "inputs.ms"
    file_path_output = "outputs.ms" # File path of the output file
    println("Polynomial degree: ", Pol.degree)
    println("Polynomial coefficients: ", size(Pol.coeffs))
    println("Dimension: ", TR.dim)
    ap = main_nd(TR.dim, Pol.degree, Pol.coeffs)
    @polyvar(x[1:TR.dim]) # Define polynomial ring 
    # Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x
    names = [x[i].name for i in 1:length(x)]
    open(loc, "w") do file
        println(file, join(names, ", "))
        println(file, 0)
    end
    # Define the polynomial approximant 
    println("size coeffs: ", size(Pol.coeffs))
    println("size ap: ", size(ap))
    PolynomialApproximant = sum(ap .* MonomialVector(x, 0:Pol.degree))
    for i in 1:TR.dim
        partial = differentiate(PolynomialApproximant, x[i])
        partial_str = replace(string(partial), "//" => "/")
        open(loc, "a") do file
            if i < TR.dim
                println(file, string(partial_str, ","))
            else
                println(file, partial_str)
            end
        end
    end

    run(`msolve -v 1 -f inputs.ms -o outputs.ms`)
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

    real_solutions = [TR.sample_range * point .+ TR.center for point in real_pts]
    println("real solutions: ", real_solutions)

    df = DataFrame(
        critical_point=real_solutions,
        point_distance=map(point -> norm(point .- p_true), real_solutions),
        eval_distance=map(point -> Error_distance(point), real_solutions)
    )
    return df
end

```Run the model```

p_true = [0.1, 0.22, 0.33]   # true values of a,b,c
p_alte = [0.11, 0.22, 0.33]  # alternative values of a,b,c
p1 = [0.01, 0.22, 0.33]   # true values of a,b,c
#  For dimension 3, it would be nice to plot the cloud point of samples in the parametr space, just to check if the samples are well distributed.

TR1 = create_test_input(Error_distance, n=3, 
        tolerance=1e-5,
        center=p_true,
        sample_range=.25,
        reduce_samples=.1)

TR2 = create_test_input(Error_distance, n=3,
    tolerance=1e-5,
    center=p_true,
    sample_range=0.25,
    reduce_samples=0.2)

TR3 = create_test_input(Error_distance, n=3,
    tolerance=1e-5,
    center=p_true,
    sample_range=0.25,
    reduce_samples=0.4)

TR4 = create_test_input(Error_distance, n=3,
    tolerance=1e-5,
    center=p_true,
    sample_range=0.25,
    reduce_samples=0.6)

TR5 = create_test_input(Error_distance, n=3,
    tolerance=1e-5,
    center=p_true,
    sample_range=0.25,
    reduce_samples=0.8)

``` By simple inspection of the polynomials, it seems there is a stabilization of the coefficients, we might be lacking precisions in floats ?```
Pol1 = Constructor(TR1, 2)
Pol2 = Constructor(TR2, 2)
Pol3 = Constructor(TR3, 2)
Pol4 = Constructor(TR4, 2)
Pol5 = Constructor(TR5, 2)
# Solve the polynomial system
println("degrees attained: ", [Pol1.degree, Pol2.degree, Pol3.degree, Pol4.degree, Pol5.degree])

```
Run with Msolve. 
```
df1 = symbolic_solve(TR1, Pol1)
df2 = symbolic_solve(TR2, Pol2)
df3 = symbolic_solve(TR3, Pol3)
df4 = symbolic_solve(TR4, Pol4)
df5 = symbolic_solve(TR5, Pol5)

sort!(df1, :point_distance)
sort!(df2, :point_distance)
sort!(df3, :point_distance)
sort!(df4, :point_distance)
sort!(df5, :point_distance)

TR = create_test_input(Error_distance, n=3,
    tolerance=1e-6,
    center=p_true,
    sample_range=0.1,
    reduce_samples=0.3)
Pol = Constructor(TR, 2)
df6 = symbolic_solve(TR, Pol)
df7 = symbolic_solve(TR, Pol)
df8 = symbolic_solve(TR, Pol)
df9 = symbolic_solve(TR, Pol)
df10 = symbolic_solve(TR, Pol)
df11 = symbolic_solve(TR, Pol)
sort!(df6, :point_distance)
sort!(df7, :point_distance)
sort!(df8, :point_distance)

sort!(df11, :eval_distance)
p_true

``` Try sparsity -- requires deeper changes in the code. ```
using Plots
histogram(abs.(Pol1.coeffs))
sort(abs.(Pol1.coeffs))

new_coeffs_vector_1 = Vector([abs(coeff) < 1e-8 ? 0.0 : coeff for coeff in Pol1.coeffs])
new_coeffs_vector_2 = [abs(coeff) < 1e-8 ? 0.0 : coeff for coeff in Pol2.coeffs]
new_coeffs_vector_3 = [abs(coeff) < 1e-8 ? 0.0 : coeff for coeff in Pol3.coeffs]
new_coeffs_vector_4 = [abs(coeff) < 1e-8 ? 0.0 : coeff for coeff in Pol4.coeffs]
new_coeffs_vector_5 = [abs(coeff) < 1e-8 ? 0.0 : coeff for coeff in Pol5.coeffs]

Pol1_sparse = ApproxPoly(
    new_coeffs_vector_1,
    Pol1.degree,
    Pol1.nrm,
    Pol1.N,
    Pol1.scale_factor,
    Pol1.grid,
    Pol1.z
)


Pol2_sparse = ApproxPoly(
    new_coeffs_vector_2,
    Pol2.degree,
    Pol2.nrm,
    Pol2.N,
    Pol2.scale_factor,
    Pol2.grid,
    Pol2.z
)

Pol3_sparse = ApproxPoly(
    new_coeffs_vector_3,
    Pol3.degree,
    Pol3.nrm,
    Pol3.N,
    Pol3.scale_factor,
    Pol3.grid,
    Pol3.z
)

Pol4_sparse = ApproxPoly(
    new_coeffs_vector_4,
    Pol4.degree,
    Pol4.nrm,
    Pol4.N,
    Pol4.scale_factor,
    Pol4.grid,
    Pol4.z
)
Pol5_sparse = ApproxPoly(
    new_coeffs_vector_5,
    Pol5.degree,
    Pol5.nrm,
    Pol5.N,
    Pol5.scale_factor,
    Pol5.grid,
    Pol5.z
)

println(Pol1_sparse.degree)
print(TR1)

df1_sparse = symbolic_solve(TR1, Pol1_sparse)
df2_sparse = symbolic_solve(TR2, Pol2_sparse)
df3_sparse = symbolic_solve(TR3, Pol3_sparse)
df4_sparse = symbolic_solve(TR4, Pol4_sparse)
df5_sparse = symbolic_solve(TR5, Pol5_sparse)


# using GLMakie
# GLMakie.activate!()
# GLMakie.closeall()
# fig = Figure(size=(800, 600))
# ax = Axis3(fig[1, 1], title="3D Cloud of Points")
# scatter!(ax, Pol.grid[:, 1], Pol.grid[:, 2], Pol.grid[:, 3], markersize=8, color=:blue)
# display(fig)