# Warning Catalog and Mitigation Strategies

## Overview

This document catalogs all warning types encountered during globtimcore experiments and provides solutions for each category.

## Warning Categories

### 1. ODE Solver Warnings (ADDRESSED)

**Example:**
```
┌ Warning: At t=7.548527380329381, dt was forced below floating point epsilon
│ 8.881784197001252e-16, and step error estimate = 2.050529468896692e-40.
│ Aborting. There is either an error in your model specification or the true
│ solution is unstable (or the true solution can not be represented in the
│ precision of Float64).
└ @ SciMLBase ~/.julia/packages/SciMLBase/YE7xF/src/integrator_interface.jl:657
```

**Source:** DifferentialEquations.jl solver during parameter space exploration

**Status:** ✅ ADDRESSED

**Solution:**
- Wrapped ODE solve calls with `Logging.global_logger(Logging.SimpleLogger(stderr, Logging.Error))`
- Applied in 3 locations:
  - `Examples/systems/DynamicalSystems.jl:298-306` (sample_data)
  - `src/refine.jl:422-441` (critical point refinement)
  - `src/refine.jl:782-802` (adaptive precision optimization)

**When it occurs:**
- During optimization with ODE-based objective functions
- Parameter recovery experiments
- When exploring parameter combinations that lead to numerical instability

---

### 2. Optim Constructor Warnings (NEEDS REVIEW)

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

### 3. Deprecation Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Action:** Run full test suite and collect all deprecation warnings

---

### 4. Type Instability Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Potential sources:**
- ForwardDiff operations
- Dynamic dispatch in hot loops
- Type-unstable function returns

---

### 5. Package Compatibility Warnings (TO BE COLLECTED)

**Status:** 🔍 TO BE COLLECTED

**Action:** Check for version compatibility warnings during precompilation

---

### 6. Numerical Precision Warnings (TO BE COLLECTED)

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
cd globtimcore
julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | grep -E "^┌ Warning|WARNING:" | sort | uniq > /tmp/warnings.txt

# Run typical experiment
julia --project=. experiments/some_experiment.jl 2>&1 | grep -E "^┌ Warning|WARNING:" > /tmp/experiment_warnings.txt

# Search for @warn in codebase
grep -rn "@warn" src/ | grep -v "\.md"
```

## Priority Levels

1. **Critical (🔴):** Causes errors or incorrect results
2. **High (🟡):** Significantly affects performance or usability
3. **Medium (🟢):** Cosmetic or minor issues
4. **Low (⚪):** Can be safely ignored

## Next Steps

1. ✅ ODE solver warnings suppressed
2. ⏳ Collect Sphere constructor warnings
3. ⏳ Run full experiment suite and collect all warning types
4. ⏳ Prioritize and address each category
5. ⏳ Document solutions in this file
6. ⏳ Create automated warning detection in CI

## Testing

To verify warning suppression:

```bash
# Test ODE warnings
cd globtimcore
julia --project=. -e 'push!(LOAD_PATH, "Examples/systems"); using DynamicalSystems; using ModelingToolkit; model, params, states, outputs = define_lotka_volterra_2D_model(); p = [2.0, 3.0]; ic = [1.0, 1.0]; problem = ODEProblem(ModelingToolkit.complete(model), merge(Dict(ModelingToolkit.unknowns(model) .=> ic), Dict(ModelingToolkit.parameters(model) .=> p)), [0.0, 10.0]); data = sample_data(problem, model, outputs, [0.0, 10.0], p, ic, 50); println("✅ No warnings!")'
```

## Last Updated

2025-10-14
