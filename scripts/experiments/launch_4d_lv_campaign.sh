#!/bin/bash
# Launch 4D Lotka-Volterra campaign on cluster
# Runs multiple experiments with different parameters in parallel tmux sessions
# Updated to use DrWatson-based session tracking (Session Tracking Implementation)
# Phase 2: Automatic GitLab integration with batch tracking

set -e

CLUSTER_HOST="scholten@r04n02"
CLUSTER_DIR="/home/scholten/globtimcore"
PROJECT_ROOT="/Users/ghscholt/GlobalOptim/globtimcore"

# Batch tracking configuration
CAMPAIGN_NAME="lv4d_campaign_2025"
TRACKING_DIR="$PROJECT_ROOT/experiments/$CAMPAIGN_NAME/tracking"
BATCH_ID="batch_$(date '+%Y%m%d_%H%M%S')"
BATCH_TRACKING_FILE="$TRACKING_DIR/${BATCH_ID}.json"
SYNC_GITLAB="${SYNC_GITLAB:-false}"  # Set SYNC_GITLAB=true to auto-sync on launch

echo "=========================================="
echo "4D L.V. Campaign Launcher (Session Tracking)"
echo "=========================================="
echo "Cluster: $CLUSTER_HOST"
echo "Directory: $CLUSTER_DIR"
echo "Batch ID: $BATCH_ID"
echo "GitLab Sync: $SYNC_GITLAB"
echo ""

# Create batch tracking JSON file
create_batch_tracking_file() {
    mkdir -p "$TRACKING_DIR"

    cat > "$BATCH_TRACKING_FILE" << EOF
{
  "batch_id": "$BATCH_ID",
  "start_time": "$(date -Iseconds)",
  "campaign": "$CAMPAIGN_NAME",
  "total_experiments": 0,
  "sessions": []
}
EOF

    echo "📋 Created batch tracking: $BATCH_TRACKING_FILE"
}

# Add session to batch tracking JSON
add_session_to_batch() {
    local session_name=$1
    local gn=$2
    local degree_min=$3
    local degree_max=$4
    local domain=$5
    local log_file=$6

    # Use Python to safely append to JSON array
    python3 -c "
import json
import sys

with open('$BATCH_TRACKING_FILE', 'r') as f:
    data = json.load(f)

# Add new session
data['sessions'].append({
    'session_name': '$session_name',
    'parameters': {
        'GN': $gn,
        'degree_range': [$degree_min, $degree_max],
        'domain_size_param': $domain,
        'max_time': 45.0
    },
    'status': 'launching',
    'log_file': '$log_file',
    'cluster_node': 'r04n02'
})

# Update total count
data['total_experiments'] = len(data['sessions'])

with open('$BATCH_TRACKING_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

# Sync batch to GitLab (if enabled)
sync_batch_to_gitlab() {
    if [[ "$SYNC_GITLAB" == "true" ]]; then
        echo "🔗 Syncing batch to GitLab..."
        python3 "$PROJECT_ROOT/tools/gitlab/sync_experiment_to_gitlab.py" "$BATCH_TRACKING_FILE"
    fi
}

# Function to launch a single experiment with DrWatson-based naming
launch_experiment() {
    local gn=$1
    local degree_min=$2
    local degree_max=$3
    local domain=$4

    echo "🔧 Generating DrWatson directory name for GN=$gn, degrees=$degree_min:$degree_max, domain=$domain..."

    # Generate directory name using DrWatson (same pattern as minimal_4d_lv_test.jl)
    # This ensures session_name == output_dir basename
    OUTPUT_DIR=$(julia --project="$PROJECT_ROOT" -e "
    using DrWatson
    using Dates

    # Match parameters from minimal_4d_lv_test.jl
    params = Dict(
        \"GN\" => $gn,
        \"degree_range\" => [$degree_min:$degree_max...],
        \"domain_size_param\" => $domain,
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
    "GN": $gn,
    "degree_range": [$degree_min, $degree_max],
    "domain_size_param": $domain,
    "max_time": 45.0
  },
  "experiment_type": "minimal_4d_lotka_volterra_test",
  "progress": {
    "percent_complete": 0.0,
    "current_step": 0,
    "total_steps": $(($degree_max - $degree_min + 1))
  }
}
EOF
)

    # Copy session_info to cluster first
    echo "$SESSION_INFO" | ssh $CLUSTER_HOST "mkdir -p '$FULL_OUTPUT_DIR' && cat > '$FULL_OUTPUT_DIR/.session_info.json'"

    # Launch experiment in tmux with session tracking
    # Pass --output-dir to ensure Julia uses the pre-generated directory name
    ssh $CLUSTER_HOST "cd $CLUSTER_DIR && tmux new-session -d -s '$SESSION_NAME' \"
        julia --project=. Examples/minimal_4d_lv_test_unified.jl --GN=$gn --degrees=$degree_min:$degree_max --domain=$domain --output-dir='$FULL_OUTPUT_DIR' 2>&1 | tee '${FULL_OUTPUT_DIR}/experiment.log'
        echo 'Experiment completed at \$(date)'
        bash
    \""

    # Add to batch tracking
    add_session_to_batch "$SESSION_NAME" "$gn" "$degree_min" "$degree_max" "$domain" "${FULL_OUTPUT_DIR}/experiment.log"

    echo "  ✅ Launched: $SESSION_NAME"
    echo ""
}

# Initialize batch tracking
create_batch_tracking_file

# Small quick tests (2-3 minutes each)
echo "=== Phase 1: Small Quick Tests ==="
launch_experiment 5 4 5 0.1
launch_experiment 5 4 5 0.15
launch_experiment 5 4 5 0.2

# Medium tests (5-10 minutes each)
echo "=== Phase 2: Medium Tests ==="
launch_experiment 6 4 6 0.1
launch_experiment 6 4 6 0.15

# Larger tests (15-30 minutes each)
echo "=== Phase 3: Larger Tests ==="
launch_experiment 8 4 7 0.1
launch_experiment 8 4 7 0.15

echo "=========================================="
echo "✓ All experiments launched!"
echo "=========================================="

# Sync to GitLab if enabled
sync_batch_to_gitlab

echo ""
echo "📊 Batch tracking saved to:"
echo "   $BATCH_TRACKING_FILE"
echo ""
echo "Monitor with:"
echo "  ssh $CLUSTER_HOST 'tmux list-sessions | grep lv4d'"
echo ""
echo "Attach to session:"
echo "  ssh $CLUSTER_HOST"
echo "  tmux attach -t lv4d_..."
echo ""
echo "Check logs:"
echo "  ssh $CLUSTER_HOST 'tail -f $CLUSTER_DIR/lv4d_*.log'"
echo ""