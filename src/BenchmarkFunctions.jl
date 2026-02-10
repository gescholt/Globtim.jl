# BenchmarkFunctions.jl
# 
# Comprehensive collection of benchmark functions for global optimization
# Based on Jamil, M. & Yang, X.-S. "A Literature Survey of Benchmark Functions 
# For Global Optimization Problems" (2013)
#
# Functions are organized by their geometric and analytical properties:
# - Bowl-Shaped: Unimodal functions with a single global minimum
# - Many Local Minima: Multimodal functions with numerous local optima
# - Valley-Shaped: Functions with narrow valleys containing the global minimum
# - Plate-Shaped: Functions with flat regions and gentle slopes
# - Steep Ridges/Drops: Functions with sharp transitions and steep gradients
# - Other: Specialized functions with unique characteristics

"""
# Benchmark Functions for Global Optimization

This module provides a comprehensive collection of benchmark functions commonly used
to test and evaluate global optimization algorithms. The functions are categorized
based on their geometric and analytical properties.

## Function Categories

### Bowl-Shaped Functions (Unimodal)
These functions have a single global minimum and are generally easier to optimize:
- `Sphere`: The most basic benchmark function
- `Rosenbrock`: Classic "banana" function with narrow valley
- `Zakharov`: Plate-shaped with increasing ill-conditioning
- `SumOfDifferentPowers`: Asymmetric bowl with different powers
- `Trid`: Bowl-shaped with known analytical minimum
- `RotatedHyperEllipsoid`: Elongated ellipsoidal shape

### Many Local Minima (Multimodal)
These functions have numerous local optima, testing global search capability:
- `Ackley`: Highly multimodal with exponential and cosine terms
- `Griewank`: Many regularly distributed local minima
- `Schwefel`: Deceptive function with distant global optimum
- `Rastrigin`: Regular grid of local minima
- `Levy`: Steep ridges with many local minima
- `Michalewicz`: Steep ridges controlled by parameter m
- `StyblinskiTang`: Scalable multimodal function

### Valley-Shaped Functions
Functions with narrow valleys containing the global minimum:
- `Rosenbrock`: Classic banana-shaped valley
- `camel_3`: Three-hump camel function
- `camel`: Six-hump camel function

### Plate-Shaped Functions
Functions with flat regions and gentle slopes:
- `Booth`: Simple 2D plate-shaped function
- `Matyas`: 2D function with cross term
- `Zakharov`: Higher-dimensional plate-shaped function

### 2D Specialized Functions
Functions specifically designed for 2D optimization:
- `Beale`: Narrow global minimum
- `Branin`: Three identical global minima
- `GoldsteinPrice`: Four local minima
- `McCormick`: Asymmetric domain
- `HolderTable`: Four symmetric global minima
- `CrossInTray`: Cross-shaped structure

### Higher-Dimensional Functions
Functions that scale to arbitrary dimensions:
- `Powell`: Requires dimension multiple of 4
- All n-D functions listed above

## Usage Examples

```julia
using Globtim

# Test a simple bowl-shaped function
f_val = Sphere([1.0, 2.0, 3.0])  # Returns 14.0

# Test the classic Rosenbrock function
f_val = Rosenbrock([1.0, 1.0])  # Returns 0.0 (global minimum)

# Test a highly multimodal function
f_val = Rastrigin([0.0, 0.0])  # Returns 0.0 (global minimum)

# Create test input for optimization
TR = test_input(Griewank, dim=5, center=zeros(5), sample_range=600.0)
pol = Constructor(TR, 6)  # Construct polynomial approximation
```

## Function Properties

Each function includes comprehensive documentation with:
- Mathematical formula
- Domain specifications
- Known global and local minima locations
- Function properties (unimodal/multimodal, separable, etc.)
- Difficulty characteristics
- Usage examples
- Literature references

## References

- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global 
  Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
- Individual function references are provided in each function's documentation.
"""

# Function categorization for easy reference
const BOWL_SHAPED_FUNCTIONS = [
    :Sphere, :Rosenbrock, :Zakharov, :SumOfDifferentPowers,
    :Trid, :RotatedHyperEllipsoid
]

const MULTIMODAL_FUNCTIONS = [
    :Ackley, :Griewank, :Schwefel, :Rastrigin, :Levy,
    :Michalewicz, :StyblinskiTang, :shubert, :dejong5
]

const VALLEY_SHAPED_FUNCTIONS = [
    :Rosenbrock, :camel_3, :camel
]

const PLATE_SHAPED_FUNCTIONS = [
    :Booth, :Matyas, :Zakharov
]

const TWO_D_FUNCTIONS = [
    :Beale, :Booth, :Branin, :GoldsteinPrice, :Matyas, :McCormick,
    :HolderTable, :CrossInTray, :camel, :camel_3, :easom, :dejong5
]

