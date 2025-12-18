# Repository Organization Review

**Date:** 2025-10-07
**Status:** ✅ Generally good, minor improvements possible

---

## ✅ What's Working Well

### Directory Structure
- Clean separation: `src/`, `test/`, `docs/`, `scripts/`, `tools/`, `experiments/`
- Tool organization: `tools/hpc/`, `tools/git/`, `tools/gitlab/`
- Proper `.gitignore` (comprehensive, includes results/archives/temp files)

### Recent Cleanup
- ✅ Root shell scripts organized (moved to proper directories)
- ✅ Custom deployment scripts archived
- ✅ Unified deployment workflow enforced
- ✅ Compliance validator created

---

## 🟡 Minor Organizational Issues

### 1. Multiple Archive Directories

**Current state:**
```
globtimcore/
├── archived/                    # Old Julia file (PostProcessing.jl.old)
├── archived_root_scripts/       # Recently archived shell scripts
└── archives/                    # HPC results archives
```

**Issue:** Three different archive directories with different purposes

**Recommendation:**
```
globtimcore/
├── docs/
│   └── archive/                # Archived documentation, old tools
│       ├── obsolete_tools_2025_10/
│       └── obsolete_scripts/
│           ├── PostProcessing.jl.old
│           ├── deploy_json_test.sh
│           └── launch_precision_study.sh
└── data/
    └── archives/               # Archived experimental results
        ├── hpc_results_archive_legacy_20250930/
        ├── precision_comparison_results/
        └── ...
```

**Actions:**
```bash
# Consolidate code/script archives
mkdir -p docs/archive/obsolete_scripts
mv archived/* docs/archive/obsolete_scripts/
mv archived_root_scripts/* docs/archive/obsolete_scripts/
rmdir archived archived_root_scripts

# Rename data archives (already in archives/)
# No action needed - data/archives/ is properly ignored in .gitignore
```

---

### 2. Root Directory Files

**Good files in root (keep):**
- `README.md`, `CHANGELOG.md`, `CLAUDE.md` - Primary documentation
- `Project.toml`, `Manifest.toml` - Julia project
- `Makefile` - Convenience commands
- `.gitignore`, `.gitlab-ci.yml` - Configuration
- `push.sh` → symlink to `tools/git/push_helper.sh` ✅

**Questionable files:**
```
globtimcore/
├── DATASET_ARCHIVAL_RECOMMENDATIONS.md   # Documentation → docs/?
├── EXPERIMENT_SCHEMA.md                  # Documentation → docs/?
├── analysis_summary.json                 # Temporary output?
```

**Recommendation:**

