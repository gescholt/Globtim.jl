using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.develop(PackageSpec(path=dirname(dirname(@__FILE__))))

using Globtim
using ModelingToolkit, DifferentialEquations
using DynamicPolynomials, DataStructures, LinearAlgebra
using HomotopyContinuation, ProgressLogging, DataFrames

include("test_helper.jl")
# include("model_parameters.jl")
include("short_config.jl")
include("lotka_volterra_model.jl")
include("parameter_sweep.jl")

