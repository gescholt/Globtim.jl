using Revise
using Globtim,
    DynamicPolynomials,
    DataFrames,
    ProgressLogging,
    Optim,
    ModelingToolkit,
    OrdinaryDiffEq,
    StaticArrays,
    DataStructures,
    LinearAlgebra,
    TimerOutputs
using Logging;
global_logger(ConsoleLogger(Logging.Error));

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

reset_timer!(Globtim._TO)

#

const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[2, 2/10, 2/10]
ic = T[1.0, -1.0]
num_points = 50
distance = log_L2_norm
model, params, states, outputs = define_fitzhugh_nagumo_3D_model()
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
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring
p_center = p_true + [0.10, 0.0, 0.0]
TR =
    test_input(error_func, dim = n, center = p_center, GN = GN, sample_range = sample_range);

# Chebyshev
pol_cheb =
    Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision, verbose = true)
real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis = pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)
df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist = 0.05);

println("########################################")
println("Fitzhugh Nagumo 3D model with Chebyshev basis")
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
println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#=
########################################
Fitzhugh Nagumo 3D model with Chebyshev basis
Configuration:
n = 3
d = 10
GN = 20
sample_range = 0.25
p_true = [2.0, 0.2, 0.2]
p_center = [2.1, 0.2, 0.2]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000023
L2 norm (error of approximation): 1.336308367733205
Critical points found:
36×10 DataFrame
 Row │ x1       x2          x3           z            y1       y2          y3           close  steps    converged
     │ Float64  Float64     Float64      Float64      Float64  Float64     Float64      Bool   Float64  Bool
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 2.33595   0.427654    0.425595     1.34866     1.97914  -0.174948    0.624918    false      8.0      false
   2 │ 2.14784   0.438334    0.439211     0.880962    2.00292   0.201548    0.19519     false      8.0      false
   3 │ 2.24011   0.429846    0.427805     1.10347     1.99503   0.049509    0.366324    false      6.0      false
   4 │ 2.33294   0.257332    0.435648     1.0017      1.98303   0.160305    0.262069    false      9.0      false
   5 │ 2.06691   0.441887    0.172511    -0.350587    1.99665   0.111103    0.2991      false     14.0      false
   6 │ 2.3348    0.181377    0.328682     0.512757    1.99362   0.0890985   0.325676    false     13.0      false
   7 │ 2.28253   0.102204    0.427549     0.348369    2.00598   0.373177    0.00831142  false      6.0      false
   8 │ 2.32241   0.367124    0.423389     1.18855     1.97069   0.339379    0.0801026   false      7.0      false
   9 │ 2.15677   0.331942    0.425086     0.587599    2.00753   0.505326   -0.136447    false      9.0      false
  10 │ 1.98733   0.445651    0.441818     0.364441    1.98848   0.0187891   0.406502    false     11.0      false
  11 │ 2.26091   0.353465    0.344049     0.786166    1.9985    0.153314    0.251279    false     10.0      false
  12 │ 1.99701   0.401686    0.410408     0.139214    2.02109   0.515037   -0.161245    false     11.0      false
  13 │ 2.09656   0.178197    0.433909    -0.229432    2.01466   0.418838   -0.0518264   false      8.0      false
  14 │ 2.33065   0.433693    0.238363     0.952828    2.00702   0.34297     0.0406572   false     10.0      false
  15 │ 2.20346   0.0769532   0.0896453   -3.92828     1.99814   0.16604     0.238257    false     13.0      false
  16 │ 1.91792  -0.0300971  -0.0271492    0.304108    2.01595   0.289985    0.0909585   false      6.0      false
  17 │ 1.86543   0.0207275  -0.0285764    0.311457    2.00809   0.356169    0.0218843   false     11.0      false
  18 │ 2.01473  -0.0357185  -0.00837222  -0.00870971  1.98682   0.130979    0.290411    false      7.0      false
  19 │ 1.85616   0.157259   -0.00326867  -0.12803     1.9891    0.0813889   0.339088    false     10.0      false
  20 │ 2.26706   0.421444    0.102548     0.302128    2.0031    0.348283    0.0381849   false      8.0      false
  21 │ 1.98273   0.0923739  -0.0188179   -0.325854    2.0325    0.687385   -0.360889    false     12.0      false
  22 │ 1.8666   -0.0308766   0.0375019    0.293326    1.98944   0.246429    0.162461    false      7.0      false
  23 │ 2.00606  -0.0144156  -0.0322871    0.0191062   2.02457   0.708828   -0.373495    false      9.0      false
  24 │ 1.88096   0.176102   -0.0471782   -0.145777    2.00325   0.278198    0.113432    false     13.0      false
  25 │ 1.98828   0.0956672  -0.0235858   -0.346051    1.99891   0.384815    0.00562739  false      6.0      false
  26 │ 2.02297   0.0837354  -0.0425708   -0.377561    2.01637   0.356168    0.0147316   false     11.0      false
  27 │ 2.32391   0.327029    0.132139     0.321389    1.9997    0.409446   -0.0223706   false     10.0      false
  28 │ 2.31315   0.371607    0.0954884    0.306888    2.03033   0.804185   -0.481783    false     13.0      false
  29 │ 1.85117  -0.010371    0.221813    -0.237383    1.97153   0.108617    0.329097    false      2.0      false
  30 │ 1.91619   0.0335411   0.0448706   -0.0607928   1.99457   0.137639    0.273746    false     10.0      false
  31 │ 2.14122   0.425751    0.330534     0.531935    1.98265   0.0836834   0.342401    false      7.0      false
  32 │ 1.99107  -0.0240109   0.0999057   -0.318147    1.96969   0.401035    0.022648    false      5.0      false
  33 │ 1.85228   0.182459    0.0890372   -0.56021     2.01829   0.388602   -0.0234613   false      6.0      false
  34 │ 2.12263   0.320585    0.309236     0.00671075  2.02421   0.196301    0.176835    false      5.0      false
  35 │ 2.31916   0.431896    0.329442     1.11877     1.99911   0.128297    0.277423    false      9.0      false
  36 │ 2.25851   0.427675    0.423604     1.14076     2.03363   1.18788    -0.876726    false      7.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1       x2        x3         z         y1       y2        y3          close  steps    converged
     │ Float64  Float64   Float64    Float64   Float64  Float64   Float64     Bool   Float64  Bool
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────
  33 │ 1.85228  0.182459  0.0890372  -0.56021  2.01829  0.388602  -0.0234613  false      6.0      false

