#!/usr/bin/env julia
"""
Standalone script to run Aqua.jl tests for Globtim.jl

This script can be run independently to check code quality without running
the full test suite. Useful for development and CI/CD integration.

Usage:
    julia scripts/run-aqua-tests.jl [--verbose] [--fix-issues]

Options:
    --verbose     Show detailed output for each test
    --fix-issues  Attempt to provide suggestions for fixing issues
    --ci          Run in CI mode (exit with error code on failure)
"""

using Pkg

# Setup environment - use test environment if available
if isfile("test/Project.toml")
    println("ℹ️  Using test environment for Aqua.jl...")
    Pkg.activate("test")

    # Ensure Aqua is available
    try
        import Aqua
    catch
        println("📦 Installing Aqua.jl in test environment...")
        Pkg.add("Aqua")
        Pkg.instantiate()
    end
else
    println("ℹ️  Using main environment...")
    Pkg.activate(".")

    # Check if Aqua is available, add if needed
    try
        import Aqua
    catch
        println("📦 Adding Aqua.jl temporarily...")
        Pkg.add("Aqua")
    end
end

# Load packages
using Aqua
using Globtim

# Parse command line arguments
verbose = "--verbose" in ARGS
fix_issues = "--fix-issues" in ARGS
ci_mode = "--ci" in ARGS

"""
Run a single Aqua test with error handling
"""
function run_aqua_test(test_name::String, test_func::Function; verbose=false)
    if verbose
        print("🔍 Testing $test_name... ")
    end
    
    try
        test_func()
        if verbose
            println("✅ PASSED")
        end
        return (true, nothing)
    catch e
        if verbose
            println("❌ FAILED")
            println("   Error: $e")
        end
        return (false, e)
    end
end

"""
Provide suggestions for fixing common Aqua issues
"""
function suggest_fixes(test_name::String, error)
    suggestions = Dict(
        "Method Ambiguities" => """
        Method ambiguities can be fixed by:
        1. Adding more specific type annotations to method signatures
        2. Reordering method definitions (more specific first)
        3. Using @nospecialize for performance-critical generic methods
        4. Consider if the ambiguity is actually problematic for your use case
        """,
        
        "Undefined Exports" => """
        Undefined exports can be fixed by:
        1. Removing the export statement if the function/type is not defined
        2. Adding the missing function/type definition
        3. Checking for typos in export names
        4. Ensuring all included files are properly loaded
        """,
        
        "Unbound Args" => """
        Unbound type parameters can be fixed by:
        1. Using the type parameter in the function signature
        2. Removing unused type parameters
        3. Adding type constraints where appropriate
        4. Consider if the type parameter is actually needed
        """,
        
        "Persistent Tasks" => """
        Persistent tasks can be fixed by:
        1. Properly closing/cleaning up background tasks
        2. Using try-finally blocks for resource cleanup
        3. Avoiding global task variables
        4. Check for infinite loops or hanging operations
        """,
        
        "Project TOML" => """
        Project.toml formatting issues can be fixed by:
        1. Running Pkg.resolve() to update dependencies
        2. Checking for proper version constraints
        3. Ensuring all dependencies are actually used
        4. Removing unused dependencies
        """
    )
    
    return get(suggestions, test_name, "No specific suggestions available for this test.")
end

"""
Main function to run all Aqua tests
"""
function main()
    println("🔍 Globtim.jl Code Quality Analysis with Aqua.jl")
    println("=" ^ 55)
    
    # Define all tests to run
    tests = [
        ("Method Ambiguities", () -> Aqua.test_ambiguities(Globtim)),
        ("Undefined Exports", () -> Aqua.test_undefined_exports(Globtim)),
        ("Unbound Args", () -> Aqua.test_unbound_args(Globtim)),
        # Skip persistent tasks test temporarily due to version constraint issues
        # ("Persistent Tasks", () -> Aqua.test_persistent_tasks(Globtim)),
        ("Project TOML", () -> begin
            if isdefined(Aqua, :test_project_toml_formatting)
                Aqua.test_project_toml_formatting(Globtim)
            else
                println("  (Skipped - not available in this Aqua version)")
                return true
            end
        end)
    ]
    
    # Optional tests that might be too strict initially
    optional_tests = [
        ("Dependency Compatibility", () -> Aqua.test_deps_compat(Globtim)),
        # Skip stale deps test due to false positives for development tools
        # ("Stale Dependencies", () -> Aqua.test_stale_deps(Globtim))
    ]
    
    results = Dict{String, Tuple{Bool, Any}}()
    
    # Run core tests
    println("📋 Running core quality tests...")
    for (test_name, test_func) in tests
        results[test_name] = run_aqua_test(test_name, test_func; verbose=verbose)
    end
    
    # Run optional tests (don't fail on these)
    println("\n📋 Running optional tests...")
    for (test_name, test_func) in optional_tests
        result = run_aqua_test(test_name, test_func; verbose=verbose)
        if !result[1] && verbose
            println("   ⚠️  Optional test failed - this may not be critical")
        end
        results[test_name] = result
    end
    
    # Summary
    println("\n📊 Test Results Summary:")
    println("-" ^ 30)
    
    core_tests = [name for (name, _) in tests]
    core_passed = sum(results[name][1] for name in core_tests)
    core_total = length(core_tests)
    
    optional_test_names = [name for (name, _) in optional_tests]
    optional_passed = sum(results[name][1] for name in optional_test_names)
    optional_total = length(optional_test_names)
    
    println("Core tests:     $core_passed/$core_total passed")
    println("Optional tests: $optional_passed/$optional_total passed")
    
    # Show failed tests
    failed_tests = [name for (name, (passed, error)) in results if !passed]
    
    if !isempty(failed_tests)
        println("\n❌ Failed Tests:")
        for test_name in failed_tests
            _, error = results[test_name]
            println("  • $test_name")
            if verbose
                println("    Error: $error")
            end
            
            if fix_issues
                println("    💡 Suggestions:")
                suggestions = suggest_fixes(test_name, error)
                for line in split(suggestions, '\n')
                    if !isempty(strip(line))
                        println("      $line")
                    end
                end
            end
        end
    end
    
    # Overall result
    core_all_passed = core_passed == core_total
    
    if core_all_passed
        println("\n🎉 All core quality tests passed!")
        if optional_passed < optional_total
            println("   ℹ️  Some optional tests failed - consider addressing these for best practices")
        end
    else
        println("\n⚠️  Some core quality tests failed")
        if fix_issues
            println("   💡 See suggestions above for fixing issues")
        else
            println("   💡 Run with --fix-issues for suggestions")
        end
    end
    
    # Additional package info
    println("\n📦 Package Information:")
    println("  Name: Globtim")
    println("  Exports: $(length(names(Globtim)) - 1)")  # Exclude module name
    
    # Exit with appropriate code for CI
    if ci_mode && !core_all_passed
        println("\n❌ Exiting with error code due to failed core tests")
        exit(1)
    elseif ci_mode
        println("\n✅ All core tests passed - CI success")
        exit(0)
    end
    
    return core_all_passed
end

# Run if called as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
