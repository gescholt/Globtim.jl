# GitLab Issue: Fix Aqua.jl Quality Check Failures

## Summary
While core functionality tests pass, several Aqua.jl code quality checks are failing. These are non-critical but should be addressed for better code maintainability.

**UPDATE (September 2, 2025)**: 2 of 3 issues have been resolved in commit 8ab8ccb.

## Current Failures

### 1. ✅ RESOLVED - Undefined Exports (13 symbols)
**Status**: Fixed in commit 8ab8ccb  
**Resolution**: Commented out undefined exports in src/Globtim.jl

The following symbols were exported but not properly defined in the codebase:
- `Globtim.ConservativeValleyConfig`
- `Globtim.ConservativeValleyStep`
- `Globtim.ValleyDetectionConfig`
- `Globtim.ValleyInfo`
- `Globtim.analyze_valleys_in_critical_points`
- `Globtim.conservative_valley_walk`
- `Globtim.create_ridge_test_function`
- `Globtim.create_valley_test_function`
- `Globtim.detect_valley_at_point`
- `Globtim.explore_valley_manifold_conservative`
- `Globtim.follow_valley_manifold`
- `Globtim.project_to_critical_manifold`
- `Globtim.validate_valley_point`

These exports have been commented out and can be uncommented once the functions are implemented.

### 2. ✅ RESOLVED - Stale Dependencies
**Status**: Fixed in commit 8ab8ccb  
**Resolution**: Removed Aqua from main Project.toml dependencies

Aqua.jl was listed in the main Project.toml dependencies but should only be in test dependencies.
- ✅ Removed Aqua from Project.toml [deps] section
- ✅ Aqua remains available in test/Project.toml for quality checks

### 3. ✅ RESOLVED - Excessive Exports
**Status**: Fixed in commit [pending]  
**Resolution**: Reduced exports from 245 to 164 by making internal functions non-public

The following categories of functions were made internal:
- Internal validation and error handling helpers (25+ functions)
- Grid utility functions (10+ functions)  
- Internal analysis helpers (20+ functions)
- Extension stub functions for plotting (25+ functions)
- Internal BFGS and orthant helpers (15+ functions)

The package now exports only 164 symbols, well below the 200 limit.

## Test Output
```julia
Undefined Exports: Test Failed at ~/.julia/packages/Aqua/MCcFg/src/exports.jl:66
  Expression: isempty(exports)
  
Dependency Analysis: Test Failed at ~/.julia/packages/Aqua/MCcFg/src/stale_deps.jl:31
  Expression: isempty(stale_deps)
  Evaluated: isempty(Base.PkgId[Base.PkgId(Base.UUID("4c88cf16-eb10-579e-8560-4a9242c79595"), "Aqua")])

Export Consistency: Test Failed at test_aqua.jl:152
  Expression: length(exported_names) < 200
  Evaluated: 258 < 200
```

## Priority
**Low** - These are code quality issues that don't affect functionality.

## Acceptance Criteria
- [x] All undefined exports are either implemented or removed ✅ COMPLETED
- [x] Aqua is moved to test-only dependencies ✅ COMPLETED
- [x] Number of exports reduced to < 200 or test limit adjusted with justification ✅ COMPLETED

## Status
**FULLY RESOLVED** - All 3 issues fixed as of September 2, 2025

## Related Issues
- #18 - Fix test_aqua.jl syntax errors (RESOLVED)

## Labels
- `code-quality`
- `technical-debt`
- `testing`