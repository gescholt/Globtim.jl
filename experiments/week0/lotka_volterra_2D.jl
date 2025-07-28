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
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points)

#

p_test = SVector(0.2, 0.5)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")

#

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 2
d = 2 # [2,2]
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring
p_center = p_true + [0.10, 0.0]
TR =
    test_input(error_func, dim = n, center = p_center, GN = GN, sample_range = sample_range);

# Chebyshev
pol_cheb =
    Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision, verbose = true)
real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis = pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

# println(df_cheb)
@info "" df_cheb

# df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist=0.05);

@info "" df_cheb

Globtim._TO

#=
Example output:
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                14.7s /  99.7%           2.80GiB /  99.8%

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    14.6s   99.8%   14.6s   2.80GiB   99.9%  2.80GiB
  MainGenerate                      1    14.6s   99.8%   14.6s   2.80GiB   99.9%  2.80GiB
    evaluation                      1    14.6s   99.3%   14.6s   2.75GiB   98.2%  2.75GiB
    lambda_vandermonde              1   3.31ms    0.0%  3.31ms    757KiB    0.0%   757KiB
    generate_grid_small_n           1   2.79ms    0.0%  2.79ms    868KiB    0.0%   868KiB
    linear_solve_vandermonde        1    720μs    0.0%   720μs   84.7KiB    0.0%  84.7KiB
solve_polynomial_system             1   31.2ms    0.2%  31.2ms   4.22MiB    0.1%  4.22MiB
test_input                          1    477ns    0.0%   477ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────
=#

#=
println(df_min_cheb)
@info "" df_min_cheb

grid = TR.sample_range * generate_grid(n, GN, basis=:chebyshev);
new_grid = map(x -> x + p_center, grid);
values = map(error_func, grid); # Prepare level set data for specific level

using GLMakie
# fig = Globtim.create_level_set_visualization(error_func, new_grid, df_cheb, (0., 1000.))
fig = Globtim.plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig)
=#