const HIGHER_D_FUNCTIONS = [
    :Sphere, :Rosenbrock, :Griewank, :Schwefel, :Levy, :Zakharov,
    :Michalewicz, :StyblinskiTang, :SumOfDifferentPowers, :Trid,
    :RotatedHyperEllipsoid, :Powell, :Ackley, :Rastrigin, :alpine1, :alpine2
]

"""
    get_function_category(func_name::Symbol) -> Vector{Symbol}

Get the categories that a function belongs to.

# Arguments
- `func_name::Symbol`: Name of the function

# Returns
- `Vector{Symbol}`: List of categories the function belongs to

# Examples
```julia
categories = get_function_category(:Rosenbrock)
# Returns [:bowl_shaped, :valley_shaped, :higher_d]
```
"""
function get_function_category(func_name::Symbol)
    categories = Symbol[]

    if func_name in BOWL_SHAPED_FUNCTIONS
        push!(categories, :bowl_shaped)
    end
    if func_name in MULTIMODAL_FUNCTIONS
        push!(categories, :multimodal)
    end
    if func_name in VALLEY_SHAPED_FUNCTIONS
        push!(categories, :valley_shaped)
    end
    if func_name in PLATE_SHAPED_FUNCTIONS
        push!(categories, :plate_shaped)
    end
    if func_name in TWO_D_FUNCTIONS
        push!(categories, :two_d)
    end
    if func_name in HIGHER_D_FUNCTIONS
        push!(categories, :higher_d)
    end

    return categories
end

"""
    list_functions_by_category(category::Symbol) -> Vector{Symbol}

List all functions in a specific category.

# Arguments
- `category::Symbol`: Category name (:bowl_shaped, :multimodal, :valley_shaped, 
  :plate_shaped, :two_d, :higher_d)

# Returns
- `Vector{Symbol}`: List of function names in the category

# Examples
```julia
bowl_functions = list_functions_by_category(:bowl_shaped)
multimodal_functions = list_functions_by_category(:multimodal)
```
"""
function list_functions_by_category(category::Symbol)
    if category == :bowl_shaped
        return BOWL_SHAPED_FUNCTIONS
    elseif category == :multimodal
        return MULTIMODAL_FUNCTIONS
    elseif category == :valley_shaped
        return VALLEY_SHAPED_FUNCTIONS
    elseif category == :plate_shaped
        return PLATE_SHAPED_FUNCTIONS
    elseif category == :two_d
        return TWO_D_FUNCTIONS
    elseif category == :higher_d
        return HIGHER_D_FUNCTIONS
    else
        throw(ArgumentError("Unknown category: $category"))
    end
end

"""
    get_function_info(func_name::Symbol) -> Dict

Get comprehensive information about a benchmark function.

# Arguments
- `func_name::Symbol`: Name of the function

# Returns
- `Dict`: Dictionary containing function information including categories,
  typical domain, global minimum location (if known), and properties

# Examples
```julia
info = get_function_info(:Rosenbrock)
println(info[:categories])  # [:bowl_shaped, :valley_shaped, :higher_d]
println(info[:global_min])  # [1.0, 1.0, ..., 1.0]
```
"""
function get_function_info(func_name::Symbol)
    info = Dict{Symbol, Any}()
    info[:name] = func_name
    info[:categories] = get_function_category(func_name)

    # Add specific information for each function
    if func_name == :Sphere
        info[:domain] = "[-5.12, 5.12]ⁿ"
        info[:global_min] = "zeros(n)"
        info[:global_min_value] = 0.0
        info[:properties] = ["unimodal", "convex", "separable"]
    elseif func_name == :Rosenbrock
        info[:domain] = "[-5, 10]ⁿ or [-2.048, 2.048]ⁿ"
        info[:global_min] = "ones(n)"
        info[:global_min_value] = 0.0
        info[:properties] = ["unimodal", "non-convex", "non-separable", "narrow valley"]
    elseif func_name == :Griewank
        info[:domain] = "[-600, 600]ⁿ"
        info[:global_min] = "zeros(n)"
        info[:global_min_value] = 0.0
        info[:properties] = ["multimodal", "non-separable", "many local minima"]
        # Add more function-specific information as needed
    end

    return info
end

# Export utility functions for function categorization
export get_function_category, list_functions_by_category, get_function_info
export BOWL_SHAPED_FUNCTIONS, MULTIMODAL_FUNCTIONS, VALLEY_SHAPED_FUNCTIONS
export PLATE_SHAPED_FUNCTIONS, TWO_D_FUNCTIONS, HIGHER_D_FUNCTIONS