(after optimization)  Best critical points:
9×5 DataFrame
 Row │ x3          x2         x1       value     captured
     │ Float64     Float64    Float64  Float64   Bool
─────┼────────────────────────────────────────────────────
   1 │ 0.19519     0.201548   2.00292  -9.88552     false
   2 │ 0.366324    0.049509   1.99503  -9.58107     false
   3 │ 0.262069    0.160305   1.98303  -7.7149      false
   4 │ 0.2991      0.111103   1.99665  -9.68376     false
   5 │ 0.00831142  0.373177   2.00598  -9.35572     false
   6 │ 0.0801026   0.339379   1.97069  -5.84864     false
   7 │ 0.406502    0.0187891  1.98848  -9.35874     false
   8 │ 0.0909585   0.289985   2.01595  -6.13338     false
   9 │ 0.162461    0.246429   1.98944  -7.93372     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                 314s /  95.6%           48.8GiB /  95.5%

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
analyze_critical_points             1     149s   49.8%    149s   23.4GiB   50.2%  23.4GiB
Constructor                         1     102s   33.9%    102s   17.8GiB   38.3%  17.8GiB
  MainGenerate                      1     102s   33.9%    102s   17.8GiB   38.3%  17.8GiB
    evaluation                      1    89.1s   29.7%   89.1s   15.9GiB   34.1%  15.9GiB
    norm_computation                1    10.9s    3.6%   10.9s   1.80GiB    3.9%  1.80GiB
    linear_solve_vandermonde        1    1.64s    0.5%   1.64s    138MiB    0.3%   138MiB
    lambda_vandermonde              1    123ms    0.0%   123ms   20.3MiB    0.0%  20.3MiB
    generate_grid                   1   16.5ms    0.0%  16.5ms   4.74MiB    0.0%  4.74MiB
solve_polynomial_system             1    48.7s   16.2%   48.7s   5.35GiB   11.5%  5.35GiB
test_input                          1    682ns    0.0%   682ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────

