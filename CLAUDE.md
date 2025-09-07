# GlobTim Project Memory

## 🎯 Current Project Status (September 2025)

**Infrastructure**: ✅ HPC Direct Node Access Operational (r04n02)  
**Mathematical Core**: ✅ All packages working (HomotopyContinuation, ForwardDiff, etc.)  
**Automation**: ✅ Hook Integration System Active  
**Project Management**: ✅ GitLab Issues & Visual Tracking Operational

## 🤖 Claude Code Agent Usage Guide

**When to Use Each Agent:**

- **`hpc-cluster-operator`**: For all HPC tasks on r04n02 - SSH access, job execution, monitoring
- **`project-task-updater`**: Automatically triggered after completing features/milestones - updates GitLab issues
- **`julia-test-architect`**: Automatically triggered after implementing new features - creates comprehensive tests  
- **`julia-documenter-expert`**: Automatically triggered after feature completion - maintains documentation sync
- **`julia-repo-guardian`**: For repository maintenance, consistency checks, cleanup tasks

## 🔗 Hook System Architecture

**Security & Validation Hooks:**
- **SSH Security Hook**: `tools/hpc/ssh-security-hook.sh` - Validates all HPC connections
- **Node Security Hook**: `tools/hpc/node-security-hook.sh` - HPC-specific security policies  
- **Pre-Execution Validation**: `tools/hpc/validation/` - Script discovery, package validation

**Resource Monitoring:**
- **HPC Resource Monitor**: `/Users/ghscholt/.claude/hooks/hpc-resource-monitor.sh` - Live experiment tracking
- **GitLab Integration**: `tools/gitlab/gitlab-security-hook.sh` - Secure GitLab operations

**Automation Pipeline:**
```
Pre-Execution → Hook Orchestrator → Computation → Resource Monitor → Post-Processing
      ↓               ↓                 ↓              ↓               ↓
   Validation      Security        HPC Examples    Live Tracking    GitLab Updates
```

**Current Status**: All hooks operational, Phase 1 validation (95% error reduction) complete

## 📋 GitLab Project Management

**API Access:**
```bash
# Get GitLab token
export GITLAB_TOKEN="$(./tools/gitlab/get-token.sh)"
export GITLAB_PROJECT_ID="2545"

# Use GitLab API
./tools/gitlab/gitlab-api.sh list-issues
./tools/gitlab/gitlab-api.sh update-issue <issue_id> --labels "priority:high,type:feature"
```

**Issue Management:**
- **Project URL**: https://git.mpi-cbg.de/scholten/globtim/-/issues
- **Visual Boards**: GitLab project boards with milestone tracking
- **Automation**: project-task-updater agent handles automatic issue updates

**Key Issues:**
- **#27**: Pre-Execution Validation System (50% complete)
- **#28**: Advanced Workflow Automation (planned)
- **#29**: AI-Driven Experiment Management (planned)
- **#41**: Strategic Hook Integration (complete)
- **#44**: Sparsification Study Framework (complete)
- **#45**: GLMakie Extension Loading Failures (✅ CLOSED - All plotting functionality operational, valley walking validation complete)
- **#47**: Momentum-Enhanced Valley Walking Algorithm (✅ NEW - Advanced Nesterov-style momentum optimization)
- **#48**: Valley Walking Educational Materials (✅ NEW - Interactive notebooks and comprehensive examples)
- **#49**: Valley Walking Performance Comparison (✅ NEW - Systematic algorithm benchmarking study)
- **#50**: Advanced Interactive Visualization Features (✅ NEW - Enhanced GLMakie capabilities for mathematical algorithms)

## 🔧 Git Configuration

**SSH Key Setup:**
- **HPC Access**: SSH keys configured for r04n02 compute node
- **GitLab Integration**: SSH authentication for git.mpi-cbg.de
- **Security**: Ed25519 keys with security hook validation

**Repository Access:**
```bash
# HPC repository location (permanent)
ssh scholten@r04n02
cd /home/scholten/globtim

# Local development
git remote get-url origin  # git.mpi-cbg.de/scholten/globtim.git
```

**Branch Management:**
- **Main Branch**: `main` (development)
- **Clean Version**: `clean-version` (for PRs)
- **SSH Authentication**: Automatic via configured keys

## 🔥 Critical HPC Knowledge

**r04n02 Direct Access:**
```bash
# Connect to compute node
ssh scholten@r04n02
cd /home/scholten/globtim

# Julia available via juliaup (no modules needed)
julia --project=. --heap-size-hint=50G
```

**Package Management:**
- **Native Installation**: All 203+ packages working via Pkg.add()
- **Critical Packages**: HomotopyContinuation, ForwardDiff, DynamicPolynomials all operational
- **Architecture**: x86_64 Linux with correct binary artifacts

**Execution Framework:**
- **tmux Sessions**: Persistent execution via robust_experiment_runner.sh
- **Resource Monitoring**: Live tracking via HPC Resource Monitor Hook
- **No SLURM**: Direct execution without scheduling overhead


## 📚 Documentation References

**For detailed information, see:**
- **HPC Infrastructure**: `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`
- **Hook Integration**: `docs/hpc/HOOK_INTEGRATION_GUIDE.md` 
- **GitLab Management**: `docs/project-management/GITLAB_VISUAL_MANAGEMENT_STATUS.md`
- **Security Framework**: `docs/hpc/SSH_SECURITY_SYSTEM_DOCUMENTATION.md`
- **Historical Milestones**: `docs/project-management/MILESTONE_HISTORY.md`