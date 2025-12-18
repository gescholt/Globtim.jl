# Unified HPC Deployment Workflow

**Status:** ✅ Active Standard (Issue #140 Phases 1 & 2 Complete)
**Purpose:** Prevent custom deployment script proliferation and enforce standardized workflow

---

## 🎯 Core Principle

**THERE IS ONLY ONE WAY TO DEPLOY EXPERIMENTS TO THE CLUSTER**

Use the unified deployment infrastructure:
- **Single experiment:** `make deploy-git EXP=path/to/experiment.jl`
- **Multiple experiments:** Use the unified tools, NOT custom scripts

---

## ⚠️ What NOT to Do

### ❌ FORBIDDEN: Writing Custom Deployment Scripts

**DO NOT CREATE:**
- `deploy_exp1.sh`, `deploy_exp2.sh`, `deploy_exp3.sh`, etc.
- `launch_campaign.sh` with hardcoded experiment paths
- `run_batch.sh` with custom rsync commands
- Any script that duplicates deployment logic

**WHY?**
- 95% code duplication
- Maintenance nightmare (fix bug in 10 places)
- Inconsistent behavior across experiments
- No validation, no git tracking, no reproducibility

### 📊 Evidence of the Problem

**Current State (as of 2025-10-07):**
```bash
$ find experiments -name "deploy*.sh" | wc -l
9  # 9 custom deploy scripts scattered across experiment dirs!

$ find experiments -name "launch*.sh" | wc -l
1  # 1 campaign launcher with hardcoded paths
```

**Each custom script:** ~178 lines of mostly duplicated code
**Total wasted code:** ~1,600 lines that could be 0 lines

---

## ✅ The Correct Workflow

### Single Experiment Deployment

```bash
# ALWAYS use this command (Phase 2 - git-aware, reproducible)
make deploy-git EXP=experiments/path/to/experiment.jl

# What it does automatically:
# 1. ✅ Checks git status
# 2. ✅ Prompts to commit if uncommitted changes exist
# 3. ✅ Records git commit hash for traceability
# 4. ✅ Validates experiment file
# 5. ✅ Syncs files to cluster
# 6. ✅ Verifies HPC environment
# 7. ✅ Launches tmux session
# 8. ✅ Shows monitoring commands
```

### Batch/Campaign Deployment (Current Best Practice)

For deploying multiple experiments in a campaign:

```bash
# Option 1: Sequential deployment with loop (RECOMMENDED)
for exp in experiments/study/configs_20251007/exp{1..4}.jl; do
    make deploy-git EXP="$exp"
done

# Option 2: Use the deployment script directly with more control
for exp in experiments/study/configs_20251007/exp{1..4}.jl; do
    ./tools/hpc/git_commit_and_deploy.sh "$exp" --auto-commit
done

# Option 3: Dry run first to preview all experiments
for exp in experiments/study/configs_20251007/exp{1..4}.jl; do
    ./tools/hpc/git_commit_and_deploy.sh "$exp" --dry-run
done
```

**Key Points:**
- Use simple bash loop with unified tools
- Each experiment gets proper validation, git tracking, error handling
- No need to write custom scripts
- Easy to modify: change loop range, add filters, etc.

---

## 🚀 Future Phase 3: Campaign Deployment (Planned)

**Goal:** Make batch deployment even easier without custom scripts

**Proposed Interface:**
```bash
# Deploy multiple experiments from config
make deploy-campaign CONFIG=experiments/study/campaign_config.json

# What campaign_config.json contains:
# - List of experiment files
# - Deployment options (auto-commit, validation, etc.)
# - Dependencies (run exp2 only if exp1 succeeds)
# - Resource allocation (which node, memory limits)
```

**Benefits:**
- Still no custom scripts
- Declarative configuration (JSON/YAML)
- Dependency management
- Parallel execution where possible
- Progress tracking across all experiments

---

## 📝 Strategy to Prevent Future Custom Scripts

### Rule 1: Always Ask "Can I Use the Unified Tools?"

**Before writing ANY deployment script, ask:**

1. Is this a single experiment?
   → Use `make deploy-git EXP=...`

2. Is this a batch of experiments?
   → Use bash loop with `make deploy-git` or `git_commit_and_deploy.sh`

3. Is this a complex campaign with dependencies?
   → Request Phase 3 implementation (campaign deployment)

4. Is this truly unique and cannot use unified tools?
   → **STOP.** Discuss with team first. 99% of cases don't need custom scripts.

### Rule 2: Unified Tools Should Be Extended, Not Bypassed

**If unified tools don't meet your needs:**

✅ **DO:** Add features to the unified deployment infrastructure
- Add options to `deploy_to_hpc.sh`
- Add new Makefile targets
- Create reusable library functions in `deployment_functions.sh`

❌ **DON'T:** Create parallel deployment system with custom scripts

**Example:**
```bash
# Bad: Create deploy_with_special_option.sh
# Good: Add option to existing script
./tools/hpc/git_commit_and_deploy.sh exp.jl --my-new-option
```

### Rule 3: Archive Old Custom Scripts, Don't Replicate Them

**Current cleanup strategy:**

```bash
# Move legacy custom scripts to archive
mv experiments/study/deploy_exp*.sh experiments/study/archived_legacy_deploy_scripts/

# Add README explaining why archived
cat > experiments/study/archived_legacy_deploy_scripts/README.md <<EOF
# Archived Deployment Scripts (Legacy)

These scripts are archived and should NOT be used.

**Reason:** Replaced by unified deployment infrastructure (Issue #140)

**Use instead:**
- make deploy-git EXP=path/to/experiment.jl

**See:** docs/hpc/DEPLOYMENT_QUICK_START.md
EOF
```

### Rule 4: Code Review Checklist

Before merging ANY code that deploys to cluster:

- [ ] Does it use `deploy_to_hpc.sh` or `git_commit_and_deploy.sh`?
- [ ] Does it avoid creating custom `deploy_*.sh` scripts?
- [ ] Does it avoid duplicating rsync/ssh/tmux logic?
- [ ] If batch deployment, does it use simple loop with unified tools?
- [ ] Is git tracking enabled (`make deploy-git` or `--auto-commit`)?

**Automated Enforcement:**

Use the validation script to detect custom deployment scripts:
```bash
# Check for problematic custom scripts
./tools/hpc/validate_deployment_compliance.sh

# This will flag:
# - Custom deploy_*.sh scripts in experiments/
# - Scripts with rsync/ssh/tmux logic outside tools/hpc/
# - Duplicated deployment patterns
```

### Rule 5: Document Exceptions

**If you MUST create a custom script (rare):**

1. Document WHY in script header
2. Explain why unified tools insufficient
3. Link to issue discussing the limitation
4. Plan to merge functionality into unified tools

Example:
```bash
#!/bin/bash
# custom_deployment_for_special_case.sh
#
# EXCEPTION TO STANDARD WORKFLOW
#
# Why: Requires X feature not yet supported by deploy_to_hpc.sh
# Issue: #XXX - Add X support to unified deployment
# TODO: Replace this script once Issue #XXX is resolved
#
# Standard workflow: make deploy-git EXP=...
# This script: ./custom_deployment_for_special_case.sh (temporary)
```

---

## 🔍 Self-Check: Am I About to Make the Same Mistake?

**Warning signs you're about to create a custom deployment script:**

1. You're writing `#!/bin/bash` in `experiments/` directory
2. Your script contains `rsync`, `ssh`, or `tmux` commands
3. You're copying an old `deploy_exp*.sh` and modifying it
4. You're about to commit a file matching `*deploy*.sh` or `*launch*.sh`

**What to do instead:**

1. STOP ✋
2. Read this document
3. Check if unified tools can handle your case
4. If not, discuss extending unified tools (don't bypass them)

---

## 📚 Reference: Unified Deployment Infrastructure

### Core Scripts

```
tools/hpc/
├── deploy_to_hpc.sh                 # Main orchestrator (275 lines)
│   └── Usage: ./deploy_to_hpc.sh experiment.jl [OPTIONS]
│
├── git_commit_and_deploy.sh         # Git-aware wrapper (Phase 2, 356 lines)
│   └── Usage: ./git_commit_and_deploy.sh experiment.jl [OPTIONS]
│
└── lib/
    └── deployment_functions.sh      # Shared library (302 lines)
        ├── sync_to_cluster()
        ├── verify_cluster_environment()
        ├── launch_remote_tmux()
        ├── extract_session_name()
        └── ... all deployment logic
```

### Makefile Targets

```bash
make deploy-git          # 🌟 RECOMMENDED - Git-aware, reproducible
make deploy-validate     # Deploy with validation (no git tracking)
make deploy              # Quick deploy (skip validation)
make validate            # Validation only
make git-check           # Check git status
make auto-commit         # Auto-commit if threshold met
```

### Documentation

- [DEPLOYMENT_QUICK_START.md](DEPLOYMENT_QUICK_START.md) - User guide
- [DEPLOYMENT_INFRASTRUCTURE_ANALYSIS.md](DEPLOYMENT_INFRASTRUCTURE_ANALYSIS.md) - Technical analysis
- [EXPERIMENT_LAUNCH_INFRASTRUCTURE.md](EXPERIMENT_LAUNCH_INFRASTRUCTURE.md) - Standard procedures

---

## 📊 Success Metrics

**Measure progress toward unified workflow:**

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Custom `deploy_*.sh` scripts | 0 | 9 | ⚠️ Needs cleanup |
| Deployments using unified tools | 100% | ~30% | ⚠️ Adoption needed |
| Code duplication in deployment | <10% | ~15% | 🟡 Improving |
| Git-tracked deployments | 100% | ~10% | ⚠️ Use `deploy-git` |

**Cleanup tasks:**
1. Archive existing custom `deploy_*.sh` scripts
2. Update all experiment READMEs with unified workflow
3. Add pre-commit hook to prevent new custom deploy scripts
4. Migrate all active campaigns to unified tools

---

## 🎓 Learning from Past Mistakes

### Case Study: lotka_volterra_4d_study

**Problem (2025-09-28):**
- Created 4 experiments (exp1, exp2, exp3, exp4)
- Wrote 4 custom scripts: `deploy_exp1.sh`, `deploy_exp2.sh`, etc.
- Each script: 178 lines, 95% identical code
- Bug in rsync path → had to fix in 4 places
- Missing validation → wasted 30 minutes debugging on cluster

**Solution (2025-10-07):**
```bash
# Before (178 lines × 4 scripts = 712 lines)
./experiments/.../configs_20251006/deploy_exp2.sh

# After (one command, 0 custom script lines)
make deploy-git EXP=experiments/.../configs_20251006/lotka_volterra_4d_exp2.jl
```

**Lessons:**
1. Custom scripts multiply like rabbits
2. Each custom script is a maintenance burden
3. Bugs must be fixed in N places instead of 1 place
4. Inconsistency leads to subtle errors
5. **Solution:** ONE unified deployment tool, ZERO custom scripts

---

## 🚨 Emergency: I Already Created Custom Scripts

**Don't panic. Here's the migration path:**

### Step 1: Identify Your Custom Scripts
```bash
find experiments -name "deploy*.sh" -o -name "launch*.sh"
```

### Step 2: Test Unified Deployment
```bash
# For each custom script, find the experiment file it deploys
# Then test with unified tools (dry run first)
make deploy-git EXP=experiments/path/to/experiment.jl --dry-run
```

### Step 3: Verify Equivalence
Compare behavior:
- Same HPC node?
- Same tmux session name?
- Same experiment file?
- Same project activation?

### Step 4: Switch Over
```bash
# Replace your custom script usage
# Old: ./experiments/study/deploy_exp2.sh
# New: make deploy-git EXP=experiments/study/configs/exp2.jl

# Or in a campaign/batch context:
for exp in experiments/study/configs/exp{1..4}.jl; do
    make deploy-git EXP="$exp"
done
```

### Step 5: Archive Custom Scripts
```bash
# Move to archive (don't delete immediately, for safety)
mkdir -p experiments/study/archived_legacy_deploy_scripts
mv experiments/study/deploy_*.sh experiments/study/archived_legacy_deploy_scripts/

# Add README explaining the archive
cat > experiments/study/archived_legacy_deploy_scripts/README.md <<EOF
# Archived Legacy Deployment Scripts

**Status:** Obsolete, do not use

**Replaced by:** Unified deployment infrastructure (Issue #140)

**Use instead:**
\`\`\`bash
make deploy-git EXP=experiments/study/configs/experiment.jl
\`\`\`

**See:** docs/hpc/DEPLOYMENT_QUICK_START.md
EOF
```

### Step 6: Update Documentation
- Update experiment README
- Remove references to custom scripts
- Add unified workflow examples

---

## 🎯 Summary: One Tool to Rule Them All

### The Golden Rule

**When you need to deploy an experiment to the cluster:**

```bash
make deploy-git EXP=path/to/experiment.jl
```

**That's it. Nothing else. No custom scripts.**

### Why This Matters

1. **Consistency:** Same process for every experiment
2. **Maintainability:** Fix once, benefits everywhere
3. **Reproducibility:** Git tracking, validation, error handling
4. **Simplicity:** One command instead of hundreds of lines
5. **Reliability:** Tested infrastructure (46 unit tests + 24 integration tests)

### Next Steps

1. **Immediate:** Use `make deploy-git` for all new deployments
2. **Short-term:** Archive existing custom deployment scripts
3. **Medium-term:** Request Phase 3 (campaign deployment) if needed
4. **Long-term:** 100% adoption, zero custom scripts

---

**Related Issues:**
- Issue #140 Phase 1: Standardized Deployment Infrastructure ✅
- Issue #140 Phase 2: Git Workflow Integration ✅
- Issue #140 Phase 3: Campaign Deployment (Planned)

**Generated:** 2025-10-07
**Status:** Active Standard
