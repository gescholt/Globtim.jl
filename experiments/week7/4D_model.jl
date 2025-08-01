using Pkg; Pkg.activate(@__DIR__)

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
using Makie
using GLMakie

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

reset_timer!(Globtim._TO)

const T = Float64

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging

config = (
    n = 4,
    d = (:one_d_for_all, 18),
    GN = 30,
    time_interval = T[0.0, 10.0],
    p_true = [[0.2, 0.3, 0.5, 0.6]],
    ic = [1.0, 2.0, 1.0, 1.0],
    num_points = 25,
    sample_range = 0.1,
    distance = L2_norm,
    model_func = define_daisy_ex3_model_4D,
    basis = :chebyshev,
    precision = RationalPrecision,
)
config = merge(
    config,
    (;
        p_center = [config.p_true[1][1] + 0.05, config.p_true[1][2] - 0.05, config.p_true[1][3] - 0.05, config.p_true[1][4] - 0.05],
    ),
)

model, params, states, outputs = config.model_func()

error_func = make_error_distance(
    model,
    outputs,
    config.ic,
    config.p_true[1],
    config.time_interval,
    config.num_points,
    config.distance
)

@polyvar(x[1:config.n]); # Define polynomial ring
TR = test_input(
    error_func,
    dim = config.n,
    center = config.p_center,
    GN = config.GN,
    sample_range = config.sample_range
);

pol_cheb = Constructor(
    TR,
    config.d,
    basis = config.basis,
    precision = config.precision,
    verbose = true
)
real_pts_cheb, (wd_in_std_basis, _sys, _nsols) = solve_polynomial_system(
    x,
    config.n,
    config.d,
    pol_cheb.coeffs;
    basis = pol_cheb.basis,
    return_system = true
)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

@info "" sort(df_cheb, [:z])

id = "4D_d18"
filename = "$(id)_$(config.model_func)_$(config.distance)"

open(joinpath(@__DIR__, "images", "$(filename).txt"), "w") do io
    println(io, "config = ", config, "\n\n")
    println(io, "Condition number of the Vandermonde system: ", pol_cheb.cond_vandermonde)
    println(io, "L2 norm (error of approximation): ", pol_cheb.nrm)
    println(io, "Polynomial system:")
    println(io, "   Number of sols: ", _nsols)
    println(
        io,
        "   Bezout bound: ",
        map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys),
        " which is ",
        prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys))
    )
    println(io, "Critical points found:\n", df_cheb)
    if !isempty(df_cheb)
        println(io, "Number of critical points: ", nrow(df_cheb))
    else
        println(io, "No critical points found.")
    end
    println(io, Globtim._TO)
end

println(Globtim._TO)

df_enhanced, df_min = analyze_critical_points(error_func, df_cheb, TR, enable_hessian=true)

#=

