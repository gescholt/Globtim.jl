using Pkg
# Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials, DataFrames, TimerOutputs
using ProgressLogging
using StaticArrays
using Optim  # required for an extension

for n in [2,3,4]
    # Choose f from: Rastringin, alpine1, Ackley
    f = Ackley

    reset_timer!(Globtim._TO)

    # Constants and Parameters
    a, b = 1, 1
    scale_factor = a / b
    rand_center = zeros(Float64, n);
    d = 9 # initial degree 
    SMPL = 20 # Number of samples
    TR = test_input(f, 
                    dim = n,
                    center=rand_center,
                    GN=SMPL, 
                    sample_range=scale_factor 
                    )

    pol_cheb = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)
    @polyvar(x[1:n]) # Define polynomial ring 
    real_pts_cheb = solve_polynomial_system(
        x, n, d, pol_cheb.coeffs;
        basis=pol_cheb.basis,
        precision=pol_cheb.precision,
        normalized=pol_cheb.normalized,
    )
    
    df_cheb = process_crit_pts(real_pts_cheb, f, TR)

    df_cheb, df_min_cheb = Globtim.analyze_critical_points(f, df_cheb, TR, tol_dist=0.5);

    println("===============================================")
    println("Function: $f")
    println("""Configuration:
    n = $n
    d = $d
    scale_factor = $scale_factor
    SMPL = $SMPL
    L2-norm (cheb): $(pol_cheb.nrm)
    Vandermode condition number: $(pol_cheb.cond_vandermonde)
    """)
    println(Globtim._TO)
end

#=
Example output:
julia> include("globtim/experiments/week0/timings_for_different_n_dim.jl")
current L2-norm: 0.3037290761559208
Processing point 1 of 17
Optimization has converged within bounds: ✓
Processing point 2 of 17
Optimization has converged within bounds: ✓
Processing point 3 of 17
Optimization has converged within bounds: ✓
Processing point 4 of 17
Optimization has converged within bounds: ✓
Processing point 5 of 17
Optimization has converged within bounds: ✓
Processing point 6 of 17
Optimization has converged within bounds: ✓
Processing point 7 of 17
Optimization has converged within bounds: ✓
Processing point 8 of 17
Optimization has converged within bounds: ✓
Processing point 9 of 17
Optimization has converged within bounds: ✓
Processing point 10 of 17
Optimization has converged within bounds: ✓
Processing point 11 of 17
Optimization has converged within bounds: ✓
Processing point 12 of 17
Optimization has converged within bounds: ✓
Processing point 13 of 17
Optimization has converged within bounds: ✓
Processing point 14 of 17
Optimization has converged within bounds: ✓
Processing point 15 of 17
Optimization has converged within bounds: ✓
Processing point 16 of 17
Optimization has converged within bounds: ✓
Processing point 17 of 17
Optimization has converged within bounds: ✓
===============================================
Function: Ackley
Configuration:
n = 2
d = 9
scale_factor = 1.0
SMPL = 20
L2-norm (cheb): 0.3037290761559208
Vandermode condition number: 4.0000000000000115

─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                5.62s /  89.3%            261MiB /  92.4%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
analyze_critical_points             1    4.92s   97.9%   4.92s    233MiB   96.9%   233MiB
solve_polynomial_system             1   92.8ms    1.8%  92.8ms   3.72MiB    1.5%  3.72MiB
Constructor                         1   11.5ms    0.2%  11.5ms   3.66MiB    1.5%  3.66MiB
  MainGenerate                      1   10.9ms    0.2%  10.9ms   3.66MiB    1.5%  3.66MiB
    norm_computation                1   5.50ms    0.1%  5.50ms   3.09MiB    1.3%  3.09MiB
    generate_grid                   1   1.86ms    0.0%  1.86ms    228KiB    0.1%   228KiB
    lambda_vandermonde              1   1.69ms    0.0%  1.69ms    200KiB    0.1%   200KiB
    linear_solve_vandermonde        1    409μs    0.0%   409μs   26.5KiB    0.0%  26.5KiB
    evaluation                      1   99.1μs    0.0%  99.1μs   3.69KiB    0.0%  3.69KiB
test_input                          1   8.27μs    0.0%  8.27μs      176B    0.0%     176B
─────────────────────────────────────────────────────────────────────────────────────────
current L2-norm: 0.2814527419894433
Tracking 512 paths... 100%|██████████████████████████████████████| Time: 0:00:25
                   # paths tracked: 512
   # non-singular solutions (real): 512 (182)
       # singular endpoints (real): 0 (0)
          # total solutions (real): 512 (182)
