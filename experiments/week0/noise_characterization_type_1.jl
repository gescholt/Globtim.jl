# NOISE ADDED TO THE TIME-SERIES OF Y_TRUE

using Pkg
# Pkg.activate(joinpath(@__DIR__, "./../../globtim"))
# Pkg.status()
using Revise
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging, Random
using Optim, ModelingToolkit, OrdinaryDiffEq
using StaticArrays, DataStructures, LinearAlgebra
using TimerOutputs, DynamicPolynomials, HomotopyContinuation, ProgressLogging
using Distributions

using Logging; global_logger(ConsoleLogger(Logging.Error))

#######################################
# Load the DynamicalSystems.jl module

Random.seed!(42) # For reproducibility

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

#######################################
# No noise

const T = Float64

time_interval = T[0.0, 1.0]
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, log_L2_norm)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-8

bias, stddev = 0., 1e-8

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-6

bias, stddev = 0., 1e-6

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-4

bias, stddev = 0., 1e-4

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-3

bias, stddev = 0., 1e-3

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-2

bias, stddev = 0., 1e-2

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#######################################
# Noise stddev 1e-1

bias, stddev = 0., 1e-1

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);
 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

df_cheb, df_min_cheb = analyze_critical_points(
    error_func, df_cheb, TR, tol_dist=0.05);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

#=
########################################
Noise added to the time series: (stddev = 1.0e-8)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534831   0.63641    0.0587346  0.191376  0.408168  false     13.0      false
   2 │ 0.537479   0.54647   -0.299342   0.202049  0.397643  false      8.0      false
   3 │ 0.433896   0.641874  -0.253909   0.202701  0.397495  false      8.0      false
   4 │ 0.498524   0.608392  -0.173256   0.210949  0.39046   false     12.0      false
   5 │ 0.397274   0.489419  -1.20511    0.202937  0.396785  false     13.0      false
   6 │ 0.125332   0.228528  -1.78231    0.200116  0.400135  false     13.0      false
   7 │ 0.0620744  0.156522  -1.24608    0.205144  0.395624  false      7.0      false
   8 │ 0.0601269  0.309746  -1.87493    0.200127  0.399891  false      8.0      false
   9 │ 0.0945727  0.210299  -1.55608    0.20077   0.399348  false     11.0      false
  10 │ 0.364997   0.244221  -5.35125    0.197097  0.402846  false      7.0      false
  11 │ 0.204225   0.394668  -8.89838    0.199655  0.400332   true      5.0      false
  12 │ 0.144672   0.452107  -6.79658    0.197882  0.402151  false      4.0      false
  13 │ 0.431431   0.522818  -0.839356   0.201071  0.399206  false      9.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
  11 │ 0.204225  0.394668  -8.89838  0.199655  0.400332   true      5.0      false

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value    captured 
     │ Float64   Float64   Float64  Bool     
─────┼───────────────────────────────────────
   1 │ 0.408168  0.191376   -9.501      true

########################################
Noise added to the time series: (stddev = 1.0e-6)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534831   0.63641    0.0587345  0.198434  0.401132  false     13.0      false
   2 │ 0.433896   0.641874  -0.253909   0.200237  0.399708  false      7.0      false
   3 │ 0.498524   0.608392  -0.173256   0.206439  0.394     false     12.0      false
   4 │ 0.397274   0.489418  -1.20511    0.196017  0.403057  false     12.0      false
   5 │ 0.0601265  0.309746  -1.87492    0.200109  0.399832  false      8.0      false
   6 │ 0.125333   0.228528  -1.78231    0.196285  0.403918  false     12.0      false
   7 │ 0.094573   0.210298  -1.55608    0.199761  0.399801  false     10.0      false
   8 │ 0.0620743  0.156522  -1.24608    0.202976  0.397486  false      7.0      false
   9 │ 0.364997   0.244221  -5.35129    0.196977  0.402932  false      7.0      false
  10 │ 0.144664   0.452115  -6.79624    0.19763   0.40236   false      4.0      false
  11 │ 0.204238   0.394656  -8.89817    0.199505  0.400504   true      4.0      false
  12 │ 0.431431   0.522818  -0.839355   0.200421  0.39981   false      9.0      false
  13 │ 0.537479   0.54647   -0.299342   0.204651  0.395301  false      8.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
  11 │ 0.204238  0.394656  -8.89817  0.199505  0.400504   true      4.0      false

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value    captured 
     │ Float64   Float64   Float64  Bool     
─────┼───────────────────────────────────────
   1 │ 0.401132  0.198434  -10.989      true

