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
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points,
    distance)

# 

p_test = SVector(0.2, .5, 0.8)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")

#

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 3
d = 11
GN = 60
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);

# Chebyshev 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)
df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist=0.05);

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
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#=
########################################
Lotka-Volterra 3D model with Chebyshev basis
Configuration:
n = 3
d = 4
GN = 10
sample_range = 0.25
p_true = [0.2, 0.4, 0.7]
p_center = [0.30000000000000004, 0.4, 0.7]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000014
L2 norm (error of approximation): 2.1458048425944027
Critical points found:
1×10 DataFrame
 Row │ x1        x2        x3        z          y1        y2        y3       close  steps    converged 
     │ Float64   Float64   Float64   Float64    Float64   Float64   Float64  Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.538836  0.561903  0.487104  -0.588186  0.116121  0.537693  0.47558  false      8.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        x3        z          y1        y2        y3       close  steps    converged 
     │ Float64   Float64   Float64   Float64    Float64   Float64   Float64  Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.538836  0.561903  0.487104  -0.588186  0.116121  0.537693  0.47558  false      8.0      false

(after optimization)  Best critical points:
1×5 DataFrame
 Row │ x3       x2        x1        value     captured 
     │ Float64  Float64   Float64   Float64   Bool     
─────┼─────────────────────────────────────────────────
   1 │ 0.47558  0.537693  0.116121  -9.67196     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                20.0s /  98.5%           3.12GiB /  99.6%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    13.1s   66.9%   13.1s   2.27GiB   73.0%  2.27GiB
  MainGenerate                      1    13.1s   66.9%   13.1s   2.27GiB   73.0%  2.27GiB
    evaluation                      1    13.1s   66.7%   13.1s   2.24GiB   72.1%  2.24GiB
    norm_computation                1   35.4ms    0.2%  35.4ms   27.5MiB    0.9%  27.5MiB
    lambda_vandermonde              1   2.00ms    0.0%  2.00ms    398KiB    0.0%   398KiB
    generate_grid                   1   1.89ms    0.0%  1.89ms    698KiB    0.0%   698KiB
    linear_solve_vandermonde        1    547μs    0.0%   547μs   12.7KiB    0.0%  12.7KiB
analyze_critical_points             1    3.32s   16.9%   3.32s    641MiB   20.2%   641MiB
solve_polynomial_system             1    3.18s   16.2%   3.18s    216MiB    6.8%   216MiB
test_input                          1   1.16μs    0.0%  1.16μs      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
Lotka-Volterra 3D model with Chebyshev basis
Configuration:
n = 3
d = 8
GN = 10
sample_range = 0.25
p_true = [0.2, 0.4, 0.7]
p_center = [0.30000000000000004, 0.4, 0.7]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000027
L2 norm (error of approximation): 1.3809373376312897
Critical points found:
20×10 DataFrame
 Row │ x1         x2        x3        z           y1          y2        y3          close  steps    converged 
     │ Float64    Float64   Float64   Float64     Float64     Float64   Float64     Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.492802   0.532399  0.913368  -0.483308    0.267261   0.302216   0.868377   false      8.0      false
   2 │ 0.322687   0.284091  0.475265  -5.61708     0.0685374  0.614702   0.388989   false      9.0      false
   3 │ 0.130182   0.422847  0.908394  -5.58413     0.22742    0.362917   0.748528   false      7.0      false
   4 │ 0.363709   0.187246  0.926326  -5.88008     0.294965   0.248785   1.07986    false      8.0      false
   5 │ 0.527774   0.626522  0.859576  -0.0521484  -0.388489   1.3789    -0.182337   false     12.0      false
   6 │ 0.230233   0.357547  0.69094   -6.275       0.230026   0.353266   0.786654   false      6.0      false
   7 │ 0.476854   0.546535  0.791347  -0.609376    0.165026   0.457213   0.598901   false      8.0      false
   8 │ 0.429776   0.162733  0.461006  -5.1849      0.0475122  0.646441   0.360318   false      6.0      false
   9 │ 0.525014   0.638804  0.554271  -0.312806    0.343022   0.162401   1.48838    false     11.0      false
  10 │ 0.541065   0.630508  0.545592  -0.293157    0.368456   0.14093    1.55204    false      9.0      false
  11 │ 0.285429   0.307377  0.609048  -5.86873     0.118736   0.53132    0.494941   false      6.0      false
  12 │ 0.166678   0.164188  0.734224  -1.91763    -0.16426    1.00518    0.0379973  false     15.0      false
  13 │ 0.42415    0.597178  0.485425  -0.939848   -0.0050272  0.756023   0.201342   false      9.0      false
  14 │ 0.486981   0.623438  0.492807  -0.563646    0.0950819  0.56818    0.450595   false      9.0      false
  15 │ 0.0698788  0.174779  0.464864  -1.45735     0.0592471  0.645481   0.284904   false      5.0      false
  16 │ 0.175476   0.164986  0.6353    -1.9358      0.18797    0.418715   0.671343   false     11.0      false
  17 │ 0.395584   0.538019  0.715881  -1.09197     0.157806   0.470819   0.567733   false      6.0      false
  18 │ 0.0633051  0.318309  0.569465  -1.99042     0.060238   0.62671    0.376895   false     11.0      false
  19 │ 0.533596   0.623096  0.779291  -0.125526    0.332614   0.19902    1.23331    false     12.0      false
  20 │ 0.0840077  0.199891  0.909835  -1.73087     0.0779352  0.594936   0.426037   false     14.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        x3       z        y1        y2        y3        close  steps    converged 
     │ Float64   Float64   Float64  Float64  Float64   Float64   Float64   Bool   Float64  Bool      
