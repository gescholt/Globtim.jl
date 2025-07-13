# Developer Guide: Implementing Weak Dependencies

This guide shows how Globtim implements weak dependencies and how you can use the same pattern in your own packages.

## Pattern Overview

Weak dependencies allow optional functionality without forcing users to install heavy dependencies. Globtim uses this for visualization features.

## Implementation Steps

### 1. Define Weak Dependencies in Project.toml

```toml
[weakdeps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"

[extensions]
GlobtimCairoMakieExt = "CairoMakie"
GlobtimGLMakieExt = "GLMakie"
```

### 2. Create Function Stubs in Main Package

In `src/hessian_analysis.jl`:

```julia
"""
    plot_hessian_norms(TR::TestInput; kwargs...)

Plot the evolution of Hessian norms. Requires CairoMakie or GLMakie to be loaded.
"""
function plot_hessian_norms end

"""
    plot_condition_numbers(TR::TestInput; kwargs...)

Plot condition number analysis. Requires CairoMakie or GLMakie to be loaded.
"""
function plot_condition_numbers end

# Export the function names
export plot_hessian_norms, plot_condition_numbers
```

### 3. Create Extension Modules

Create `ext/GlobtimCairoMakieExt.jl`:

```julia
module GlobtimCairoMakieExt

using Globtim
using CairoMakie

# Import the function stubs to extend them
import Globtim: plot_hessian_norms, plot_condition_numbers

function plot_hessian_norms(TR::Globtim.TestInput; 
                          title="Hessian Norms Evolution",
                          save_path=nothing,
                          kwargs...)
    # Implementation using CairoMakie
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], title=title, xlabel="Index", ylabel="Norm")
    
    # Your plotting code here
    lines!(ax, 1:length(TR.data), TR.data)
    
    if !isnothing(save_path)
        save(save_path, fig)
    end
    
    return fig
end

# Similar implementation for other functions...

end # module
```

### 4. Create Backend-Specific Utilities

You can include additional files in extensions:

```julia
module GlobtimCairoMakieExt

using Globtim
using CairoMakie

# Include backend-specific utilities
include("../src/graphs_cairo.jl")

# Rest of extension code...

end
```

## Best Practices

### 1. Clear Documentation

Always document that functions require optional dependencies:

```julia
"""
    plot_results(data; backend=:auto)

Plot analysis results.

# Requirements
Requires CairoMakie or GLMakie to be loaded:
```julia
using MyPackage
using CairoMakie  # or GLMakie
plot_results(data)
```
"""
function plot_results end
```

### 2. Helpful Error Messages

Consider adding a custom error message when functions are called without loading dependencies:

```julia
# In main package
function plot_results(args...; kwargs...)
    error("""
    plot_results requires a Makie backend to be loaded.
    
    Please load either CairoMakie or GLMakie:
        using CairoMakie  # for static plots
        # or
        using GLMakie     # for interactive plots
    """)
end

# This will be overwritten by the extension
```

### 3. Type Stability

Keep type information in the main package:

```julia
# In main package
struct PlotConfig
    title::String
    width::Int
    height::Int
end

# Function stub that extensions will implement
function create_plot(data::Vector{Float64}, config::PlotConfig) end
```

### 4. Testing Weak Dependencies

Create separate test environments:

```julia
# test/test_weak_deps.jl
using Test
using MyPackage

@testset "Without weak deps" begin
    # Test that functions exist but throw errors
    @test_throws MethodError plot_results([1, 2, 3])
end

# In a separate environment with deps
@testset "With CairoMakie" begin
    using CairoMakie
    @test plot_results([1, 2, 3]) isa Figure
end
```

## Common Patterns

### 1. Multiple Backends, Same Interface

```julia
# Both extensions implement the same interface
# ext/MyPkgCairoMakieExt.jl
function plot_data(data; static=true, kwargs...)
    # CairoMakie-specific implementation
end

# ext/MyPkgGLMakieExt.jl  
function plot_data(data; interactive=true, kwargs...)
    # GLMakie-specific implementation
end
```

### 2. Backend-Specific Features

```julia
# Only available with GLMakie
function plot_interactive_3d end

# In GLMakie extension
function plot_interactive_3d(data)
    # 3D interactive plotting
end
```

### 3. Conditional Exports

You can conditionally export functions in extensions:

```julia
module MyPkgPlottingExt

using MyPkg
using SomePlottingPkg

# Extend existing function
import MyPkg: plot_basic

# Add new function only available with this extension
function plot_advanced(data)
    # Implementation
end

# Make it available
MyPkg.plot_advanced = plot_advanced

end
```

## Migration from Requires.jl

If migrating from the older Requires.jl pattern:

### Old Pattern (Requires.jl)
```julia
using Requires

function __init__()
    @require CairoMakie="13f3f980-e62b-5c42-98c6-ff1f3baf88f0" begin
        include("cairo_plots.jl")
    end
end
```

### New Pattern (Weak Dependencies)
```julia
# In Project.toml
[weakdeps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"

[extensions]
MyPkgCairoMakieExt = "CairoMakie"

# Create ext/MyPkgCairoMakieExt.jl with the content from cairo_plots.jl
```

## Debugging

### Check if Extension is Loaded

```julia
# In REPL
using MyPackage
Base.get_extension(MyPackage, :MyPkgCairoMakieExt)  # nothing if not loaded

using CairoMakie
Base.get_extension(MyPackage, :MyPkgCairoMakieExt)  # returns the module
```

### Common Issues

1. **Extension not loading**: Check that extension name in Project.toml matches the module name
2. **Method ambiguities**: Ensure proper type constraints in extension methods
3. **Precompilation issues**: Extensions are precompiled separately, may need explicit precompile statements

## Summary

Weak dependencies in Globtim provide:
- Optional visualization without forcing Makie on all users
- Clean separation of concerns
- No runtime overhead for users who don't need visualization
- Easy backend switching for different use cases

This pattern is ideal for:
- Visualization features
- Format converters (JSON, XML, etc.)
- Database interfaces
- Hardware-specific optimizations
- Any heavy dependency that only some users need