########################################
Noise added to the time series: (stddev = 0.0001)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534819   0.636414   0.0588251  0.186034  0.413119  false     12.0      false
   2 │ 0.14382    0.452903  -6.75065    0.20032   0.399839  false      5.0      false
   3 │ 0.397361   0.489178  -1.2059     0.201671  0.398379  false      8.0      false
   4 │ 0.498507   0.608384  -0.173216   0.206041  0.393789  false     13.0      false
   5 │ 0.0600599  0.309531  -1.87368    0.211694  0.389698  false      4.0      false
   6 │ 0.433836   0.641873  -0.253986   0.201863  0.398255  false      8.0      false
   7 │ 0.125448   0.228432  -1.78276    0.202371  0.398018  false     11.0      false
   8 │ 0.0946642  0.21012   -1.55601    0.200498  0.39938   false      9.0      false
   9 │ 0.0620498  0.156541  -1.24629    0.200888  0.398923  false     10.0      false
  10 │ 0.206198   0.392815  -8.85689    0.200818  0.399189   true      8.0      false
  11 │ 0.364994   0.244168  -5.35866    0.200818  0.39919   false     11.0      false
  12 │ 0.537494   0.546452  -0.299224   0.201523  0.398442  false     11.0      false
  13 │ 0.431545   0.522779  -0.83884    0.200794  0.399376  false      8.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
  10 │ 0.206198  0.392815  -8.85689  0.200818  0.399189   true      8.0      false

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.413119  0.186034  -8.71699      true

########################################
Noise added to the time series: (stddev = 0.001)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534781   0.636429   0.0593596  0.198888  0.40067   false     14.0      false
   2 │ 0.433867   0.641839  -0.253289   0.198814  0.400733  false     12.0      false
   3 │ 0.537454   0.546604  -0.29794    0.198814  0.400733  false     12.0      false
   4 │ 0.430915   0.522369  -0.842782   0.198814  0.400733  false     13.0      false
   5 │ 0.196542   0.401416  -7.63406    0.198814  0.400733   true     12.0      false
   6 │ 0.364697   0.244124  -5.31833    0.198814  0.400733  false     14.0      false
   7 │ 0.0952902  0.210123  -1.56038    0.198814  0.400733  false     16.0      false
   8 │ 0.061764   0.156466  -1.24658    0.198814  0.400733  false     11.0      false
   9 │ 0.124367   0.227476  -1.77436    0.198814  0.400733  false     14.0      false
  10 │ 0.162885   0.433767  -7.10219    0.198814  0.400733   true     10.0      false
  11 │ 0.0597086  0.308326  -1.86702    0.198814  0.400733  false     14.0      false
  12 │ 0.39847    0.489532  -1.19603    0.198814  0.400733  false     15.0      false
  13 │ 0.498637   0.608498  -0.171593   0.198814  0.400733  false     14.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
   5 │ 0.196542  0.401416  -7.63406  0.198814  0.400733   true     12.0      false

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2       x1        value     captured 
     │ Float64  Float64   Float64   Bool     
─────┼───────────────────────────────────────
   1 │ 0.40067  0.198888  -7.75503      true

########################################
Noise added to the time series: (stddev = 0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
6×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.533182   0.635518   0.0667797  0.135683  0.450472  false     13.0      false
   2 │ 0.431668   0.643795  -0.232494   0.135683  0.450472  false     15.0      false
   3 │ 0.0580556  0.152622  -1.25731    0.135683  0.450472  false     15.0      false
   4 │ 0.337552   0.261129  -4.34025    0.135683  0.450472  false     11.0      false
   5 │ 0.502      0.611793  -0.127738   0.135683  0.450472  false     15.0      false
   6 │ 0.539386   0.54697   -0.268287   0.135683  0.450472  false     16.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
   4 │ 0.337552  0.261129  -4.34025  0.135683  0.450472  false     11.0      false

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.450472  0.135683  -4.67876     false

########################################
Noise added to the time series: (stddev = 0.1)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
1×8 DataFrame
 Row │ x1        x2        z         y1       y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64  Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────
   1 │ 0.208751  0.349557  -1.11346  1.71892  -1.67539  false     16.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1       y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64  Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────
   1 │ 0.208751  0.349557  -1.11346  1.71892  -1.67539  false     16.0      false

(after optimization)  Best critical points:
0×4 DataFrame
 Row │ x2       x1       value    captured 
     │ Float64  Float64  Float64  Bool     
─────┴─────────────────────────────────────
=#
