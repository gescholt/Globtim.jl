using Pkg
# Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials, DataFrames, TimerOutputs
using ProgressLogging
using StaticArrays
using Optim  # required for an extension

for n in [2, 3, 4]
    # Choose f from: Rastringin, alpine1, Ackley
    f = Ackley

    reset_timer!(Globtim._TO)

    # Constants and Parameters
    a, b = 1, 1
    scale_factor = a / b
    rand_center = zeros(Float64, n)
    d = 9 # initial degree
    SMPL = 20 # Number of samples
    TR =
        test_input(f, dim = n, center = rand_center, GN = SMPL, sample_range = scale_factor)

    pol_cheb = Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision)
    @polyvar(x[1:n]) # Define polynomial ring
    real_pts_cheb = solve_polynomial_system(
        x,
        n,
        d,
        pol_cheb.coeffs;
        basis = pol_cheb.basis,
        precision = pol_cheb.precision,
        normalized = pol_cheb.normalized,
    )

    df_cheb = process_crit_pts(real_pts_cheb, f, TR)

    df_cheb, df_min_cheb = Globtim.analyze_critical_points(f, df_cheb, TR, tol_dist = 0.5)

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


==============================================
Function: Ackley
Configuration:
n = 4
d = 9
scale_factor = 1.0
SMPL = 20
L2-norm (cheb): 0.2940375130229731

─────────────────────────────────────────────────────────────────────────────────────────
                                                Time                    Allocations
                                       ───────────────────────   ────────────────────────
           Tot / % measured:                4.69h / 100.0%            573GiB / 100.0%

Section                        ncalls     time    %tot     avg     alloc    %tot      avg
─────────────────────────────────────────────────────────────────────────────────────────
Constructor                         1    4.68h   99.7%   4.68h    571GiB   99.6%   571GiB
  MainGenerate                      1    4.68h   99.7%   4.68h    571GiB   99.6%   571GiB
    norm_computation                1    4.68h   99.7%   4.68h    570GiB   99.4%   570GiB
    lambda_vandermonde              1    8.76s    0.1%   8.76s   1.04GiB    0.2%  1.04GiB
    generate_grid                   1    493ms    0.0%   493ms    129MiB    0.0%   129MiB
    evaluation                      1   67.1ms    0.0%  67.1ms   8.64MiB    0.0%  8.64MiB
    linear_solve_vandermonde        1   59.8ms    0.0%  59.8ms   3.93MiB    0.0%  3.93MiB
solve_polynomial_system             1    46.0s    0.3%   46.0s   2.32GiB    0.4%  2.32GiB
analyze_critical_points             1    333ms    0.0%   333ms   65.3MiB    0.0%  65.3MiB
test_input                          1    770ns    0.0%   770ns      208B    0.0%     208B
─────────────────────────────────────────────────────────────────────────────────────────

=#
