# Documentation Organization Plan

## 📊 Current State Analysis

**Total Markdown Files**: 395 files across the repository

## 🗂️ File Categories & Recommendations

### 1. **Root Level Files** (Keep & Update)
- ✅ `README.md` - Main project documentation
- ✅ `CHANGELOG.md` - Version history
- ✅ `DEVELOPMENT_GUIDE.md` - Developer onboarding
- ⚠️ `ENVIRONMENT_SETUP.md` - **CONSOLIDATE** with DEVELOPMENT_GUIDE.md
- ⚠️ `JULIA_CONDA_SETUP.md` - **CONSOLIDATE** with DEVELOPMENT_GUIDE.md
- ⚠️ `NOTEBOOK_SETUP_COMPLETE.md` - **CONSOLIDATE** with DEVELOPMENT_GUIDE.md
- ⚠️ `NOTEBOOK_WORKFLOW.md` - **CONSOLIDATE** with DEVELOPMENT_GUIDE.md
- ⚠️ `JULIA_WARNINGS_SOLUTION.md` - **MOVE** to docs/troubleshooting/

### 2. **HPC Documentation** (Consolidate & Update)
#### Current Status: SCATTERED across multiple locations
- `hpc/README.md` ✅ **KEEP** - Main HPC guide
- `hpc/docs/TMP_FOLDER_PACKAGE_STRATEGY.md` ✅ **KEEP** - New quota solution
- `hpc/jobs/submission/QUOTA_WORKAROUND_SOLUTION.md` ✅ **KEEP** - Working solution
- `hpc/jobs/submission/DEUFLHARD_BENCHMARK_RESULTS.md` ✅ **KEEP** - Test results

#### Obsolete HPC Files (ARCHIVE):
- `docs/HPC_*.md` (8+ files) - **CONSOLIDATE** into hpc/docs/
- `archive/docs/SLURM_VSCODE_SETUP.md` - **DELETE** (obsolete)
- `archive/docs/PYTHON_SLURM_MONITOR_GUIDE.md` - **UPDATE** or DELETE

### 3. **Examples Documentation** (Organize by Function)
#### Current: 50+ scattered README files
#### Recommendation: **CONSOLIDATE** into function-specific guides
- `Examples/*/README.md` - Many duplicates and outdated
- Create: `docs/examples/BENCHMARK_FUNCTIONS_GUIDE.md`
- Create: `docs/examples/4D_TESTING_GUIDE.md`
- Create: `docs/examples/ADAPTIVE_PRECISION_GUIDE.md`

### 4. **Archive Directory** (Clean Up)
#### Status: Contains 50+ obsolete files
- `archive/docs/` - **REVIEW** and DELETE most files
- `archive/obsolete/` - **DELETE** entire directory
- Keep only: Recent backup files with clear purpose

### 5. **Development Documentation** (Consolidate)
#### Current: 30+ files in docs/development/
#### Recommendation: **MERGE** related topics
- Anisotropic grid files (5 files) → 1 comprehensive guide
- Implementation plans (8 files) → Current roadmap
- Integration issues (6 files) → Known issues tracker

### 6. **Experiment Documentation** (Archive Old)
#### Current: 100+ files across experiments/week*/
#### Recommendation: **ARCHIVE** old experiments, keep recent
- `experiments/week0-6/` → **ARCHIVE** (historical)
- `experiments/week7/` → **KEEP** (recent work)
- Create: `docs/experiments/EXPERIMENT_ARCHIVE.md`

## 🎯 Consolidation Actions

### Phase 1: Root Level Cleanup
```bash
# Consolidate setup guides
cat ENVIRONMENT_SETUP.md JULIA_CONDA_SETUP.md NOTEBOOK_SETUP_COMPLETE.md >> DEVELOPMENT_GUIDE.md
rm ENVIRONMENT_SETUP.md JULIA_CONDA_SETUP.md NOTEBOOK_SETUP_COMPLETE.md NOTEBOOK_WORKFLOW.md

# Move troubleshooting
mkdir -p docs/troubleshooting/
mv JULIA_WARNINGS_SOLUTION.md docs/troubleshooting/
```

