#!/bin/bash
# Node Experiments Runner for r04n02
# Unified runner for all node_experiments with proper path management

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
NODE_EXPERIMENTS_DIR="$GLOBTIM_DIR/node_experiments"
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
    local heap_size=$3
    
    print_info "Starting experiment in tmux session: $session_name"
    print_info "Heap size allocation: $heap_size"
    
    # Create a tmux session and run the experiment
    tmux new-session -d -s "$session_name" bash -c "
        cd $GLOBTIM_DIR
        
        # Julia 1.11.6 is available via juliaup (no module system)
        
        # Setup environment
        export JULIA_PROJECT='$GLOBTIM_DIR'
        export EXPERIMENT_SESSION='$session_name'
        
        # Create log directory
        LOG_DIR='$NODE_EXPERIMENTS_DIR/outputs/${session_name}'
        mkdir -p \$LOG_DIR
        
        # Run with output logging
        exec 1> >(tee -a \$LOG_DIR/output.log)
        exec 2> >(tee -a \$LOG_DIR/error.log >&2)
        
        echo '========================================='
        echo 'Node Experiment: $EXPERIMENT_NAME'
        echo 'Started: \$(date)'
        echo 'Session: $session_name'
        echo 'Script: $experiment_script'
        echo 'Heap Size: $heap_size'
        echo '========================================='
        
        # Issue #53 Fix: Ensure all package dependencies are instantiated
        echo 'Instantiating package dependencies (Issue #53 fix)...'
        julia --project=. -e 'using Pkg; Pkg.instantiate()' || {
            echo 'ERROR: Pkg.instantiate() failed - dependencies not properly installed'
            exit 1
        }
        echo '✅ Package dependencies instantiated successfully'
        
        # Run the actual experiment with specified heap size
        julia --project=. --heap-size-hint=$heap_size $experiment_script \$LOG_DIR
        
        echo '========================================='
        echo 'Completed: \$(date)'
        echo '========================================='
    "
    
    print_info "Experiment started successfully!"
    print_info "To monitor: tmux attach -t $session_name"
    print_info "To detach: Ctrl+B then D"
    print_info "Results will be saved to: $NODE_EXPERIMENTS_DIR/outputs/$session_name"
    
    # Save session info for later reference
    echo "$session_name" > "$NODE_EXPERIMENTS_DIR/.current_experiment_session"
}

# Function to check experiment status
function check_status() {
    if [ -f "$NODE_EXPERIMENTS_DIR/.current_experiment_session" ]; then
        local session=$(cat "$NODE_EXPERIMENTS_DIR/.current_experiment_session")
        if tmux ls 2>/dev/null | grep -q "$session"; then
            print_info "Experiment '$session' is RUNNING"
            print_info "Attach with: tmux attach -t $session"
        else
            print_warning "Experiment '$session' has COMPLETED or STOPPED"
            print_info "Check results in: $NODE_EXPERIMENTS_DIR/outputs/$session/"
        fi
    else
        print_info "No current experiment session found"
    fi
}

# Function to verify packages
function verify_packages() {
    print_info "Verifying package dependencies..."
    
    # Check if CSV extension is available
    julia --project=. -e 'using CSV; println("✓ CSV extension loaded successfully")' 2>/dev/null || {
        print_warning "CSV extension failed to load (this is expected for weak dependency)"
    }
    
    # Check if JSON is installed
    julia --project=. -e 'using JSON; println("✓ JSON package loaded successfully")' 2>/dev/null || {
        print_error "JSON package not found. Please install with: julia --project=. -e 'using Pkg; Pkg.add(\"JSON\")'"
        return 1
    }
    
    # Check core dependencies
    julia --project=. -e 'using Statistics, DataFrames; println("✓ Core dependencies available")' || {
        print_error "Core dependencies failed to load"
        return 1
    }
    
    print_info "Package verification completed"
    return 0
}

