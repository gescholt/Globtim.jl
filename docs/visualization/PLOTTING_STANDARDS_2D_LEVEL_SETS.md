# 2D Level Set Plotting Standards

## Overview

This document establishes standardized practices for creating 2D level set visualizations across the GlobTim project, based on the working implementation in `Examples/valley_walking_demo.jl`.

## Standard Configuration

### Recommended Plot Setup

```julia
# Interactive GLMakie (preferred) with CairoMakie fallback
try
    using GLMakie
    GLMakie.activate!()
    backend_name = "GLMakie (Interactive Window)"
catch
    using CairoMakie 
    CairoMakie.activate!()
    backend_name = "CairoMakie (Static)"
end

# Create figure and axis
fig = Figure(size=(1000, 800))
ax = Axis(fig[1, 1], 
    title="Your Function Title",
    xlabel="x₁", ylabel="x₂",
    aspect=DataAspect()
)
```

### Level Set Visualization Components

**1. Continuous Background (Heatmap)**
```julia
# Create function evaluation grid
x_range = range(-1.5, 1.5, length=200)
y_range = range(-1.5, 1.5, length=200) 
Z = [your_function([x, y]) for y in y_range, x in x_range]

# Add continuous color background
heatmap!(ax, x_range, y_range, Z, colormap=:viridis, alpha=0.6)
```

**2. Contour Lines Overlay**
```julia
# Add white contour lines for level set clarity
contour!(ax, x_range, y_range, Z, levels=15, color=:white, linewidth=0.8, alpha=0.8)
```

**3. Algorithm Paths/Features**
```julia
# Example: Valley walking paths
colors = [:blue, :green, :orange, :purple, :brown, :pink]
for (i, (name, path)) in enumerate(paths_data)
    if length(path) > 0
        path_x = [p[1] for p in path]
        path_y = [p[2] for p in path]
        
        color = colors[mod(i-1, length(colors)) + 1]
        
        # Plot path
        lines!(ax, path_x, path_y, color=color, linewidth=2, alpha=0.8,
               label="Path $i: $(length(path)) pts")
        
        # Mark start and end points
        scatter!(ax, [path_x[1]], [path_y[1]], color=color, marker=:circle, 
                markersize=12, strokewidth=2, strokecolor=:black)
        scatter!(ax, [path_x[end]], [path_y[end]], color=color, marker=:rect, 
                markersize=10)
    end
end
```

**4. Theoretical/True Solutions**
```julia
# Example: True valley manifold (unit circle)
θ = range(0, 2π, length=100)
circle_x = cos.(θ)
circle_y = sin.(θ)
lines!(ax, circle_x, circle_y, color=:red, linewidth=3, 
       label="True Valley (Unit Circle)")
```

### Interactive Display (GLMakie)

```julia
# Display interactive window and wait
display(fig)
println("→ Interactive GLMakie window displayed!")
println("   Press Enter in this terminal to continue (window will stay open)...")
readline()
```

### Legend and Formatting

```julia
# Add legend
axislegend(ax, position=:rt, framevisible=true, backgroundcolor=(:white, 0.8))

# Set appropriate axis limits
xlims!(ax, -1.4, 1.4)
ylims!(ax, -1.4, 1.4)
```

## Color Schemes

### Recommended Colormaps

- **Primary**: `:viridis` - Perceptually uniform, printer-friendly
- **Alternative**: `:plasma`, `:inferno` for high contrast
- **Mathematical**: `:RdBu` for signed functions (positive/negative)

### Path Colors

Standard color sequence for multiple algorithm paths:
```julia
colors = [:blue, :green, :orange, :purple, :brown, :pink]
```

## Performance Guidelines

### Grid Resolution
- **Standard**: 200x200 for interactive viewing
- **High-quality**: 400x400 for publication
- **Draft/Debug**: 100x100 for quick iteration

### Alpha Values
- **Background heatmap**: 0.6 (allows overlay visibility)
- **Contour lines**: 0.8 (clear but not overwhelming) 
- **Algorithm paths**: 0.8 (prominent but blendable)

## Backend-Specific Notes

### GLMakie (Interactive)
- Requires `display(fig)` + `readline()` to keep window open
- Best for exploratory analysis and debugging
- May show GLFW warnings on script exit (harmless)

### CairoMakie (Static)
- Best for publication-quality output
- Direct save to PNG/PDF without display
- No interactive features but faster rendering

## Examples in Codebase

### Working Reference Implementation
- **File**: `Examples/valley_walking_demo.jl:202-236`
- **Function**: `create_valley_visualization()`
- **Status**: ✅ Validated and working

### Usage Pattern
```julia
function create_visualization(data, function_to_plot, config; use_interactive=true)
    # Backend selection
    if use_interactive && HAS_GLMAKIE
        GLMakie.activate!()
    elseif HAS_CAIROMAKIE
        CairoMakie.activate!()
    else
        println("⚠️  No visualization backend available")
        return nothing
    end
    
    # Apply standard plotting components above
    # ...
    
    return fig
end
```

## Validation Checklist

- [ ] Continuous background heatmap visible
- [ ] White contour lines provide level set clarity  
- [ ] Algorithm paths clearly distinguishable
- [ ] Interactive window displays and waits (GLMakie)
- [ ] Legend positioned appropriately
- [ ] Axis labels and title descriptive
- [ ] Color scheme accessible and informative

---
*This standard is based on the successful valley walking visualization implementation and should be applied consistently across all 2D level set plots in the GlobTim project.*