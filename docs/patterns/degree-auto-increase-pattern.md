# Pattern: Automatic Degree Increase in Constructor

## Problem Description

The `Constructor` function in Globtim has an automatic degree increase feature that can cause unexpected behavior when combined with tolerance-based `test_input`.

### How it Works

1. When `test_input` is created with a `tolerance` parameter:
   ```julia
   TR = test_input(f, dim = dim, sample_range = 1.0, tolerance = 1e-6)
   ```

2. And then `Constructor` is called with an initial degree:
   ```julia
   pol = Constructor(TR, 10)  # Starting degree
   ```

3. If the polynomial of the initial degree cannot achieve the L2-norm error below the specified tolerance, the Constructor will automatically increment the degree until either:
   - The tolerance is achieved
   - Some maximum degree limit is reached (if implemented)

### The Issue

This automatic increase can cause the degree to exceed intended bounds. For example, if tests are designed to keep polynomial degrees ≤ 14, but the Constructor starts at degree 10 with a tight tolerance (e.g., 1e-8), it might increase to degrees 15, 16, 17, etc.

### Example Output

When this happens, you'll see output like:
```
attained the desired L2-norm: 8.63117574729711e-9
Degree :10 
Increase degree to: 11
Increase degree to: 12
Increase degree to: 13
Increase degree to: 14
Increase degree to: 15
Increase degree to: 16
Increase degree to: 17
Increase degree to: 18
Increase degree to: 19
```

## Solutions

### Solution 1: Start with Maximum Allowed Degree
If you want to respect a degree bound while still using tolerance-based construction:
```julia
TR = test_input(f, dim = dim, sample_range = 1.0, tolerance = 1e-6)
pol = Constructor(TR, 14)  # Start at max degree
```

### Solution 2: Remove Tolerance Parameter
If the goal is to test a specific degree without auto-increment:
```julia
TR = test_input(f, dim = dim, sample_range = 1.0)  # No tolerance
pol = Constructor(TR, 10)  # Will use exactly degree 10
```

### Solution 3: Implement Maximum Degree Limit
Consider adding a `max_degree` parameter to Constructor:
```julia
pol = Constructor(TR, 10, max_degree = 14)  # Would stop at 14
```

## Affected Files (as of fixing)

- `test/test_l2_norm_scaling.jl` - Multiple tests used `Constructor(TR, 10)` with tolerance-based TR
- Pattern was: functions with tolerance 1e-6 or 1e-8 starting at degree 10, causing increase beyond 14

## Prevention

1. Be aware that `tolerance` in `test_input` triggers adaptive behavior in `Constructor`
2. When writing tests with degree bounds, either:
   - Start at the maximum allowed degree
   - Don't use tolerance parameter
   - Explicitly test that degree doesn't exceed bounds
3. Consider adding warnings when auto-increment exceeds certain thresholds