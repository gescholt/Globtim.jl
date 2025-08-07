#!/bin/bash

# Enhanced Job Submission with Automatic Tracking
# Creates job, submits to cluster, tracks automatically, and enables auto-pull

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
JOB_TYPE="standard"
FUNCTION="deuflhard"
DEGREE=""
BASIS=""
SAMPLES=""
SAMPLE_RANGE=""
DESCRIPTION=""
TAGS=""
AUTO_PULL=true
PULL_INTERVAL=300  # 5 minutes

show_usage() {
    echo "Enhanced Job Submission with Automatic Tracking"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Job Creation Options:"
    echo "  -f, --function FUNC      Function to analyze (default: deuflhard)"
    echo "  -t, --type TYPE          Job type: quick|standard|thorough|long (default: standard)"
    echo "  -d, --degree DEGREE      Polynomial degree"
    echo "  -b, --basis BASIS        Basis: chebyshev|legendre"
    echo "  -s, --samples SAMPLES    Number of samples"
    echo "  -r, --range RANGE        Sample range"
    echo "  --description DESC       Job description"
    echo "  --tags TAGS              Comma-separated tags"
    echo ""
    echo "Automation Options:"
    echo "  --no-auto-pull          Don't automatically pull results when complete"
    echo "  --pull-interval SEC     Check interval for auto-pull (default: 300s)"
    echo "  --submit-only           Only submit, don't start monitoring"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Standard Deuflhard job with auto-pull"
    echo "  $0 -t quick -d 6                     # Quick test with degree 6"
    echo "  $0 -t thorough -b legendre --description 'Paper analysis'"
    echo "  $0 --submit-only                     # Submit and exit (manual monitoring)"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--function)
            FUNCTION="$2"
            shift 2
            ;;
        -t|--type)
            JOB_TYPE="$2"
            shift 2
            ;;
        -d|--degree)
            DEGREE="$2"
            shift 2
            ;;
        -b|--basis)
            BASIS="$2"
            shift 2
            ;;
        -s|--samples)
            SAMPLES="$2"
            shift 2
            ;;
        -r|--range)
            SAMPLE_RANGE="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --no-auto-pull)
            AUTO_PULL=false
            shift
            ;;
        --pull-interval)
            PULL_INTERVAL="$2"
            shift 2
            ;;
        --submit-only)
            AUTO_PULL=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Enhanced Job Submission with Auto-Tracking ===${NC}"
echo "Function: $FUNCTION"
echo "Job type: $JOB_TYPE"
echo "Auto-pull: $AUTO_PULL"
if [ "$AUTO_PULL" = true ]; then
    echo "Pull check interval: ${PULL_INTERVAL}s"
fi
echo ""

# Step 1: Create the job
echo -e "${YELLOW}📋 Step 1: Creating JSON-tracked job...${NC}"

cd hpc/jobs/creation

# Build job creation command
JOB_CMD="julia create_json_tracked_job.jl $FUNCTION $JOB_TYPE"

if [ -n "$DEGREE" ]; then
    JOB_CMD="$JOB_CMD --degree $DEGREE"
fi
if [ -n "$BASIS" ]; then
    JOB_CMD="$JOB_CMD --basis $BASIS"
fi
if [ -n "$SAMPLES" ]; then
    JOB_CMD="$JOB_CMD --samples $SAMPLES"
fi
if [ -n "$SAMPLE_RANGE" ]; then
    JOB_CMD="$JOB_CMD --sample_range $SAMPLE_RANGE"
fi
if [ -n "$DESCRIPTION" ]; then
    JOB_CMD="$JOB_CMD --description '$DESCRIPTION'"
fi

echo "Command: $JOB_CMD"
echo ""

# Execute job creation and capture output
JOB_OUTPUT=$(eval "$JOB_CMD" 2>&1)
JOB_CREATE_EXIT=$?

if [ $JOB_CREATE_EXIT -ne 0 ]; then
    echo -e "${RED}❌ Job creation failed${NC}"
    echo "$JOB_OUTPUT"
    exit 1
fi

echo "$JOB_OUTPUT"

# Extract information from automation section (more reliable)
AUTOMATION_SECTION=$(echo "$JOB_OUTPUT" | sed -n '/=== AUTOMATION_INFO ===/,/=== END_AUTOMATION_INFO ===/p')

if [ -n "$AUTOMATION_SECTION" ]; then
    # Extract from automation section
    COMPUTATION_ID=$(echo "$AUTOMATION_SECTION" | grep "COMPUTATION_ID=" | cut -d'=' -f2)
    JOB_SCRIPT=$(echo "$AUTOMATION_SECTION" | grep "JOB_SCRIPT_PATH=" | cut -d'=' -f2)
    OUTPUT_DIR=$(echo "$AUTOMATION_SECTION" | grep "OUTPUT_DIRECTORY=" | cut -d'=' -f2)
