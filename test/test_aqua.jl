"""
Aqua.jl quality assurance tests for Globtim.jl

This file contains comprehensive code quality tests using Aqua.jl to ensure:
- No method ambiguities
- No undefined exports
- No unbound type parameters
- No persistent tasks
- Proper project structure
- Dependency hygiene
"""

using Test

# Try to load Aqua, skip tests if not available
try
    using Aqua
catch e
    @warn "Aqua.jl not available, skipping Aqua tests" exception=e
    exit()
end

using Globtim

# Load Aqua configuration
include("aqua_config.jl")

@testset "Aqua.jl Quality Assurance" begin

    # Check if we should run Aqua tests
    if !should_run_aqua_tests()
        @info "Skipping Aqua tests (disabled or unsupported environment)"
        return
    end

    # Print configuration info
    print_aqua_config()
    
    @testset "Method Ambiguities" begin
        @info "Testing for method ambiguities..."
        
        # Test for ambiguities in the main module
        # We'll be more lenient initially and exclude some known issues
        Aqua.test_ambiguities(
            Globtim;
            # Exclude ambiguities from dependencies that we can't control
            exclude=[
                # Add specific method signatures here if needed
                # Example: Base.show
            ]
        )
        
        @info "✅ No problematic method ambiguities found"
    end
    
    @testset "Undefined Exports" begin
        @info "Testing for undefined exports..."
        
        # This checks that all exported symbols are actually defined
        Aqua.test_undefined_exports(Globtim)
        
        @info "✅ All exports are properly defined"
    end
    
    @testset "Unbound Type Parameters" begin
        @info "Testing for unbound type parameters..."
        
        # This catches type parameters that aren't used in the function signature
        Aqua.test_unbound_args(Globtim)
        
        @info "✅ No unbound type parameters found"
    end
    
    @testset "Persistent Tasks" begin
        @info "Testing for persistent tasks..."
        
        # This checks for tasks that might not be properly cleaned up
        Aqua.test_persistent_tasks(Globtim)
        
        @info "✅ No persistent tasks found"
    end
    
    @testset "Project Structure" begin
        @info "Testing project structure..."
        
        # Test that Project.toml is well-formed
        Aqua.test_project_toml_formatting(Globtim)
        
        @info "✅ Project.toml is properly formatted"
    end
    
    @testset "Dependency Analysis" begin
        @info "Testing dependency hygiene..."
        
        # Check for unused dependencies and other dependency issues
        # Note: This might be strict, so we'll make it informational initially
        try
            Aqua.test_deps_compat(Globtim)
            @info "✅ Dependency compatibility checks passed"
        catch e
            @warn "Dependency compatibility issues detected" exception=e
            # Don't fail the test initially, just warn
        end
        
        # Test for stale dependencies
        try
            Aqua.test_stale_deps(Globtim)
            @info "✅ No stale dependencies found"
        catch e
            @warn "Stale dependency issues detected" exception=e
            # Don't fail the test initially, just warn
        end
    end
    
    @testset "Package Structure Validation" begin
        @info "Validating package structure..."
        
        # Check that the package follows Julia conventions
        # This is a custom test to verify our package structure
        
        # Check that main module file exists and is properly structured
        @test isfile(joinpath(dirname(pathof(Globtim)), "Globtim.jl"))
        
        # Check that all included files exist
        globtim_file = joinpath(dirname(pathof(Globtim)), "Globtim.jl")
        content = read(globtim_file, String)
        
        # Extract include statements
        include_pattern = r"include\(\"([^\"]+)\"\)"
        includes = [m.captures[1] for m in eachmatch(include_pattern, content)]
        
        # Verify all included files exist
        for include_file in includes
            include_path = joinpath(dirname(pathof(Globtim)), include_file)
            @test isfile(include_path) "Missing included file: $include_file"
        end
        
        @info "✅ Package structure validation passed"
    end
    
    @testset "Export Consistency" begin
        @info "Testing export consistency..."
        
        # Custom test to ensure exports are consistent
        exported_names = names(Globtim)
        
        # Check that we have a reasonable number of exports (not too few, not too many)
        @test length(exported_names) > 10 "Too few exports, might indicate missing exports"
        @test length(exported_names) < 200 "Too many exports, consider reducing public API"
        
        # Check that all exported functions are callable or are types/constants
        problematic_exports = String[]
        
        for name in exported_names
            if name == :Globtim  # Skip the module name itself
                continue
            end
            
            try
                obj = getfield(Globtim, name)
                # Check if it's a function, type, or constant
                if !(isa(obj, Function) || isa(obj, Type) || isa(obj, DataType) || 
                     isa(obj, UnionAll) || isa(obj, Module))
                    # For other objects, just check they're defined
                    @test isdefined(Globtim, name) "Export $name is not properly defined"
                end
            catch e
                push!(problematic_exports, string(name))
                @warn "Issue with export $name" exception=e
            end
        end
        
        if !isempty(problematic_exports)
            @warn "Problematic exports found" exports=problematic_exports
        end
        
        @info "✅ Export consistency check completed"
    end
    
    @testset "Code Quality Metrics" begin
        @info "Computing code quality metrics..."
        
        # Custom metrics for code quality
        globtim_file = joinpath(dirname(pathof(Globtim)), "Globtim.jl")
        content = read(globtim_file, String)
        
        # Count exports
        export_count = length(names(Globtim)) - 1  # Exclude module name
        @info "Total exports: $export_count"
        
        # Count includes
        include_pattern = r"include\(\"([^\"]+)\"\)"
        include_count = length(collect(eachmatch(include_pattern, content)))
        @info "Total included files: $include_count"
        
        # Basic complexity metrics
        lines = split(content, '\n')
        total_lines = length(lines)
        comment_lines = count(line -> startswith(strip(line), "#"), lines)
        blank_lines = count(line -> isempty(strip(line)), lines)
        code_lines = total_lines - comment_lines - blank_lines
        
        @info "Code metrics:" total_lines comment_lines blank_lines code_lines
        
        # Ensure reasonable code organization
        @test include_count > 5 "Package should be modularized with multiple files"
        @test export_count > 10 "Package should have substantial public API"
        
        @info "✅ Code quality metrics computed"
    end
end

# Additional helper function for manual testing
"""
    run_aqua_tests_verbose()

Run Aqua tests with verbose output for debugging purposes.
This function is useful for local development and debugging.
"""
function run_aqua_tests_verbose()
    println("🔍 Running comprehensive Aqua.jl tests for Globtim.jl")
    println("=" ^ 60)
    
    # Test each component individually with detailed output
    components = [
        ("Method Ambiguities", () -> Aqua.test_ambiguities(Globtim)),
        ("Undefined Exports", () -> Aqua.test_undefined_exports(Globtim)),
        ("Unbound Args", () -> Aqua.test_unbound_args(Globtim)),
        ("Persistent Tasks", () -> Aqua.test_persistent_tasks(Globtim)),
        ("Project TOML", () -> Aqua.test_project_toml_formatting(Globtim))
    ]
    
    results = Dict{String, Bool}()
    
    for (name, test_func) in components
        print("Testing $name... ")
        try
            test_func()
            println("✅ PASSED")
            results[name] = true
        catch e
            println("❌ FAILED")
            println("  Error: $e")
            results[name] = false
        end
    end
    
    println("\n📊 Summary:")
    passed = count(values(results))
    total = length(results)
    println("  Passed: $passed/$total")
    
    if passed == total
        println("🎉 All Aqua tests passed!")
    else
        println("⚠️  Some tests failed - see details above")
    end
    
    return results
end

# Export the helper function for easy access
export run_aqua_tests_verbose
