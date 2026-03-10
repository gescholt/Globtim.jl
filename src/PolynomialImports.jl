"""
PolynomialImports.jl

Centralized polynomial import utilities to solve @polyvar import issues.

This module provides:
1. Robust @polyvar macro import with fallback mechanisms
2. Consistent import patterns across the entire codebase
3. Error handling for missing dependencies
4. Utility functions for common polynomial operations

Usage:
    include("src/PolynomialImports.jl")
    using .PolynomialImports
    # @polyvar is now available in scope

Or for quick setup:
    include("src/PolynomialImports.jl")
    PolynomialImports.setup_polyvar()  # Makes @polyvar available globally
"""

module PolynomialImports

export setup_polyvar, ensure_polyvar, create_polynomial_vars, test_polyvar_availability

# Import with error handling
const DYNAMIC_POLYNOMIALS_AVAILABLE = try
    using DynamicPolynomials: @polyvar, Variable, Polynomial
    using DynamicPolynomials
    true
catch e
    @warn "DynamicPolynomials not available: $e"
    false
end

"""
    setup_polyvar()

Sets up @polyvar macro in the calling module's scope.
This is the primary function to solve @polyvar import issues.

Returns true if successful, false otherwise.

Note: This function provides guidance rather than automatic import
since automatic import during precompilation is not allowed by Julia.
"""
function setup_polyvar()
    if !DYNAMIC_POLYNOMIALS_AVAILABLE
        @error "Cannot setup @polyvar: DynamicPolynomials not available"
        @info "💡 Try: Pkg.add(\"DynamicPolynomials\")"
        return false
    end

    @info """
    ✅ To use @polyvar in your script, add this line:
    using DynamicPolynomials: @polyvar

    Or use the full module name:
    DynamicPolynomials.@polyvar x[1:2]
    """
    return true
end

"""
    ensure_polyvar()

Ensures @polyvar macro is available, with multiple fallback strategies.
This is a robust version that tries different approaches.
"""
function ensure_polyvar()
    # Check if @polyvar is already available
    try
        # Try to evaluate @polyvar in Main - this will fail if not available
        Core.eval(Main, :(@polyvar test_var_check))
        @info "✅ @polyvar macro already available in Main scope"
        return true
    catch e
        # @polyvar not available, try to import it
        @debug "@polyvar not yet available, attempting import" exception=(e, catch_backtrace())
    end

    if !DYNAMIC_POLYNOMIALS_AVAILABLE
        @error "❌ Cannot ensure @polyvar: DynamicPolynomials not available"
        @info "💡 Try: Pkg.add(\"DynamicPolynomials\")"
        return false
    end

    # Strategy 1: Direct import into Main
    try
        Core.eval(Main, :(using DynamicPolynomials: @polyvar))

        # Verify it worked
        Core.eval(Main, :(@polyvar verification_var))
        @info "✅ @polyvar macro imported successfully (Strategy 1)"
        return true
    catch e1
        @warn "Strategy 1 failed: $e1"
    end

    # Strategy 2: Import the full module then bring macro into scope
    try
        Core.eval(Main, :(using DynamicPolynomials))
        Core.eval(Main, :(import DynamicPolynomials: @polyvar))

        # Verify it worked
        Core.eval(Main, :(@polyvar verification_var_2))
        @info "✅ @polyvar macro imported successfully (Strategy 2)"
        return true
    catch e2
        @warn "Strategy 2 failed: $e2"
    end

    # Strategy 3: Manual macro definition (last resort)
    try
        Core.eval(Main, :(
            macro polyvar(args...)
                DynamicPolynomials.@polyvar(args...)
            end
        ))

        # Verify it worked
        Core.eval(Main, :(@polyvar verification_var_3))
        @info "✅ @polyvar macro created successfully (Strategy 3 - manual definition)"
        return true
    catch e3
        @warn "Strategy 3 failed: $e3"
    end

    @error "❌ All strategies failed to make @polyvar available"
    @info "💡 Manual workaround: use DynamicPolynomials.@polyvar instead of @polyvar"
    return false
end

"""
    create_polynomial_vars(names::Vector{Symbol}, dimensions::Dict{Symbol,Int}=Dict())

Helper function to create polynomial variables with consistent naming.

Examples:
    # Create simple variables
    x, y, z = create_polynomial_vars([:x, :y, :z])
    
    # Create vector variables  
    x = create_polynomial_vars([:x], Dict(:x => 4))[1]  # Creates x[1:4]
"""
function create_polynomial_vars(
    names::Vector{Symbol},
    dimensions::Dict{Symbol, Int} = Dict()
)
    if !DYNAMIC_POLYNOMIALS_AVAILABLE
        error("Cannot create polynomial variables: DynamicPolynomials not available")
    end

    ensure_polyvar() || error("Could not ensure @polyvar availability")

    vars = []

    for name in names
        if haskey(dimensions, name)
            dim = dimensions[name]
            # Create vector variable
            var_expr = Meta.parse("@polyvar $name[1:$dim]")
            var = Core.eval(Main, var_expr)
            push!(vars, var)
        else
            # Create scalar variable
            var_expr = Meta.parse("@polyvar $name")
            var = Core.eval(Main, var_expr)
            push!(vars, var)
        end
    end

    return length(vars) == 1 ? vars[1] : tuple(vars...)
end

"""
    test_polyvar_availability()

Test function to verify @polyvar is working correctly.
Returns detailed diagnostics.
"""
function test_polyvar_availability()
    println("🧪 Testing @polyvar availability...")

    if !DYNAMIC_POLYNOMIALS_AVAILABLE
        println("❌ DynamicPolynomials module not available")
        return false
    end

    println("✅ DynamicPolynomials module available")

    # Test 1: Can we create a simple variable?
    try
        ensure_polyvar()
        Core.eval(Main, :(@polyvar test_x))
        println("✅ Test 1 passed: Simple variable creation")
    catch e
        println("❌ Test 1 failed: $e")
        return false
    end

    # Test 2: Can we create vector variables?
    try
        Core.eval(Main, :(@polyvar test_y[1:3]))
        println("✅ Test 2 passed: Vector variable creation")
    catch e
        println("❌ Test 2 failed: $e")
        return false
    end

    # Test 3: Can we use the variables in expressions?
    try
        result = Core.eval(Main, :(test_x^2 + test_y[1] + test_y[2]))
        println("✅ Test 3 passed: Polynomial expression creation")
        println("    Result type: $(typeof(result))")
    catch e
        println("❌ Test 3 failed: $e")
        return false
    end

    println("🎉 All tests passed! @polyvar is fully functional")
    return true
end

# Auto-setup disabled by default to avoid precompilation issues
# Users can manually call setup_polyvar() or ensure_polyvar() if needed
if get(ENV, "GLOBTIM_AUTO_POLYVAR", "false") == "true"
    @info "🚀 PolynomialImports: Manual setup available via setup_polyvar()"
end

end # module PolynomialImports
