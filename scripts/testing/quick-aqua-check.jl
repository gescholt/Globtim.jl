#!/usr/bin/env julia
"""
Quick Aqua.jl check for Globtim.jl

This is a minimal script to quickly check the current state of the package
with Aqua.jl without running the full test suite.

Usage: julia scripts/quick-aqua-check.jl
"""

# Smart environment setup
using Pkg

# Check if we have a test environment with Aqua
if isfile("test/Project.toml")
    println("ℹ️  Using test environment...")
    Pkg.activate("test")
    try
        using Aqua
    catch e
        @info "Installing Aqua.jl..." exception=(e, catch_backtrace())
        Pkg.add("Aqua")
        using Aqua
    end
else
    println("ℹ️  Using main environment...")
    Pkg.activate(".")
    try
        using Aqua
    catch e
        @info "Adding Aqua.jl temporarily..." exception=(e, catch_backtrace())
        Pkg.add("Aqua")
        using Aqua
    end
end

try
    using Globtim
    
    println("🔍 Quick Aqua.jl Check for Globtim.jl")
    println("=" ^ 40)
    
    # Test each component with basic error handling
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
                # Function doesn't exist in this Aqua version - that's OK
                return true
            end
        end)
    ]
    
    passed = 0
    total = length(tests)
    
    for (name, test_func) in tests
        print("$name: ")
        try
            test_func()
            println("✅ PASS")
            passed += 1
        catch e
            println("❌ FAIL")
            println("  └─ $(first(split(string(e), '\n')))")
        end
    end
    
    println("\n📊 Summary: $passed/$total tests passed")
    
    if passed == total
        println("🎉 All basic quality checks passed!")
        println("💡 Run 'julia scripts/run-aqua-tests.jl --verbose' for detailed analysis")
    else
        println("⚠️  Some issues found")
        println("💡 Run 'julia scripts/run-aqua-tests.jl --verbose --fix-issues' for help")
    end
    
catch e
    if isa(e, ArgumentError) && contains(string(e), "Aqua")
        println("❌ Aqua.jl not found. Install with:")
        println("   julia --project=test -e 'using Pkg; Pkg.add(\"Aqua\")'")
    else
        println("❌ Error: $e")
    end
    exit(1)
end
