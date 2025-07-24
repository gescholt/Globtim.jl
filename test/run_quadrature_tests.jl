#!/usr/bin/env julia

# Simple test runner for quadrature L2 norm development
# Run this file to test the implementation as you develop it

using Pkg
Pkg.activate(".")

using Test
using Globtim

# Color codes for output
const GREEN = "\033[32m"
const RED = "\033[31m"
const YELLOW = "\033[33m"
const RESET = "\033[0m"

function print_header(text)
    println("\n" * "="^60)
    println(text)
    println("="^60)
end

function print_phase_status(phase_num, phase_name, tests)
    print_header("Phase $phase_num: $phase_name")
    for (test_name, implemented) in tests
        status = implemented ? "$(GREEN)✓$(RESET)" : "$(RED)✗$(RESET)"
        println("  $status $test_name")
    end
end

# Check if the implementation exists
impl_exists = isdefined(Globtim, :compute_l2_norm_quadrature)

if !impl_exists
    println("$(YELLOW)Warning: quadrature_l2_norm.jl not found.$(RESET)")
    println("Tests will be skipped until implementation is available.")
    println("\nExpected implementation location: src/quadrature_l2_norm.jl")
    println("\nThe implementation should export:")
    println("  - compute_l2_norm_quadrature(f::Function, n_points::Vector{Int}, basis::Symbol)")
end

# Track test results
test_results = Dict{String, Bool}()

# Define test phases (will be updated with actual results)
phase1_tests = [
    ("1.1 Polynomial Exactness (1D)", false),
    ("1.2 Basic Multi-dimensional (2D)", false),
    ("1.3 Single Basis Type (Chebyshev)", false),
    ("1.4 Basic Convergence", false),
]

phase2_tests = [
    ("2.1 3D and 4D Integration", false),
    ("2.2 Different Polynomial Bases", false),
]

# Run tests if implementation exists
if impl_exists
    print_header("Running Tests")
    
    # Run the tests and capture if they all pass
    global all_tests_passed = true
    try
        include("test_quadrature_l2_phase1_2.jl")
    catch e
        if isa(e, Test.TestSetException)
            global all_tests_passed = false
        else
            rethrow(e)
        end
    end
    
    # Update test status based on results
    if all_tests_passed
        # If all tests pass, mark all as passed
        phase1_tests = [
            ("1.1 Polynomial Exactness (1D)", true),
            ("1.2 Basic Multi-dimensional (2D)", true),
            ("1.3 Single Basis Type (Chebyshev)", true),
            ("1.4 Basic Convergence", true),
        ]
        
        phase2_tests = [
            ("2.1 3D and 4D Integration", true),
            ("2.2 Different Polynomial Bases", true),
        ]
        
        # Print updated status
        println("\n$(GREEN)All tests passed! Great job!$(RESET)")
        print_phase_status(1, "Core Functionality", phase1_tests)
        print_phase_status(2, "Extended Dimensions", phase2_tests)
    end
    
else
    # Print initial status only if implementation doesn't exist
    print_phase_status(1, "Core Functionality", phase1_tests)
    print_phase_status(2, "Extended Dimensions", phase2_tests)
    println("\n$(YELLOW)Skipping test execution until implementation is available.$(RESET)")
end

# Provide next steps
print_header("Next Steps")
if !impl_exists
    println("1. Create src/quadrature_l2_norm.jl")
    println("2. Implement compute_l2_norm_quadrature function")
    println("3. Start with Phase 1 tests (1D polynomial exactness)")
    println("4. Run this script again to test your implementation")
else
    println("1. Fix any failing tests in Phase 1")
    println("2. Once Phase 1 passes, move to Phase 2")
    println("3. Run specific test sets with: julia --project test/test_quadrature_l2_phase1_2.jl")
end

println("\n$(GREEN)Happy coding!$(RESET)\n")