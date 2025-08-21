"""
msolve Integration for AdaptivePrecision Polynomials

This module provides utilities to:
1. Convert AdaptivePrecision polynomials to msolve format
2. Generate msolve input files
3. Execute msolve and parse results
4. Compare msolve vs HomotopyContinuation performance

Usage:
    include("Examples/msolve_integration.jl")
    export_to_msolve(polynomial, "output.ms")
"""

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using Printf
using JSON

println("🔧 msolve Integration System")
println("=" ^ 40)

# ============================================================================
# MSOLVE FORMAT CONVERSION
# ============================================================================

"""
    polynomial_to_msolve_string(poly, var_names=["x1", "x2", "x3", "x4"])

Convert polynomial to msolve input string format.
"""
function polynomial_to_msolve_string(poly, var_names=["x1", "x2", "x3", "x4"])
    @polyvar x[1:4]
    
    # Convert to monomial basis if needed
    if isa(poly, ApproxPoly)
        mono_poly = to_exact_monomial_basis(poly, variables=x)
    else
        mono_poly = poly
    end
    
    terms_strings = []
    
    for term in terms(mono_poly)
        coeff = coefficient(term)
        mono = monomial(term)
        
        # Convert coefficient to rational string
        if isa(coeff, Rational)
            coeff_str = string(coeff)
        else
            # Convert to rational with high precision
            rational_coeff = rationalize(Float64(coeff), tol=1e-15)
            coeff_str = string(rational_coeff)
        end
        
        # Handle coefficient formatting
        if coeff_str == "1"
            coeff_str = ""
        elseif coeff_str == "-1"
            coeff_str = "-"
        end
        
        # Convert monomial to msolve format
        mono_str = monomial_to_msolve_string(mono, var_names)
        
        # Combine coefficient and monomial
        if mono_str == "1"
            term_str = coeff_str == "" ? "1" : coeff_str
        else
            term_str = coeff_str * mono_str
        end
        
        push!(terms_strings, term_str)
    end
    
    # Join terms with + (handle signs properly)
    result = join(terms_strings, " + ")
    result = replace(result, "+ -" => "- ")
    
    return result
end

"""
    monomial_to_msolve_string(mono, var_names)

Convert a monomial to msolve variable format.
"""
function monomial_to_msolve_string(mono, var_names)
    if isa(mono, Number) && mono == 1
        return "1"
    end
    
    # Extract exponents
    exponents = exponents(mono)
    
    if all(exp == 0 for exp in exponents)
        return "1"
    end
    
    var_parts = []
    for (i, exp) in enumerate(exponents)
        if exp > 0
            if exp == 1
                push!(var_parts, var_names[i])
            else
                push!(var_parts, "$(var_names[i])^$(exp)")
            end
        end
    end
    
    return join(var_parts, "*")
end

"""
    export_gradient_system_to_msolve(poly, filename; var_names=["x1", "x2", "x3", "x4"])

Export gradient system to msolve input file.
"""
function export_gradient_system_to_msolve(poly, filename; var_names=["x1", "x2", "x3", "x4"])
    println("📝 Exporting gradient system to msolve format...")
    
    @polyvar x[1:4]
    
    # Convert to monomial basis if needed
    if isa(poly, ApproxPoly)
        mono_poly = to_exact_monomial_basis(poly, variables=x)
    else
        mono_poly = poly
    end
    
    # Compute gradient
    grad_polys = [differentiate(mono_poly, x[i]) for i in 1:4]
    
    # Convert each gradient component to msolve string
    grad_strings = [polynomial_to_msolve_string(grad_poly, var_names) for grad_poly in grad_polys]
    
    # Create msolve input file
    open(filename, "w") do file
        # Header
        println(file, "# msolve input file")
        println(file, "# Generated from AdaptivePrecision polynomial")
        println(file, "# Variables: $(join(var_names, ", "))")
        println(file, "# Gradient system for critical points")
        println(file, "")
        
        # Variable declaration
        println(file, "$(join(var_names, ", "))")
        println(file, "")
        
        # Polynomial system (gradient = 0)
        for (i, grad_str) in enumerate(grad_strings)
            println(file, "$(grad_str)")
        end
    end
    
    @printf "  Exported %d equations to %s\n" length(grad_strings) filename
    @printf "  Variables: %s\n" join(var_names, ", ")
    
    return grad_strings
end

"""
    run_msolve(input_file, output_file="msolve_output.txt")

Execute msolve on input file and return results.
"""
function run_msolve(input_file, output_file="msolve_output.txt")
    println("🚀 Running msolve...")
    
    # Check if msolve is available
    try
        run(`which msolve`)
    catch
        println("❌ msolve not found in PATH")
        println("   Please install msolve: https://github.com/algebraic-solving/msolve")
        return nothing
    end
    
    # Run msolve
    start_time = time()
    
    try
        # Execute msolve with rational arithmetic
        cmd = `msolve -f $(input_file) -o $(output_file) -p 0`
        run(cmd)
        
        solve_time = time() - start_time
        @printf "  msolve completed in %.4fs\n" solve_time
        
        # Parse output
        solutions = parse_msolve_output(output_file)
        
        return Dict(
            :solve_time => solve_time,
            :solutions => solutions,
            :output_file => output_file,
            :success => true
        )
        
    catch e
        solve_time = time() - start_time
        println("❌ msolve execution failed: $e")
        
        return Dict(
            :solve_time => solve_time,
            :success => false,
            :error => string(e)
        )
    end
