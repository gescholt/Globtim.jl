#!/bin/bash
# Test launcher for session tracking - launches ONE small experiment
# Tests DrWatson-based naming and .session_info.json creation

set -e

CLUSTER_HOST="scholten@r04n02"
CLUSTER_DIR="/home/scholten/globtimcore"
PROJECT_ROOT="/Users/ghscholt/GlobalOptim/globtimcore"

echo "=========================================="
echo "Session Tracking Test Launcher"
echo "=========================================="
echo "Testing DrWatson-based session tracking with minimal experiment"
echo ""

# Test parameters (very small for quick validation)
GN=5
DEGREE_MIN=4
DEGREE_MAX=4  # Only one degree for quick test
DOMAIN=0.1

echo "🔧 Generating DrWatson directory name for GN=$GN, degrees=$DEGREE_MIN:$DEGREE_MAX, domain=$DOMAIN..."

# Generate directory name using DrWatson (same pattern as minimal_4d_lv_test.jl)
OUTPUT_DIR=$(julia --project="$PROJECT_ROOT" -e "
using DrWatson
using Dates

# Match parameters from minimal_4d_lv_test.jl
params = Dict(
    \"GN\" => $GN,
    \"degree_range\" => [$DEGREE_MIN:$DEGREE_MAX...],
    \"domain_size_param\" => $DOMAIN,
    \"max_time\" => 45.0
)

timestamp = Dates.format(now(), \"yyyymmdd_HHMMSS\")
param_name = savename(params; connector=\"_\")
dirname = \"minimal_4d_lv_test_\$(param_name)_\$(timestamp)\"
println(dirname)
")

# Use the SAME name for tmux session (solves Priority 1: session-directory linkage)
SESSION_NAME="$OUTPUT_DIR"
FULL_OUTPUT_DIR="$CLUSTER_DIR/hpc_results/$OUTPUT_DIR"

echo "📁 Session: $SESSION_NAME"
echo "📁 Output:  $FULL_OUTPUT_DIR"
echo ""

# Create .session_info.json immediately (solves Priority 2: progress tracking)
SESSION_INFO=$(cat <<EOF
{
  "session_name": "$SESSION_NAME",
  "output_dir": "$FULL_OUTPUT_DIR",
  "started_at": "$(date -Iseconds)",
  "status": "launching",
  "cluster_node": "r04n02",
  "launched_from": "local",
  "parameters": {
    "GN": $GN,
    "degree_range": [$DEGREE_MIN, $DEGREE_MAX],
    "domain_size_param": $DOMAIN,
    "max_time": 45.0
  },
  "experiment_type": "minimal_4d_lotka_volterra_test",
  "progress": {
    "percent_complete": 0.0,
    "current_step": 0,
    "total_steps": $(($DEGREE_MAX - $DEGREE_MIN + 1))
  }
}
EOF
)

echo "📝 Creating .session_info.json on cluster..."
echo "$SESSION_INFO" | ssh $CLUSTER_HOST "mkdir -p '$FULL_OUTPUT_DIR' && cat > '$FULL_OUTPUT_DIR/.session_info.json'"

echo "🚀 Launching experiment in tmux session..."
# Pass --output-dir to ensure Julia uses the pre-generated directory name
ssh $CLUSTER_HOST "cd $CLUSTER_DIR && tmux new-session -d -s '$SESSION_NAME' \"
    julia --project=. Examples/minimal_4d_lv_test.jl --GN=$GN --degrees=$DEGREE_MIN:$DEGREE_MAX --domain=$DOMAIN --output-dir='$FULL_OUTPUT_DIR' 2>&1 | tee '${FULL_OUTPUT_DIR}/experiment.log'
    echo 'Experiment completed at \$(date)'
    bash
\""

echo ""
echo "=========================================="
echo "✅ Test experiment launched!"
echo "=========================================="
echo ""
echo "Session name: $SESSION_NAME"
echo "Output dir:   $FULL_OUTPUT_DIR"
echo ""
echo "Monitor progress:"
echo "  ssh $CLUSTER_HOST 'cat $FULL_OUTPUT_DIR/.session_info.json'"
echo ""
echo "Check tmux session:"
echo "  ssh $CLUSTER_HOST 'tmux list-sessions | grep \"$SESSION_NAME\"'"
echo ""
echo "Attach to session:"
echo "  ssh $CLUSTER_HOST 'tmux attach -t \"$SESSION_NAME\"'"
echo ""
