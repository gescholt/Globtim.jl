# Debug Plan for Recovery Statistics

## Issues Identified

1. **`found_minimizer` never updated**
   - Line 158: `found_minimizer = false`
   - Never set to `true` even when minimizer is found
   - This causes all entries to show `found_minimizer = false`

2. **Logic error in distance checking**
   - Line 162: `for (ind , x) in enumerate(subdomain_minimizer_idx)`
   - `subdomain_minimizer_idx` is an integer, not an array
   - This loop doesn't make sense

3. **`accuracy` field calculation**
   - Depends on `found_minimizer` which is always false
   - For subdomains with minimizers: always 0%
   - For subdomains without minimizers: 100% if no computed points, 0% otherwise

## Debugging Steps

### Step 1: Check Current Output
Let's examine a sample recovery CSV file to confirm the issue.

### Step 2: Fix the Logic
The correct logic should be:
```julia
found_minimizer = false
if subdomain_has_minimizer && !isempty(computed_pts)
    # Calculate distance from the true minimizer to nearest computed point
    true_min = true_minimizers[subdomain_minimizer_idx]
    min_distance = minimum(norm(true_min - cp) for cp in computed_pts)
    
    if min_distance < threshold
        found_minimizer = true
        minimizers_recovered[subdomain_minimizer_idx] = true
    end
end
```

### Step 3: Test Cases to Verify
1. **Subdomain with minimizer, found within threshold** → Should show found_minimizer=true, accuracy=100%
2. **Subdomain with minimizer, not found** → Should show found_minimizer=false, accuracy=0%
3. **Subdomain without minimizer, no computed points** → Should show found_minimizer=false, accuracy=100%
4. **Subdomain without minimizer, has computed points** → Should show found_minimizer=false, accuracy=0%

### Step 4: Additional Debugging Info
We should also track:
- The actual minimum distance for each subdomain
- Which minimizer index is expected in each subdomain
- How many computed points are in each subdomain

## Implementation Plan

1. First, create a test script to verify the current behavior
2. Fix the logic in `compute_minimizer_recovery`
3. Add debug output to track what's happening
4. Run tests to verify the fix works correctly