**Option 1: Move to docs/**
```bash
mv DATASET_ARCHIVAL_RECOMMENDATIONS.md docs/data/
mv EXPERIMENT_SCHEMA.md docs/experiments/
```

**Option 2: Keep in root if actively used**
- These might be "top-level" docs users need to find quickly
- If frequently referenced, root is OK
- Check: Are they linked from README.md?

**For `analysis_summary.json`:**
- Appears to be temporary output (analysis results)
- Should be in `analysis_output/` or ignored
- Add to `.gitignore` if not already: `analysis_summary.json`

---

### 3. Multiple Output Directories

**Current state:**
```
globtimcore/
├── analysis_output/             # Analysis outputs
├── hpc_results/                 # HPC experiment results (ignored)
├── test_results/                # Test outputs
├── test_metrics_output/         # Test metrics
├── node_experiments/            # Node experiment outputs (ignored)
└── collected_experiments_*/     # Collected results
```

**Issue:** Some output dirs are ignored (good), others might not be

**Recommendation:**

Verify `.gitignore` coverage:
```bash
# Should be ignored (don't commit outputs):
hpc_results/          ✅ (line 100)
node_experiments/     ✅ (line 151)
analysis_output/      ❌ NOT ignored
test_results/         ❌ NOT ignored
test_metrics_output/  ❌ NOT ignored
collected_experiments_*/ ✅ (line 169: collected_*_results/)
```

**Add to `.gitignore`:**
```gitignore
# Analysis and test outputs (keep local, don't commit)
analysis_output/
test_results/
test_metrics_output/
analysis_summary.json
```

**Rationale:** Output directories should not be committed to git (bloat, binary data, reproducible)

---

### 4. GitLab CI Configuration Files

**Current state:**
```
globtimcore/
├── .gitlab-ci.yml                  # Active
├── .gitlab-ci-enhanced.yml         # Alternative?
├── .gitlab-ci-hpc.yml              # Alternative?
├── .gitlab-ci-multiarch.yml        # Alternative?
├── .gitlab-ci-security.yml         # Alternative?
└── .gitlab-ci.yml.npm-example      # Example
```

**Issue:** Multiple CI config files (unclear which is active)

**Questions:**
1. Is `.gitlab-ci.yml` the only active one?
2. Are the others included/imported, or are they alternatives?
3. Is `.gitlab-ci.yml.npm-example` used?

**Recommendation:**

**If alternatives (not included):**
```bash
mkdir -p .gitlab/ci-configurations
mv .gitlab-ci-*.yml .gitlab/ci-configurations/
mv .gitlab-ci.yml.npm-example .gitlab/ci-configurations/examples/
```

**If included (modular CI):**
- Keep in root (GitLab may require it)
- Add comment in `.gitlab-ci.yml` explaining the structure

---

### 5. Hidden Directories

**Current state:**
```
.augment/       # ??? (3rd party tool?)
.cache/         # OK (build cache)
.claude/        # OK (Claude Code config)
.globtim/       # ??? (project-specific?)
.vscode/        # OK (editor config, should be in .gitignore ✅)
```

**Check `.augment/` and `.globtim/`:**

**Questions:**
- What is `.augment/`? (External tool, should be gitignored?)
- What is `.globtim/`? (Project-specific, should be documented)

**If unused/3rd party:**
```bash
# Add to .gitignore
.augment/
```

---

## 🎯 Recommended Actions

### Priority 1: Fix .gitignore (Prevent Output Commits)

```bash
# Add to .gitignore
echo "" >> .gitignore
echo "# Analysis and test output (temporary, don't commit)" >> .gitignore
echo "analysis_output/" >> .gitignore
echo "test_results/" >> .gitignore
echo "test_metrics_output/" >> .gitignore
echo "analysis_summary.json" >> .gitignore
```

### Priority 2: Consolidate Archive Directories

```bash
# Move code/script archives to docs/archive/
mkdir -p docs/archive/obsolete_scripts
mv archived/PostProcessing.jl.old docs/archive/obsolete_scripts/
mv archived/README.md docs/archive/obsolete_scripts/
mv archived_root_scripts/* docs/archive/obsolete_scripts/
rmdir archived archived_root_scripts

# Update docs/archive/obsolete_scripts/README.md
```

### Priority 3: Consider Moving Schema Docs

```bash
# If appropriate, move to docs/
mkdir -p docs/data docs/experiments
mv DATASET_ARCHIVAL_RECOMMENDATIONS.md docs/data/
mv EXPERIMENT_SCHEMA.md docs/experiments/

# Update README.md links if needed
```

### Priority 4: Document/Organize GitLab CI Files

Either:
1. Add comment to `.gitlab-ci.yml` explaining other files
2. Move alternatives to `.gitlab/ci-configurations/`
3. Delete unused configurations

### Priority 5: Check Unknown Directories

```bash
# Investigate .augment/ and .globtim/
ls -la .augment/
ls -la .globtim/

# If unused/external: add to .gitignore
```

---

## 🔍 Verification

### After Cleanup, Verify:

```bash
# 1. No shell scripts in root (except symlink)
ls *.sh 2>/dev/null  # Should only show push.sh symlink

# 2. Archive directories consolidated
ls -d archived* 2>/dev/null  # Should be empty/not exist

# 3. Output directories in .gitignore
git check-ignore analysis_output/ test_results/ test_metrics_output/
# Should output: analysis_output/, test_results/, test_metrics_output/

# 4. No untracked cruft
git status --short  # Should be clean

# 5. Deployment compliance
./tools/hpc/validate_deployment_compliance.sh  # Should pass
```

---

## 📊 Before/After Comparison

### Before
```
globtimcore/
├── hpc_tools.sh                         ❌ Obsolete
├── deploy_json_test.sh                  ❌ Custom deploy
├── launch_precision_study.sh            ❌ Custom deploy
├── test_*.sh (4 scripts)                ❌ Unorganized
├── archived/ (mixed content)            ❌ Unclear
├── archived_root_scripts/               ❌ Recent addition
├── archives/ (data)                     ⚠️  Mixed with code archives
├── analysis_output/ (not ignored)       ❌ Committed outputs
├── test_results/ (not ignored)          ❌ Committed outputs
└── Multiple unclear CI files            ⚠️  Undocumented
```

### After
```
globtimcore/
├── push.sh → tools/git/push_helper.sh   ✅ Symlink
├── docs/
│   └── archive/
│       └── obsolete_scripts/            ✅ Consolidated
├── data/
│   └── archives/                        ✅ Clear purpose
├── test/cluster/test_*.sh               ✅ Organized
├── tools/
│   ├── git/push_helper.sh              ✅ Organized
│   ├── hpc/diagnostics/                ✅ Organized
│   └── utilities/                      ✅ Organized
├── .gitignore (updated)                 ✅ Outputs ignored
└── .gitlab-ci.yml (documented)          ✅ Clear structure
```

---

## 🎯 Summary

### Current Status
- **Generally good** organization ✅
- Recent cleanup very effective ✅
- Minor improvements possible 🟡

### Key Issues
1. 🟡 Multiple archive directories (low priority)
2. 🔴 Output directories not gitignored (fix now)
3. 🟡 Schema docs in root (optional move)
4. 🟡 Multiple CI configs (document or organize)
5. 🟡 Unknown hidden dirs (investigate)

### Actions
1. ✅ **DO NOW:** Update `.gitignore` for output directories
2. 🟡 **SOON:** Consolidate archive directories
3. 🟡 **OPTIONAL:** Move schema docs to `docs/`
4. 🟡 **OPTIONAL:** Organize GitLab CI files
5. 🟡 **INVESTIGATE:** `.augment/`, `.globtim/` directories

---

**Generated:** 2025-10-07
**Priority:** Low-Medium (organizational maintenance)
**Estimated effort:** 15-30 minutes