### Phase 2: HPC Documentation Consolidation
```bash
# Move scattered HPC docs to central location
mkdir -p hpc/docs/archive/
mv docs/HPC_*.md hpc/docs/archive/
mv archive/docs/SLURM_*.md hpc/docs/archive/
mv archive/docs/PYTHON_SLURM_*.md hpc/docs/archive/

# Create consolidated HPC guide
# Combine: hpc/README.md + working solutions + troubleshooting
```

### Phase 3: Examples Organization
```bash
# Create examples documentation structure
mkdir -p docs/examples/
mkdir -p docs/examples/functions/
mkdir -p docs/examples/testing/

# Consolidate function-specific READMEs
find Examples/ -name "README.md" -exec echo "Processing: {}" \;
```

### Phase 4: Archive Cleanup
```bash
# Remove obsolete archives
rm -rf archive/obsolete/
rm -rf archive/temp-files/

# Clean up old experiment documentation
find experiments/week[0-6]/ -name "*.md" -exec mv {} archive/docs/experiments/ \;
```

## 📋 New Documentation Structure

### Proposed Organization:
```
docs/
├── README.md                    # Documentation index
├── user_guides/
│   ├── GETTING_STARTED.md      # Consolidated setup guide
│   ├── BENCHMARK_FUNCTIONS.md  # Function usage guide
│   └── HPC_USAGE.md            # HPC user guide
├── development/
│   ├── ROADMAP.md              # Current development plan
│   ├── KNOWN_ISSUES.md         # Consolidated issues tracker
│   └── CONTRIBUTING.md         # Developer guidelines
├── examples/
│   ├── BASIC_USAGE.md          # Simple examples
│   ├── ADVANCED_FEATURES.md    # Complex workflows
│   └── HPC_BENCHMARKING.md     # Cluster usage examples
├── troubleshooting/
│   ├── COMMON_ISSUES.md        # FAQ and solutions
│   ├── JULIA_SETUP.md          # Julia-specific issues
│   └── HPC_ISSUES.md           # Cluster-specific problems
└── archive/
    ├── EXPERIMENT_HISTORY.md   # Historical experiments
    ├── DEPRECATED_FEATURES.md  # Removed functionality
    └── old_docs/               # Archived documentation
```

## 🔄 Implementation Priority

### High Priority (Complete First)
1. **Root level consolidation** - Reduce clutter in main directory
2. **HPC documentation** - Critical for current work
3. **Archive cleanup** - Remove obsolete files

### Medium Priority
4. **Examples organization** - Improve user experience
5. **Development docs** - Consolidate scattered plans

### Low Priority
6. **Experiment archives** - Historical preservation
7. **Advanced reorganization** - Fine-tuning structure

## 📊 Expected Results

### Before Cleanup:
- **395 markdown files** scattered across repository
- **Duplicate information** in multiple locations
- **Obsolete documentation** mixed with current
- **Difficult navigation** for users and developers

### After Cleanup:
- **~100 markdown files** in organized structure
- **Single source of truth** for each topic
- **Clear separation** of current vs. archived content
- **Easy navigation** with logical hierarchy

## 🎯 Success Metrics

1. **File Reduction**: 395 → ~100 files (75% reduction)
2. **Duplicate Elimination**: No duplicate information
3. **Clear Structure**: Logical hierarchy for all documentation
4. **User Experience**: Easy to find relevant information
5. **Maintenance**: Easier to keep documentation current

## 📞 Next Steps

1. **Review and approve** this organization plan
2. **Execute Phase 1** (root level cleanup)
3. **Test navigation** with reorganized structure
4. **Iterate and improve** based on usage patterns
5. **Establish maintenance** procedures for future documentation

This plan will transform the documentation from a scattered collection into a well-organized, maintainable knowledge base.
