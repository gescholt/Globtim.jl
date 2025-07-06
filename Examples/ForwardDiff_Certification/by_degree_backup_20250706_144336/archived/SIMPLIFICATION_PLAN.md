# Plan to Simplify Centralized Degree Analysis

## Current Issues
1. Too much printing/verbosity
2. Manual coordinate transformation instead of using Globtim's built-in functionality
3. Not clear where each function is called
4. Need to verify critical points match imported local minimizers

## Proposed Changes

### 1. Use Globtim's `process_crit_pts` Instead of Manual Transformation
**Current approach:** Manually transform from [-1,1]^n to actual coordinates
**Better approach:** Use `process_crit_pts` which handles this automatically and returns points in actual domain coordinates

### 2. Reduce Printing
- Remove per-subdomain progress messages
- Only print summary statistics per degree
- Add optional verbose flag for detailed output

### 3. Clearer Structure Without Excessive Wrapping
```julia
# Main flow (visible in one place):
for degree in degrees
    for subdomain in subdomains
        # 1. Create test_input with subdomain specs
        TR = test_input(...)
        
        # 2. Construct polynomial (let GN be fixed)
        pol = Constructor(TR, degree)
        
        # 3. Get critical points (already transformed)
        df_crit_pts = process_crit_pts(...)
        
        # 4. Compute distances to theoretical minimizers
        distances = compute_distances(...)
    end
end
```

### 4. Verification Against Theoretical Minimizers
- Add explicit check that some critical points match theoretical minimizers within tolerance
- Print warning if no theoretical minimizers are recovered

### 5. Key Simplifications
- Remove redundant subdomain checking (Globtim already filters)
- Use DataFrames from `process_crit_pts` directly
- Consolidate results processing
- Make tolerance behavior clear (GN fixed = no adaptation)

## Benefits
1. **Clarity**: One can see exactly what Globtim functions are called
2. **Correctness**: Uses Globtim's coordinate transformation
3. **Verification**: Explicitly checks recovery of known minimizers
4. **Simplicity**: Less code, fewer custom functions
5. **Focus**: Clear emphasis on degree convergence analysis