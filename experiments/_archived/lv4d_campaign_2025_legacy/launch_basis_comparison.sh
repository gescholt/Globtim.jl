#!/bin/bash
# Lotka-Volterra 4D Basis Comparison Campaign Launcher
#
# PURPOSE: Launch experiments to compare Chebyshev vs Legendre polynomial bases
#          on the same Lotka-Volterra 4D parameter estimation problem
#
# WORKFLOW:
#   1. Launches Chebyshev experiment (degrees 4-6)
#   2. Launches Legendre experiment (degrees 4-6)
#   3. Both run in parallel tmux sessions
#   4. Results can be compared after completion
#
# USAGE:
#   ./launch_basis_comparison.sh [--dry-run]
#
# NOTES:
#   - Uses standardized launch infrastructure (tmux, tracking, logging)
#   - Small degree range (4-6) for quick comparison testing
#   - Each basis type gets its own tmux session and results directory

set -e

# Parse arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔵 DRY RUN MODE - No experiments will be launched"
    echo ""
fi

echo "="^80
echo "LOTKA-VOLTERRA 4D BASIS COMPARISON CAMPAIGN"
echo "="^80
echo "Configuration:"
echo "  - Basis types: Chebyshev, Legendre"
echo "  - Domain: ±0.3"
echo "  - Degree range: 4-6 (small range for testing)"
echo "  - GN (samples/dim): 16"
echo "  - Experiments: 2 (one per basis type)"
echo "  - Estimated time: ~5-10 minutes per basis"
echo "="^80
echo ""

# Create experiment tracking directory
TRACKING_DIR="experiments/lv4d_campaign_2025/tracking"
mkdir -p "$TRACKING_DIR"

# Timestamp for this launch batch
BATCH_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BATCH_ID="batch_basis_comparison_$BATCH_TIMESTAMP"

# Create batch tracking file
BATCH_FILE="$TRACKING_DIR/$BATCH_ID.json"

# Initialize batch tracking
cat > "$BATCH_FILE" << EOF
{
  "batch_id": "$BATCH_ID",
  "campaign": "lv4d_basis_comparison_2025",
  "start_time": "$(date --iso-8601=seconds 2>/dev/null || date -Iseconds)",
  "domain_range": 0.3,
  "degree_range": [4, 6],
  "basis_types": ["chebyshev", "legendre"],
  "rationale": "Direct comparison of Chebyshev vs Legendre polynomial bases for parameter estimation",
  "total_experiments": 2,
  "sessions": []
}
EOF

echo "Batch ID: $BATCH_ID"
echo "Tracking file: $BATCH_FILE"
echo ""

# Experiment script base (will be copied with different BASIS_TYPE settings)
EXPERIMENT_SCRIPT_BASE="experiments/lv4d_campaign_2025/basis_comparison_experiment.jl"

# Validate script exists
if [ ! -f "$EXPERIMENT_SCRIPT_BASE" ]; then
    echo "❌ Error: Experiment script not found: $EXPERIMENT_SCRIPT_BASE"
    exit 1
fi

echo "✓ Experiment script validated: $EXPERIMENT_SCRIPT_BASE"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔵 DRY RUN: Would launch the following experiments:"
    echo ""
    echo "  1. Chebyshev basis"
    echo "     Session: lv4d_basis_chebyshev"
    echo "     Command: julia --project=. --heap-size-hint=50G $EXPERIMENT_SCRIPT_BASE"
    echo ""
    echo "  2. Legendre basis"
    echo "     Session: lv4d_basis_legendre"
    echo "     Command: julia --project=. --heap-size-hint=50G $EXPERIMENT_SCRIPT_BASE"
    echo ""
    echo "To launch for real, run:"
    echo "  $0"
    echo ""
    exit 0
fi

# Array of basis types to test
BASIS_TYPES=("chebyshev" "legendre")

for BASIS in "${BASIS_TYPES[@]}"; do
    echo "="^60
    echo "Launching $BASIS basis experiment..."
    echo "="^60

    SESSION_NAME="lv4d_basis_${BASIS}"

    # Create a temporary script with the correct BASIS_TYPE setting
    # Use absolute path for the script
    TEMP_SCRIPT="/home/scholten/globtimcore/$TRACKING_DIR/temp_${BASIS}_${BATCH_TIMESTAMP}.jl"

    # Copy base script and modify BASIS_TYPE constant
    sed "s/const BASIS_TYPE = :chebyshev/const BASIS_TYPE = :${BASIS}/" \
        "$EXPERIMENT_SCRIPT_BASE" > "$TEMP_SCRIPT"

    echo "  Session: $SESSION_NAME"
    echo "  Basis: $BASIS"
    echo "  Script: $TEMP_SCRIPT"
    echo ""

    # Kill existing session if it exists
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

    # Create new tmux session
    tmux new-session -d -s "$SESSION_NAME" \
        "cd /home/scholten/globtimcore && \
         julia --project=. --heap-size-hint=50G $TEMP_SCRIPT 2>&1 | \
         tee $TRACKING_DIR/${SESSION_NAME}_${BATCH_TIMESTAMP}.log"

    # Update batch tracking
    python3 -c "
import json
from datetime import datetime

with open('$BATCH_FILE', 'r') as f:
    data = json.load(f)

data['sessions'].append({
    'session_name': '$SESSION_NAME',
    'basis_type': '$BASIS',
    'parameters': {
        'domain_range': 0.3,
        'min_degree': 4,
        'max_degree': 6,
        'GN': 16
    },
    'status': 'launching',
    'launch_time': datetime.now().isoformat(),
    'log_file': '$TRACKING_DIR/${SESSION_NAME}_${BATCH_TIMESTAMP}.log',
    'script_file': '$TEMP_SCRIPT',
    'cluster_node': 'r04n02'
})

with open('$BATCH_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"

    echo "  ✓ Started successfully"
    echo ""
done

echo "="^80
echo "EXPERIMENTS LAUNCHED"
echo "="^80
echo ""
echo "Monitor experiments:"
echo "  Chebyshev: tmux attach -t lv4d_basis_chebyshev"
echo "  Legendre:  tmux attach -t lv4d_basis_legendre"
echo ""
echo "View logs:"
echo "  Chebyshev: tail -f $TRACKING_DIR/lv4d_basis_chebyshev_${BATCH_TIMESTAMP}.log"
echo "  Legendre:  tail -f $TRACKING_DIR/lv4d_basis_legendre_${BATCH_TIMESTAMP}.log"
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
