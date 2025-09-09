#!/bin/bash

# DEPRECATED - Custom HPC Test Runner using SLURM
# This script generates SLURM scripts for legacy clusters
# 
# For current r04n02 cluster execution, use instead:
# ./hpc/experiments/robust_experiment_runner.sh <experiment-name> <script>
# or
# ./node_experiments/runners/experiment_runner.sh <script-pattern>
#
# Issue #56: Legacy SLURM infrastructure removal

echo "⚠️  DEPRECATED SCRIPT"
echo "This SLURM-based script is no longer used on r04n02"  
echo ""
echo "Use direct execution instead:"
echo "  ./hpc/experiments/robust_experiment_runner.sh my-test <your-script.jl>"
echo "  ./node_experiments/runners/experiment_runner.sh <pattern>"
echo ""
echo "Exiting to prevent confusion with legacy SLURM workflow"
exit 1

# Legacy SLURM implementation follows (preserved for reference)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# USAGE AND CONFIGURATION
# ============================================================================

show_usage() {
    echo "Usage: $0 <julia_file> [options]"
    echo ""
    echo "Examples:"
    echo "  $0 Examples/hpc_light_2d_example.jl"
    echo "  $0 Examples/hpc_light_2d_example.jl --light"
    echo "  $0 Examples/hpc_robust_test_runner.jl --cpus=4 --mem=8G"
    echo "  $0 test/my_custom_test.jl --time=00:30:00"
    echo ""
    echo "Options:"
    echo "  --light              Pass --light flag to Julia script"
    echo "  --cpus=N            Number of CPUs (default: 2)"
    echo "  --mem=XG            Memory allocation (default: 4G)"
    echo "  --time=HH:MM:SS     Time limit (default: 00:10:00)"
    echo "  --partition=NAME    SLURM partition (default: batch)"
    echo "  --args='...'        Additional arguments to pass to Julia script"
    echo "  --no-monitor        Submit job but don't monitor"
    echo ""
}

# Check if file provided
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

JULIA_FILE="$1"
shift

# Default job parameters
CPUS=2
MEMORY="4G"
TIME_LIMIT="00:10:00"
PARTITION="batch"
JULIA_ARGS=""
MONITOR_JOB=true
LIGHT_MODE=false

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --light)
            LIGHT_MODE=true
            JULIA_ARGS="$JULIA_ARGS --light"
            shift
            ;;
        --cpus=*)
            CPUS="${1#*=}"
            shift
            ;;
        --mem=*)
            MEMORY="${1#*=}"
            shift
            ;;
        --time=*)
            TIME_LIMIT="${1#*=}"
            shift
            ;;
        --partition=*)
            PARTITION="${1#*=}"
            shift
            ;;
        --args=*)
            JULIA_ARGS="$JULIA_ARGS ${1#*=}"
            shift
            ;;
        --no-monitor)
            MONITOR_JOB=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Load cluster config
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    export CLUSTER_HOST="scholten@falcon"
    export CLUSTER_PATH="~/globtim_hpc"
fi

echo -e "${BLUE}🚀 Custom HPC Test Runner${NC}"
echo "=" * 60
echo "Julia file: $JULIA_FILE"
echo "Arguments: $JULIA_ARGS"
echo "CPUs: $CPUS, Memory: $MEMORY, Time: $TIME_LIMIT"
echo "Cluster: $CLUSTER_HOST"
echo ""

# ============================================================================
# VALIDATION
# ============================================================================

# Check if Julia file exists
if [ ! -f "$JULIA_FILE" ]; then
    echo -e "${RED}❌ File not found: $JULIA_FILE${NC}"
    exit 1
fi

# Check cluster connection
echo -e "${BLUE}🔗 Checking cluster connection...${NC}"
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$CLUSTER_HOST" "echo 'OK'" >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster connection OK${NC}"

# ============================================================================
# SYNC AND SETUP
# ============================================================================

echo -e "${BLUE}📤 Syncing files to cluster...${NC}"

# Create unique job ID for this run
JOB_UUID=$(date +%s)_$(basename "$JULIA_FILE" .jl)

# Sync the specific Julia file and dependencies
rsync -avz "$JULIA_FILE" "$CLUSTER_HOST:$CLUSTER_PATH/"

# Sync project files if they exist
for proj_file in "Project.toml" "hpc/config/Project_HPC.toml" "Manifest.toml"; do
    if [ -f "$proj_file" ]; then
        rsync -avz "$proj_file" "$CLUSTER_HOST:$CLUSTER_PATH/"
    fi
done

# Sync any additional directories the Julia file might need
JULIA_DIR=$(dirname "$JULIA_FILE")
if [ "$JULIA_DIR" != "." ] && [ -d "$JULIA_DIR" ]; then
    rsync -avz "$JULIA_DIR"/ "$CLUSTER_HOST:$CLUSTER_PATH/$JULIA_DIR/"
fi

echo -e "${GREEN}✅ Files synced${NC}"

# ============================================================================
# CREATE CUSTOM SLURM SCRIPT
# ============================================================================

echo -e "${BLUE}📝 Creating custom SLURM script...${NC}"

SLURM_SCRIPT="custom_${JOB_UUID}.slurm"
JULIA_BASENAME=$(basename "$JULIA_FILE")

cat > "$SLURM_SCRIPT" << EOF
#!/bin/bash
#SBATCH --job-name=custom_$(basename "$JULIA_FILE" .jl)
#SBATCH --partition=$PARTITION
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$CPUS
#SBATCH --mem=$MEMORY
#SBATCH --time=$TIME_LIMIT
#SBATCH --output=custom_${JOB_UUID}_%j.out
#SBATCH --error=custom_${JOB_UUID}_%j.err

