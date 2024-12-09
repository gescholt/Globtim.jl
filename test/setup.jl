using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.develop(PackageSpec(path=dirname(dirname(@__FILE__))))

using Globtim
using ModelingToolkit, DifferentialEquations
using DynamicPolynomials, DataStructures, LinearAlgebra
using HomotopyContinuation, ProgressLogging, DataFrames
include("test_helper.jl")
