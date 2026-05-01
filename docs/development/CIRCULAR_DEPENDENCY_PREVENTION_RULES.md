# Circular Dependency Prevention Rules

## Overview
This document establishes enforceable rules to prevent circular dependencies in the Globtim package, based on lessons learned from the JuliaFormatter KeyError and ModelingToolkit circular dependency issues.

## Rule Categories

### 1. Extension Configuration Rules

#### Rule 1.1: Extension-WeakDep Consistency
- **Rule**: Extensions must only reference packages listed in `[weakdeps]`, never regular `[deps]`
- **Validation**: Every entry in `[extensions]` must have a corresponding entry in `[weakdeps]`
- **Example**:
```toml
# VALID
[weakdeps]
HeavyPackage = "some-uuid-here"

[extensions]
GlobtimHeavyPackageExt = "HeavyPackage"

# INVALID - causes KeyError
[deps]
HeavyPackage = "some-uuid-here"

[extensions]
GlobtimHeavyPackageExt = "HeavyPackage"  # ERROR: references regular dep
```

#### Rule 1.2: No Dual Dependencies
- **Rule**: A package cannot exist in both `[deps]` and `[weakdeps]`
- **Validation**: Check for package UUID conflicts between dependency sections

### 2. Package Architecture Rules

#### Rule 2.1: Core Minimal Principle
- **Rule**: Keep core package functionality minimal and dependency-light
- **Guidelines**:
  - Core algorithms and data structures only
  - No heavy plotting, modeling, or UI dependencies in core
  - Abstract interfaces preferred over concrete implementations

#### Rule 2.2: Heavy Dependencies → Extensions
- **Rule**: Move heavy dependencies to extensions
- **Target Dependencies**:
  - Heavy modeling packages
  - Plotting packages (Makie, Plots)
  - Database packages
  - Web frameworks
  - GUI packages

#### Rule 2.3: Interface Segregation
- **Rule**: Define clear abstract interfaces in core, implement in extensions
- **Pattern**:
```julia
# Core package (src/Globtim.jl)
abstract type AbstractModel end
function solve end  # Generic function

# Extension (ext/GlobtimHeavyPackageExt.jl)
module GlobtimHeavyPackageExt
    using Globtim, HeavyPackage
    Globtim.solve(::HeavyPackage.ProblemType, ...) = ...
end
```

### 3. Error Handling Rules

#### Rule 3.1: No Fallbacks for Circular Dependencies
- **Rule**: Align with project's "no fallbacks" policy - fail fast on circular dependencies
- **Implementation**: Don't silently work around circular dependencies, surface them as errors
- **Rationale**: Consistent with CLAUDE.md: "I don't want any fallbacks in the code"

#### Rule 3.2: Explicit Failure Messages
- **Rule**: Provide clear error messages when circular dependencies are detected
- **Format**: Include package names, dependency chain, and suggested fix

### 4. Testing Rules

#### Rule 4.1: Isolation Testing
- **Rule**: Always test package loading in isolation
- **Commands**:
```bash
# Test core package loading
julia --project=. -e "using Globtim; println(\"Success\")"

# Test with extensions
julia --project=. -e "using Globtim, ExtensionPackage; println(\"Both loaded\")"
```

#### Rule 4.2: Precompilation Validation
- **Rule**: Test precompilation explicitly and monitor warnings
- **Command**:
```bash
julia --project=. -e "using Pkg; Pkg.precompile()"
```
- **Acceptance**: Warnings allowed only if functionality is unaffected

#### Rule 4.3: CI Integration
- **Rule**: Include circular dependency checks in CI pipeline
- **Implementation**: Automated Project.toml validation and precompilation testing

### 5. Architectural Enforcement

#### Rule 5.1: Abstract First Pattern
- **Rule**: Define abstract types and generic functions in core
- **Implementation**: Use abstract base types, generic function signatures

#### Rule 5.2: Concrete in Extensions
- **Rule**: Implement specific behaviors only in extensions
- **Benefit**: Prevents core from depending on heavy packages

#### Rule 5.3: Lazy Loading
- **Rule**: Use conditional loading patterns for optional features
- **Pattern**:
```julia
function advanced_solve(problem)
    if !hasmethod(solve, (typeof(problem),))
        error("Advanced solving requires the appropriate extension. Load the required package first.")
    end
    solve(problem)
end
```

## Validation Tools

### Automated Checks
1. **Project.toml Validator**: Script to check extension-weakdep consistency
2. **Circular Dependency Detector**: Monitor for circular dependency warnings
3. **Package Loading Tests**: Automated isolation and integration testing

### Manual Review Checklist
- [ ] New dependencies added to appropriate section ([deps] vs [weakdeps])
- [ ] Extensions only reference weakdeps
- [ ] No package appears in multiple dependency sections
- [ ] Heavy dependencies moved to extensions
- [ ] Core functionality remains minimal

## Implementation Status

- **Fixed**: JuliaFormatter KeyError (extension configuration corrected)
- **Target**: Zero circular dependency warnings through proper architecture

## References

- Source: `docs/CIRCULAR_DEPENDENCY_RESOLUTION.md`
- Julia Extensions Documentation: https://pkgdocs.julialang.org/v1/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)
- Project Philosophy: CLAUDE.md "no fallbacks" policy