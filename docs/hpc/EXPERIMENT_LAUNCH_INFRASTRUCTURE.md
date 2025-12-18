# HPC Experiment Launch Infrastructure

**Document Date**: 2025-10-06
**Status**: Active Standard Operating Procedure

## Overview

This document describes the standard infrastructure for launching experiments on the HPC cluster (r04n02). All experiment launches MUST follow this infrastructure pattern.

## Core Principles

1. **Deployment Script Required**: Every experiment or campaign must have a deployment script
2. **Tmux Sessions**: All experiments run in persistent tmux sessions for reliability
3. **Rsync for Sync**: Use rsync to sync project files to the cluster
4. **No Direct SSH Julia**: Never run experiments via direct SSH commands - always use deployment scripts
5. **Standard Directory Structure**: Follow the established paths and naming conventions

## Infrastructure Components

### 1. Deployment Script Structure

Every deployment script must include these components:

#### A. Configuration Section
```bash
HPC_NODE="scholten@r04n02"
PROJECT_DIR="/home/scholten/globtimcore"
EXPERIMENT_DIR="relative/path/to/experiment"
TMUX_SESSION="unique_session_name"
EXPERIMENT_SCRIPT="script_name.jl"
```

#### B. File Sync Step
```bash
rsync -avz --progress \
    --exclude '.git/' \
    --exclude 'hpc_results/' \
    --exclude 'hpc_results_archive_legacy_*/' \
    --exclude '.julia/' \
    ./ ${HPC_NODE}:${PROJECT_DIR}/
```

#### C. Environment Verification Step
```bash
ssh ${HPC_NODE} << 'EOF'
# Check Julia
if ! command -v julia &> /dev/null; then
    echo "ERROR: Julia not found"
    exit 1
fi

# Check project files
if [ ! -f "Project.toml" ]; then
    echo "ERROR: Project.toml not found"
    exit 1
fi

# Instantiate packages
julia --project=. -e 'using Pkg; Pkg.instantiate()' > /dev/null 2>&1

# Check experiment script exists
# [script-specific verification]
EOF
```

#### D. Tmux Launch Step
```bash
ssh ${HPC_NODE} << EOF
# Kill existing session if it exists
tmux kill-session -t ${TMUX_SESSION} 2>/dev/null || true

# Create new tmux session and run experiment
tmux new-session -d -s ${TMUX_SESSION} \
    "cd /home/scholten/globtimcore/${EXPERIMENT_DIR} && julia --project=../../.. ${EXPERIMENT_SCRIPT}"

# Display session info
tmux list-sessions | grep ${TMUX_SESSION} || true
EOF
```

### 2. Tmux Session Management

#### Naming Convention
- **Single experiments**: `lv4d_exp{N}_range{R}` (e.g., `lv4d_exp1_range0.4`)
- **Campaign batches**: `lv4d_batch_{YYYYMMDD}` (e.g., `lv4d_batch_2025_10_01`)
- **Test runs**: `{model}_test_{timestamp}` (e.g., `minimal_4d_lv_test_20251005_105246`)

#### Session Commands
```bash
# List all sessions
ssh scholten@r04n02 'tmux list-sessions'

# Attach to a running session
ssh scholten@r04n02
tmux attach -t session_name

# Detach from session: Ctrl+B, then D

# Kill a session
ssh scholten@r04n02 'tmux kill-session -t session_name'
```

### 3. Standard File Locations

#### Local Machine
- Experiment configs: `/Users/ghscholt/GlobalOptim/globtimcore/experiments/*/configs_*/`
- Deployment scripts: Same directory as experiment configs
- Campaign launchers: `/Users/ghscholt/GlobalOptim/globtimcore/scripts/launch_*.sh`

#### HPC Cluster (r04n02)
- Project root: `/home/scholten/globtimcore`
- Experiment configs: `/home/scholten/globtimcore/experiments/*/configs_*/`
- Results: `/home/scholten/globtimcore/*/hpc_results/`

