# Folder Structure Cleanup Plan for by_degree/

## Current State Analysis

The `by_degree` folder has evolved through multiple iterations (v1, v2, v3) and contains:
- **70+ files** in archived directories
- **Active code**: Only ~10 files actually in use
- **Rich documentation**: 12+ detailed docs in documentation/
- **Historical outputs**: Many timestamped result directories

## Proposed Structure (Minimal Disruption)

```
by_degree/
├── README.md                    # Keep as-is
├── run_all_examples.jl          # Keep as-is
├── CLEANUP_PLAN.md             # This document
│
├── src/                        # Active source code (renamed from 'shared')
│   ├── Common4DDeuflhard.jl
│   ├── SubdomainManagement.jl
│   ├── MinimizerTracking.jl
│   └── EnhancedVisualization.jl
│
├── examples/                   # Keep current structure
│   ├── degree_convergence_analysis_enhanced_v3.jl  # Active
│   └── README.md
│
├── data/                       # Reference data (renamed from 'points_deufl')
│   ├── 2d_coords.csv
│   └── 4d_min_min_domain.csv
│
├── docs/                       # Consolidated documentation (renamed from 'documentation')
│   ├── README.md              # Main docs index
│   ├── implementation/        # Implementation details
│   │   ├── V3_IMPLEMENTATION_SUMMARY.md
│   │   ├── implementation_summary.md
│   │   ├── critical_code_decisions.md
│   │   └── data_flow_diagram.md
│   └── reference/            # Reference documentation
│       ├── function_io_reference.md
│       ├── orthant_restriction.md
│       └── output_structure.md
│
├── outputs/                   # Keep as-is (active outputs)
│   └── [timestamped dirs]
│
└── archive/                   # All historical content (renamed from 'archived')
    ├── 2025_01_cleanup/      # Previous cleanup
    ├── legacy_examples/      # Old example versions
    ├── archived_outputs/     # Historical outputs
    └── legacy_v2/           # Archive v2 implementation
```

## Key Changes (Minimal Code Impact)

### 1. Simple Renames (No Code Changes)
- `shared/` → `src/` (more standard Julia convention)
- `points_deufl/` → `data/` (clearer purpose)
- `documentation/` → `docs/` (shorter, standard)
- `archived/` → `archive/` (consistency)

### 2. Code Updates Required (4 lines total)

**In `examples/degree_convergence_analysis_enhanced_v3.jl`:**
```julia
# Lines 16-19: Update includes
include("../src/Common4DDeuflhard.jl")           # was: ../shared/
include("../src/SubdomainManagement.jl")         # was: ../shared/
include("../src/MinimizerTracking.jl")           # was: ../shared/
include("../src/EnhancedVisualization.jl")       # was: ../shared/
```

**In `examples/degree_convergence_analysis_enhanced_v3.jl`:**
```julia
# Line 269: Update data path
load_true_minimizers(joinpath(@__DIR__, "../data/4d_min_min_domain.csv"))  # was: ../points_deufl/
```

### 3. Files to Archive
- `examples/degree_convergence_analysis_enhanced_v2.jl` → `archive/legacy_v2/`
- `archive_files.sh` → Can be removed after cleanup

### 4. Documentation Reorganization
- Group implementation docs together
- Separate reference material
- Keep README files at each level for navigation

## Migration Steps

1. **Create new directories**:
   ```bash
   mkdir -p src data docs/implementation docs/reference archive/legacy_v2
   ```

2. **Move files** (see migration script below)

3. **Update code paths** (5 lines total)

4. **Test** to ensure everything works

5. **Clean up** empty directories

## Benefits

1. **Cleaner root**: Only essential files visible
2. **Standard naming**: Following Julia package conventions
3. **Logical grouping**: Implementation vs reference docs
4. **Preserved history**: All content retained in archive
5. **Minimal disruption**: Only 5 lines of code to update

## Migration Script

```bash
#!/bin/bash
# migration.sh - Safe migration with backups

# Create backup first
cp -r . ../by_degree_backup_$(date +%Y%m%d_%H%M%S)

# Create new structure
mkdir -p src data docs/implementation docs/reference archive/legacy_v2

# Move shared to src
mv shared/* src/

# Move points_deufl to data
mv points_deufl/* data/

# Move and organize documentation
mv documentation/README.md docs/
mv documentation/{V3_IMPLEMENTATION_SUMMARY,implementation_summary,critical_code_decisions,data_flow_diagram}.md docs/implementation/
mv documentation/{function_io_reference,orthant_restriction,output_structure}.md docs/reference/
mv documentation/*.md docs/reference/  # Remaining docs

# Archive v2
mv examples/degree_convergence_analysis_enhanced_v2.jl archive/legacy_v2/

# Clean up empty dirs
rmdir shared points_deufl documentation

echo "Migration complete! Don't forget to update the 5 code paths."
```

## Post-Cleanup Verification

1. Run `run_all_examples.jl` to ensure functionality
2. Check all imports resolve correctly
3. Verify outputs are generated properly
4. Update any documentation references to old paths