─────┼───────────────────────────────────────────────────────────────────────────────────────────────
   6 │ 0.230233  0.357547  0.69094   -6.275  0.230026  0.353266  0.786654  false      6.0      false

(after optimization)  Best critical points:
6×5 DataFrame
 Row │ x3        x2        x1         value      captured 
     │ Float64   Float64   Float64    Float64    Bool     
─────┼────────────────────────────────────────────────────
   1 │ 0.868377  0.302216  0.267261    -8.7705      false
   2 │ 0.748528  0.362917  0.22742     -9.38704     false
   3 │ 0.598901  0.457213  0.165026   -12.2501      false
   4 │ 0.494941  0.53132   0.118736   -11.8851      false
   5 │ 0.450595  0.56818   0.0950819  -10.3382      false
   6 │ 0.671343  0.418715  0.18797    -10.596       false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 100s /  99.6%           15.6GiB /  99.7%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
analyze_critical_points             1    78.2s   78.6%   78.2s   12.8GiB   81.9%  12.8GiB
Constructor                         1    14.1s   14.2%   14.1s   2.27GiB   14.6%  2.27GiB
  MainGenerate                      1    14.1s   14.2%   14.1s   2.27GiB   14.6%  2.27GiB
    evaluation                      1    14.0s   14.1%   14.0s   2.24GiB   14.4%  2.24GiB
    norm_computation                1   74.2ms    0.1%  74.2ms   27.5MiB    0.2%  27.5MiB
    lambda_vandermonde              1   14.0ms    0.0%  14.0ms   1.70MiB    0.0%  1.70MiB
    linear_solve_vandermonde        1   2.79ms    0.0%  2.79ms    230KiB    0.0%   230KiB
    generate_grid                   1   2.77ms    0.0%  2.77ms    698KiB    0.0%   698KiB
