module Globtim

export MainGenerate, ApproxPoly, main_nd, process_output_file, parse_point, camel, CrossInTray, Deuflhard

using CSV
using DataFrames
using DynamicPolynomials
using LinearSolve
using LinearAlgebra

include("lib_func.jl")
include("Samples.jl")
include("ApproxConstruct.jl")
include("main_gen.jl")

end