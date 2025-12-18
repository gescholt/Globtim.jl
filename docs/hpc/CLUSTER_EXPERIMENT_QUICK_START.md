# HPC Cluster Experiment Quick Start Guide
**For: GlobTim Project - Session Tracking + Hook Integration**
**Updated**: 2025-10-01

## 🚀 Launching Experiments with Session Tracking

### Standard Launch Pattern

```bash
#!/bin/bash
# Example: Launch 4D Lotka-Volterra experiment with proper tracking

# Parameters
GN=10
DEGREE_MIN=8
DEGREE_MAX=12
DOMAIN=0.1

# 1. Generate directory name BEFORE launching Julia
OUTPUT_DIR=$(julia --project=. -e "
using DrWatson, Dates
params = Dict(
    \"GN\" => $GN,
    \"degree_range\" => [$DEGREE_MIN:$DEGREE_MAX...],
    \"domain_size_param\" => $DOMAIN
)
timestamp = Dates.format(now(), \"yyyymmdd_HHMMSS\")
dirname = savename(params) * \"_\" * timestamp
println(dirname)
")

# 2. Session name = directory name (enables trivial linkage)
SESSION_NAME="$OUTPUT_DIR"
FULL_OUTPUT_DIR="/home/scholten/globtimcore/hpc_results/$OUTPUT_DIR"

# 3. Create output directory and .session_info.json BEFORE Julia
ssh scholten@r04n02 "mkdir -p '$FULL_OUTPUT_DIR'"

ssh scholten@r04n02 "cat > '$FULL_OUTPUT_DIR/.session_info.json' << 'EOF'
{
  \"session_name\": \"$SESSION_NAME\",
  \"output_dir\": \"$FULL_OUTPUT_DIR\",
  \"started_at\": \"$(date -Iseconds)\",
  \"hostname\": \"r04n02\",
  \"status\": \"launching\",
  \"parameters\": {
    \"GN\": $GN,
    \"degree_range\": [$DEGREE_MIN, $DEGREE_MAX],
    \"domain_size_param\": $DOMAIN
  }
}
EOF
"

# 4. Launch Julia with --output-dir argument
ssh scholten@r04n02 "cd globtimcore && \
  tmux new-session -d -s '$SESSION_NAME' \
  'julia --project=. Examples/minimal_4d_lv_test.jl \
    --GN=$GN \
    --degrees=$DEGREE_MIN:$DEGREE_MAX \
    --domain=$DOMAIN \
    --output-dir=\"$FULL_OUTPUT_DIR\" \
    2>&1 | tee \"$FULL_OUTPUT_DIR/experiment.log\"; \
  bash'"

echo "✅ Experiment launched!"
echo "   Session: $SESSION_NAME"
echo "   Output:  $FULL_OUTPUT_DIR"
```

## 📊 Monitoring Running Experiments

### List All Sessions
```bash
ssh scholten@r04n02 'tmux list-sessions'
```

### Check Experiment Status
```bash
# Check specific experiment
ssh scholten@r04n02 'cat /home/scholten/globtimcore/hpc_results/GN=10_*/. session_info.json'

# Check all running experiments
ssh scholten@r04n02 'find /home/scholten/globtimcore/hpc_results -name ".session_info.json" -exec jq -r ".session_name + \" (\" + .status + \")\"" {} \;'
```

### Attach to Running Session
```bash
# Get session name from .session_info.json
SESSION_NAME=$(ssh scholten@r04n02 'jq -r .session_name /path/to/.session_info.json')

# Attach
ssh scholten@r04n02 "tmux attach -t '$SESSION_NAME'"

# Detach: Press Ctrl+B, then D
```

### Monitor Progress
```bash
# Watch progress updates (refreshes every 10 seconds)
watch -n 10 'ssh scholten@r04n02 "jq .progress /home/scholten/globtimcore/hpc_results/GN=10_*/.session_info.json"'
```

## 🔍 Checking Results

### Quick Status Check
```bash
# Check if experiment completed
ssh scholten@r04n02 'jq .status /path/to/.session_info.json'
# Expected: "completed" (success) or "failed"
```

### List Output Files
```bash
ssh scholten@r04n02 'ls -lh /path/to/experiment/directory/'
```

