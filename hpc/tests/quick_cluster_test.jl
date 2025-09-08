#!/usr/bin/env julia
# Quick Cluster Test for Issue #53
# Minimal test to verify StaticArrays works after Pkg.instantiate()

using Dates
println("Quick Issue #53 Test - $(now())")
println("Testing StaticArrays availability after Pkg.instantiate()")

# Apply the fix
using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
Pkg.instantiate()

# Test the dependency that was failing
using StaticArrays
using LinearAlgebra

# Simple test that would have failed in jobs 59780287, 59780288
v = SVector(1.0, 2.0, 3.0, 4.0)
println("✅ StaticArrays working: norm(SVector) = $(norm(v))")

# Test Globtim integration
using Globtim
using DynamicPolynomials

@polyvar x[1:2]
println("✅ Globtim integration working")

println("SUCCESS: Issue #53 resolved!")
exit(0)