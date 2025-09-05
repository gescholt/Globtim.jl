#!/usr/bin/env julia
"""
Debug script to understand what solve_polynomial_system actually returns
"""

using Pkg
Pkg.activate(dirname(@__DIR__))

using Globtim
using DynamicPolynomials: @polyvar

println("Debugging solve_polynomial_system return values...")

@polyvar y[1:2]

# Simple 2D polynomial coefficients
degree = 2
n_coeffs = binomial(2 + degree, degree)  
coeffs_2d = ones(Float64, n_coeffs)
coeffs_2d[2] = 0.0

println("Input:")
println("  Variables: $y") 
println("  Dimension: 2")
println("  Degree: $degree")
println("  Coefficients: $coeffs_2d")
println("  Basis: chebyshev")
println("  Precision: Float64Precision")

try
    result = Globtim.solve_polynomial_system(
        y, 2, (:one_d_for_all, degree), coeffs_2d;
        basis = :chebyshev,
        precision = Float64Precision,
        return_system = true
    )
    
    println("\nResult structure:")
    println("  Type: $(typeof(result))")
    println("  Length: $(length(result))")
    
    if length(result) >= 1
        println("  First element type: $(typeof(result[1]))")
        println("  First element: $(result[1])")
    end
    
    if length(result) >= 2  
        println("  Second element type: $(typeof(result[2]))")
        println("  Second element: $(result[2])")
        
        if isa(result[2], Tuple)
            println("  Second element is tuple, length: $(length(result[2]))")
            for (i, elem) in enumerate(result[2])
                println("    Element $i type: $(typeof(elem))")
                println("    Element $i: $elem")
            end
        end
    end
    
    # Try to understand the expected unpacking
    if isa(result, Tuple) && length(result) == 2
        real_pts, second_part = result
        println("\nUnpacked:")
        println("  real_pts type: $(typeof(real_pts))")
        println("  real_pts: $real_pts")
        println("  second_part type: $(typeof(second_part))")
        println("  second_part: $second_part")
        
        if isa(second_part, Tuple) && length(second_part) == 2
            system, nsols = second_part
            println("  system type: $(typeof(system))")
            println("  nsols type: $(typeof(nsols))")
            println("  nsols value: $nsols")
        end
    end
    
catch e
    println("\nError occurred: $e")
    println("Stacktrace:")
    for (exc, bt) in Base.catch_stack()
        println("  $exc")
    end
end