julia> df_cheb
25×25 DataFrame
 Row │ x1        x2        x3        x4        z           y1        y2           y3        y4        close  steps    converged  region_id  function_value_cluster  nearest_neighbor_dist  gradie ⋯
     │ Float64   Float64   Float64   Float64   Float64     Float64   Float64      Float64   Float64   Bool   Float64  Bool       Int64      Int64                   Float64                Float6 ⋯
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.206496  0.27641   0.430588  0.580888     62.3053  0.249789   0.00149995  0.447162  0.785071  false      7.0      false        442                       2             0.18152            ⋯
   2 │ 0.342911  0.184315  0.505572  0.4919    11639.6     0.594755  -1.67963     0.374707  1.99138   false     12.0      false        205                       5             0.0164526
   3 │ 0.323317  0.160842  0.53673   0.450621  12811.7     0.643318   0.325772    0.652131  1.06104   false     11.0      false        105                       1             0.0228014
   4 │ 0.347087  0.181503  0.545203  0.474367  12492.3     0.347989  -0.242246    0.441915  1.00163   false      9.0      false        105                       1             0.00487224
   5 │ 0.338197  0.179121  0.519028  0.485541  11915.4     0.244178   0.145926    0.478199  0.713498  false      8.0      false        105                       5             0.0164526          ⋯
   6 │ 0.330155  0.163794  0.515435  0.497422  11653.0     0.485013  -0.545557    0.45171   1.29271   false      9.0      false        230                       5             0.00929097
   7 │ 0.309974  0.15337   0.547209  0.469138  12418.6     0.290315   0.0610751   0.481751  0.802043  false     10.0      false        104                       1             0.0127642
   8 │ 0.303459  0.151874  0.54259   0.459295  12520.7     0.248531   0.175739    0.494097  0.70849   false      5.0      false        104                       1             0.00270648
   9 │ 0.311853  0.174241  0.473868  0.461983  11697.9     0.515794  -1.60926     0.356842  1.87983   false     12.0      false         80                       5             0.0160877          ⋯
  10 │ 0.297202  0.167654  0.472983  0.461996  11543.6     0.59697   -0.848846    0.449804  1.55689   false     11.0      false         79                       3             0.0160877
  11 │ 0.349059  0.228028  0.545166  0.456486  12443.6     0.36271   -0.473021    0.420255  1.13525   false     12.0      false        110                       1             0.0029011
  12 │ 0.345289  0.153441  0.547342  0.452764  13157.9     0.453202  -0.100437    0.51315   1.04756   false     12.0      false        105                       4             0.0255885
  13 │ 0.251109  0.175934  0.52967   0.458605  11383.0     0.659084  -0.0516641   0.578795  1.23746   false     14.0      false        103                       3             0.0250431          ⋯
  14 │ 0.27471   0.175074  0.521501  0.456974  11731.8     0.40293   -0.0765714   0.498529  0.983342  false     13.0      false        104                       5             0.0250431
  15 │ 0.334385  0.17615   0.519873  0.451758  12644.7     0.274951   0.0638255   0.470729  0.781873  false      8.0      false        105                       1             0.0144909
  16 │ 0.326016  0.155482  0.546138  0.474537  12480.4     0.267375   0.0953564   0.474311  0.75943   false      8.0      false        105                       1             0.0170908
  17 │ 0.302807  0.196849  0.476597  0.45749   11423.9     0.598485  -0.546084    0.480441  1.40281   false     14.0      false         84                       3             0.00247766         ⋯
  18 │ 0.347197  0.173637  0.520951  0.457953  12704.3     0.242277   0.249205    0.502634  0.665462  false      8.0      false        105                       1             0.0144909
  19 │ 0.325261  0.218709  0.546393  0.450848  12356.7     0.370491  -0.313824    0.446884  1.06409   false     12.0      false        110                       1             0.0262007
  20 │ 0.330184  0.172078  0.511901  0.499703  11464.2     0.489658  -0.217326    0.507329  1.14156   false     10.0      false        230                       3             0.00929097
  21 │ 0.304898  0.197813  0.475992  0.456804  11456.6     0.531203  -1.24415     0.381019  1.6919    false     16.0      false         84                       3             0.00247766         ⋯
  22 │ 0.298931  0.150265  0.546651  0.454702  12608.4     0.30275   -0.238715    0.429874  0.957171  false     10.0      false        104                       1             0.00690936
  23 │ 0.34914   0.228622  0.54451   0.459247  12373.8     0.52662   -0.833442    0.430134  1.47948   false     11.0      false        110                       1             0.0029011
  24 │ 0.304146  0.152435  0.543293  0.456836  12581.5     0.314368  -0.820633    0.348848  1.26214   false     12.0      false        104                       1             0.00270648
  25 │ 0.347523  0.179125  0.546253  0.478465  12444.0     0.351563  -0.332655    0.429944  1.05023   false      9.0      false        105                       1             0.00487224         ⋯
                                                                                                                                                                                 10 columns omitted


────────────────────────────────────────────────────────────────────────────────────────────
                                                   Time                    Allocations      
                                          ───────────────────────   ────────────────────────
            Tot / % measured:                  3598s / 100.0%            121GiB / 100.0%    

Section                           ncalls     time    %tot     avg     alloc    %tot      avg
────────────────────────────────────────────────────────────────────────────────────────────
solve_polynomial_system                1    2902s   80.7%   2902s   44.3GiB   36.6%  44.3GiB
Constructor                            1     696s   19.3%    696s   76.7GiB   63.4%  76.7GiB
  MainGenerate                         1     696s   19.3%    696s   76.7GiB   63.4%  76.7GiB
    lambda_vandermonde_original        1     408s   11.3%    408s   41.2GiB   34.0%  41.2GiB
    evaluation                         1    83.1s    2.3%   83.1s   33.7GiB   27.8%  33.7GiB
    linear_solve_vandermonde           1    6.30s    0.2%   6.30s    274MiB    0.2%   274MiB
    norm_computation                   1    5.36s    0.1%   5.36s    411MiB    0.3%   411MiB
    generate_grid                      1    1.52s    0.0%   1.52s    527MiB    0.4%   527MiB
test_input                             1   1.01μs    0.0%  1.01μs      272B    0.0%     272B
────────────────────────────────────────────────────────────────────────────────────────────
=#
