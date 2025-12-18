#!/bin/bash

# Lotka-Volterra 4D Extended Degree Campaign Launcher (deg 4-18)
# Based on analysis from campaign_lotka_volterra_4d_extended_degrees
# Testing hypothesis: extended degrees up to 18 will improve convergence
#
# Rationale:
# - Previous campaign (deg 4-12) showed good L2 convergence
# - Domain 0.3 chosen for balance of accuracy and computation cost
# - Single experiment to test extended degree range before full campaign
#
# Usage: ./launch_deg18_campaign.sh [--dry-run]

set -e

# Parse arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔵 DRY RUN MODE - No experiments will be launched"
    echo ""
fi

echo "="^80
echo "LOTKA-VOLTERRA 4D EXTENDED DEGREE CAMPAIGN"
echo "="^80
echo "Configuration:"
echo "  - Domain: ±0.3"
echo "  - Degree range: 4-18 (EXTENDED)"
echo "  - GN (samples/dim): 16"
echo "  - Experiments: 1"
echo "  - Estimated time: ~15-20 minutes"
echo "="^80
echo ""

# Create experiment tracking directory
TRACKING_DIR="experiments/lv4d_campaign_2025/tracking"
mkdir -p "$TRACKING_DIR"

# Timestamp for this launch batch
BATCH_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BATCH_ID="batch_deg18_$BATCH_TIMESTAMP"

# Create batch tracking file
BATCH_FILE="$TRACKING_DIR/$BATCH_ID.json"

# Initialize batch tracking
cat > "$BATCH_FILE" << EOF
{
  "batch_id": "$BATCH_ID",
  "campaign": "lv4d_deg18_testing_2025",
  "start_time": "$(date --iso-8601=seconds 2>/dev/null || date -Iseconds)",
  "domain_range": 0.3,
  "degree_range": [4, 18],
  "rationale": "Testing extended degrees based on successful convergence in campaign_lotka_volterra_4d_extended_degrees",
  "reference": "globtimpostprocessing/collected_experiments_20251013_083530/campaign_lotka_volterra_4d_extended_degrees",
  "total_experiments": 1,
  "sessions": []
}
EOF

echo "Batch ID: $BATCH_ID"
echo "Tracking file: $BATCH_FILE"
echo ""

# Experiment script
EXPERIMENT_SCRIPT="experiments/lv4d_campaign_2025/launch_deg18_experiment.jl"

# Validate script exists
if [ ! -f "$EXPERIMENT_SCRIPT" ]; then
    echo "❌ Error: Experiment script not found: $EXPERIMENT_SCRIPT"
    exit 1
fi

echo "✓ Experiment script validated: $EXPERIMENT_SCRIPT"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔵 DRY RUN: Would launch the following experiment:"
    echo ""
    echo "  Session: lv4d_deg18_domain03"
    echo "  Command: julia --project=. --heap-size-hint=50G $EXPERIMENT_SCRIPT"
    echo "  Domain: ±0.3"
    echo "  Degrees: 4-18"
    echo ""
    echo "To launch for real, run:"
    echo "  $0"
    echo ""
    exit 0
fi

# Session name for tmux
SESSION_NAME="lv4d_deg18_domain03"

echo "Launching extended degree experiment..."
echo "  Session: $SESSION_NAME"
echo "  Domain: ±0.3"
echo "  Degrees: 4-18"
echo ""

# Kill existing session if it exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Create new tmux session
tmux new-session -d -s "$SESSION_NAME" \
    "cd /home/scholten/globtimcore && \
     julia --project=. --heap-size-hint=50G $EXPERIMENT_SCRIPT 2>&1 | \
     tee $TRACKING_DIR/${SESSION_NAME}_${BATCH_TIMESTAMP}.log"

# Update batch tracking
python3 -c "
import json
from datetime import datetime

with open('$BATCH_FILE', 'r') as f:
    data = json.load(f)

data['sessions'].append({
    'session_name': '$SESSION_NAME',
    'parameters': {
        'domain_range': 0.3,
        'min_degree': 4,
        'max_degree': 18,
        'GN': 16
    },
    'status': 'launching',
    'launch_time': datetime.now().isoformat(),
    'log_file': '$TRACKING_DIR/${SESSION_NAME}_${BATCH_TIMESTAMP}.log',
    'cluster_node': 'r04n02'
})

with open('$BATCH_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"

echo "  ✓ Started successfully"
echo ""

echo "="^80
echo "EXPERIMENT LAUNCHED"
echo "="^80
echo ""
echo "Monitor experiment:"
echo "  tmux attach -t $SESSION_NAME"
echo ""
echo "View log:"
echo "  tail -f $TRACKING_DIR/${SESSION_NAME}_${BATCH_TIMESTAMP}.log"
echo ""
echo "Check completion:"
echo "  ~/.globtim/scripts/completion_checker.sh"
echo ""
echo "Collect results when complete:"
echo "  ~/.globtim/scripts/collect_batch.sh $BATCH_ID"
echo ""
echo "Tracking file:"
echo "  $BATCH_FILE"
echo ""
echo "="^80
