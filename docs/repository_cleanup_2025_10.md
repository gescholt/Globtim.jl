# Repository Cleanup Report - October 2025

**Generated**: 2025-10-20
**Repository**: globtimcore
**Objective**: Audit and clean up orphaned test files, unused scripts, and legacy Claude agents/hooks

---

## Executive Summary

**Audit Results**:
- **Test Files**: 175 total, 26 included in `runtests.jl`, **149 orphaned/specialized**
- **Scripts**: 43 active scripts across 6 categories
- **Claude Agents**: 6 agents (5 active, 1 needs review)
- **Claude Hooks**: 3 hooks (all potentially legacy)
- **Experiment Templates**: 3 campaigns (1 exemplar template identified)

**Recommended Actions**:
1. Archive 149 orphaned/development test files
2. Consolidate specialized test suites into organized structure
3. Update/archive Claude hooks (git-auto-commit-push is problematic)
4. Maintain all Claude agents with minor documentation updates
5. Use lv4d_campaign_2025 as canonical experiment template

---

## 1. Test File Analysis

### 1.1 Current State

**Main Test Suite** (`test/runtests.jl`):
- Includes **26 test files** that are actively run by CI
- Covers core functionality: approximation, quadrature, grids, metrics

**Orphaned/Specialized Tests**: **149 test files** not included in main suite

Categories:
1. **Development Tests** (24 files in `development_tests/`)
   - Plot testing, visualization, dashboard generation
   - File I/O validation, JSON handling
   - Interactive display experiments
   - **Status**: Development artifacts, not production tests

2. **Specialized Tests** (25+ files in `specialized_tests/`)
   - Dagger integration tests (3 files)
   - Error categorization tests
   - Environment/path resolution tests
   - Integration results (4 timestamped test files)
   - **Status**: One-off investigation tests

3. **DrWatson Tests** (6 files in `drwatson/`)
   - Installation, savename, dict macro, datadir, tagsave, produce_or_load
   - **Status**: Legacy from abandoned DrWatson.jl integration

4. **Modular Architecture Tests** (4 files in `modular_architecture/`)
   - DashboardCore, DataInterface, EnvironmentBridge, SafeVisualization
   - **Status**: Tests for experimental architecture (not adopted)

5. **Launch Helper Tests** (5 files in `launch_helper/`)
   - Config discovery, environment detection, HPC sync, SSH launcher
   - **Status**: Tests for abandoned launch infrastructure

6. **Dataframe Interface Tests** (1 file in `dataframe_interface/`)
   - Column naming consistency
   - **Status**: May be relevant if feature is active

7. **Phase 1 Tests** (2 files in `phase1/`)
   - Core independence, core load
   - **Status**: Tests from phased refactoring (completed?)

8. **Lifecycle Manager Tests** (1 file in `lifecycle_manager_error_recovery/`)
   - Collection error reporting
   - **Status**: May be active if lifecycle manager exists

9. **Adaptive Format CSV Tests** (1 file in `adaptive_format_csv/`)
   - Adaptive CSV format handling
   - **Status**: Check if this feature is still used

10. **Fixtures** (2 files in `fixtures/mock_scripts/`)
    - Mock experiment scripts for testing
    - **Status**: Utilities, should be kept if tests use them

11. **Standalone Development Tests** (78+ files in `test/` root)
    - Numerous one-off test files (test_4d_benchmark_hpc.jl, test_aqua_compliance.jl, etc.)
    - Many have duplicates or variations (test_adaptive_precision*.jl - 4 variants)
    - **Status**: Most are development experiments or abandoned features

### 1.2 Recommended Test File Actions

#### Archive Immediately (Low Risk)
```bash
test/drwatson/                          # 6 files - DrWatson abandoned
test/development_tests/                  # 24 files - not production tests
test/modular_architecture/               # 4 files - experimental architecture not adopted
test/launch_helper/                      # 5 files - abandoned infrastructure
test/specialized_tests/integration/results/  # 4 files - timestamped integration tests
```
**Total**: ~43 files to archive

#### Review and Decide
```bash
test/specialized_tests/dagger_integration/  # 3 files - is Dagger still used?
test/specialized_tests/environment/         # 2 files - path resolution still relevant?
test/specialized_tests/error_categorization/ # 1 file - error taxonomy still active?
test/lifecycle_manager_error_recovery/      # 1 file - lifecycle manager status?
test/adaptive_format_csv/                   # 1 file - CSV format still used?
test/dataframe_interface/                   # 1 file - column naming still relevant?
test/phase1/                                # 2 files - phased refactoring complete?
```

