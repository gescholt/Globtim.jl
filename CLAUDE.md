# CLAUDE.md - AI Assistant Development Guide

This file provides structured guidance for AI assistants (Claude Code) working with the Globtim Julia package.

## 🚀 Quick Start for AI Assistants

### Essential Commands
```julia
# Setup development environment
]dev .
using Revise, Pkg; Pkg.activate("."); using Globtim

# Run tests
]test Globtim

# Basic workflow with tolerance control
# Proper initialization for examples
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

f = Deuflhard
# Use tolerance parameter for automatic degree adaptation
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2, tolerance=0.001)
pol = Constructor(TR, 4)  # Starting degree (auto-increases until tolerance met)
@polyvar x[1:2]
crit_pts = solve_polynomial_system(x, 2, pol.degree, pol.coeffs)

# For high accuracy (4D Deuflhard example)
TR = test_input(deuflhard_4d_composite, dim=4, 
               center=[0.0, 0.0, 0.0, 0.0], sample_range=0.5,
               tolerance=0.0007)  # Tight tolerance for accuracy
pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)
```

## Memories and AI Assistant Notes

### Development Workflow
- I run the tests in Julia myself
- **Enhanced 4D Deuflhard Analysis**: 
  - Use tolerance-controlled polynomial approximation (L²-norm ≤ 0.0007)
  - Apply BFGS refinement for critical points near minimizers
  - Analyze all 16 orthants for comprehensive coverage
  - Fixed scope warnings in Julia loops
- **Key Parameters**:
  - `tolerance=0.0007` for high-accuracy polynomial approximation
  - Avoid fixed `GN` parameter to enable automatic adaptation
  - Use `basis=:chebyshev` for better numerical properties 