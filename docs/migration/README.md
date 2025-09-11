# Globtim Plotting Migration Toolkit

This directory contains all the tools and documentation needed to manually migrate plotting functionality from Globtim to the independent GlobtimPlots.jl package.

## 📋 What's Available

### Documentation
- **[PLOTTING_API_INVENTORY.md](PLOTTING_API_INVENTORY.md)** - Complete inventory of all 45+ plotting functions
- **[MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)** - Detailed checklist for manual migration
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference for common patterns and commands

### Code Interfaces  
- **[src/migration/AbstractPlottingInterfaces.jl](../../src/migration/AbstractPlottingInterfaces.jl)** - Abstract interfaces for GlobtimPlots
- **[src/migration/GlobtimDataAdapters.jl](../../src/migration/GlobtimDataAdapters.jl)** - Data adapters for compatibility testing

### Analysis Tools
- **[scripts/migration/extract_plotting_functions.jl](../../scripts/migration/extract_plotting_functions.jl)** - Function extraction helper
- **[scripts/migration/analyze_plotting_dependencies.jl](../../scripts/migration/analyze_plotting_dependencies.jl)** - Dependency analysis tool

## 🚀 Getting Started

### 1. Analyze Current State
```bash
# See all plotting functions 
julia scripts/migration/extract_plotting_functions.jl --list

# Analyze dependencies and migration order
julia scripts/migration/analyze_plotting_dependencies.jl
```

### 2. Extract Function Information
```bash
# Get detailed info about a specific function
julia scripts/migration/extract_plotting_functions.jl cairo_plot_polyapprox_levelset
```

### 3. Follow Migration Checklist
- Open [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) 
- Work through phases 1-4 systematically
- Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common patterns

## 🎯 Migration Strategy Summary

### Zero-Breakage Approach
1. **Build GlobtimPlots.jl independently** (no Globtim changes)
2. **Test thoroughly with sample data**
3. **Add optional integration to Globtim** (keeping old functions)
4. **Community validation period**
5. **Gradual deprecation** (only after proven stable)

### Migration Phases
- **Phase 1**: Simple statistical plots (low risk)
- **Phase 2**: Standard 2D/3D visualization (medium risk)
- **Phase 3**: Advanced interactive features (high risk)  
- **Phase 4**: Complex animations and real-time systems (highest risk)

## 📊 Current State Analysis

### Functions to Migrate: **45+**
- **CairoMakie Functions**: 11 (static plots)
- **GLMakie Functions**: 10 (interactive/3D)  
- **Interactive Systems**: 8 (real-time features)
- **Specialized Analysis**: 16+ (eigenvalues, convergence, etc.)

### Files to Process: **10 major files**
- `src/graphs_cairo.jl` (580 lines) - **Priority: HIGH**
- `src/graphs_makie.jl` (1000+ lines) - **Priority: HIGH** 
- `ext/GlobtimCairoMakieExt.jl` (580 lines) - **Priority: HIGH**
- `ext/GlobtimGLMakieExt.jl` (1155 lines) - **Priority: HIGH**
- Plus 6 additional specialized files

### Key Data Types to Abstract:
- `ApproxPoly{T,S}` → `AbstractPolynomialData`
- `test_input` → `AbstractProblemData`  
- `DataFrame` → `AbstractCriticalPointData`
- `LevelSetData` → `AbstractLevelSetData`

## 🛠️ Tools Usage

### Function Analysis
```bash
# List all functions by category
julia scripts/migration/extract_plotting_functions.jl --list

# Deep dive on specific function
julia scripts/migration/extract_plotting_functions.jl plot_polyapprox_3d
```

### Dependency Analysis  
```bash
# Analyze all dependencies and get migration order
julia scripts/migration/analyze_plotting_dependencies.jl
```

Output shows:
- Complexity scores for each file
- Suggested migration phases
- Internal/external dependency mapping
- Function complexity analysis

## 📁 Directory Structure for GlobtimPlots.jl

Recommended structure for the new package:

```
GlobtimPlots.jl/
├── src/
│   ├── GlobtimPlots.jl              # Main module  
│   ├── interfaces/
│   │   ├── data_types.jl            # Abstract interfaces
│   │   └── plotting_api.jl          # Common API
│   ├── backends/
│   │   ├── cairo_backend.jl         # CairoMakie implementation
│   │   ├── glmakie_backend.jl       # GLMakie implementation
│   │   └── abstract_backend.jl      # Backend abstraction
│   ├── visualizations/
│   │   ├── level_sets.jl           # Level set plots
│   │   ├── convergence.jl          # Convergence analysis  
│   │   ├── eigenvalue.jl           # Eigenvalue visualization
│   │   ├── polynomial.jl           # Polynomial analysis
│   │   └── interactive.jl          # Interactive features
│   └── utilities/
│       ├── data_conversion.jl      # Data adapters
│       └── plot_config.jl          # Configuration
├── ext/
│   ├── CairoMakieExt.jl           # CairoMakie extension
│   ├── GLMakieExt.jl              # GLMakie extension  
│   └── VisualizationExt.jl        # Framework extension
└── test/
    ├── plotting_tests.jl          # Core tests
    └── backend_tests.jl           # Backend tests
```

## ✅ Success Criteria

### Technical Goals
- [ ] All plotting functions work independently of Globtim
- [ ] Identical visual output to original functions
- [ ] Clean abstract interfaces with no Globtim dependencies
- [ ] Performance parity or improvement
- [ ] Comprehensive test coverage

### User Experience Goals  
- [ ] Easy migration path for existing users
- [ ] Clear documentation and examples
- [ ] Backward compatibility during transition
- [ ] Community validation and feedback

## 💡 Next Steps

1. **Create GlobtimPlots.jl repository**
2. **Copy abstract interfaces** from this toolkit
3. **Start with Phase 1 functions** (simple statistical plots)
4. **Use analysis tools** to understand each function before copying
5. **Test thoroughly** with sample data before integration
6. **Follow the checklist** systematically

## 🆘 Need Help?

- Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common patterns
- Use the analysis tools to understand function dependencies
- Refer to [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) for detailed steps
- Test each phase completely before moving to the next

---

**Remember**: This is a manual migration process. The tools help analyze and understand the current code, but you'll copy and adapt files by hand to ensure quality and understanding.

*Happy migrating! 🚀*