########################################
Fitzhugh Nagumo 3D model with Chebyshev basis
Configuration:
n = 3
d = 11
GN = 40
sample_range = 0.25
p_true = [2.0, 0.2, 0.2]
p_center = [2.1, 0.2, 0.2]
Distance function: log_L2_norm
Condition number of the polynomial system: 8.000000000000028
L2 norm (error of approximation): 1.196917813944598
Critical points found:
55×10 DataFrame
 Row │ x1       x2           x3           z           y1       y2         y3          close  steps    converged
     │ Float64  Float64      Float64      Float64     Float64  Float64    Float64     Bool   Float64  Bool
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 2.17446   0.430722     0.430796     0.922581   1.99019  0.206855    0.208195   false      4.0      false
   2 │ 2.20828   0.420236     0.435569     1.00897    2.01712  0.445552   -0.0832955  false      9.0      false
   3 │ 2.25704   0.326625     0.420563     0.8981     1.98607  0.190214    0.225501   false      9.0      false
   4 │ 2.07154   0.17646      0.428388    -0.416762   2.00442  0.204793    0.189981   false     11.0      false
   5 │ 2.34059   0.0690697    0.432471     0.495938   1.99376  0.120466    0.292283   false      7.0      false
   6 │ 1.98598   0.441137     0.4381       0.331986   1.99725  0.152517    0.254139   false     13.0      false
   7 │ 2.31084   0.415614     0.204627     0.757984   2.00407  0.313125    0.07462    false      6.0      false
   8 │ 2.21578   0.436872     0.415965     1.02386    2.00807  0.303107    0.0808387  false      9.0      false
   9 │ 2.00888   0.366402     0.413078     0.0658253  1.99797  0.231645    0.168154   false      7.0      false
  10 │ 2.22716   0.332605     0.317258     0.531199   2.0204   0.545448   -0.193571   false      6.0      false
  11 │ 2.34057   0.295749     0.417063     1.07132    1.99735  0.101367    0.308154   false      7.0      false
  12 │ 2.12091   0.310219     0.415136     0.350608   1.98993  0.0421418   0.379099   false      7.0      false
  13 │ 1.91315   0.19629      0.307741    -5.08628    2.0016   0.302441    0.0886109  false      7.0      false
  14 │ 2.2393    0.166433     0.409128     0.326221   1.99807  0.227398    0.174077   false      7.0      false
  15 │ 2.34006   0.426337     0.262774     1.0209     2.00529  0.315856    0.0705515  false      7.0      false
  16 │ 2.05374   0.436697     0.156784    -0.545939   1.9932   0.13888     0.273433   false      8.0      false
  17 │ 2.10654   0.416532     0.308447     0.296037   2.00945  0.389334   -0.0136242  false     11.0      false
  18 │ 1.89297   0.30756      0.213496    -4.76021    2.01776  0.289538    0.0832038  false      5.0      false
  19 │ 1.91347   0.241077     0.261459    -5.00311    1.99828  0.366794    0.0251875  false      6.0      false
  20 │ 2.31689   0.436286     0.434609     1.33391    2.04788  0.274593    0.0630759  false      9.0      false
  21 │ 2.26802  -0.0360012    0.134714    -3.50068    2.00594  0.316744    0.0682598  false      8.0      false
  22 │ 2.33098   0.327885     0.286878     0.807165   2.01287  0.362844    0.0110256  false      8.0      false
  23 │ 2.22633   0.40834      0.146869     0.226499   2.00841  0.499084   -0.128248   false      8.0      false
  24 │ 2.306     0.247586     0.208088     0.214487   2.00467  0.296148    0.0926218  false      9.0      false
  25 │ 2.33818   0.436649     0.397865     1.31864    2.01391  0.195666    0.190504   false      8.0      false
  26 │ 1.96135   0.297017     0.14378     -6.10414    2.00649  0.396677   -0.017447   false      6.0      false
  27 │ 1.86897   0.241658     0.307922    -4.55403    1.99942  0.212193    0.188805   false      6.0      false
  28 │ 2.23169   0.0651281    0.0757322   -3.69774    2.01474  0.497973   -0.136015   false      8.0      false
  29 │ 1.85911   0.0536335   -0.0179641    0.219054   1.99499  0.118505    0.292862   false      8.0      false
  30 │ 1.97615   0.274487     0.149678    -6.76854    2.00003  0.258576    0.136427    true      3.0      false
  31 │ 1.88076   0.054958     0.0538073   -0.0384275  2.01184  0.409973   -0.0385825  false      7.0      false
  32 │ 1.90678   0.0151246    0.0241186    0.0870937  2.00494  0.306074    0.0805375  false      8.0      false
  33 │ 2.26458   0.124628    -0.035101    -3.57835    1.99599  0.189284    0.216355   false      7.0      false
  34 │ 1.86133  -0.0368956   -0.0340451    0.46632    2.00387  0.33626     0.0493034  false     12.0      false
  35 │ 1.98854  -0.0154815    0.00697297  -0.0316565  1.97957  0.184812    0.239358   false      7.0      false
  36 │ 1.98283   0.0341691   -0.0309418   -0.0666336  2.00516  0.308515    0.0778117  false      6.0      false
  37 │ 1.87092   0.0674179   -0.0395895    0.201067   1.99542  0.236074    0.16704    false      5.0      false
  38 │ 2.3385    0.435635     0.0564875    0.503085   2.00068  0.209845    0.188756   false     10.0      false
  39 │ 1.98424  -0.02582      0.0311491   -0.0538377  2.00949  0.309883    0.0715349  false      8.0      false
  40 │ 1.85583  -0.0105847    0.048068     0.244552   1.99601  0.0857427   0.326552   false     10.0      false
  41 │ 1.89482  -0.0190961   -0.0153335    0.308751   2.00218  0.242096    0.152437   false      5.0      false
  42 │ 1.87894  -0.0458931    0.0637665    0.240536   1.99934  0.179905    0.222021   false      7.0      false
  43 │ 1.8523    0.00136886   0.032607     0.257989   2.0077   0.299465    0.0829846  false      7.0      false
  44 │ 1.97951   0.074286     0.0153504   -0.364311   2.00834  0.336426    0.0447213  false     10.0      false
  45 │ 2.33847   0.406838     0.435074     1.33359    2.01034  0.490635   -0.121445   false      9.0      false
  46 │ 1.89212   0.106746     0.0988044   -0.439401   2.00371  0.289621    0.100099   false      8.0      false
  47 │ 2.29206   0.358852     0.119006     0.246602   2.00785  0.331452    0.0500294  false     11.0      false
  48 │ 2.34143   0.218063     0.44733      0.961091   2.00796  0.345935    0.0347539  false     10.0      false
  49 │ 1.88053   0.114166     0.116065    -0.490578   2.00369  0.247909    0.144563   false      4.0      false
  50 │ 2.34181   0.301468     0.272003     0.734102   1.99847  0.188143    0.21494    false      7.0      false
  51 │ 2.26076   0.42331      0.300856     0.856109   2.00016  0.219763    0.178244   false      8.0      false
  52 │ 2.31604   0.238571     0.412821     0.845497   2.00019  0.37216     0.0174335  false     12.0      false
  53 │ 2.3082    0.136323     0.347452     0.307316   2.01139  0.451567   -0.0825387  false      9.0      false
  54 │ 2.10812   0.300192     0.301136    -0.196081   2.00237  0.264949    0.127478   false      6.0      false
  55 │ 2.30518   0.387584     0.37656      1.08394    2.00109  0.181443    0.218823   false      9.0      false

