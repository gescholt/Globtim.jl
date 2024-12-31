using Pkg
Pkg.activate("../../.")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging


# SMPL = calculate_samples(binomial(n + d, d), delta, alpha)#Number of samples is too LinearAlgebra


ms_cheb = msolve_polynomial_system(pol_cheb, x; n=2, basis=:chebyshev, bigint=true)