solve_polynomial_system             1    7.18s    7.2%   7.18s    564MiB    3.5%   564MiB
test_input                          1    694ns    0.0%   694ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
Lotka-Volterra 3D model with Chebyshev basis
Configuration:
n = 3
d = 10
GN = 10
sample_range = 0.25
p_true = [0.2, 0.4, 0.7]
p_center = [0.30000000000000004, 0.4, 0.7]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000039
L2 norm (error of approximation): 1.1440627708106073
Critical points found:
34×10 DataFrame
 Row │ x1         x2        x3        z          y1          y2         y3         close  steps    converged 
     │ Float64    Float64   Float64   Float64    Float64     Float64    Float64    Bool   Float64  Bool      
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.369751   0.645613  0.868299  -0.513398   0.214658   0.377542    0.736772  false      9.0      false
   2 │ 0.453022   0.465535  0.874296  -0.998096   0.243154   0.339175    0.789751  false      8.0      false
   3 │ 0.549881   0.366468  0.891897  -1.01256   -0.0480161  0.818807    0.172034  false     12.0      false
   4 │ 0.47422    0.418098  0.9392    -1.07333    0.26573    0.288274    0.966969  false      7.0      false
   5 │ 0.098905   0.17672   0.878451  -1.6887     0.165262   0.447838    0.6417    false     11.0      false
   6 │ 0.503228   0.643988  0.801439  -0.126505  -0.384235   1.40555    -0.23938   false     11.0      false
   7 │ 0.527994   0.612995  0.851908  -0.108338  -0.560971   1.68718    -0.368167  false      8.0      false
   8 │ 0.251694   0.336911  0.700815  -6.73085    0.191016   0.414807    0.669859  false      8.0      false
   9 │ 0.0577951  0.493147  0.889721  -5.02944    0.255998   0.307821    0.917114  false      6.0      false
  10 │ 0.390844   0.16839   0.840782  -5.70027    0.234643   0.345093    0.812367  false     10.0      false
  11 │ 0.514543   0.583279  0.916772  -0.19849   -0.475023   1.5253     -0.25388   false     14.0      false
  12 │ 0.401585   0.163536  0.790457  -5.63992    0.178862   0.436508    0.624225  false      7.0      false
  13 │ 0.543645   0.644214  0.607274  -0.182833  -0.5166     1.60438    -0.324457  false     11.0      false
  14 │ 0.130656   0.177926  0.695594  -1.78097    0.0890436  0.581326    0.428063  false      8.0      false
  15 │ 0.519617   0.643726  0.477786  -0.385175   0.406524   0.0499141   2.94351   false     11.0      false
  16 │ 0.364478   0.243145  0.45107   -5.46603    0.122572   0.549353    0.389383  false      5.0      false
  17 │ 0.158041   0.17249   0.486757  -1.82981   -0.356321   1.33096    -0.171095  false     13.0      false
  18 │ 0.0610644  0.16274   0.478411  -1.39654    0.148592   0.485724    0.54491   false     10.0      false
  19 │ 0.441895   0.639025  0.760993  -0.398574   0.131032   0.512431    0.51932   false     10.0      false
  20 │ 0.0629172  0.406945  0.480754  -2.4157     0.145004   0.488248    0.55342   false      8.0      false
  21 │ 0.531796   0.643363  0.543649  -0.283749   0.296478   0.251387    1.0448    false     11.0      false
  22 │ 0.065829   0.26761   0.46581   -1.73577    0.124233   0.521418    0.511038  false     11.0      false
  23 │ 0.0610531  0.163573  0.532923  -1.40893    0.125656   0.512792    0.541229  false      5.0      false
  24 │ 0.162972   0.228902  0.516142  -2.12006    0.0589371  0.632226    0.364671  false     12.0      false
  25 │ 0.103371   0.312382  0.450714  -2.12568    0.13318    0.514457    0.499498  false      9.0      false
  26 │ 0.184904   0.200218  0.490721  -2.10322    0.12617    0.519419    0.511073  false     10.0      false
  27 │ 0.081334   0.251272  0.729683  -1.86669    0.143124   0.492528    0.546007  false     11.0      false
  28 │ 0.546502   0.578182  0.732654  -0.286864  -0.0138606  0.733256    0.312786  false     12.0      false
  29 │ 0.4197     0.158669  0.667014  -5.412      0.158007   0.463971    0.603071  false      5.0      false
  30 │ 0.379463   0.533411  0.841804  -1.0419     0.328754   0.231323    0.946325  false      9.0      false
  31 │ 0.128778   0.433191  0.873728  -5.77307    0.209778   0.383842    0.735079  false      8.0      false
  32 │ 0.412888   0.170597  0.610961  -5.39908    0.131599   0.507015    0.527855  false      7.0      false
  33 │ 0.150958   0.209556  0.735702  -2.05472    0.0967902  0.568888    0.441278  false     11.0      false
  34 │ 0.497219   0.583297  0.817718  -0.358178   0.10055    0.544313    0.522935  false      8.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        x3        z         y1        y2        y3        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────
   8 │ 0.251694  0.336911  0.700815  -6.73085  0.191016  0.414807  0.669859  false      8.0      false

