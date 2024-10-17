using Pkg
Pkg.activate(joinpath(ENV["HOME"], "Globtim.jl"))
# Pkg.instantiate()
using Globtim, ModelingToolkit, DifferentialEquations, DataStructures, LinearAlgebra
using DynamicPolynomials, HomotopyContinuation, ProgressLogging


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
p_alte = [0.11, 0.22, 0.33]  # alternative values of a,b,c
p1     = [0.01, 0.22, 0.33]   # true values of a,b,c
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
    return norm(Y_true - Y_test)
end

Error_distance(p_true)
Error_distance(p_alte)
Error_distance(p1)

#  For dimension 3, it would be nice to plot the cloud point of samples in the parametr space, just to check if the samples are well distributed.

TR = create_test_input(Error_distance, n=3, 
        tolerance=1e-6,
        center=[.5,.5, .5],
        sample_range=.5,
        reduce_samples=.1)
Pol = Constructor(TR, 2)

# Solve the polynomial system

```
This seems awfully slow, but we are at 3 variables I suppose. 
Compare with Msolve. 
```

@polyvar(x[1:TR.dim]) # Define polynomial ring 
ap = main_nd(TR.dim, Pol.degree, Pol.coeffs)
# Expand the polynomial approximant to the standard monomial basis in the Lexicographic order w.r.t x. 
PolynomialApproximant = sum(Float64.(ap) .* MonomialVector(x, 0:Pol.degree)) # Convert coefficients to Float64 for homotopy continuation
grad = differentiate.(PolynomialApproximant, x)
sys = HomotopyContinuation.System(grad)
Real_sol_lstsq = HomotopyContinuation.solve(sys)
real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
# We need to translate and scale back this solutions
real_solutions = [TR.sample_range * point .+ TR.center for point in real_pts]

using DataFrames
df = DataFrame(
    critical_point=real_solutions,
    point_distance= map(point -> norm(point .- p_true), real_solutions),
    eval_distance=map(point -> Error_distance(point), real_solutions)
)

sort!(df, :point_distance)


using GLMakie
GLMakie.activate!()
GLMakie.closeall()
fig = Figure(size=(800, 600))
ax = Axis3(fig[1, 1], title="3D Cloud of Points")
scatter!(ax, Pol.grid[:, 1], Pol.grid[:, 2], Pol.grid[:, 3], markersize=8, color=:blue)
display(fig)