(before optimization) Best critical points:
DataFrameRow
 Row │ x1       x2        x3        z         y1       y2        y3        close  steps    converged
     │ Float64  Float64   Float64   Float64   Float64  Float64   Float64   Bool   Float64  Bool
─────┼───────────────────────────────────────────────────────────────────────────────────────────────
  30 │ 1.97615  0.274487  0.149678  -6.76854  2.00003  0.258576  0.136427   true      3.0      false

(after optimization)  Best critical points:
8×5 DataFrame
 Row │ x3          x2         x1       value      captured
     │ Float64     Float64    Float64  Float64    Bool
─────┼─────────────────────────────────────────────────────
   1 │  0.208195   0.206855   1.99019   -6.5731      false
   2 │  0.292283   0.120466   1.99376   -9.8232      false
   3 │  0.07462    0.313125   2.00407  -10.0295      false
   4 │  0.379099   0.0421418  1.98993   -8.74451     false
   5 │ -0.0136242  0.389334   2.00945   -9.39497     false
   6 │  0.0630759  0.274593   2.04788   -6.17438     false
   7 │  0.136427   0.258576   2.00003   -8.55515      true
   8 │  0.0347539  0.345935   2.00796   -9.90787     false
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                1786s / 100.0%            226GiB / 100.0%

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    1577s   88.3%   1577s    190GiB   83.9%   190GiB
  MainGenerate                      1    1577s   88.3%   1577s    190GiB   83.9%   190GiB
    norm_computation                1     891s   49.9%    891s   71.5GiB   31.6%  71.5GiB
    evaluation                      1     684s   38.3%    684s    118GiB   52.2%   118GiB
    lambda_vandermonde              1    1.18s    0.1%   1.18s    192MiB    0.1%   192MiB
    generate_grid                   1    113ms    0.0%   113ms   35.2MiB    0.0%  35.2MiB
    linear_solve_vandermonde        1   8.76ms    0.0%  8.76ms   1.04MiB    0.0%  1.04MiB
analyze_critical_points             1     199s   11.2%    199s   35.3GiB   15.6%  35.3GiB
solve_polynomial_system             1    9.41s    0.5%   9.41s   1.09GiB    0.5%  1.09GiB
test_input                          1    751ns    0.0%   751ns      240B    0.0%     240B
─────────────────────────────────────────────────────────────────────────────────────────
=#