(after optimization)  Best critical points:
8×5 DataFrame
 Row │ x3        x2        x1        value      captured 
     │ Float64   Float64   Float64   Float64    Bool     
─────┼───────────────────────────────────────────────────
   1 │ 0.736772  0.377542  0.214658  -10.8197      false
   2 │ 0.789751  0.339175  0.243154   -9.11283     false
   3 │ 0.6417    0.447838  0.165262   -9.14593     false
   4 │ 0.669859  0.414807  0.191016  -11.2453      false
   5 │ 0.917114  0.307821  0.255998   -9.80703     false
   6 │ 0.54491   0.485724  0.148592   -9.6832      false
   7 │ 0.511038  0.521418  0.124233  -11.3629      false
   8 │ 0.946325  0.231323  0.328754   -6.99576     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 180s /  99.6%           24.7GiB /  99.7%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
analyze_critical_points             1     155s   86.5%    155s   21.5GiB   87.3%  21.5GiB
Constructor                         1    15.1s    8.4%   15.1s   2.27GiB    9.2%  2.27GiB
  MainGenerate                      1    15.1s    8.4%   15.1s   2.27GiB    9.2%  2.27GiB
    evaluation                      1    14.9s    8.3%   14.9s   2.24GiB    9.1%  2.24GiB
    norm_computation                1   97.1ms    0.1%  97.1ms   27.5MiB    0.1%  27.5MiB
    lambda_vandermonde              1   21.3ms    0.0%  21.3ms   2.92MiB    0.0%  2.92MiB
    linear_solve_vandermonde        1   2.90ms    0.0%  2.90ms    650KiB    0.0%   650KiB
    generate_grid                   1   2.82ms    0.0%  2.82ms    698KiB    0.0%   698KiB
solve_polynomial_system             1    9.18s    5.1%   9.18s    884MiB    3.5%   884MiB
test_input                          1    578ns    0.0%   578ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
Lotka-Volterra 3D model with Chebyshev basis
Configuration:
n = 3
d = 10
GN = 40
sample_range = 0.25
p_true = [0.2, 0.4, 0.7]
p_center = [0.30000000000000004, 0.4, 0.7]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000025
L2 norm (error of approximation): 1.1564777681649934
Critical points found:
23×10 DataFrame
 Row │ x1         x2        x3        z          y1          y2         y3          close  steps    converged 
     │ Float64    Float64   Float64   Float64    Float64     Float64    Float64     Bool   Float64  Bool      
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.497608   0.645285  0.813671  -0.127292   0.392232    0.115621   1.64404    false     11.0      false
   2 │ 0.356931   0.48218   0.877773  -1.41023    0.206312    0.389938   0.720027   false     10.0      false
   3 │ 0.203805   0.156619  0.838898  -2.13766    0.0355878   0.669237   0.329691   false     10.0      false
   4 │ 0.277379   0.273492  0.940509  -6.45762    0.249886    0.319231   0.876785   false      4.0      false
   5 │ 0.241194   0.318561  0.880725  -6.53741    0.252554    0.316437   0.877736    true      6.0      false
   6 │ 0.360518   0.494367  0.838933  -1.36662    0.248349    0.318541   0.892357   false      8.0      false
   7 │ 0.353737   0.644531  0.921232  -0.511278   0.179724    0.433075   0.638187   false      9.0      false
   8 │ 0.0634364  0.409676  0.479901  -2.43767    0.186792    0.418793   0.668961   false     12.0      false
   9 │ 0.10731    0.179333  0.838691  -1.72431   -0.128627    0.94527    0.0834547  false      8.0      false
  10 │ 0.324382   0.269934  0.58397   -5.81899    0.106148    0.553031   0.462286   false     10.0      false
  11 │ 0.382358   0.516112  0.760363  -1.22135    0.160709    0.464313   0.588784   false      7.0      false
  12 │ 0.0780514  0.232083  0.718864  -1.76144    0.111324    0.545124   0.471061   false     10.0      false
  13 │ 0.293763   0.31752   0.491851  -5.80287    0.0345289   0.658889   0.371406   false      8.0      false
  14 │ 0.144063   0.245867  0.54244   -2.10068    0.0226012   0.683368   0.335425   false      9.0      false
  15 │ 0.15563    0.216766  0.611433  -2.05963    0.0812406   0.593077   0.420137   false     11.0      false
  16 │ 0.456787   0.455906  0.885626  -1.01699    0.214208    0.37718    0.744325   false      8.0      false
  17 │ 0.538541   0.574358  0.683426  -0.373181   1.20156    -1.33095   -0.0587228  false      9.0      false
  18 │ 0.178975   0.201805  0.507587  -2.08124    0.158344    0.463857   0.604152   false      9.0      false
  19 │ 0.450046   0.645443  0.765966  -0.338779   0.197248    0.405867   0.676521   false      8.0      false
  20 │ 0.52819    0.649718  0.538588  -0.279479   0.266515    0.287365   0.991862   false     10.0      false
  21 │ 0.118998   0.176724  0.74564   -1.737      0.216666    0.367936   0.791567   false      8.0      false
  22 │ 0.195907   0.401376  0.67557   -6.91466    0.170979    0.445544   0.6242     false      6.0      false
  23 │ 0.349118   0.644183  0.933881  -0.513888   0.125039    0.524826   0.486337   false      9.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        x3       z         y1        y2        y3       close  steps    converged 
     │ Float64   Float64   Float64  Float64   Float64   Float64   Float64  Bool   Float64  Bool      