# Main script logic
case "${1:-}" in
    status)
        check_status
        ;;
    verify)
        verify_packages
        ;;
    lotka-volterra-4d)
        # Lotka-Volterra 4D parameter estimation
        SAMPLES=${2:-8}
        DEGREE=${3:-10}
        HEAP_SIZE="50G"
        
        print_info "Lotka-Volterra 4D Parameter Estimation"
        print_info "Samples per parameter: $SAMPLES, Degree: $DEGREE"
        
        # Verify packages first
        verify_packages || exit 1
        
        # Create custom script with parameters
        SCRIPT_DIR="$NODE_EXPERIMENTS_DIR/scripts/temp"
        mkdir -p "$SCRIPT_DIR"
        SCRIPT_FILE="$SCRIPT_DIR/lotka_volterra_4d_${SESSION_NAME}.jl"
        
        cat > "$SCRIPT_FILE" << EOF
ENV["SAMPLES_PER_DIM"] = "$SAMPLES"
ENV["DEGREE"] = "$DEGREE"
include("$NODE_EXPERIMENTS_DIR/scripts/lotka_volterra_4d.jl")
EOF
        
        start_experiment "$SCRIPT_FILE" "$SESSION_NAME" "$HEAP_SIZE"
        ;;
    rosenbrock-4d)
        # Test case - 4D Rosenbruck optimization
        SAMPLES=${2:-10}
        DEGREE=${3:-12}
        HEAP_SIZE="50G"
        
        print_info "4D Rosenbrock Test Case"
        print_info "Samples per dimension: $SAMPLES, Degree: $DEGREE"
        
        verify_packages || exit 1
        
        # Use existing script from hpc/experiments (for backward compatibility)
        SCRIPT_DIR="$GLOBTIM_DIR/hpc/experiments/temp"
        mkdir -p "$SCRIPT_DIR"
        SCRIPT_FILE="$SCRIPT_DIR/4d_model_${SESSION_NAME}.jl"
        
        cat > "$SCRIPT_FILE" << EOF
ENV["SAMPLES_PER_DIM"] = "$SAMPLES"
ENV["DEGREE"] = "$DEGREE"
include("$GLOBTIM_DIR/hpc/experiments/run_4d_experiment.jl")
EOF
        
        start_experiment "$SCRIPT_FILE" "$SESSION_NAME" "$HEAP_SIZE"
        ;;
    test-2d)
        # Simple 2D test for validation
        HEAP_SIZE="10G"
        
        verify_packages || exit 1
        start_experiment "$GLOBTIM_DIR/hpc/experiments/test_2d_deuflhard.jl" "$SESSION_NAME" "$HEAP_SIZE"
        ;;
    attach)
        if [ -f "$NODE_EXPERIMENTS_DIR/.current_experiment_session" ]; then
            session=$(cat "$NODE_EXPERIMENTS_DIR/.current_experiment_session")
            tmux attach -t "$session"
        else
            print_error "No current session found"
        fi
        ;;
    list)
        print_info "Active tmux sessions:"
        tmux ls 2>/dev/null | grep globtim || echo "No GlobTim sessions found"
        ;;
    outputs)
        print_info "Available experiment outputs:"
        ls -la "$NODE_EXPERIMENTS_DIR/outputs/" 2>/dev/null || echo "No outputs directory found"
        ;;
    *)
        echo "Node Experiments Runner for r04n02"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  lotka-volterra-4d [s] [d]  - Lotka-Volterra 4D parameter estimation (s=samples, d=degree)"
        echo "  rosenbrock-4d [s] [d]      - 4D Rosenbrock test case (s=samples, d=degree)"
        echo "  test-2d                    - Simple 2D test for validation"
        echo "  verify                     - Check package dependencies"
        echo "  status                     - Check current experiment status"
        echo "  attach                     - Attach to current experiment"
        echo "  list                       - List all GlobTim sessions"
        echo "  outputs                    - Show available experiment outputs"
        echo ""
        echo "Examples:"
        echo "  $0 verify                           # Check dependencies"
        echo "  $0 lotka-volterra-4d 8 10          # LV parameter estimation"
        echo "  $0 rosenbrock-4d 10 12             # 4D test case"
        echo "  $0 status                          # Check progress"
        echo ""
        echo "🎯 PRIORITY: Use 'lotka-volterra-4d' for today's main goal"
        exit 1
        ;;
esac