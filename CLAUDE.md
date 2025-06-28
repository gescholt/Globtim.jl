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

# Basic workflow
# Proper initialization for examples
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)  # Can use integer (auto-converts to (:one_d_for_all, 8))
@polyvar x[1:2]
crit_pts = solve_polynomial_system(x, 2, 8, pol.coeffs)
```

## Memories and AI Assistant Notes

### Development Workflow
- I run the tests in Julia myself 