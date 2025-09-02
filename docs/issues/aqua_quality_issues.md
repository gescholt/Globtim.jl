# GitLab Issue: Fix Aqua.jl Quality Check Failures

## Summary
While core functionality tests pass, several Aqua.jl code quality checks are failing. These are non-critical but should be addressed for better code maintainability.

## Current Failures

### 1. Undefined Exports (13 symbols)
The following symbols are exported but not properly defined in the codebase:
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

**Action Required**: Either implement these functions or remove them from exports.

### 2. Stale Dependencies
Aqua.jl is currently listed in the main Project.toml dependencies but should only be in test dependencies.

**Action Required**: 
- Remove Aqua from Project.toml [deps] section
- Ensure it's only in test/Project.toml

### 3. Excessive Exports
The package currently exports 258 symbols, which the test considers excessive (limit is 200).

**Action Required**: Review exports and consider:
- Using submodules for logical grouping
- Making some functions internal (not exported)
- Providing a more selective public API

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
- [ ] All undefined exports are either implemented or removed
- [ ] Aqua is moved to test-only dependencies
- [ ] Number of exports reduced to < 200 or test limit adjusted with justification

## Related Issues
- #18 - Fix test_aqua.jl syntax errors (RESOLVED)

## Labels
- `code-quality`
- `technical-debt`
- `testing`