# NOISE ADDED TO THE ERROR FUNCTION

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
println("No noise:")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("Best critical points after optimization:\n", df_min_cheb)

#######################################
# Noise added to error function

noise = 1e-2

model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    (y_true, y_pred) -> log_L2_norm(y_true, y_pred) + noise * rand((-1,1)) * rand(Float64))

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
println("Noise added to the error function: ($noise)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("Best critical points after optimization:\n", df_min_cheb)

#######################################
# Noise added to error function

noise = 1e-1

model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    (y_true, y_pred) -> log_L2_norm(y_true, y_pred) + noise * rand((-1,1)) * rand(Float64))

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
println("Noise added to the error function: ($noise)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("Best critical points after optimization:\n", df_min_cheb)

#######################################
# Noise added to error function

noise = 1e-0

model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    (y_true, y_pred) -> log_L2_norm(y_true, y_pred) + noise * rand((-1,1)) * rand(Float64))

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
println("Noise added to the error function: ($noise)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("Best critical points after optimization:\n", df_min_cheb)

#######################################
# Noise added to error function

noise = 1e+1

model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points, 
    (y_true, y_pred) -> log_L2_norm(y_true, y_pred) + noise * rand((-1,1)) * rand(Float64))

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
println("Noise added to the error function: ($noise)")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Critical points found:\n", df_cheb)
println("Best critical points after optimization:\n", df_min_cheb)

#=
########################################
No noise:
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1        y2        close  steps    converged 
     │ Float64    Float64   Float64     Float64   Float64   Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534831   0.63641    0.0587346  0.200382  0.399847  false     14.0      false
   2 │ 0.537479   0.54647   -0.299342   0.201127  0.398462  false      8.0      false
   3 │ 0.431431   0.522818  -0.839356   0.201056  0.399221  false      9.0      false
   4 │ 0.144672   0.452108  -6.79657    0.19788   0.402153  false      4.0      false
   5 │ 0.364997   0.244221  -5.35125    0.197097  0.402845  false      7.0      false
   6 │ 0.204225   0.394668  -8.89838    0.199652  0.400335   true      5.0      false
   7 │ 0.0620744  0.156522  -1.24608    0.204043  0.396198  false      7.0      false
   8 │ 0.0945727  0.210299  -1.55608    0.199412  0.400785  false     11.0      false
   9 │ 0.125332   0.228528  -1.78231    0.198901  0.401297  false     13.0      false
  10 │ 0.0601269  0.309746  -1.87493    0.203166  0.396992  false      7.0      false
  11 │ 0.498524   0.608392  -0.173256   0.209511  0.392008  false     12.0      false
  12 │ 0.433896   0.641874  -0.253909   0.202827  0.397408  false      8.0      false
  13 │ 0.397274   0.489419  -1.20511    0.203704  0.396105  false     13.0      false
Best critical points after optimization:
1×4 DataFrame
 Row │ x2        x1        value     captured 
     │ Float64   Float64   Float64   Bool     
─────┼────────────────────────────────────────
   1 │ 0.399847  0.200382  -11.7982      true


########################################
Noise added to the error function: (0.01)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1          y2          close  steps    converged 
     │ Float64    Float64   Float64     Float64     Float64     Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534899   0.636326   0.0683851  -0.172816   -0.203144   false      2.0      false
   2 │ 0.53756    0.546329  -0.294617    0.538251    0.546201    true      2.0      false
   3 │ 0.43385    0.641899  -0.259676   -0.060197    0.639759   false      4.0      false
   4 │ 0.498551   0.608325  -0.168894    0.523879    0.088901   false      3.0      false
   5 │ 0.397236   0.489254  -1.19669     0.397236    0.489254    true      1.0       true
   6 │ 0.125386   0.228595  -1.78371     0.125386    0.228595    true      1.0      false
   7 │ 0.0620772  0.156443  -1.2532      0.491149    0.0869599  false      5.0      false
   8 │ 0.0943779  0.210601  -1.54856     0.408637    0.340422   false      2.0       true
   9 │ 0.365593   0.243596  -5.35503     0.366119    0.243661    true      2.0      false
  10 │ 0.0599897  0.309634  -1.87071     0.0612643   0.305712    true      2.0      false
  11 │ 0.20454    0.394321  -8.83142     0.205709    0.394709    true      5.0      false
  12 │ 0.144503   0.45227   -6.78922     0.14409     0.451538    true      2.0      false
  13 │ 0.431751   0.522517  -0.840228    0.432594    0.522106    true      2.0       true
