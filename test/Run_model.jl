using Pkg
Pkg.activate(dirname(@__FILE__)) # Add package in development mode
Pkg.develop(PackageSpec(path=dirname(dirname(@__FILE__)))) # Assuming package root is one level up from /test
# Now you can use your package
using Globtim, Test, ModelingToolkit, DifferentialEquations, Random
using DataStructures,  LinearAlgebra, DynamicPolynomials
using HomotopyContinuation, ProgressLogging, DataFrames

include("test_helper.jl")
# @testset "globtim Tests" begin
#     # Individual tests
# end
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
@variables x1(t) x2(t) y1(t)
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
 Different candidates of centers for the samples
```
p1 = [0.01, 0.22, 0.33]   # true values of a,b,c
p2 = [0.2, 0.0, 0.0]  # alternative values of a,b,c

```
Evaluate the Euclidean distance between the vector of evaluations of the true parameters model and the test parameters.  
This takes a vector of test parameters p_test as input and assumes the Lotka-Volterra model with parameters set by by 
Alexander and Alexey.
In particular, it assumes 5 time points for t in 0.0 to 1.0, and the vector of observations Y_true, that was computed ahead of time 
using the true parameters p_true.
It returns the Euclidean distance between the new vector of observations Y_test and the vector of observations Y_true.
```

#  For dimension 3, it would be nice to plot the cloud point of samples in the parametr space, just to check if the samples are well distributed.
``` 
Fewer sample points, yet a better outcome.
```

TR = create_test_input(Error_distance, n=3,
    tolerance=1.e-3,
    center=p_true + [0.05, 0.0, 0.0],
    sample_range=0.15,
    reduce_samples=0.4)
Pol = Constructor(TR, 2, basis=:legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)

TR = create_test_input(Error_distance, n=3,
    tolerance=1.e-3,
    center=p_true + [0.05, 0.0, 0.0],
    sample_range=0.15,
    reduce_samples=0.2)
Pol = Constructor(TR, 2, basis=:legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)

TR = create_test_input(Error_distance, n=3, 
        tolerance=1.e-3,
        center=p_true + [0.05, 0.0, 0.0],
        sample_range=.15,
        reduce_samples=.1)
Pol = Constructor(TR, 2, basis = :legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)

TR = create_test_input(Error_distance, n=3,
    tolerance=1.e-3,
    center=p_true + [0.05, 0.0, 0.0],
    sample_range=0.15,
    reduce_samples=0.05)
Pol = Constructor(TR, 2, basis=:legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)

TR = create_test_input(Error_distance, n=3,
    tolerance=1.e-3,
    center=p_true + [0.05, 0.0, 0.0],
    sample_range=0.15,
    reduce_samples=0.025)
Pol = Constructor(TR, 2, basis=:legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)

TR = create_test_input(Error_distance, n=3,
    tolerance=1.e-3,
    center=p_true + [0.05, 0.0, 0.0],
    sample_range=0.15,
    reduce_samples=0.0125)
Pol = Constructor(TR, 2, basis=:legendre)
Pol.degree
res = compute_critical_points(TR, Pol, p_true, Error_distance)
sort!(res.dataframe, :eval_distance)
sort!(res.dataframe, :point_distance)