Processing point 1 of 123
Optimization has converged within bounds: ✓
Processing point 2 of 123
Optimization has converged within bounds: ✓
Processing point 3 of 123
Optimization has converged within bounds: ✓
Processing point 4 of 123
Optimization has converged within bounds: ✓
Processing point 5 of 123
Optimization has converged within bounds: ✓
Processing point 6 of 123
Optimization has converged within bounds: ✓
Processing point 7 of 123
Optimization has converged within bounds: ✓
Processing point 8 of 123
Optimization has converged within bounds: ✓
Processing point 9 of 123
Optimization has converged within bounds: ✓
Processing point 10 of 123
Optimization has converged within bounds: ✓
Processing point 11 of 123
Optimization has converged within bounds: ✓
Processing point 12 of 123
Optimization has converged within bounds: ✓
Processing point 13 of 123
Optimization has converged within bounds: ✓
Processing point 14 of 123
Optimization has converged within bounds: ✓
Processing point 15 of 123
Optimization has converged within bounds: ✓
Processing point 16 of 123
Optimization has converged within bounds: ✓
Processing point 17 of 123
Optimization has converged within bounds: ✓
Processing point 18 of 123
Optimization has converged within bounds: ✓
Processing point 19 of 123
Optimization has converged within bounds: ✓
Processing point 20 of 123
Optimization has converged within bounds: ✓
Processing point 21 of 123
Optimization has converged within bounds: ✓
Processing point 22 of 123
Optimization has converged within bounds: ✓
Processing point 23 of 123
Optimization has converged within bounds: ✓
Processing point 24 of 123
Optimization has converged within bounds: ✓
Processing point 25 of 123
Optimization has converged within bounds: ✓
Processing point 26 of 123
Optimization has converged within bounds: ✓
Processing point 27 of 123
Optimization has converged within bounds: ✓
Processing point 28 of 123
Optimization has converged within bounds: ✓
Processing point 29 of 123
Optimization has converged within bounds: ✓
Processing point 30 of 123
Optimization has converged within bounds: ✓
Processing point 31 of 123
Optimization has converged within bounds: ✓
Processing point 32 of 123
Optimization has converged within bounds: ✓
Processing point 33 of 123
Optimization has converged within bounds: ✓
Processing point 34 of 123
Optimization has converged within bounds: ✓
Processing point 35 of 123
Optimization has converged within bounds: ✓
Processing point 36 of 123
Optimization has converged within bounds: ✓
Processing point 37 of 123
Optimization has converged within bounds: ✓
Processing point 38 of 123
Optimization has converged within bounds: ✓
Processing point 39 of 123
Optimization has converged within bounds: ✓
Processing point 40 of 123
Optimization has converged within bounds: ✓
Processing point 41 of 123
Optimization has converged within bounds: ✓
Processing point 42 of 123
Optimization has converged within bounds: ✓
Processing point 43 of 123
Optimization has converged within bounds: ✓
Processing point 44 of 123
Optimization has converged within bounds: ✓
Processing point 45 of 123
Optimization has converged within bounds: ✓
Processing point 46 of 123
Optimization has converged within bounds: ✓
Processing point 47 of 123
Optimization has converged within bounds: ✓
Processing point 48 of 123
Optimization has converged within bounds: ✓
Processing point 49 of 123
Optimization has converged within bounds: ✓
Processing point 50 of 123
Optimization has converged within bounds: ✓
Processing point 51 of 123
Optimization has converged within bounds: ✓
Processing point 52 of 123
Optimization has converged within bounds: ✓
Processing point 53 of 123
Optimization has converged within bounds: ✓
Processing point 54 of 123
Optimization has converged within bounds: ✓
Processing point 55 of 123
Optimization has converged within bounds: ✓
Processing point 56 of 123
Optimization has converged within bounds: ✓
Processing point 57 of 123
Optimization has converged within bounds: ✓
Processing point 58 of 123
Optimization has converged within bounds: ✓
Processing point 59 of 123
Optimization has converged within bounds: ✓
Processing point 60 of 123
Optimization has converged within bounds: ✓
Processing point 61 of 123
Optimization has converged within bounds: ✓
Processing point 62 of 123
Optimization has converged within bounds: ✓
Processing point 63 of 123
Optimization has converged within bounds: ✓
Processing point 64 of 123
Optimization has converged within bounds: ✓
Processing point 65 of 123
Optimization has converged within bounds: ✓
Processing point 66 of 123
Optimization has converged within bounds: ✓
Processing point 67 of 123
Optimization has converged within bounds: ✓
Processing point 68 of 123
Optimization has converged within bounds: ✓
Processing point 69 of 123
Optimization has converged within bounds: ✓
Processing point 70 of 123
Optimization has converged within bounds: ✓
Processing point 71 of 123
Optimization has converged within bounds: ✓
Processing point 72 of 123
Optimization has converged within bounds: ✓
Processing point 73 of 123
Optimization has converged within bounds: ✓
Processing point 74 of 123
Optimization has converged within bounds: ✓
Processing point 75 of 123
Optimization has converged within bounds: ✓
Processing point 76 of 123
Optimization has converged within bounds: ✓
Processing point 77 of 123
Optimization has converged within bounds: ✓
Processing point 78 of 123
Optimization has converged within bounds: ✓
Processing point 79 of 123
Optimization has converged within bounds: ✓
Processing point 80 of 123
Optimization has converged within bounds: ✓
Processing point 81 of 123
Optimization has converged within bounds: ✓
Processing point 82 of 123
Optimization has converged within bounds: ✓
Processing point 83 of 123
Optimization has converged within bounds: ✓
Processing point 84 of 123
Optimization has converged within bounds: ✓
Processing point 85 of 123
Optimization has converged within bounds: ✓
Processing point 86 of 123
Optimization has converged within bounds: ✓
Processing point 87 of 123
Optimization has converged within bounds: ✓
Processing point 88 of 123
Optimization has converged within bounds: ✓
Processing point 89 of 123
Optimization has converged within bounds: ✓
Processing point 90 of 123
Optimization has converged within bounds: ✓
Processing point 91 of 123
Optimization has converged within bounds: ✓
Processing point 92 of 123
Optimization has converged within bounds: ✓
Processing point 93 of 123
Optimization has converged within bounds: ✓
Processing point 94 of 123
Optimization has converged within bounds: ✓
Processing point 95 of 123
Optimization has converged within bounds: ✓
Processing point 96 of 123
Optimization has converged within bounds: ✓
Processing point 97 of 123
Optimization has converged within bounds: ✓
Processing point 98 of 123
Optimization has converged within bounds: ✓
Processing point 99 of 123
Optimization has converged within bounds: ✓
Processing point 100 of 123
Optimization has converged within bounds: ✓
Processing point 101 of 123
Optimization has converged within bounds: ✓
Processing point 102 of 123
Optimization has converged within bounds: ✓
Processing point 103 of 123
Optimization has converged within bounds: ✓
Processing point 104 of 123
Optimization has converged within bounds: ✓
Processing point 105 of 123
Optimization has converged within bounds: ✓
Processing point 106 of 123
Optimization has converged within bounds: ✓
Processing point 107 of 123
Optimization has converged within bounds: ✓
Processing point 108 of 123
Optimization has converged within bounds: ✓
Processing point 109 of 123
Optimization has converged within bounds: ✓
Processing point 110 of 123
Optimization has converged within bounds: ✓
Processing point 111 of 123
Optimization has converged within bounds: ✓
Processing point 112 of 123
Optimization has converged within bounds: ✓
Processing point 113 of 123
Optimization has converged within bounds: ✓
Processing point 114 of 123
Optimization has converged within bounds: ✓
Processing point 115 of 123
Optimization has converged within bounds: ✓
Processing point 116 of 123
Optimization has converged within bounds: ✓
Processing point 117 of 123
Optimization has converged within bounds: ✓
Processing point 118 of 123
Optimization has converged within bounds: ✓
Processing point 119 of 123
Optimization has converged within bounds: ✓
Processing point 120 of 123
Optimization has converged within bounds: ✓
Processing point 121 of 123
Optimization has converged within bounds: ✓
Processing point 122 of 123
Optimization has converged within bounds: ✓
Processing point 123 of 123
Optimization has converged within bounds: ✓
===============================================
Function: Ackley
Configuration:
n = 3
d = 9
scale_factor = 1.0
SMPL = 20
L2-norm (cheb): 0.2814527419894433
Vandermode condition number: 8.00000000000002

