#!/bin/bash
# Robust Experiment Runner for r04n02
# Uses tmux for persistent execution without SLURM

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
EXPERIMENT_NAME="${1:-experiment}"
SESSION_NAME="globtim_${EXPERIMENT_NAME}_$(date +%Y%m%d_%H%M%S)"

function print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to start experiment in tmux
function start_experiment() {
    local experiment_script=$1
    local session_name=$2
    
    print_info "Starting experiment in tmux session: $session_name"
    
    # Create a tmux session and run the experiment
    tmux new-session -d -s "$session_name" bash -c "
        cd $GLOBTIM_DIR
        
        # Julia 1.11.6 is available via juliaup (no module system)
        
        # Setup environment
        export JULIA_PROJECT='$GLOBTIM_DIR'
        export EXPERIMENT_SESSION='$session_name'
        
        # Create log directory
        LOG_DIR='$GLOBTIM_DIR/hpc_results/${session_name}'
        mkdir -p \$LOG_DIR
        
        # Run with output logging
        exec 1> >(tee -a \$LOG_DIR/output.log)
        exec 2> >(tee -a \$LOG_DIR/error.log >&2)
        
        echo '========================================='
        echo 'Experiment: $EXPERIMENT_NAME'
        echo 'Started: \$(date)'
        echo 'Session: $session_name'
        echo '========================================='
        
        # Run the actual experiment
        julia --project=. $experiment_script \$LOG_DIR
        
        echo '========================================='
        echo 'Completed: \$(date)'
        echo '========================================='
    "
    
    print_info "Experiment started successfully!"
    print_info "To monitor: tmux attach -t $session_name"
    print_info "To detach: Ctrl+B then D"
    print_info "To list sessions: tmux ls"
    
    # Save session info for later reference
    echo "$session_name" > "$GLOBTIM_DIR/.current_experiment_session"
}

# Function to check experiment status
function check_status() {
    if [ -f "$GLOBTIM_DIR/.current_experiment_session" ]; then
        local session=$(cat "$GLOBTIM_DIR/.current_experiment_session")
        if tmux ls 2>/dev/null | grep -q "$session"; then
            print_info "Experiment '$session' is RUNNING"
            print_info "Attach with: tmux attach -t $session"
        else
            print_warning "Experiment '$session' has COMPLETED or STOPPED"
            print_info "Check results in: $GLOBTIM_DIR/hpc_results/$session/"
        fi
    else
        print_info "No current experiment session found"
    fi
}

# Main script logic
case "${1:-}" in
    status)
        check_status
        ;;
    2d-test)
        start_experiment "hpc/experiments/test_2d_deuflhard.jl" "$SESSION_NAME"
        ;;
    4d-model)
        # Get parameters
        SAMPLES=${2:-10}
        DEGREE=${3:-12}
        
        # Create custom 4D script with parameters in the experiment directory
        SCRIPT_DIR="$GLOBTIM_DIR/hpc/experiments/temp"
        mkdir -p "$SCRIPT_DIR"
        SCRIPT_FILE="$SCRIPT_DIR/4d_model_${SESSION_NAME}.jl"
        
        cat > "$SCRIPT_FILE" << EOF
ENV["SAMPLES_PER_DIM"] = "$SAMPLES"
ENV["DEGREE"] = "$DEGREE"
include("$GLOBTIM_DIR/hpc/experiments/run_4d_experiment.jl")
EOF
        
        start_experiment "$SCRIPT_FILE" "$SESSION_NAME"
        ;;
    attach)
        if [ -f "$GLOBTIM_DIR/.current_experiment_session" ]; then
            session=$(cat "$GLOBTIM_DIR/.current_experiment_session")
            tmux attach -t "$session"
        else
            print_error "No current session found"
        fi
        ;;
    list)
        print_info "Active tmux sessions:"
        tmux ls 2>/dev/null | grep globtim || echo "No GlobTim sessions found"
        ;;
    *)
        echo "Robust Experiment Runner for r04n02"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  2d-test           - Run 2D Deuflhard test"
        echo "  4d-model [s] [d]  - Run 4D model (s=samples, d=degree)"
        echo "  status            - Check current experiment status"
        echo "  attach            - Attach to current experiment"
        echo "  list              - List all GlobTim sessions"
        echo ""
        echo "Examples:"
        echo "  $0 2d-test"
        echo "  $0 4d-model 10 12"
        echo "  $0 status"
        exit 1
        ;;
esac