Best critical points after optimization:
8×4 DataFrame
 Row │ x2        x1         value       captured 
     │ Float64   Float64    Float64     Bool     
─────┼───────────────────────────────────────────
   1 │ 0.546201  0.538251    -0.306625      true
   2 │ 0.489254  0.397236    -1.20201       true
   3 │ 0.228595  0.125386    -1.78079       true
   4 │ 0.340422  0.408637    -2.32813      false
   5 │ 0.243661  0.366119    -5.34793       true
   6 │ 0.305712  0.0612643   -1.86749       true
   7 │ 0.394709  0.205709   -10.1539        true
   8 │ 0.451538  0.14409     -6.83671       true

########################################
Noise added to the error function: (0.1)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
13×8 DataFrame
 Row │ x1         x2        z           y1          y2         close  steps    converged 
     │ Float64    Float64   Float64     Float64     Float64    Bool   Float64  Bool      
─────┼───────────────────────────────────────────────────────────────────────────────────
   1 │ 0.53415    0.636964   0.0789786   0.53415     0.636964   true      1.0      false
   2 │ 0.537531   0.545407  -0.37152     0.518552    0.508783   true      6.0       true
   3 │ 0.430338   0.5246    -0.891018   -0.50163     0.981784  false      4.0      false
   4 │ 0.145737   0.451263  -6.77238     0.14583     0.451362   true      3.0       true
   5 │ 0.205182   0.394305  -9.3122      0.205254    0.395154   true      4.0      false
   6 │ 0.0606008  0.307669  -1.91086     0.413125    0.195055  false      3.0      false
   7 │ 0.356975   0.251707  -5.50492     0.343701    0.256336   true      2.0      false
   8 │ 0.0986809  0.206926  -1.53303     0.136156    0.624397  false      3.0      false
   9 │ 0.0627973  0.157001  -1.24409     0.0627973   0.157001   true      1.0       true
  10 │ 0.126407   0.228283  -1.70791     0.467523    0.126559  false      5.0      false
  11 │ 0.388067   0.496339  -1.25699     0.388063    0.496346   true      2.0       true
  12 │ 0.437805   0.641202  -0.192896   -1.22997     1.63058   false      3.0      false
  13 │ 0.500041   0.607592  -0.230082    0.19522    -0.785733  false      2.0      false
Best critical points after optimization:
9×4 DataFrame
 Row │ x2        x1         value       captured 
     │ Float64   Float64    Float64     Bool     
─────┼───────────────────────────────────────────
   1 │ 0.636964  0.53415      0.096822      true
   2 │ 0.508783  0.518552    -0.534636      true
   3 │ 0.451362  0.14583     -6.75277       true
   4 │ 0.395154  0.205254   -10.3334        true
   5 │ 0.195055  0.413125    -4.95247      false
   6 │ 0.256336  0.343701    -5.47905       true
   7 │ 0.624397  0.136156    -1.98402      false
   8 │ 0.157001  0.0627973   -1.17524       true
   9 │ 0.496346  0.388063    -1.24595       true

########################################
Noise added to the error function: (1.0)
Lotka-Volterra 2D model with Chebyshev basis
Critical points found:
16×8 DataFrame
 Row │ x1         x2        z          y1             y2             close  steps    converged 
     │ Float64    Float64   Float64    Float64        Float64        Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.534145   0.631084   0.523903       0.534145       0.631084   true      1.0      false
   2 │ 0.339837   0.586764  -0.871339       0.339863       0.58681    true      2.0      false
   3 │ 0.495921   0.604839   0.473331       0.495921       0.60484    true      1.0      false
   4 │ 0.375995   0.572039  -1.06253        0.281814       0.177742  false      2.0      false
   5 │ 0.165894   0.423802  -6.04273        0.165224       0.423859   true      2.0      false
   6 │ 0.101225   0.489704  -5.57006        0.108433       0.481731   true      2.0      false
   7 │ 0.462865   0.500226  -1.79819        0.222647       0.331905  false      2.0      false
   8 │ 0.227464   0.370437  -6.32725        0.227464       0.370437   true      2.0      false
   9 │ 0.297468   0.317954  -6.46531        0.297732       0.318305   true      5.0      false
  10 │ 0.100193   0.234919  -1.48849       -0.190948       0.900621  false      3.0      false
  11 │ 0.385911   0.221424  -6.066          0.393864       0.221865   true      3.0      false
  12 │ 0.0501418  0.178372  -0.584835       0.231382       0.374602  false      4.0      false
  13 │ 0.123925   0.234667  -2.69429        3.42309       -8.09309   false      3.0      false
  14 │ 0.421488   0.468351  -0.738885       0.523705       0.503087  false      3.0      false
  15 │ 0.420766   0.635989   0.198107  -65111.2       -22885.2       false      3.0      false
  16 │ 0.539898   0.552238  -0.656664       2.18687       -2.46993   false      3.0      false
