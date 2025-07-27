#

using Pkg
# Pkg.activate(joinpath(@__DIR__, "./../../globtim"))
# Pkg.status()
using Revise
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using ModelingToolkit
using OrdinaryDiffEq
using StaticArrays
using DataStructures
using LinearAlgebra
using TimerOutputs

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

reset_timer!(Globtim._TO)

#

const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[0.2, 0.4, 0.7]
ic = T[0.3, 0.6]
num_points = 20
distance = log_L2_norm
model, params, states, outputs = define_lotka_volterra_3D_model()
error_func =
    make_error_distance(model, outputs, ic, p_true, time_interval, num_points, distance)

#

p_test = SVector(0.2, 0.5, 0.8)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")

#

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 3
d = 11
GN = 150
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring
p_center = p_true + [0.10, 0.0, 0.0]
TR =
    test_input(error_func, dim = n, center = p_center, GN = GN, sample_range = sample_range);

# Chebyshev
# @profview
pol_cheb =
    Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision, verbose = true)
real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis = pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)
# df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Lotka-Volterra 3D model with Chebyshev basis")
println("Configuration:")
println("n = ", n)
println("d = ", d)
println("GN = ", GN)
println("sample_range = ", sample_range)
println("p_true = ", p_true)
println("p_center = ", p_center)
println("Distance function: ", distance)
println("Condition number of the polynomial system: ", pol_cheb.cond_vandermonde)
println("L2 norm (error of approximation): ", pol_cheb.nrm)
println("Critical points found:\n", df_cheb)
println(
    "\n(before optimization) Best critical points:\n",
    df_cheb[
        findmin(
            map(
                p -> abs(sum((p .- p_true) .^ 2)),
                zip([getproperty(df_cheb, Symbol(:x, i)) for i = 1:n]...),
            ),
        )[2],
        :,
    ],
)
# println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#=

=#
