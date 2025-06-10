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

reset_timer!(Globtim._TO)

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
println("No noise:")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#######################################
# Noise stddev 1e-2

reset_timer!(Globtim._TO)
bias, stddev = 0., 1e-2

add_noise_in_time_series = (Y_true) -> begin
    noise = rand(Normal(bias, stddev), length(Y_true))
    Y_true = Y_true .+ noise
end

num_points = 80     # 20
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    log_L2_norm,
    add_noise_in_time_series)

n = 2
d = 12                # 9
GN = 120              # 40
sample_range = 0.25  # 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.01, 0.01]
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
    error_func, df_cheb, TR, tol_dist=0.05, 
    max_iters_in_optim=200);

println("########################################")
println("Noise added to the time series: (stddev = $stddev)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#=
########################################
PARAMS:
n = 2
d = 9                # 9
GN = 160             # 40
sample_range = 0.25  # 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.01, 0.01]

Noise added to the time series: (stddev = 0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
7×8 DataFrame
 Row │ x1           x2        z          y1        y2        close  steps    converged 
     │ Float64      Float64   Float64    Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────
   1 │  0.443114    0.649715  -0.197256  0.148834  0.451397  false     11.0       true
   2 │  0.00533067  0.296949  -1.51562   0.148834  0.451397  false     36.0       true
   3 │  0.0706154   0.239096  -1.54259   0.148834  0.451397  false     38.0       true
   4 │ -0.00619283  0.284065  -1.41971   0.148834  0.451397  false     14.0       true
   5 │ -0.0257223   0.170986  -1.01553   0.148834  0.451397  false      9.0       true
   6 │  0.0393008   0.221063  -1.35482   0.148834  0.451397  false     11.0       true
   7 │  0.234857    0.366142  -4.61816   0.148834  0.451397  false     36.0       true

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
   7 │ 0.234857  0.366142  -4.61816  0.148834  0.451397  false     36.0       true

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.451397  0.148834  -4.73891     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 247s /  99.9%           57.9GiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1     225s   91.0%    225s   53.5GiB   92.4%  53.5GiB
  MainGenerate                      1     225s   91.0%    225s   53.5GiB   92.4%  53.5GiB
    evaluation                      1     220s   89.0%    220s   42.4GiB   73.3%  42.4GiB
    norm_computation                1    4.83s    2.0%   4.83s   11.1GiB   19.1%  11.1GiB
    lambda_vandermonde              1   53.3ms    0.0%  53.3ms   11.1MiB    0.0%  11.1MiB
    generate_grid                   1   44.7ms    0.0%  44.7ms   13.1MiB    0.0%  13.1MiB
    linear_solve_vandermonde        1   1.94ms    0.0%  1.94ms   27.3KiB    0.0%  27.3KiB
analyze_critical_points             1    19.4s    7.9%   19.4s   4.14GiB    7.2%  4.14GiB
solve_polynomial_system             1    2.71s    1.1%   2.71s    245MiB    0.4%   245MiB
test_input                          1    654ns    0.0%   654ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
n = 2
d = 9                # 9
GN = 300             # 40
sample_range = 0.25  # 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.01, 0.01]

Noise added to the time series: (stddev = 0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
7×8 DataFrame
 Row │ x1           x2        z          y1        y2        close  steps    converged 
     │ Float64      Float64   Float64    Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────
   1 │  0.443114    0.649715  -0.197256  0.148834  0.451397  false     17.0       true
   2 │  0.00533067  0.296949  -1.51562   0.148834  0.451397  false     26.0       true
   3 │  0.0706154   0.239096  -1.54259   0.148834  0.451397  false     15.0       true
   4 │ -0.00619283  0.284065  -1.41971   0.148834  0.451397  false     37.0       true
   5 │ -0.0257223   0.170986  -1.01553   0.148834  0.451397  false     26.0       true
   6 │  0.0393008   0.221063  -1.35482   0.148834  0.451397  false     55.0       true
   7 │  0.234857    0.366142  -4.61816   0.148834  0.451397  false     19.0       true

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
   7 │ 0.234857  0.366142  -4.61816  0.148834  0.451397  false     19.0       true

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.451397  0.148834  -4.73891     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                1244s / 100.0%            281GiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    1202s   96.6%   1202s    276GiB   98.0%   276GiB
  MainGenerate                      1    1202s   96.6%   1202s    276GiB   98.0%   276GiB
    evaluation                      1     909s   73.1%    909s    148GiB   52.7%   148GiB
    norm_computation                1     292s   23.5%    292s    127GiB   45.3%   127GiB
    lambda_vandermonde              1    209ms    0.0%   209ms   38.8MiB    0.0%  38.8MiB
    generate_grid                   1    191ms    0.0%   191ms   45.6MiB    0.0%  45.6MiB
    linear_solve_vandermonde        1   15.1ms    0.0%  15.1ms   2.64MiB    0.0%  2.64MiB
analyze_critical_points             1    38.7s    3.1%   38.7s   5.29GiB    1.9%  5.29GiB
solve_polynomial_system             1    3.71s    0.3%   3.71s    245MiB    0.1%   245MiB
test_input                          1    599ns    0.0%   599ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
n = 2
d = 12                # 9
GN = 120              # 40
sample_range = 0.25  # 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.01, 0.01]

Noise added to the time series: (stddev = 0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
9×8 DataFrame
 Row │ x1          x2        z          y1        y2        close  steps    converged 
     │ Float64     Float64   Float64    Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │  0.452708   0.653595  -0.147506  0.148834  0.451397  false     33.0       true
   2 │  0.386892   0.645466  -0.421603  0.148834  0.451397  false     37.0       true
   3 │  0.444882   0.594335  -0.439478  0.148834  0.451397  false     14.0       true
   4 │  0.397396   0.613397  -0.534974  0.148834  0.451397  false     29.0       true
   5 │  0.370474   0.634702  -0.53841   0.148834  0.451397  false     13.0       true
   6 │  0.433435   0.580058  -0.552181  0.148834  0.451397  false     30.0       true
   7 │ -0.0326785  0.163581  -0.980389  0.148834  0.451397  false     15.0       true
   8 │  0.306888   0.304041  -4.48728   0.148834  0.451397  false     17.0       true
   9 │  0.420714   0.630139  -0.365369  0.148834  0.451397  false     24.0       true

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        z         y1        y2        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────
   8 │ 0.306888  0.304041  -4.48728  0.148834  0.451397  false     17.0       true

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.451397  0.148834  -4.73891     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 190s /  99.9%           33.5GiB /  99.9%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1     150s   79.0%    150s   27.5GiB   82.3%  27.5GiB
  MainGenerate                      1     150s   79.0%    150s   27.5GiB   82.3%  27.5GiB
    evaluation                      1     147s   77.5%    147s   24.0GiB   71.6%  24.0GiB
    norm_computation                1    2.88s    1.5%   2.88s   3.58GiB   10.7%  3.58GiB
    lambda_vandermonde              1   50.7ms    0.0%  50.7ms   10.3MiB    0.0%  10.3MiB
    generate_grid                   1   24.2ms    0.0%  24.2ms   7.40MiB    0.0%  7.40MiB
    linear_solve_vandermonde        1   1.47ms    0.0%  1.47ms    100KiB    0.0%   100KiB
analyze_critical_points             1    36.1s   19.0%   36.1s   5.60GiB   16.7%  5.60GiB
solve_polynomial_system             1    3.84s    2.0%   3.84s    319MiB    0.9%   319MiB
test_input                          1    581ns    0.0%   581ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────


########################################
n = 2
d = 12                # 9
GN = 120              # 40
sample_range = 0.25  # 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.01, 0.01]

Noise added to the time series: (stddev = 0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
9×8 DataFrame
 Row │ x1          x2        z           y1        y2        close  steps    converged 
     │ Float64     Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────
   1 │  0.452834   0.653535   0.801452   0.237814  0.366522  false     15.0       true
   2 │  0.384185   0.642937   0.506959   0.237814  0.366522  false     18.0       true
   3 │  0.0870219  0.506715  -3.34662    0.237814  0.366522  false      7.0       true
   4 │  0.375595   0.636715   0.443874   0.237814  0.366522  false      9.0       true
   5 │  0.420201   0.628224   0.575633   0.237814  0.366522  false     27.0       true
   6 │ -0.0341811  0.163832  -0.0172383  0.237814  0.366522  false     20.0       true
   7 │  0.434027   0.58122    0.411722   0.237814  0.366522  false     12.0       true
   8 │  0.443851   0.593813   0.508611   0.237814  0.366522  false     14.0       true
   9 │  0.399697   0.614205   0.431693   0.237814  0.366522  false     21.0       true

(before optimization) Best critical points:
DataFrameRow
 Row │ x1         x2        z         y1        y2        close  steps    converged 
     │ Float64    Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼──────────────────────────────────────────────────────────────────────────────
   3 │ 0.0870219  0.506715  -3.34662  0.237814  0.366522  false      7.0       true

(after optimization)  Best critical points:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.366522  0.237814  -3.52651     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 172s /  99.9%           32.0GiB /  99.9%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1     143s   83.2%    143s   27.7GiB   86.7%  27.7GiB
  MainGenerate                      1     143s   83.2%    143s   27.7GiB   86.7%  27.7GiB
    evaluation                      1     140s   81.5%    140s   24.1GiB   75.5%  24.1GiB
    norm_computation                1    2.76s    1.6%   2.76s   3.58GiB   11.2%  3.58GiB
    lambda_vandermonde              1   51.9ms    0.0%  51.9ms   10.3MiB    0.0%  10.3MiB
    generate_grid                   1   25.7ms    0.0%  25.7ms   7.40MiB    0.0%  7.40MiB
    linear_solve_vandermonde        1   1.73ms    0.0%  1.73ms    100KiB    0.0%   100KiB
analyze_critical_points             1    25.1s   14.6%   25.1s   3.93GiB   12.3%  3.93GiB
solve_polynomial_system             1    3.76s    2.2%   3.76s    317MiB    1.0%   317MiB
test_input                          1    650ns    0.0%   650ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────
=#
