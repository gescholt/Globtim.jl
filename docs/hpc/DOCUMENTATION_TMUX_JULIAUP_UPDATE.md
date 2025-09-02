# Documentation Update: tmux and juliaup Migration
**Date:** December 2024  
**Purpose:** Update all HPC documentation to reflect the correct current state with tmux and juliaup

## Summary of Changes

All HPC-related documentation has been updated to reflect:
1. **tmux** is used instead of GNU Screen for persistent sessions
2. **Julia 1.11.6** is available via juliaup (no module system exists)
3. Commands use tmux syntax instead of screen syntax

## Files Updated

### Core Documentation Files

1. **docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md**
   - Changed all "Screen-based" references to "tmux-based"
   - Updated Julia references from "module load julia/1.11.2" to juliaup availability
   - Updated command examples from screen to tmux syntax

2. **docs/hpc/ROBUST_WORKFLOW_GUIDE.md**
   - Swapped priority: tmux is now primary, Screen is alternative
   - Updated all command examples to tmux syntax
   - Removed module loading references

3. **docs/hpc/DOCUMENTATION_UPDATE_SUMMARY_20250902.md**
   - Updated all references from Screen to tmux framework
   - Corrected Julia version information

4. **docs/hpc/TMUX_FRAMEWORK_MIGRATION.md** (renamed from SCREEN_FRAMEWORK_MIGRATION.md)
   - File renamed to reflect tmux usage
   - Content already correctly referenced tmux

### Project Management Files

5. **docs/project-management/issues/HPC_4D_MODEL_WORKFLOW_ISSUE.md**
   - Updated all Screen references to tmux
   - Corrected Julia version and juliaup references

6. **docs/project-management/PHASE1_IMPLEMENTATION_SUMMARY.md**
   - Updated execution framework references to tmux

### Agent Configuration

7. **.claude/agents/hpc-cluster-operator.md**
   - Updated primary workflow to tmux-based execution
   - Corrected Julia availability via juliaup
   - Updated all command examples

### Main Project Memory

8. **CLAUDE.md**
   - Updated one remaining "Screen-Based Framework" reference to "tmux-Based Framework"

### Shell Scripts

9. **hpc/monitoring/live_monitor.sh**
   - Changed function names from monitor_screen to monitor_tmux
   - Updated all screen commands to tmux equivalents
   - Updated display text to show tmux sessions

10. **hpc/infrastructure/deploy_to_hpc.sh**
    - Removed all "module load julia" references
    - Updated to note Julia 1.11.6 via juliaup

11. **hpc/experiments/robust_experiment_runner.sh**
    - Changed from screen to tmux session management
    - Updated all screen commands to tmux equivalents
    - Removed module loading, noted juliaup availability

## Key Changes Summary

### Command Equivalents
| Old (Screen) | New (tmux) |
|--------------|------------|
| `screen -S name` | `tmux new -s name` |
| `screen -r name` | `tmux attach -t name` |
| `screen -ls` | `tmux ls` |
| Detach: Ctrl+A, D | Detach: Ctrl+B, D |

### Julia Access
| Old | New |
|-----|-----|
| `module load julia/1.11.2` | Julia 1.11.6 available via juliaup |
| Module system required | No module system, juliaup in PATH |

## Verification

All documentation now correctly reflects:
- ✅ tmux as the primary persistent session manager
- ✅ Julia 1.11.6 available via juliaup without module system
- ✅ Correct tmux command syntax throughout
- ✅ Consistent terminology across all files

## Impact

These changes ensure that:
1. Documentation matches the actual HPC environment
2. Users receive correct instructions for session management
3. Julia access instructions are accurate
4. No confusion between Screen and tmux commands