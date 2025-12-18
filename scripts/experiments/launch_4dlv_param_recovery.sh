#!/bin/bash
# Launch 4D Lotka-Volterra Parameter Recovery Campaign on Cluster
# Runs multiple experiments with different parameters in parallel tmux sessions

set -e

CLUSTER_HOST="scholten@r04n02"
CLUSTER_DIR="/home/scholten/globtimcore"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================="
echo "4D L.V. Parameter Recovery Campaign"
echo "=========================================="
echo "Cluster: $CLUSTER_HOST"
echo "Directory: $CLUSTER_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Function to launch a single experiment
launch_experiment() {
    local gn=$1
    local degree_min=$2
    local degree_max=$3
    local domain=$4
    local session_name="lv4d_paramrec_GN${gn}_deg${degree_min}-${degree_max}_dom${domain}_${TIMESTAMP}"

    echo "Launching: $session_name"
    echo "  GN=$gn, degrees=$degree_min:$degree_max, domain=$domain"

    ssh $CLUSTER_HOST "cd $CLUSTER_DIR && tmux new-session -d -s $session_name \"
        julia --project=. Examples/4DLV/parameter_recovery_experiment_unified.jl --GN=$gn --degrees=$degree_min:$degree_max --domain=$domain 2>&1 | tee ${session_name}.log
        echo 'Experiment completed at \$(date)'
        bash
    \""

    echo "  ✓ Session: $session_name"
    echo ""
}

# Phase 1: Small quick tests (2-5 minutes each)
echo "=== Phase 1: Small Quick Tests ==="
launch_experiment 5 4 4 0.3
launch_experiment 5 4 5 0.3
launch_experiment 6 4 4 0.3

# Phase 2: Medium tests (5-15 minutes each)
echo "=== Phase 2: Medium Tests ==="
launch_experiment 6 4 5 0.3
launch_experiment 7 4 5 0.3
launch_experiment 8 4 5 0.3

# Phase 3: Larger tests (15-45 minutes each)
echo "=== Phase 3: Larger Tests ==="
launch_experiment 8 4 6 0.3
launch_experiment 10 4 6 0.3
launch_experiment 10 4 7 0.3

echo "=========================================="
echo "✓ All experiments launched!"
echo "=========================================="
echo ""
echo "Monitor with:"
echo "  ssh $CLUSTER_HOST 'tmux list-sessions | grep lv4d_paramrec'"
echo ""
echo "Attach to session:"
echo "  ssh $CLUSTER_HOST"
echo "  tmux attach -t lv4d_paramrec_..."
echo ""
echo "Check logs:"
echo "  ssh $CLUSTER_HOST 'tail -f $CLUSTER_DIR/lv4d_paramrec_*.log'"
echo ""