### Download Results
```bash
# Download entire experiment directory
rsync -avz --progress \
  scholten@r04n02:/home/scholten/globtimcore/hpc_results/GN=10_*/ \
  ./local_results/

# Download specific files only
scp scholten@r04n02:/path/to/experiment/*.csv ./
```

## 🛠️ Troubleshooting

### Experiment Won't Start
```bash
# Check if tmux session exists
ssh scholten@r04n02 'tmux list-sessions | grep "SESSION_NAME"'

# Check experiment log for errors
ssh scholten@r04n02 'tail -50 /path/to/experiment/experiment.log'

# Check if .session_info.json was created
ssh scholten@r04n02 'ls -l /path/to/experiment/.session_info.json'
```

### Stuck Experiment
```bash
# Check last heartbeat
ssh scholten@r04n02 'jq .progress.last_heartbeat /path/to/.session_info.json'

# If stuck, kill session and restart
ssh scholten@r04n02 'tmux kill-session -t "SESSION_NAME"'
```

### Session Name Mismatch
**Problem**: Session name doesn't match directory name

**Cause**: Directory was generated in Julia instead of bash

**Solution**: Always generate directory name in bash BEFORE launching Julia, then pass via `--output-dir`

## 📚 Key Files and Locations

### On Cluster (r04n02)
- **Project directory**: `/home/scholten/globtimcore`
- **Results directory**: `/home/scholten/globtimcore/hpc_results/`
- **Session info**: `/home/scholten/globtimcore/hpc_results/<experiment>/.session_info.json`

### Local Development
- **Project root**: `/Users/ghscholt/GlobalOptim/globtimcore`
- **Test launchers**: `globtimcore/scripts/test_session_tracking_launcher.sh`
- **Examples**: `globtimcore/Examples/session_tracking_test/`
- **Documentation**: `globtimcore/docs/SESSION_TRACKING_IMPLEMENTATION.md`

## 🎯 Core Principles

### 1. Pre-Generate Directory Names
**Why**: Prevents timestamp mismatch between bash and Julia
**How**: Use Julia from bash to call `DrWatson.savename()` before launching

### 2. Session Name = Directory Name
**Why**: Enables trivial correlation without lookup tables
**How**: Use `$OUTPUT_DIR` for both session name and directory path

### 3. Create Metadata Immediately
**Why**: Enables tracking even if Julia fails to start
**How**: Create `.session_info.json` in bash before launching Julia

### 4. Pass Directory to Julia
**Why**: Julia uses bash-generated path instead of creating its own
**How**: Add `--output-dir="$FULL_OUTPUT_DIR"` to Julia command

## 📖 Examples

### Example 1: Test Launcher
Location: `globtimcore/scripts/test_session_tracking_launcher.sh`

Small experiment (GN=5, 1 degree) for quick validation.

```bash
./scripts/test_session_tracking_launcher.sh
```

### Example 2: Toy Launcher
Location: `globtimcore/Examples/session_tracking_test/toy_launcher.sh`

Minimal example with local/cluster/tmux options.

```bash
# Run locally
./Examples/session_tracking_test/toy_launcher.sh

# Run on cluster
./Examples/session_tracking_test/toy_launcher.sh --cluster
```

## 🔗 Related Documentation

- **Session Tracking**: [SESSION_TRACKING_IMPLEMENTATION.md](../SESSION_TRACKING_IMPLEMENTATION.md)
- **Hook Integration**: [STRATEGIC_HOOK_INTEGRATION_DOCUMENTATION.md](STRATEGIC_HOOK_INTEGRATION_DOCUMENTATION.md)
- **Claude Hooks**: [CLAUDE_HOOKS_SETUP.md](../../CLAUDE_HOOKS_SETUP.md)

## ⚡ Quick Commands Cheat Sheet

```bash
# Launch experiment
./scripts/launch_experiment.sh

# List sessions
ssh scholten@r04n02 'tmux ls'

# Check status
ssh scholten@r04n02 'jq .status hpc_results/*/.session_info.json'

# Attach to session
ssh scholten@r04n02 'tmux attach -t "SESSION_NAME"'

# Kill session
ssh scholten@r04n02 'tmux kill-session -t "SESSION_NAME"'

# Download results
rsync -avz scholten@r04n02:globtimcore/hpc_results/EXPERIMENT/ ./
```

---

**Status**: Production Ready ✅
**Last Tested**: 2025-10-01 on r04n02
**Validated By**: Cluster testing with minimal 4D L-V experiments