─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                55.0s / 100.0%           2.59GiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
solve_polynomial_system             1    41.9s   76.2%   41.9s    771MiB   29.1%   771MiB
Constructor                         1    12.6s   22.9%   12.6s   1.83GiB   70.7%  1.83GiB
  MainGenerate                      1    12.6s   22.9%   12.6s   1.83GiB   70.7%  1.83GiB
    norm_computation                1    11.6s   21.0%   11.6s   1.77GiB   68.3%  1.77GiB
    generate_grid                   1    328ms    0.6%   328ms   22.0MiB    0.8%  22.0MiB
    lambda_vandermonde              1    172ms    0.3%   172ms   15.6MiB    0.6%  15.6MiB
    evaluation                      1    113ms    0.2%   113ms   7.02MiB    0.3%  7.02MiB
    linear_solve_vandermonde        1   5.65ms    0.0%  5.65ms    391KiB    0.0%   391KiB
analyze_critical_points             1    463ms    0.8%   463ms   5.16MiB    0.2%  5.16MiB
test_input                          1   1.13μs    0.0%  1.13μs      176B    0.0%     176B
─────────────────────────────────────────────────────────────────────────────────────────








^CERROR: LoadError: InterruptException:
Stacktrace:
  [1] -(A::Vector{Float64}, B::Vector{Float64})
    @ Base ./arraymath.jl:6
  [2] (::Globtim.var"#41#43"{Matrix{…}, SciMLBase.LinearSolution{…}, Vector{…}, Array{…}})(x::SVector{4, Float64})
    @ Globtim ~/projects/globtim/src/scaling_utils.jl:46
  [3] #82
    @ ./none:0 [inlined]
  [4] MappingRF
    @ ./reduce.jl:100 [inlined]
  [5] _foldl_impl(op::Base.MappingRF{…}, init::Base._InitialValue, itr::Base.Iterators.Zip{…})
    @ Base ./reduce.jl:62
  [6] foldl_impl
    @ ./reduce.jl:48 [inlined]
  [7] mapfoldl_impl
    @ ./reduce.jl:44 [inlined]
  [8] mapfoldl
    @ ./reduce.jl:175 [inlined]
  [9] mapreduce
    @ ./reduce.jl:307 [inlined]
 [10] sum
    @ ./reduce.jl:532 [inlined]
 [11] sum(a::Base.Generator{Base.Iterators.Zip{Tuple{…}}, Globtim.var"#82#90"{Globtim.var"#41#43"{…}}})
    @ Base ./reduce.jl:561
 [12] discrete_l2_norm_riemann(f::Globtim.var"#41#43"{…}, grid::Array{…})
    @ Globtim ~/projects/globtim/src/l2_norm.jl:71
 [13] compute_norm(scale_factor::Float64, VL::Matrix{…}, sol::SciMLBase.LinearSolution{…}, F::Vector{…}, grid::Array{…}, n::Int64, d::Int64)
    @ Globtim ~/projects/globtim/src/scaling_utils.jl:47
 [14] MainGenerate(f::typeof(Ackley), n::Int64, d::Int64, delta::Float64, alpha::Float64, scale_factor::Float64, scl::Float64; center::Vector{…}, verbose::Int64, basis::Symbol, GN::Int64, precision::PrecisionType, normalized::Bool, power_of_two_denom::Bool)
    @ Globtim ~/projects/globtim/src/Main_Gen.jl:42
 [15] 
    @ Globtim ~/projects/globtim/src/Main_Gen.jl:128
 [16] Constructor
    @ ~/projects/globtim/src/Main_Gen.jl:128 [inlined]
 [17] top-level scope
    @ ~/projects/globtim/experiments/week0/timings_for_different_n_dim.jl:28
 [18] include(fname::String)
    @ Main ./sysimg.jl:38
in expression starting at /Users/demin/projects/globtim/experiments/week0/timings_for_different_n_dim.jl:9
Some type information was truncated. Use `show(err)` to see complete types.

julia> Globtim._TO
─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations      
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                1.72h /  99.8%            117GiB / 100.0%    

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    1.72h  100.0%   1.72h    116GiB  100.0%   116GiB
  MainGenerate                      1    1.72h  100.0%   1.72h    116GiB  100.0%   116GiB
    norm_computation                1    1.71h   99.1%   1.71h    115GiB   99.0%   115GiB
    lambda_vandermonde              1    48.8s    0.8%   48.8s   1.04GiB    0.9%  1.04GiB
    generate_grid                   1    2.65s    0.0%   2.65s    129MiB    0.1%   129MiB
    evaluation                      1    337ms    0.0%   337ms   8.74MiB    0.0%  8.74MiB
    linear_solve_vandermonde        1    125ms    0.0%   125ms   3.93MiB    0.0%  3.93MiB
test_input                          1   3.01μs    0.0%  3.01μs      208B    0.0%     208B
─────────────────────────────────────────────────────────────────────────────────────────


=#