#### Consolidate Duplicates/Variants
```bash
# Adaptive precision tests (4 variants - pick one canonical version)
test/test_adaptive_precision.jl
test/test_adaptive_precision_core.jl
test/test_adaptive_precision_minimal.jl
test/test_adaptive_precision_runner.jl

# Aqua tests (2 variants)
test/test_aqua.jl  (✓ In runtests.jl)
test/test_aqua_compliance.jl

# Enhanced metrics tests (check which are in runtests.jl)
test/test_enhanced_metrics_cluster.jl
test/test_enhanced_metrics_dejong2d.jl  (✓ In runtests.jl)
test/test_enhanced_metrics_e2e.jl       (✓ In runtests.jl)
test/test_enhanced_metrics_integration.jl (✓ In runtests.jl)

# Issue 124 tests (2 variants)
test/test_issue_124_end_to_end.jl
test/test_issue_124_integration.jl      (✓ In runtests.jl)

# MainGen grid tests (5 variants - which ones are canonical?)
test/test_maingen_grid_basic.jl
test/test_maingen_grid_extension_fixed.jl
test/test_maingen_grid_extension_plan.jl
test/test_maingen_grid_extension.jl
test/test_maingen_grid_functionality.jl (✓ In runtests.jl)
```

### 1.3 Proposed Archive Structure

Create organized archive:
```bash
test/archived_2025_10/
├── drwatson_integration/          # DrWatson.jl experiments
├── visualization_development/     # Plot/display tests
├── modular_architecture/          # Experimental architecture
├── launch_infrastructure/         # Abandoned launch helpers
├── development_experiments/       # One-off development tests
├── integration_snapshots/         # Timestamped integration tests
└── README.md                      # Archive documentation
```

---

## 2. Scripts Analysis

### 2.1 Active Scripts (Keep All)

**Analysis Scripts** (11 files in `scripts/analysis/`):
- ✓ `analyze_lotka_volterra_results.jl` - LV result analysis
- ✓ `analyze_lv4d_range_study.jl` - Range study analysis
- ✓ `analyze_transferred_data.jl` - Data transfer analysis
- ✓ `collect_cluster_experiments.jl` - HPC result collection
- ✓ `compare_experiments_demo.jl` - Experiment comparison
- ✓ `critical_point_refinement_analyzer.jl` - Refinement analysis
- ✓ `lotka_volterra_convergence_analysis.jl` - Convergence analysis
- ✓ `plot_convergence_simple.jl` - Simple plotting
- ✓ `simple_lv4d_analysis.jl` - Basic LV4D analysis
- ✓ `visualize_cluster_results.jl` - Cluster visualization
- ✓ `visualize_with_globtimplots.jl` - GlobtimPlots integration

**Development Scripts** (4 files in `scripts/dev/`):
- ✓ `activate_local.jl` - Local environment activation
- ✓ `create_fixed_homotopy_bundle.jl` - Homotopy bundling
- ✓ `format-julia.sh` - Code formatting
- ✓ `hpc-mode.sh` - HPC mode switching
- ⚠️ `auto-release.jl` - Check if still used for releases
- ⚠️ `julia-project.sh` - Purpose unclear
- ⚠️ `setup-npm-docs.sh` - NPM docs setup (Julia project?)

**Experiment Scripts** (3 files in `scripts/experiments/`):
- ✓ `launch_4d_lv_campaign.sh` - LV campaign launcher
- ✓ `launch_4dlv_param_recovery.sh` - Parameter recovery launcher
- ✓ `test_session_tracking_launcher.sh` - Session tracking test

**GitLab Scripts** (17 files in `scripts/gitlab/`):
- ✓ All GitLab integration scripts appear active
- Used for issue tracking, sprint planning, project dashboards
- **Recommendation**: Keep all, verify they work with current glab CLI

**HPC Scripts** (2 files in `scripts/hpc/`):
- ✓ `activate_hpc.jl` - HPC environment activation
- ✓ `generate_cluster_report.jl` - Cluster reporting

**Setup Scripts** (2 files in `scripts/setup/`):
- ✓ `setup_repository.sh` - Repository initialization
- ✓ `validate_git_config.sh` - Git configuration validation

