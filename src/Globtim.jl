module Globtim

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end Agents


# Exported functions and variables
export MainGenerate, ApproxPoly, test_input, main_nd, process_output_file, parse_point, camel, CrossInTray, Deuflhard, noisy_Deuflhard,
    random_noise, bivariate_gaussian_noise, tref, Ackley, camel_3, camel, shubert, dejong5, easom, init_gaussian_params,
    rand_gaussian, HolderTable, CrossInTray, Deuflhard, noisy_Deuflhard, old_alpine1, shubert_4d, camel_4d, camel_3_by_3,
    cosine_mixture, camel_3_6d, Csendes, alpine1, alpine2, create_test_input, Constructor, SupportGen, ChebyshevPolyExact,
    GaussianParams, uniform_grid, lambda_vandermonde, 
    symbolic_legendre, evaluate_legendre, generate_grid


using CSV
using DataFrames
using DynamicPolynomials
using LinearSolve
using LinearAlgebra
using Distributions


include("lib_func.jl") #list of test functions. 
include("Samples.jl")
include("ApproxConstruct.jl")
include("main_gen.jl")
include("SymbolicLegendre.jl")
# include("legendre_poly.jl")

end