using Pkg
Pkg.activate("/home/user/Globtim.jl/Examples")
using ModelingToolkit
using OrdinaryDiffEq
using DataStructures
using LinearAlgebra
using StaticArrays
using SharedArrays


const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[0.11, 0.22, 0.33]
ic = T[0.11, 0.15]
num_points = 6
include("model_eval.jl")
model, params, states, outputs = define_lotka_volterra_model()
error_func = make_error_distance(model, outputs, p_true, num_points)

""" 
Test
"""

p_test = SVector(0.55, 0.048, -0.73)  # Example test parameters
error_value = error_func(p_test)
error_func([.1, .2, .3])

"""
Globtim
"""

p_center = p_true + [0.1, 0.0, 0.0]

n = 3
d = 8
Pkg.develop(path="/home/user/Globtim.jl")
using Globtim
using DynamicPolynomials
@polyvar(x[1:n]); # Define polynomial ring 

TR = test_input(error_func,
    dim=n,
    center=p_true,
    GN=10,
    sample_range=1//10
);

# Chebyshev 
pol_cheb = Constructor(TR, d, basis=:chebyshev);
msolve_polynomial_system(pol_cheb, x; n=3, basis=:chebyshev, bigint=true);
df_cheb = msolve_parser("outputs.ms", error_func, TR)

# Legendre
pol_lege = Constructor(TR, d, basis=:legendre);
msolve_polynomial_system(pol_lege, x; n=3, basis=:legendre, bigint=true);
df_lege = msolve_parser("outputs.ms", error_func, TR)



# using GLMakie

# include("Visual.jl")
# """What do we want to achieve here?"""