**Testing Scripts** (4 files in `scripts/testing/`):
- ✓ `performance-regression-check.jl` - Performance monitoring
- ✓ `quick-aqua-check.jl` - Fast Aqua checks
- ✓ `run-aqua-tests.jl` - Full Aqua suite
- ✓ `setup-aqua-env.jl` - Aqua environment setup

**Root Scripts** (2 files in `scripts/`):
- ✓ `cleanup_legacy_results.sh` - Result cleanup
- ✓ `setup_results_root.sh` - Results directory setup

### 2.2 Scripts Needing Review

1. **scripts/dev/auto-release.jl**
   - **Question**: Is automated releasing still used?
   - **Action**: Check last modification date and usage

2. **scripts/dev/julia-project.sh**
   - **Question**: What does this do? Redundant with Pkg activation?
   - **Action**: Review purpose and consolidate if redundant

3. **scripts/dev/setup-npm-docs.sh**
   - **Question**: Why NPM in a Julia project?
   - **Action**: Verify if documentation still uses NPM tools

4. **scripts/gitlab/\* (all 17 files)**
   - **Question**: Do they work with current glab CLI?
   - **Action**: Test critical scripts (issue creation, listing, updates)

---

## 3. Claude Agents Analysis

### 3.1 Current Agents

Located in `.claude/agents/` (6 agents):

1. **hpc-cluster-operator.md** ✅ ACTIVE
   - **Purpose**: HPC r04n02 node operations, tmux management, Julia packages
   - **Status**: Actively used, well-documented
   - **Action**: Keep, consider updating with latest node details

2. **julia-documenter-expert.md** ✅ ACTIVE
   - **Purpose**: Documenter.jl documentation generation
   - **Status**: Used for documentation tasks
   - **Action**: Keep, verify Documenter.jl setup is current

3. **julia-repo-guardian.md** ✅ ACTIVE
   - **Purpose**: Repository consistency, code quality, structure
   - **Status**: Useful for maintenance tasks
   - **Action**: Keep, update with current repo structure

4. **julia-test-architect.md** ✅ ACTIVE
   - **Purpose**: Test suite design and implementation
   - **Status**: Valuable for test creation
   - **Action**: Keep, very relevant given test cleanup

5. **project-task-updater.md** ⚠️ REVIEW
   - **Purpose**: GitLab issue management and project tracking
   - **Status**: Extensive agent (419 lines), uses glab CLI
   - **Issues**:
     - References `/Users/ghscholt/globtimcore` (should be `/Users/ghscholt/GlobalOptim/globtimcore`)
     - Complex GitLab integration - verify it works with current setup
     - Has HPC security integration that may not be needed
   - **Action**: Review and update paths, test GitLab operations

6. **ssh-security-integration-guide.md** ⚠️ REVIEW
   - **Purpose**: SSH security for HPC operations
   - **Status**: May be overly complex for current needs
   - **Action**: Review if still necessary given direct r04n02 access

### 3.2 Agent Recommendations

**Keep As-Is**: hpc-cluster-operator, julia-documenter-expert, julia-repo-guardian, julia-test-architect

**Update Paths**: project-task-updater (fix repository paths)

**Review Necessity**: ssh-security-integration-guide (may be legacy)

---

## 4. Claude Hooks Analysis

### 4.1 Current Hooks

Located in `.claude/hooks/` (3 hooks):

1. **git-auth-enforcer.md** ⚠️ REVIEW
   - **Purpose**: Enforce proper git authentication
   - **Status**: May conflict with normal git operations
   - **Issues**: Could be annoying if it blocks legitimate work
   - **Action**: Test behavior, consider disabling

2. **git-auto-commit-push.md** ❌ PROBLEMATIC
   - **Purpose**: Auto-commit and push after significant work
   - **Status**: **DANGEROUS PATTERN**
   - **Issues**:
     - Auto-commits can create messy history
     - Pushes without user review
     - Could push sensitive data or broken code
     - Goes against best practices for version control
   - **Action**: **Archive immediately**, remove from active hooks

3. **hpc-node-security.md** ⚠️ REVIEW
   - **Purpose**: Security checks for HPC operations
   - **Status**: May be redundant given direct node access
   - **Action**: Review necessity, may be legacy

### 4.2 Hook Recommendations

**Archive**: git-auto-commit-push (dangerous pattern)

