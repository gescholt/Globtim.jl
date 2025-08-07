#!/bin/bash

# JSON-Tracked Results Pull Script
# Integrates with existing HPC infrastructure to pull JSON-tracked computation results

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
DAYS_BACK=7
FORCE_OVERWRITE=false
COMPUTATION_ID=""
CLUSTER_HOST="scholten@falcon"
CLUSTER_PATH="~/globtim_hpc"
LOCAL_PATH="hpc/results"

# Load cluster configuration if available
CONFIG_FILE="hpc/config/cluster_config.sh"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${BLUE}Loading cluster configuration from $CONFIG_FILE${NC}"
    source "$CONFIG_FILE"
    
    # Use configuration values if available
    if [ -n "$CLUSTER_HOST" ]; then
        CLUSTER_HOST="$CLUSTER_HOST"
    fi
    if [ -n "$REMOTE_HOST" ]; then
        CLUSTER_HOST="$REMOTE_HOST"
    fi
fi

# Function to show usage
show_usage() {
    echo "JSON-Tracked Results Pull Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --days DAYS        Number of days back to search (default: 7)"
    echo "  -c, --computation-id ID Pull specific computation by ID"
    echo "  -f, --force            Force overwrite existing local results"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Pull all results from last 7 days"
    echo "  $0 -d 14               # Pull results from last 14 days"
    echo "  $0 -c abc12345         # Pull specific computation"
    echo "  $0 -f -d 3             # Force pull results from last 3 days"
    echo ""
    echo "Integration with existing infrastructure:"
    echo "  • Uses cluster_config.sh if available"
    echo "  • Builds on existing HPC monitoring tools"
    echo "  • Maintains JSON tracking directory structure"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--days)
            DAYS_BACK="$2"
            shift 2
            ;;
        -c|--computation-id)
            COMPUTATION_ID="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_OVERWRITE=true
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

# Check if Python script exists
PYTHON_SCRIPT="hpc/infrastructure/pull_json_results.py"
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}Error: Python script not found: $PYTHON_SCRIPT${NC}"
    exit 1
fi

# Build Python command
PYTHON_CMD="python3 $PYTHON_SCRIPT"
PYTHON_CMD="$PYTHON_CMD --cluster-host $CLUSTER_HOST"
PYTHON_CMD="$PYTHON_CMD --cluster-path $CLUSTER_PATH"
PYTHON_CMD="$PYTHON_CMD --local-path $LOCAL_PATH"

if [ -n "$COMPUTATION_ID" ]; then
    PYTHON_CMD="$PYTHON_CMD --computation-id $COMPUTATION_ID"
else
    PYTHON_CMD="$PYTHON_CMD --days $DAYS_BACK"
fi

if [ "$FORCE_OVERWRITE" = true ]; then
    PYTHON_CMD="$PYTHON_CMD --force"
fi

# Show what we're about to do
echo -e "${BLUE}=== JSON-Tracked Results Pull ===${NC}"
echo "Cluster: $CLUSTER_HOST"
echo "Remote path: $CLUSTER_PATH"
echo "Local path: $LOCAL_PATH"

if [ -n "$COMPUTATION_ID" ]; then
    echo "Target: Specific computation $COMPUTATION_ID"
else
    echo "Target: Results from last $DAYS_BACK days"
fi

if [ "$FORCE_OVERWRITE" = true ]; then
    echo "Mode: Force overwrite existing results"
fi

echo ""

# Test SSH connection first
echo -e "${YELLOW}Testing SSH connection to cluster...${NC}"
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$CLUSTER_HOST" "echo 'Connection successful'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "Please check:"
    echo "  • SSH keys are properly configured"
    echo "  • Cluster host is reachable: $CLUSTER_HOST"
    echo "  • VPN connection if required"
    exit 1
fi

# Check if remote directory exists
echo -e "${YELLOW}Checking remote Globtim directory...${NC}"
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$CLUSTER_HOST" "test -d $CLUSTER_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Remote directory found: $CLUSTER_PATH${NC}"
else
    echo -e "${RED}✗ Remote directory not found: $CLUSTER_PATH${NC}"
    echo "Please ensure Globtim is deployed to the cluster"
    exit 1
fi

# Run the Python script
echo -e "${YELLOW}Starting results pull...${NC}"
echo "Command: $PYTHON_CMD"
echo ""

if eval "$PYTHON_CMD"; then
    echo ""
    echo -e "${GREEN}✓ Results pull completed successfully${NC}"
    
    # Show quick access information
    if [ -d "$LOCAL_PATH" ]; then
        echo ""
        echo -e "${BLUE}📁 Quick Access:${NC}"
        echo "  All results: $LOCAL_PATH"
        
        if [ -d "$LOCAL_PATH/by_date" ]; then
            echo "  By date: $LOCAL_PATH/by_date/"
            # Show recent dates
            recent_dates=$(ls "$LOCAL_PATH/by_date/" 2>/dev/null | tail -3 | tr '\n' ' ')
            if [ -n "$recent_dates" ]; then
                echo "    Recent: $recent_dates"
            fi
        fi
        
        if [ -d "$LOCAL_PATH/by_function" ]; then
            echo "  By function: $LOCAL_PATH/by_function/"
            # Show available functions
            functions=$(ls "$LOCAL_PATH/by_function/" 2>/dev/null | tr '\n' ' ')
            if [ -n "$functions" ]; then
                echo "    Functions: $functions"
            fi
        fi
        
        if [ -d "$LOCAL_PATH/by_tag" ]; then
            echo "  By tags: $LOCAL_PATH/by_tag/"
            # Show available tags
            tags=$(ls "$LOCAL_PATH/by_tag/" 2>/dev/null | head -5 | tr '\n' ' ')
            if [ -n "$tags" ]; then
                echo "    Tags: $tags"
            fi
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  • Explore results in your preferred directory structure"
    echo "  • Load JSON files into notebooks for analysis"
    echo "  • Use CSV files for detailed data examination"
    
else
    echo ""
    echo -e "${RED}✗ Results pull failed${NC}"
    echo "Check the error messages above for details"
    exit 1
fi