end

"""
    parse_msolve_output(filename)

Parse msolve output file and extract solutions.
"""
function parse_msolve_output(filename)
    if !isfile(filename)
        println("⚠️  Output file not found: $filename")
        return []
    end
    
    solutions = []
    
    try
        content = read(filename, String)
        lines = split(content, '\n')
        
        # Simple parsing - this may need refinement based on msolve output format
        in_solutions = false
        current_solution = []
        
        for line in lines
            line = strip(line)
            
            if contains(line, "SOLUTIONS") || contains(line, "solutions")
                in_solutions = true
                continue
            end
            
            if in_solutions && !isempty(line)
                # Parse solution coordinates
                # This is a simplified parser - may need adjustment
                if contains(line, "[") && contains(line, "]")
                    # Extract coordinates from line like [1/2, -3/4, 0, 1]
                    coords_str = match(r"\[(.*)\]", line)
                    if coords_str !== nothing
                        coords = split(coords_str.captures[1], ",")
                        solution = [parse_rational_or_float(strip(c)) for c in coords]
                        push!(solutions, solution)
                    end
                end
            end
        end
        
        @printf "  Parsed %d solutions from %s\n" length(solutions) filename
        
    catch e
        println("⚠️  Error parsing msolve output: $e")
    end
    
    return solutions
end

"""
    parse_rational_or_float(s)

Parse string as rational or float.
"""
function parse_rational_or_float(s)
    s = strip(s)
    
    if contains(s, "/")
        # Parse as rational
        parts = split(s, "/")
        if length(parts) == 2
            return parse(Int, parts[1]) // parse(Int, parts[2])
        end
    end
    
    # Parse as float
    return parse(Float64, s)
end

# ============================================================================
# COMPARISON SYSTEM
# ============================================================================

"""
    compare_msolve_vs_homotopy(poly, threshold=1e-10)

Compare msolve vs HomotopyContinuation for critical point solving.
"""
function compare_msolve_vs_homotopy(poly, threshold=1e-10)
    println("\n🔍 Comparing msolve vs HomotopyContinuation")
    println("=" ^ 50)
    
    # Create sparse version
    sparse_poly, sparsity = create_sparse_polynomial(poly, threshold)
    
    # Export to msolve format
    msolve_file = "temp_gradient_system.ms"
    export_gradient_system_to_msolve(sparse_poly, msolve_file)
    
    # Run msolve
    msolve_result = run_msolve(msolve_file)
    
    # Run HomotopyContinuation (from critical_points_4d.jl)
    if @isdefined(solve_critical_points_homotopy)
        hc_result = solve_critical_points_homotopy(sparse_poly, :sparse)
    else
        println("⚠️  HomotopyContinuation solver not available")
        hc_result = Dict(:success => false, :error => "Function not loaded")
    end
    
    # Display comparison
    println("\n📊 Solver Comparison:")
    println("┌─────────────────┬──────────┬───────────┬─────────────┐")
    println("│ Solver          │ Time (s) │ Solutions │ Status      │")
    println("├─────────────────┼──────────┼───────────┼─────────────┤")
    
    if msolve_result !== nothing && msolve_result[:success]
        @printf "│ msolve          │ %8.4f │ %9d │ ✅ Success   │\n" msolve_result[:solve_time] length(msolve_result[:solutions])
    else
        @printf "│ msolve          │        - │         - │ ❌ Failed    │\n"
    end
    
    if hc_result[:success]
        @printf "│ HomotopyCont.   │ %8.4f │ %9d │ ✅ Success   │\n" hc_result[:solve_time] hc_result[:real_solutions]
    else
        @printf "│ HomotopyCont.   │        - │         - │ ❌ Failed    │\n"
    end
    
    println("└─────────────────┴──────────┴───────────┴─────────────┘")
    
    # Cleanup
    if isfile(msolve_file)
        rm(msolve_file)
    end
    
    return Dict(
        :msolve => msolve_result,
        :homotopy => hc_result,
        :sparsity => sparsity
    )
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    validate_rational_conversion(poly, tolerance=1e-12)

Validate that rational conversion preserves polynomial accuracy.
"""
function validate_rational_conversion(poly, tolerance=1e-12)
    println("🔍 Validating rational conversion...")
    
    @polyvar x[1:4]
    mono_poly = to_exact_monomial_basis(poly, variables=x)
    
    # Convert to rationals and back
    coeffs = [coefficient(t) for t in terms(mono_poly)]
    rational_coeffs = [rationalize(Float64(c), tol=1e-15) for c in coeffs]
    float_coeffs = [Float64(r) for r in rational_coeffs]
    
    # Compare
    errors = [abs(Float64(orig) - converted) for (orig, converted) in zip(coeffs, float_coeffs)]
    max_error = maximum(errors)
    avg_error = mean(errors)
    
    @printf "  Max error: %.2e\n" max_error
    @printf "  Avg error: %.2e\n" avg_error
    
    if max_error < tolerance
        println("  ✅ Conversion within tolerance")
        return true
    else
        println("  ⚠️  Conversion exceeds tolerance")
        return false
    end
end

println("\n💡 msolve integration functions loaded:")
println("  - export_gradient_system_to_msolve(poly, filename)")
println("  - run_msolve(input_file)")
println("  - compare_msolve_vs_homotopy(poly)")
println("  - validate_rational_conversion(poly)")
println("\n🚀 Ready for msolve integration!")
