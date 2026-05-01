# Package Architecture Guidelines

## Overview
This document provides architectural guidelines for maintaining clean dependencies and preventing circular dependency issues in the Globtim package ecosystem.

## Core Architecture Principles

### 1. Layered Architecture

```
┌─────────────────────────────────────┐
│           Extensions Layer          │
│  (Heavy dependencies, optional)     │
├─────────────────────────────────────┤
│          Interface Layer            │
│   (Abstract types, protocols)       │
├─────────────────────────────────────┤
│            Core Layer               │
│  (Algorithms, data structures)      │
└─────────────────────────────────────┘
```

### 2. Dependency Flow Rules

- **Core → Interface**: Core can define interfaces
- **Interface → Extensions**: Extensions implement interfaces
- **Extensions → Core**: Extensions can use core functionality
- **❌ Core → Extensions**: Core must NEVER depend on extensions
- **❌ Extensions → Extensions**: Extensions should not depend on each other

## Implementation Patterns

### Pattern 1: Abstract Interface Definition

**Core Package (src/Globtim.jl)**:
```julia
module Globtim

# Abstract interfaces
abstract type AbstractModel end
abstract type AbstractSolver end
abstract type AbstractVisualizer end

# Generic function signatures
function solve end
function visualize end
function analyze end

# Core implementations
include("core/algorithms.jl")
include("core/data_structures.jl")

end
```

### Pattern 2: Extension Implementation

**Extension (ext/GlobtimHeavyPackageExt.jl)**:
```julia
module GlobtimHeavyPackageExt

using Globtim
using HeavyPackage

# Extend core interfaces with HeavyPackage functionality
struct HeavyPackageSolver <: Globtim.AbstractSolver
    system::HeavyPackage.ProblemType
end

function Globtim.solve(solver::HeavyPackageSolver, problem)
    # Implementation using HeavyPackage
end

end
```

### Pattern 3: Conditional Feature Access

**Core Package with Optional Features**:
```julia
function advanced_solve(problem)
    # Check if the required extension is available
    if !hasmethod(solve, (HeavyPackageSolver, typeof(problem)))
        error("""
        Advanced solving requires HeavyPackage extension.
        Load with: using HeavyPackage
        """)
    end

    solver = HeavyPackageSolver(problem.system)
    return solve(solver, problem)
end
```

## Project.toml Structure

### Recommended Structure

```toml
[deps]
# Only lightweight, essential dependencies
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[weakdeps]
# Heavy or optional dependencies
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"
Clustering = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"

[extensions]
GlobtimVisualizationExt = ["CairoMakie", "GLMakie"]
GlobtimAnalysisExt = "Clustering"
```

## Dependency Classification

### Core Dependencies (Keep in [deps])
- **Standard Library**: LinearAlgebra, Random, Statistics, Printf
- **Lightweight**: JSON, TOML, UUIDs
- **Essential Algorithms**: Core mathematical libraries that are always needed
- **Data Structures**: Only if used throughout the core

### Extension Dependencies (Move to [weakdeps])
- **Plotting**: Makie ecosystem, Plots, etc.
- **Heavy Modeling**: Large modeling frameworks
- **Database/IO**: Database drivers, web frameworks
- **Machine Learning**: MLJ, Flux, etc.
- **Visualization**: Any plotting or GUI packages

### Borderline Cases
- **CSV**: Can be heavy for I/O intensive packages → Consider extension
- **DataFrames**: Heavy but sometimes essential → Evaluate based on usage
- **JSON**: Usually lightweight → Keep in deps
- **HomotopyContinuation**: Mathematical core → Keep in deps if essential

## Migration Strategies

### Strategy 1: Gradual Extension Migration

1. **Identify Heavy Dependencies**:
```bash
julia tools/validation/validate_project_toml.jl
```

2. **Create Extension Stub**:
```julia
# ext/GlobtimHeavyPackageExt.jl
module GlobtimHeavyPackageExt
    using Globtim, HeavyPackage
    # Implementation
end
```

3. **Move to weakdeps**:
```toml
[weakdeps]
HeavyPackage = "uuid-here"

[extensions]
GlobtimHeavyPackageExt = "HeavyPackage"
```

4. **Update Core Package**:
```julia
# Add conditional loading in core
function heavy_feature(args...)
    if !hasmethod(heavy_implementation, (typeof(args)...,))
        error("Heavy features require HeavyPackage. Load with: using HeavyPackage")
    end
    return heavy_implementation(args...)
end
```

### Strategy 2: Interface-First Refactoring

1. **Define Interfaces**:
```julia
abstract type AbstractAnalyzer end
function analyze(::AbstractAnalyzer, data) end
```

2. **Move Implementations to Extensions**:
```julia
# ext/GlobtimClusteringExt.jl
struct ClusteringAnalyzer <: Globtim.AbstractAnalyzer end
Globtim.analyze(::ClusteringAnalyzer, data) = # implementation
```

3. **Provide Factory Functions**:
```julia
function create_analyzer(type::Symbol)
    if type == :clustering
        return ClusteringAnalyzer()  # Will error if extension not loaded
    end
    error("Unknown analyzer type: $type")
end
```

## Testing Guidelines

### Extension Testing Pattern

```julia
# test/extensions/test_extension.jl
using Test
using Globtim

@testset "Extension Loading" begin
    # Test loading
    try
        using HeavyPackage
        @test hasmethod(Globtim.solve, (Globtim.HeavyPackageSolver, Any))
    catch LoadError
        @test_skip "HeavyPackage not available"
    end
end
```

### Core Testing Pattern

```julia
# test/core/test_algorithms.jl
using Test
using Globtim

@testset "Core Algorithms" begin
    # Test core functionality without extensions
    problem = SimpleProblem(...)
    result = solve_basic(problem)
    @test result isa ExpectedType
end
```

## Common Anti-Patterns

### ❌ Anti-Pattern 1: Heavy Core
```julia
# BAD: Core depends on heavy packages
module Globtim
using HeavyPackage, GLMakie, DataFrames  # Too heavy!
```

### ❌ Anti-Pattern 2: Extension Interdependence
```julia
# BAD: Extensions depending on each other
module GlobtimPlottingExt
using GlobtimAnalysisExt  # Extensions shouldn't depend on each other
```

### ❌ Anti-Pattern 3: Circular Dependencies
```toml
# BAD: Package in both deps and extensions
[deps]
HeavyPackage = "..."

[extensions]
GlobtimHeavyPackageExt = "HeavyPackage"  # Circular!
```

## Best Practices Summary

1. **Keep Core Minimal**: Only essential, lightweight dependencies
2. **Use Abstract Interfaces**: Define protocols in core, implement in extensions
3. **Conditional Loading**: Graceful degradation when extensions unavailable
4. **Clear Error Messages**: Help users understand what extensions they need
5. **Test Both Modes**: With and without extensions loaded
6. **Document Dependencies**: Clear documentation about optional features

## Validation Tools

- **Project.toml Validator**: `julia tools/validation/validate_project_toml.jl`
- **CI Checks**: Automated validation in GitHub Actions
- **Dependency Analysis**: Regular review of dependency weights

## Examples in Globtim

### Current Good Examples
```toml
[weakdeps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"

[extensions]
GlobtimAnalysisExt = ["Clustering", "Distributions"]
```

### Areas for Improvement
- Evaluate `CSV` and `DataStructures` for extension migration
- Create plotting extensions for Makie dependencies