Best critical points after optimization:
9×4 DataFrame
 Row │ x2        x1        value      captured 
     │ Float64   Float64   Float64    Bool     
─────┼─────────────────────────────────────────
   1 │ 0.631084  0.534145  -0.525804      true
   2 │ 0.58681   0.339863  -1.58678       true
   3 │ 0.177742  0.281814  -3.47315      false
   4 │ 0.423859  0.165224  -7.2851        true
   5 │ 0.481731  0.108433  -6.96325       true
   6 │ 0.331905  0.222647  -4.91037       true
   7 │ 0.318305  0.297732  -6.64427       true
   8 │ 0.221865  0.393864  -5.25768       true
   9 │ 0.503087  0.523705   0.242808     false

Critical points found:
26×8 DataFrame
 Row │ x1         x2        z           y1               y2               close  steps    converged 
     │ Float64    Float64   Float64     Float64          Float64          Bool   Float64  Bool      
─────┼──────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.522369   0.649374    2.82379        -0.880937         2.05339    false      4.0      false
   2 │ 0.445625   0.620583   -6.98815        -1.50424e5       -8.92706e5  false      4.0      false
   3 │ 0.0562537  0.6237     -7.80485         0.0562537        0.6237      true      1.0      false
   4 │ 0.156588   0.631223   -3.78972         0.156588         0.631223    true      1.0       true
   5 │ 0.330461   0.627511    0.760551        0.330461         0.627511    true      2.0       true
   6 │ 0.525989   0.520518    1.26194        10.2552          -4.916      false      3.0      false
   7 │ 0.432357   0.565567   -1.42695         0.475928         0.686094   false      2.0      false
   8 │ 0.493433   0.485302    0.430139   -11019.6            971.631      false      2.0      false
   9 │ 0.517252   0.57853    -2.95248        -8.10509e5       -2.62677e5  false      2.0      false
  10 │ 0.532197   0.391789   -8.20572         1.78798         -0.190048   false      2.0      false
  11 │ 0.238856   0.616423   -2.70456        -4.64601e5   -77599.8        false      4.0      false
  12 │ 0.0897053  0.27397   -10.9274          0.281698         0.325406   false      4.0      false
  13 │ 0.0615556  0.268023   -0.676985        0.117639         0.092593   false      2.0      false
  14 │ 0.530085   0.163114   -6.92236    -11987.7         -18368.1        false      4.0      false
  15 │ 0.248909   0.166816   -2.04431       NaN              NaN          false     -1.0      false
  16 │ 0.141016   0.167215   -2.51818       NaN              NaN          false     -1.0      false
  17 │ 0.414174   0.162853  -10.7024        NaN              NaN          false     -1.0      false
  18 │ 0.445105   0.212691    4.70728    -17610.9           6344.35       false      4.0      false
  19 │ 0.0772213  0.201789   -9.10726        -2.74291e5   119211.0        false      3.0      false
  20 │ 0.0647559  0.205815    0.256757  -624158.0        -169487.0        false      4.0      false
  21 │ 0.203447   0.395348   -3.38523         0.196514         0.424191    true      2.0      false
  22 │ 0.358639   0.3817     -8.48842         0.45295          0.163527   false      2.0      false
  23 │ 0.537399   0.514476   -5.63669        -1.18621e6       -3.95402e6  false      5.0      false
  24 │ 0.0940828  0.630258  -11.0461         -4.13549e5        1.43077e5  false      5.0      false
  25 │ 0.0779039  0.550114  -12.4152         -0.058073         0.770527   false      2.0      false
  26 │ 0.138127   0.492225   -9.38988         1.51406          0.0181066  false      3.0      false

julia> println("Best critical points after optimization:\n", df_min_cheb)
Best critical points after optimization:
6×4 DataFrame
 Row │ x2        x1         value      captured 
     │ Float64   Float64    Float64    Bool     
─────┼──────────────────────────────────────────
   1 │ 0.6237    0.0562537    3.8679       true
   2 │ 0.631223  0.156588   -10.3957       true
   3 │ 0.627511  0.330461     3.24215      true
   4 │ 0.325406  0.281698   -14.3494      false
   5 │ 0.424191  0.196514    -4.27996      true
   6 │ 0.163527  0.45295    -14.0588       true
=#