else
    # Fallback to old extraction method
    echo -e "${YELLOW}⚠️  Using fallback extraction method...${NC}"
    COMPUTATION_ID=$(echo "$JOB_OUTPUT" | grep -o "Computation ID: [a-zA-Z0-9]*" | cut -d' ' -f3)
    JOB_SCRIPT=$(echo "$JOB_OUTPUT" | grep "SLURM job script created:" | sed 's/.*SLURM job script created: //')
    OUTPUT_DIR=""
fi

# If still no job script, try to find it
if [ -z "$JOB_SCRIPT" ] && [ -n "$COMPUTATION_ID" ]; then
    echo -e "${YELLOW}⚠️  Searching for job script with computation ID...${NC}"

    # Look for recently created .slurm files with the computation ID
    POSSIBLE_SCRIPTS=$(find ../../../hpc/results -name "*${COMPUTATION_ID}*.slurm" -type f 2>/dev/null | head -1)
    if [ -n "$POSSIBLE_SCRIPTS" ]; then
        JOB_SCRIPT="$POSSIBLE_SCRIPTS"
        echo -e "${GREEN}✅ Found job script: $JOB_SCRIPT${NC}"
    fi
fi

if [ -z "$COMPUTATION_ID" ]; then
    echo -e "${RED}❌ Could not extract computation ID${NC}"
    echo "Full output:"
    echo "$JOB_OUTPUT"
    exit 1
fi

if [ -z "$JOB_SCRIPT" ]; then
    echo -e "${RED}❌ Could not find job script${NC}"
    echo "Computation ID: '$COMPUTATION_ID'"
    echo "Searched for: *${COMPUTATION_ID}*.slurm"
    exit 1
fi

echo -e "${GREEN}✅ Job created successfully${NC}"
echo "Computation ID: $COMPUTATION_ID"
echo "Job script: $JOB_SCRIPT"

# Debug: Check if job script actually exists
if [ -f "$JOB_SCRIPT" ]; then
    echo "✅ Job script file exists"
else
    echo "⚠️  Job script file not found at reported path: $JOB_SCRIPT"
    echo "Current directory: $(pwd)"
    echo "Looking for .slurm files with computation ID..."
    FOUND_SCRIPTS=$(find . -name "*${COMPUTATION_ID}*.slurm" -type f 2>/dev/null | head -5)
    if [ -n "$FOUND_SCRIPTS" ]; then
        echo "Found scripts:"
        echo "$FOUND_SCRIPTS"
    else
        echo "No .slurm files found with computation ID"
    fi
fi
echo ""

# Step 2: Submit to cluster
echo -e "${YELLOW}🚀 Step 2: Submitting to HPC cluster...${NC}"

cd ../../..  # Back to project root

