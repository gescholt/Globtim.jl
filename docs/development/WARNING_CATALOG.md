# Warning Catalog and Mitigation Strategies

## Overview

This document catalogs all warning types encountered during Globtim experiments and provides solutions for each category.

## Warning Categories

### 1. Optim Constructor Warnings (NEEDS REVIEW)

**Example:**
```
WARNING: Constructor for type "Sphere" was extended in `Globtim` without
explicit qualification or import.
NOTE: Assumed "Sphere" refers to `Optim.Sphere`.
```

**Source:** Optim.jl constructor override in Globtim

**Status:** ⚠️ NEEDS REVIEW

**Potential Solutions:**
1. Explicitly import: `using Optim: Sphere`
2. Qualify in method: `function Optim.Sphere(...)`
3. Rename constructor to avoid conflict

**Impact:** Low (deprecation warning, no functional impact)

**Files to check:**
- Search for `Sphere` constructor definitions in `src/`

---

### 2. Deprecation Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Action:** Run full test suite and collect all deprecation warnings

---

### 3. Type Instability Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Potential sources:**
- ForwardDiff operations
- Dynamic dispatch in hot loops
- Type-unstable function returns

---

### 4. Package Compatibility Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Action:** Check for version compatibility warnings during precompilation

---

### 5. Numerical Precision Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Potential sources:**
- Loss of precision in BigFloat ↔ Float64 conversions
- Matrix condition number warnings
- Singular Hessian warnings

---

## Collection Strategy

To systematically collect all warnings:

```bash
# Run full test suite and collect warnings
julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | grep -E "^┌ Warning|WARNING:" | sort | uniq > /tmp/warnings.txt

# Run a sample script and collect warnings
julia --project=. scripts/run_experiment.jl examples/configs/ackley_3d.toml 2>&1 | grep -E "^┌ Warning|WARNING:" > /tmp/experiment_warnings.txt

# Search for @warn in codebase
grep -rn "@warn" src/ | grep -v "\.md"
```

## Priority Levels

1. **Critical (🔴):** Causes errors or incorrect results
2. **High (🟡):** Significantly affects performance or usability
3. **Medium (🟢):** Cosmetic or minor issues
4. **Low (⚪):** Can be safely ignored

## Next Steps

1. ⏳ Collect Sphere constructor warnings
2. ⏳ Run full experiment suite and collect all warning types
3. ⏳ Prioritize and address each category
4. ⏳ Document solutions in this file
5. ⏳ Create automated warning detection in CI

## Last Updated

2025-10-14
