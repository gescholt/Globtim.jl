# Archived Examples Files - August 21, 2025

This directory contains Examples/ files that were archived during the dependency system restructuring on August 21, 2025.

## Reason for Archival

These files were moved to archive because they:
1. **Tested specific issues that have been resolved**
2. **Used outdated approaches superseded by the new dependency system**
3. **Contained demo code that is no longer relevant**
4. **Were specific workarounds for resolved problems**

## Archived Files by Category

### Old Test Files (Superseded by test suite)
- `test_basis_and_msolve.jl` - Old testing file for basis and msolve functionality
- `test_coefficient_plots.jl` - Test plotting functionality (now handled by extensions)
- `test_formatting_fix.jl` - Specific formatting test (issue resolved)
- `test_string_formatting.jl` - String formatting test (issue resolved)
- `debug_legendre_issue.jl` - Debug script for resolved Legendre issue
- `minimal_test.jl` - Minimal testing (superseded by comprehensive test suite)

### Superseded Setup Files (Replaced by modern system)
- `notebook_fix_test_input.jl` - Superseded by new notebook setup in .globtim/
- `notebook_makie_setup.jl` - Superseded by Makie extension system
- `parameters_jl_demo.jl` - Demo for Parameters.jl usage (now core dependency)

### Demo/Ideas Files (No longer relevant)
- `memory_usage_demo.jl` - Memory usage demonstration
- `L2_grid_ideas.jl` - Experimental ideas file (ideas implemented)

### Specific Issue Files (Issues resolved)
- `hpc_no_json3_example.jl` - Specific to resolved JSON3 issue
- `install_optional_deps.jl` - Obsolete with new weak dependency system

### Integration Files (Now in main codebase)
- `msolve_integration.jl` - Msolve integration (now part of core functionality)

## Context

These files were archived during the migration from a monolithic dependency system (33 direct dependencies) to a modern weak dependency system with package extensions (18 core + 8 weak dependencies).

The new system provides:
- ⚡ Faster startup times
- 🖥️ Better HPC compatibility  
- 🧩 Modular functionality
- 🔧 Cleaner maintainability

## Restoration

If any of these files are needed again:
1. Check if the functionality exists in the current codebase
2. Review if the approach is still valid with the new dependency system
3. Update to use modern package extensions if needed
4. Move back to appropriate Examples/ location

## Related Documentation

- `PACKAGE_DEPENDENCIES.md` - Complete guide to new dependency architecture
- `DEVELOPMENT_GUIDE.md` - Updated development workflows
- `Examples/Notebooks/` - Modern example implementations