## Launch Procedures

### Procedure 1: Single Experiment Launch

**Example**: Launching Issue #131 (LV4D Exp 1)

1. **Navigate to project root**:
   ```bash
   cd /Users/ghscholt/GlobalOptim/globtimcore
   ```

2. **Create deployment script** (if not exists):
   ```bash
   # Create deploy_expN.sh in the experiment config directory
   experiments/lotka_volterra_4d_study/configs_YYYYMMDD_HHMMSS/deploy_exp1.sh
   ```

3. **Make executable**:
   ```bash
   chmod +x experiments/lotka_volterra_4d_study/configs_YYYYMMDD_HHMMSS/deploy_exp1.sh
   ```

4. **Launch**:
   ```bash
   ./experiments/lotka_volterra_4d_study/configs_YYYYMMDD_HHMMSS/deploy_exp1.sh
   ```

5. **Monitor**:
   ```bash
   ssh scholten@r04n02
   tmux attach -t lv4d_exp1_range0.4
   ```

### Procedure 2: Campaign Launch

**Example**: Launching a multi-experiment campaign

1. **Navigate to project root**:
   ```bash
   cd /Users/ghscholt/GlobalOptim/globtimcore
   ```

2. **Use campaign launcher**:
   ```bash
   ./scripts/launch_4d_lv_campaign.sh
   ```

3. **Monitor batch**:
   ```bash
   # Check tracking file
   cat experiments/lv4d_campaign_2025/tracking/batch_*.json

   # List all sessions
   ssh scholten@r04n02 'tmux list-sessions | grep lv4d'
   ```

### Procedure 3: Results Collection

After experiments complete:

```bash
cd /Users/ghscholt/GlobalOptim/globtimcore

# Collect results from cluster
julia --project=. scripts/analysis/collect_cluster_experiments.jl

# Results will be downloaded to local machine
```

## Best Practices

### DO:
✅ Always use deployment scripts
✅ Verify files synced before launching
✅ Use unique tmux session names
✅ Monitor experiments via tmux attach
✅ Keep deployment scripts with experiment configs
✅ Include environment verification steps
✅ Document session names in GitLab issues

### DON'T:
❌ Never run `ssh scholten@r04n02 "julia script.jl"` directly
❌ Don't skip rsync step
❌ Don't reuse tmux session names
❌ Don't forget to make scripts executable
❌ Don't run experiments without deployment script
❌ Don't use nohup with ssh directly (causes timeouts)

## Troubleshooting

### Issue: SSH command timeout
**Cause**: Direct ssh commands with `nohup` can timeout
**Solution**: Use tmux sessions via deployment script

### Issue: Files not found on cluster
**Cause**: Forgot to sync files
**Solution**: Deployment script includes rsync step

### Issue: Experiment not running
**Cause**: Tmux session died
**Solution**: Check `tmux list-sessions`, attach to session to see errors

### Issue: Session name conflict
**Cause**: Reused session name
**Solution**: Kill old session first, or use unique timestamp-based names

## Templates

### Single Experiment Deployment Template

See: `experiments/lotka_volterra_4d_study/configs_20251005_105246/deploy_exp1.sh`

### Campaign Deployment Template

See: `Examples/4DLV/experiments_2025_10_01/deploy_hpc.sh`

### Minimal Test Launcher Template

See: `scripts/launch_4d_lv_campaign.sh`

## Related Documentation

- [HPC Execution Guide](HPC_EXECUTION_GUIDE.md)
- [Session Tracking Implementation](../SESSION_TRACKING_IMPLEMENTATION.md)
- [Cluster Experiment Quick Start](CLUSTER_EXPERIMENT_QUICK_START.md)
- [Robust Workflow Guide](ROBUST_WORKFLOW_GUIDE.md)

## Maintenance

This infrastructure pattern is the **standard operating procedure** for all HPC experiment launches. Any new experiment types should follow this pattern. Updates to this document should be made when new patterns emerge or improvements are validated.