# Ensure job script path is absolute
if [[ "$JOB_SCRIPT" != /* ]]; then
    JOB_SCRIPT="$(pwd)/$JOB_SCRIPT"
fi

# Verify job script exists
if [ ! -f "$JOB_SCRIPT" ]; then
    echo -e "${RED}❌ Job script not found: $JOB_SCRIPT${NC}"
    echo "Looking for alternative locations..."

    # Try to find the script by computation ID
    FOUND_SCRIPT=$(find . -name "*${COMPUTATION_ID}*.slurm" -type f 2>/dev/null | head -1)
    if [ -n "$FOUND_SCRIPT" ]; then
        JOB_SCRIPT="$(realpath "$FOUND_SCRIPT")"
        echo -e "${GREEN}✅ Found job script: $JOB_SCRIPT${NC}"
    else
        echo -e "${RED}❌ Could not find job script anywhere${NC}"
        exit 1
    fi
fi

# Copy job script to cluster
echo "Copying job script to cluster: $JOB_SCRIPT"
if scp "$JOB_SCRIPT" scholten@falcon:~/globtim_hpc/; then
    echo -e "${GREEN}✅ Job script copied to cluster${NC}"
else
    echo -e "${RED}❌ Failed to copy job script to cluster${NC}"
    echo "Job script path: $JOB_SCRIPT"
    echo "Checking if file exists: $(ls -la "$JOB_SCRIPT" 2>/dev/null || echo 'File not found')"
    exit 1
fi

# Submit job and capture job ID
JOB_SCRIPT_NAME=$(basename "$JOB_SCRIPT")
echo "Submitting job: $JOB_SCRIPT_NAME"

SUBMIT_OUTPUT=$(ssh scholten@falcon "cd ~/globtim_hpc && sbatch $JOB_SCRIPT_NAME" 2>&1)
SUBMIT_EXIT=$?

if [ $SUBMIT_EXIT -ne 0 ]; then
    echo -e "${RED}❌ Job submission failed${NC}"
    echo "$SUBMIT_OUTPUT"
    exit 1
fi

# Extract job ID
JOB_ID=$(echo "$SUBMIT_OUTPUT" | grep -o "Submitted batch job [0-9]*" | cut -d' ' -f4)

if [ -z "$JOB_ID" ]; then
    echo -e "${RED}❌ Could not extract job ID from submission output${NC}"
    echo "$SUBMIT_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ Job submitted successfully${NC}"
echo "Job ID: $JOB_ID"
echo "Computation ID: $COMPUTATION_ID"
echo ""

# Step 3: Add to job tracker
echo -e "${YELLOW}📊 Step 3: Adding to job tracker...${NC}"

# OUTPUT_DIR should already be set from automation section above
if [ -z "$OUTPUT_DIR" ]; then
    # Fallback: try to extract from job creation output
    OUTPUT_DIR=$(echo "$JOB_OUTPUT" | grep -o "output_directory.*" | cut -d'"' -f3)
fi

# Add to tracker
python3 hpc/infrastructure/job_tracker.py << EOF
import sys
sys.path.append('hpc/infrastructure')
from job_tracker import JobTracker

tracker = JobTracker()
tracker.add_job(
    computation_id="$COMPUTATION_ID",
    job_id="$JOB_ID", 
    job_script_path="$JOB_SCRIPT",
    output_directory="$OUTPUT_DIR",
    description="$DESCRIPTION"
)
EOF

echo -e "${GREEN}✅ Job added to tracker${NC}"
echo ""

# Step 4: Show monitoring information
echo -e "${BLUE}📊 Job Information:${NC}"
echo "  Job ID: $JOB_ID"
echo "  Computation ID: $COMPUTATION_ID"
echo "  Function: $FUNCTION"
echo "  Type: $JOB_TYPE"
if [ -n "$DESCRIPTION" ]; then
    echo "  Description: $DESCRIPTION"
fi
echo ""

echo -e "${BLUE}🔍 Monitoring Options:${NC}"
echo "  Manual check: python hpc/monitoring/python/slurm_monitor.py --analyze $JOB_ID"
echo "  Auto-pull check: python3 hpc/infrastructure/job_tracker.py --auto-pull"
echo "  List all jobs: python3 hpc/infrastructure/job_tracker.py --list"
echo ""

if [ "$AUTO_PULL" = true ]; then
    echo -e "${YELLOW}🤖 Starting automatic monitoring and result pulling...${NC}"
    echo "Will check every ${PULL_INTERVAL} seconds for job completion"
    echo "Press Ctrl+C to stop monitoring (job will continue running)"
    echo ""
    
    # Start monitoring loop
    CHECKS=0
    while true; do
        CHECKS=$((CHECKS + 1))
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Check #$CHECKS - Monitoring job $JOB_ID...${NC}"
        
        # Run auto-pull check
        PULL_OUTPUT=$(python3 hpc/infrastructure/job_tracker.py --auto-pull 2>&1)
        PULL_EXIT=$?
        
        echo "$PULL_OUTPUT"
        
        # Check if our job was pulled
        if echo "$PULL_OUTPUT" | grep -q "Successfully pulled results for $COMPUTATION_ID"; then
            echo ""
            echo -e "${GREEN}🎉 SUCCESS! Results automatically pulled for computation $COMPUTATION_ID${NC}"
            echo ""
            echo -e "${BLUE}📁 Your results are available at:${NC}"
            echo "  By date: hpc/results/by_date/$(date +%Y-%m-%d)/$COMPUTATION_ID"
            echo "  By function: hpc/results/by_function/$FUNCTION/"
            echo ""
            echo -e "${YELLOW}🔬 Next steps:${NC}"
            echo "  1. Explore the results: ls hpc/results/by_date/$(date +%Y-%m-%d)/$COMPUTATION_ID"
            echo "  2. Load into notebook: JSON3.read(read(\"path/to/output_results.json\", String), Dict)"
            echo "  3. Analyze detailed data: CSV.read(\"path/to/detailed_outputs/critical_points.csv\", DataFrame)"
            break
        fi
        
        # Check if job failed
        if echo "$PULL_OUTPUT" | grep -q "Job.*failed\|Job.*cancelled\|Job.*timeout"; then
            echo ""
            echo -e "${RED}❌ Job appears to have failed. Check logs for details.${NC}"
            echo "  Check logs: ssh scholten@falcon 'cat ~/globtim_hpc/slurm-$JOB_ID.out'"
            break
        fi
        
        echo "  ⏳ Job still running, will check again in ${PULL_INTERVAL} seconds..."
        echo ""
        sleep $PULL_INTERVAL
    done
else
    echo -e "${YELLOW}📋 Manual monitoring mode${NC}"
    echo "Your job is running. Use these commands to check progress:"
    echo ""
    echo "  # Check job status"
    echo "  python hpc/monitoring/python/slurm_monitor.py --analyze $JOB_ID"
    echo ""
    echo "  # Pull results when complete"
    echo "  python3 hpc/infrastructure/job_tracker.py --auto-pull"
    echo ""
    echo "  # Or pull specific computation"
    echo "  ./hpc/infrastructure/pull_results.sh --computation-id $COMPUTATION_ID"
fi