echo "🚀 Custom HPC Test: $JULIA_BASENAME"
echo "=================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: $CPUS"
echo "Memory: $MEMORY"
echo "Started: \$(date)"
echo ""

# Set up Julia environment
export JULIA_DEPOT_PATH="/tmp/julia_depot_\$SLURM_JOB_ID"
mkdir -p "\$JULIA_DEPOT_PATH"

echo "📦 Julia depot: \$JULIA_DEPOT_PATH"
echo ""

# Use system Julia
export PATH="/sw/bin:\$PATH"

echo "🔧 Julia version:"
julia --version
echo ""

echo "📁 Working directory: \$(pwd)"
echo ""

# Setup project if Project.toml exists
if [ -f "Project_HPC.toml" ]; then
    echo "📦 Using HPC project configuration..."
    cp Project_HPC.toml Project.toml
elif [ ! -f "Project.toml" ]; then
    echo "📦 Creating minimal project..."
    echo 'name = "CustomTest"' > Project.toml
fi

echo "📦 Installing packages..."
julia --project=. -e "
using Pkg
Pkg.instantiate()
Pkg.precompile()
println(\"✅ Package setup complete\")
"

echo ""
echo "🚀 Running: $JULIA_BASENAME $JULIA_ARGS"
echo "=================================="
julia --project=. $JULIA_BASENAME $JULIA_ARGS

echo ""
echo "✅ Custom test completed"
echo "Finished: \$(date)"
EOF

# Upload SLURM script
scp "$SLURM_SCRIPT" "$CLUSTER_HOST:$CLUSTER_PATH/"

echo -e "${GREEN}✅ SLURM script created: $SLURM_SCRIPT${NC}"

# ============================================================================
# SUBMIT JOB
# ============================================================================

echo -e "${BLUE}🚀 Submitting job...${NC}"

JOB_OUTPUT=$(ssh "$CLUSTER_HOST" "cd $CLUSTER_PATH && sbatch $SLURM_SCRIPT" 2>&1)

if echo "$JOB_OUTPUT" | grep -q "Submitted batch job"; then
    JOB_ID=$(echo "$JOB_OUTPUT" | grep -o '[0-9]*')
    echo -e "${GREEN}✅ Job submitted successfully${NC}"
    echo "   Job ID: $JOB_ID"
    echo "   Script: $SLURM_SCRIPT"
    echo "   Output: custom_${JOB_UUID}_${JOB_ID}.out"
    echo "   Error:  custom_${JOB_UUID}_${JOB_ID}.err"
else
    echo -e "${RED}❌ Job submission failed${NC}"
    echo "   Output: $JOB_OUTPUT"
    exit 1
fi

# ============================================================================
# MONITOR JOB (OPTIONAL)
# ============================================================================

if [ "$MONITOR_JOB" = true ]; then
    echo ""
    echo -e "${BLUE}👀 Monitoring job $JOB_ID...${NC}"
    echo "Press Ctrl+C to stop monitoring (job will continue)"
    echo ""
    
    while true; do
        STATUS=$(ssh "$CLUSTER_HOST" "squeue -j $JOB_ID -h -o '%T' 2>/dev/null" || echo "COMPLETED")
        
        if [ -z "$STATUS" ] || [ "$STATUS" = "COMPLETED" ]; then
            echo -e "${GREEN}✅ Job $JOB_ID completed${NC}"
            break
        fi
        
        echo "📊 Job $JOB_ID status: $STATUS ($(date '+%H:%M:%S'))"
        
        # Show latest output if running
        if [ "$STATUS" = "RUNNING" ]; then
            OUTPUT_FILE="custom_${JOB_UUID}_${JOB_ID}.out"
            LATEST=$(ssh "$CLUSTER_HOST" "cd $CLUSTER_PATH && tail -3 $OUTPUT_FILE 2>/dev/null" || echo "")
            if [ -n "$LATEST" ]; then
                echo "📄 Latest output:"
                echo "$LATEST" | sed 's/^/   /'
                echo ""
            fi
        fi
        
        sleep 10
    done
    
    # Show final results
    echo ""
    echo -e "${BLUE}📥 Final Results:${NC}"
    OUTPUT_FILE="custom_${JOB_UUID}_${JOB_ID}.out"
    
    if ssh "$CLUSTER_HOST" "cd $CLUSTER_PATH && test -f $OUTPUT_FILE"; then
        echo "📄 Job Output:"
        ssh "$CLUSTER_HOST" "cd $CLUSTER_PATH && tail -20 $OUTPUT_FILE" | sed 's/^/   /'
        
        # Check for success/failure
        if ssh "$CLUSTER_HOST" "cd $CLUSTER_PATH && grep -q 'SUCCESS\\|✅' $OUTPUT_FILE"; then
            echo -e "${GREEN}🎉 Test completed successfully!${NC}"
        else
            echo -e "${YELLOW}⚠️  Test completed with issues${NC}"
        fi
    fi
    
    echo ""
    echo "📁 Download results with:"
    echo "   scp $CLUSTER_HOST:$CLUSTER_PATH/custom_${JOB_UUID}_${JOB_ID}.out ./"
    echo "   scp $CLUSTER_HOST:$CLUSTER_PATH/custom_${JOB_UUID}_${JOB_ID}.err ./"
else
    echo ""
    echo -e "${YELLOW}📋 Job submitted without monitoring${NC}"
    echo "Check status with: ssh $CLUSTER_HOST 'squeue -j $JOB_ID'"
    echo "View output with: ssh $CLUSTER_HOST 'cat $CLUSTER_PATH/custom_${JOB_UUID}_${JOB_ID}.out'"
fi

# Cleanup local SLURM script
rm "$SLURM_SCRIPT"

echo ""
echo -e "${GREEN}🏁 Custom HPC test completed!${NC}"
echo "Finished: $(date)"
