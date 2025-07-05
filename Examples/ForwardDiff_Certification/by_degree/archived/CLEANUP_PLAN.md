# Cleanup Plan for Degree Convergence Analysis

## Current Issues
1. Multiple versions of the same analysis (centralized, simplified, simplified_v2)
2. Complex shared modules with tensor product generation that's hard to debug
3. Overcomplicated coordinate transformation logic
4. Too many files doing similar things

## What to Remove

### 1. Redundant Example Files
- `centralized_degree_analysis.jl` - overcomplicated
- `simplified_degree_analysis.jl` - has bugs with tensor products
- `legacy_simplified_subdomain_analysis_new_distance.jl` - already legacy

### 2. Complex Shared Module Functions
- `generate_4d_tensor_products()` - replace with simple loop
- `generate_4d_tensor_products_orthant()` - unnecessary wrapper
- `load_theoretical_4d_points_orthant()` - replace with direct generation

### 3. Unnecessary Complexity
- Manual coordinate transformation code (use process_crit_pts instead)
- Complex type filtering logic for min+min points
- Excessive documentation files about issues already fixed

## What to Keep/Replace With

### 1. Single Clean Example: `degree_convergence_analysis.jl`
Based on simplified_degree_analysis_v2.jl with:
- Direct generation of 9 min+min points (simple for loop)
- Clean distance computation function
- Use Globtim's process_crit_pts for coordinate handling
- Clear parameter section at top
- Minimal but sufficient documentation

### 2. Simplified Shared Modules
- **Keep**: `SubdomainManagement.jl` - clean and necessary
- **Keep**: `Common4DDeuflhard.jl` - just the function definition
- **Simplify**: `TheoreticalPoints.jl` - just keep 2D point loading

### 3. Core Functionality
```julia
# Direct and simple:
min_min_points = generate_min_min_points()  # 9 points from 3×3 tensor product
distances = compute_min_distances(min_min_points, critical_points)
```

## Implementation Steps

1. **Create single clean example**
   - Start with simplified_degree_analysis_v2.jl as base
   - Remove verbose parameter (keep output minimal by default)
   - Add clear comments explaining each step

2. **Archive old versions**
   - Move all other analysis files to archived/
   - Keep only the clean version

3. **Update run_all_examples.jl**
   - Single include statement
   - Clear parameter definitions
   - Minimal output messages

4. **Clean up shared modules**
   - Remove complex tensor product functions
   - Keep only essential utilities

## Expected Result
- One clear example file that's easy to understand
- Direct approach: generate points → compute approximant → find critical points → measure distances
- No hidden complexity or coordinate confusion
- Easy to modify parameters and extend