─────┼───────────────────────────────────────────────────────────────────────────────────────────────
  22 │ 0.195907  0.401376  0.67557  -6.91466  0.170979  0.445544   0.6242  false      6.0      false

(after optimization)  Best critical points:
6×5 DataFrame
 Row │ x3        x2        x1        value      captured 
     │ Float64   Float64   Float64   Float64    Bool     
─────┼───────────────────────────────────────────────────
   1 │ 0.720027  0.389938  0.206312  -11.9125       true
   2 │ 0.876785  0.319231  0.249886  -11.2407       true
   3 │ 0.638187  0.433075  0.179724  -11.348       false
   4 │ 0.462286  0.553031  0.106148  -11.4419      false
   5 │ 0.588784  0.464313  0.160709  -11.5261      false
   6 │ 0.791567  0.367936  0.216666   -8.90338     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                1318s / 100.0%            203GiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    1231s   93.4%   1231s    188GiB   92.4%   188GiB
  MainGenerate                      1    1231s   93.4%   1231s    188GiB   92.4%   188GiB
    norm_computation                1     682s   51.8%    682s   71.5GiB   35.2%  71.5GiB
    evaluation                      1     547s   41.5%    547s    116GiB   57.1%   116GiB
    lambda_vandermonde              1    944ms    0.1%   944ms    151MiB    0.1%   151MiB
    generate_grid                   1    162ms    0.0%   162ms   35.2MiB    0.0%  35.2MiB
    linear_solve_vandermonde        1   7.01ms    0.0%  7.01ms    650KiB    0.0%   650KiB
