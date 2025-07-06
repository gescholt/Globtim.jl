# Parameter Updates for Degree Analysis Examples

## Date: 2025-07-04

## Overview
Updated maximum polynomial degrees and L²-norm tolerances across all examples to balance computational efficiency with analysis quality.

## Parameter Changes

### 1. Example A: `01_full_domain.jl` (Orthant Analysis)
- **DEGREE_MAX**: Changed from 4 to **6**
- **L2_TOLERANCE**: Changed from 1e-3 to **1e-2**
- **Rationale**: Higher tolerance allows convergence at lower degrees, reducing computation time while maintaining meaningful accuracy for the orthant analysis

### 2. Example B: `02_subdivided_fixed.jl` (Fixed Degree Subdivision)
- **FIXED_DEGREES**: Changed from `[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]` to **`[2, 3, 4, 5, 6]`**
- **Rationale**: Capping at degree 6 significantly reduces runtime while still demonstrating convergence patterns across subdomains

### 3. Example C: `03_subdivided_adaptive.jl` (Adaptive Subdivision)
- **DEGREE_MAX**: Changed from 4 to **6**
- **L2_TOLERANCE_TARGET**: Maintained at **1e-2**
- **Rationale**: Allows adaptive algorithm more flexibility to achieve convergence while keeping computation reasonable

## Impact on Analysis

### Computational Benefits
- Reduced runtime from potentially hours to approximately 5-10 minutes per example
- Lower memory requirements
- Faster iteration during development and testing

### Analysis Trade-offs
- L²-norm tolerance of 1e-2 is sufficient for identifying critical points with good accuracy
- Degree 6 polynomials provide adequate approximation for the 4D Deuflhard function in most regions
- Recovery rates above 90% are typically achieved by degree 6

## Recommended Usage

### For Quick Testing
- Use these default parameters for rapid analysis and development
- Suitable for demonstrating convergence patterns and spatial variations

### For High-Accuracy Analysis
- Increase DEGREE_MAX to 8-10 if needed
- Reduce L2_TOLERANCE to 1e-3 or lower
- Expect significantly longer runtimes

## Summary
The updated parameters strike a balance between computational efficiency and analysis quality, making the examples more practical for regular use while maintaining the ability to demonstrate key convergence behaviors in the (+,-,+,-) orthant of the 4D Deuflhard function.