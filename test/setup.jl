using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.develop(PackageSpec(path=dirname(dirname(@__FILE__))))
using Globtim, Test, ModelingToolkit, DifferentialEquations, Random
using DataStructures, LinearAlgebra, DynamicPolynomials
using HomotopyContinuation, ProgressLogging, DataFrames
include("test_helper.jl")