analyze_critical_points             1    79.9s    6.1%   79.9s   14.6GiB    7.2%  14.6GiB
solve_polynomial_system             1    7.10s    0.5%   7.10s    871MiB    0.4%   871MiB
test_input                          1    592ns    0.0%   592ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
Lotka-Volterra 3D model with Chebyshev basis
Configuration:
n = 3
d = 11
GN = 60
sample_range = 0.25
p_true = [0.2, 0.4, 0.7]
p_center = [0.30000000000000004, 0.4, 0.7]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.00000000000003
L2 norm (error of approximation): 1.1060328349980868
Critical points found:
19×10 DataFrame
 Row │ x1         x2        x3        z          y1         y2          y3        close  steps    converged 
     │ Float64    Float64   Float64   Float64    Float64    Float64     Float64   Bool   Float64  Bool      
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 0.238871   0.153149  0.628267  -2.26948   0.160918    0.474541   0.54246   false      9.0      false
   2 │ 0.354245   0.645606  0.820806  -0.635584  0.0950325   0.594359   0.337513  false      7.0      false
   3 │ 0.460883   0.564273  0.904503  -0.477348  0.180475    0.427456   0.66396   false      6.0      false
   4 │ 0.41004    0.486639  0.856605  -1.11962   0.158538    0.457498   0.629442  false     10.0      false
   5 │ 0.540574   0.550818  0.841281  -0.30801   2.31016    -2.96758    1.02967   false     11.0      false
   6 │ 0.119775   0.247654  0.694615  -2.04542   0.160126    0.46356    0.592753  false     11.0      false
   7 │ 0.115441   0.208588  0.665444  -1.82344   0.144907    0.491522   0.538783  false      7.0      false
   8 │ 0.546129   0.64044   0.590111  -0.202851  0.0610889   0.62906    0.366585  false     12.0      false
   9 │ 0.0574786  0.401047  0.565784  -2.43133   0.154733    0.474097   0.572237  false      4.0      false
  10 │ 0.0887152  0.150101  0.529671  -1.46918   0.0809266   0.595423   0.410166  false      8.0      false
  11 │ 0.469517   0.595305  0.605944  -0.62809   0.0890026   0.579972   0.431389  false      8.0      false
  12 │ 0.0566338  0.168053  0.540166  -1.40724   0.148747    0.477874   0.586421  false      5.0      false
  13 │ 0.368073   0.538164  0.629206  -1.34524   0.120759    0.526079   0.515349  false      6.0      false
  14 │ 0.432135   0.156996  0.464384  -5.19893   0.0220173   0.682495   0.335655  false      6.0      false
  15 │ 0.52906    0.554188  0.612395  -0.545653  0.202337    0.396865   0.699018  false     11.0      false
  16 │ 0.537984   0.543907  0.631985  -0.53248   0.168616    0.450358   0.608087  false      8.0      false
  17 │ 0.418662   0.640082  0.613072  -0.647092  0.164281    0.460896   0.598444  false      8.0      false
  18 │ 0.484985   0.636236  0.700916  -0.319324  0.503254    0.0582462  0.838008  false     10.0      false
  19 │ 0.223648   0.358108  0.789447  -8.98485   0.235525    0.344362   0.807238   true      4.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1        x2        x3        z         y1        y2        y3        close  steps    converged 
     │ Float64   Float64   Float64   Float64   Float64   Float64   Float64   Bool   Float64  Bool      
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────
  19 │ 0.223648  0.358108  0.789447  -8.98485  0.235525  0.344362  0.807238   true      4.0      false

(after optimization)  Best critical points:
6×5 DataFrame
 Row │ x3        x2        x1        value      captured 
     │ Float64   Float64   Float64   Float64    Bool     
─────┼───────────────────────────────────────────────────
   1 │ 0.54246   0.474541  0.160918   -8.61836     false
   2 │ 0.66396   0.427456  0.180475  -10.2127      false
   3 │ 0.629442  0.457498  0.158538   -8.94632     false
   4 │ 0.515349  0.526079  0.120759   -9.00398     false
   5 │ 0.699018  0.396865  0.202337  -10.0526      false
   6 │ 0.807238  0.344362  0.235525  -11.3714       true
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                3.33h / 100.0%           1.14TiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    3.30h   99.2%   3.30h   1.13TiB   98.9%  1.13TiB
  MainGenerate                      1    3.30h   99.2%   3.30h   1.13TiB   98.9%  1.13TiB
    norm_computation                1    2.76h   82.9%   2.76h    776GiB   66.2%   776GiB
    evaluation                      1    1945s   16.2%   1945s    382GiB   32.6%   382GiB
    lambda_vandermonde              1    4.50s    0.0%   4.50s    632MiB    0.1%   632MiB
    generate_grid                   1    391ms    0.0%   391ms    116MiB    0.0%   116MiB
    linear_solve_vandermonde        1   25.5ms    0.0%  25.5ms   1.04MiB    0.0%  1.04MiB
analyze_critical_points             1    91.8s    0.8%   91.8s   12.2GiB    1.0%  12.2GiB
solve_polynomial_system             1    9.85s    0.1%   9.85s   1.08GiB    0.1%  1.08GiB
test_input                          1    985ns    0.0%   985ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────
=#
