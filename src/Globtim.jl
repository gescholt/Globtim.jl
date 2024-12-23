module Globtim


# Exported functions and variables
export test_input, ApproxPoly,
    camel, CrossInTray, Deuflhard, noisy_Deuflhard, random_noise,
    bivariate_gaussian_noise, tref, Ackley, camel_3, camel, shubert,
    dejong5, easom, init_gaussian_params, rand_gaussian, HolderTable,
    CrossInTray, Deuflhard, noisy_Deuflhard, old_alpine1, shubert_4d,
    camel_4d, camel_3_by_3, cosine_mixture, camel_3_6d, Csendes,
    alpine1, alpine2, GaussianParams,
    calculate_samples,
    create_test_input,
    Constructor, solve_polynomial_system, msolve_polynomial_system,
    process_critical_points, msolve_parser, process_output_file, plot_polyapprox

using CSV
using DataFrames
using DynamicPolynomials
using LinearSolve
using LinearAlgebra
using Distributions
using GLMakie


import HomotopyContinuation: solve, real_solutions, System


include("LibFunctions.jl") #list of test functions. 
include("Structures.jl") # list of structures used in the code.
include("Samples.jl") #functions to generate samples.
include("OrthogPoly.jl") #functions to generate orthogonal polynomials.
include("ApproxConstruct.jl") # Construct Vandermonde like matrix.
include("Main_Gen.jl") #functions to construct polynomial approximations.
include("ParsingOutputs.jl") #functions to parse the output of the polynomial approximation.


end