**Review and Test**: git-auth-enforcer, hpc-node-security

**Potential Replacement**: Consider simpler hooks that prompt user rather than auto-execute

---

## 5. Experiment Templates

### 5.1 Current Campaigns

Located in `experiments/`:

1. **lv4d_campaign_2025/** ✅ EXEMPLAR TEMPLATE
   - **Purpose**: 4D Lotka-Volterra domain sweep campaign
   - **Status**: Well-structured, documented, complete
   - **Components**:
     - experiment_manifest.json (metadata)
     - run_lv4d_experiment.jl (single experiment runner)
     - launch_deg18_campaign.sh (batch launcher)
     - monitor_campaign.sh (progress monitoring)
     - collect_campaign_results.jl (result aggregation)
     - basis_comparison_experiment.jl (basis comparison)
     - README.md (comprehensive documentation)
   - **Action**: **Use as canonical template for new campaigns**

2. **daisy_ex3_4d_study/** ✅ ACTIVE
   - **Purpose**: Daisy example 3 validation
   - **Status**: Contains many validation scripts (7 files)
   - **Action**: Keep - campaign will be expanded

3. **lv4d_loss_comparison_2025/** ✅ ACTIVE
   - **Purpose**: Loss function comparison experiments
   - **Status**: Active, will be expanded
   - **Action**: Keep - ongoing work

4. **generated/** ⚠️ CLEANUP
   - **Purpose**: Auto-generated experiment files?
   - **Status**: Contains 1 file (lv4d_deg4-12_domain0.1_GN12_20251016_134239.jl)
   - **Action**: Review policy for generated files, may need .gitignore

### 5.2 Template Recommendations

- **Canonical Template**: lv4d_campaign_2025 is the reference
- **Skill Created**: experiment-campaign.md now provides expert guidance
- **Archive Completed Studies**: Move daisy_ex3_4d_study if complete
- **Review Active Experiments**: Determine lv4d_loss_comparison_2025 status

---

## 6. Implementation Plan

### Phase 1: Test File Cleanup (High Priority)

```bash
# 1. Create archive structure
mkdir -p test/archived_2025_10/{drwatson_integration,visualization_development,modular_architecture,launch_infrastructure,development_experiments,integration_snapshots}

# 2. Archive low-risk directories
mv test/drwatson test/archived_2025_10/drwatson_integration/
mv test/development_tests test/archived_2025_10/visualization_development/
mv test/modular_architecture test/archived_2025_10/modular_architecture/
mv test/launch_helper test/archived_2025_10/launch_infrastructure/
mv test/specialized_tests/integration/results test/archived_2025_10/integration_snapshots/

# 3. Document archive
cat > test/archived_2025_10/README.md << 'EOF'
# Archived Tests - October 2025

This directory contains test files archived during the October 2025 repository cleanup.

## Archive Categories

- **drwatson_integration/**: Tests for abandoned DrWatson.jl integration
- **visualization_development/**: Development tests for plotting/visualization
- **modular_architecture/**: Experimental architecture tests (not adopted)
- **launch_infrastructure/**: Tests for abandoned launch helpers
- **development_experiments/**: One-off development test files
- **integration_snapshots/**: Timestamped integration test results

## Restoration

If you need to restore any of these tests:
1. Move the file back to test/
2. Add appropriate include() to test/runtests.jl if needed
3. Update dependencies in Project.toml if required

## Safe to Delete?

These tests can be safely deleted if:
- No issues arise from main test suite for 2+ months
- No features from archived tests are re-implemented
- All relevant functionality covered by current test suite
EOF

# 4. Verify main test suite still passes
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Phase 2: Hook Management (Medium Priority)

```bash
# 1. Create hooks archive
mkdir -p .claude/archived_hooks_2025_10/

# 2. Archive dangerous/problematic hooks
mv .claude/hooks/git-auto-commit-push.md .claude/archived_hooks_2025_10/

# 3. Document why hooks were archived
cat > .claude/archived_hooks_2025_10/README.md << 'EOF'
# Archived Hooks - October 2025

## git-auto-commit-push.md

**Reason for archiving**: Anti-pattern for version control

**Issues**:
- Auto-commits create messy history without meaningful messages
- Auto-pushes bypass code review and testing
- Risk of pushing broken code or sensitive data
- Goes against Git best practices

**Better approach**: Manual commits with thoughtful messages

## Restoration

These hooks should NOT be restored. If auto-commit functionality is desired,
implement a safer version that:
- Prompts user before committing
- Requires explicit confirmation before pushing
- Runs tests before pushing
- Creates meaningful commit messages
EOF

# 4. Test remaining hooks don't interfere with normal workflow
```

### Phase 3: Agent Updates (Low Priority)

```bash
# Update project-task-updater.md paths
sed -i '' 's|/Users/ghscholt/globtimcore|/Users/ghscholt/GlobalOptim/globtimcore|g' \
    .claude/agents/project-task-updater.md

# Review and test agent functionality
# - Test project-task-updater with glab CLI
# - Verify hpc-cluster-operator connects to r04n02
# - Check julia-test-architect examples are current
```

### Phase 4: Experiment Cleanup (Low Priority)

```bash
# Review experiment campaign status
# - Check if daisy_ex3_4d_study is complete
# - Determine lv4d_loss_comparison_2025 status
# - Clean up experiments/generated/ directory

# Create .gitignore for generated experiments if needed
echo "experiments/generated/*.jl" >> .gitignore
```

---

## 7. Success Metrics

### Post-Cleanup Goals

1. **Test Suite**:
   - ✓ Main test suite passes (26 core tests)
   - ✓ Archived tests documented and organized
   - ✓ No duplicate or variant test files in main suite
   - ✓ Clear distinction between production and development tests

2. **Scripts**:
   - ✓ All active scripts verified functional
   - ✓ Legacy/unused scripts identified and documented
   - ✓ GitLab scripts tested with current glab CLI

3. **Claude Agents**:
   - ✓ All agent paths corrected
   - ✓ Agent functionality verified
   - ✓ Legacy agents archived with documentation

4. **Claude Hooks**:
   - ✓ Dangerous hooks archived
   - ✓ Remaining hooks tested and functional
   - ✓ Hook behavior documented

5. **Experiment Templates**:
   - ✓ Canonical template identified (lv4d_campaign_2025)
   - ✓ Experiment skill created
   - ✓ Completed campaigns archived

### Verification Tests

After cleanup:
```bash
# 1. Run main test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# 2. Verify key scripts work
./scripts/analysis/collect_cluster_experiments.jl --help
./scripts/gitlab/quick_summary.sh

# 3. Test experiment template structure
ls -R experiments/lv4d_campaign_2025/

# 4. Check Claude agents load
grep -r "name:" .claude/agents/

# 5. Verify hooks are functional
cat .claude/hooks/*.md
```

---

## 8. Rollback Plan

If cleanup causes issues:

```bash
# Restore archived tests
mv test/archived_2025_10/* test/

# Restore archived hooks
mv .claude/archived_hooks_2025_10/* .claude/hooks/

# Revert agent changes
git checkout .claude/agents/project-task-updater.md

# Run full test suite to verify restoration
julia --project=. -e 'using Pkg; Pkg.test()'
```

---

## 9. Future Maintenance

### Quarterly Review Process

Every 3 months, review:
1. Test files not in runtests.jl
2. Scripts not used in last 90 days
3. Claude agents/hooks effectiveness
4. Experiment templates and completed campaigns

### Prevention Guidelines

1. **Test Files**:
   - Development tests go in `test/dev/` (not mixed with production)
   - Every new test should be added to `runtests.jl` or documented why not
   - Delete or archive test files when features are deprecated

2. **Scripts**:
   - Document script purpose in header comments
   - Add last-used date in script header
   - Archive scripts unused for 6+ months

3. **Claude Agents/Hooks**:
   - Review agent effectiveness quarterly
   - Archive hooks that cause friction
   - Update agent documentation with latest practices

4. **Experiments**:
   - Archive completed campaign directories
   - Maintain clear active/archived separation
   - Document campaign outcomes in README

---

## 10. Conclusion

This audit identified significant opportunity for cleanup:
- **149 orphaned test files** (85% of total) can be archived
- **1 dangerous hook** (git-auto-commit-push) must be removed
- **1 powerful skill** (experiment-campaign) created from best practices
- **All scripts** appear functional and should be kept
- **Most agents** are valuable, need minor updates

**Next Steps**: Execute Phase 1 (test cleanup) immediately, followed by Phase 2 (hook management) within the week.

---

**Report Author**: Claude Code
**Date**: 2025-10-20
**Repository**: globaloptim/globtimcore
**Status**: Ready for Implementation
