#!/bin/bash

# Test Enhanced Metrics Module on HPC Cluster (Issue #128)
# This script copies the test to the cluster and runs it

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing Enhanced Metrics on r04n02 Cluster ===${NC}"
echo

# Cluster configuration
CLUSTER_HOST="scholten@r04n02"
CLUSTER_DIR="globtimcore"
TEST_FILE="test/test_enhanced_metrics_cluster.jl"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo -e "${RED}Error: Test file not found: $TEST_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Pulling latest code on cluster via git...${NC}"
ssh "${CLUSTER_HOST}" "cd ${CLUSTER_DIR} && git reset --hard origin/main && git pull"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Code updated on cluster${NC}"
else
    echo -e "${RED}✗ Failed to update code${NC}"
    exit 1
fi

echo
echo -e "${YELLOW}Step 2: Resolving and instantiating packages on cluster...${NC}"
ssh "${CLUSTER_HOST}" "cd ${CLUSTER_DIR} && julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Packages ready${NC}"
else
    echo -e "${YELLOW}⚠ Package setup had issues (may be OK if packages already installed)${NC}"
fi

echo
echo -e "${YELLOW}Step 3: Running test on cluster...${NC}"
echo

# Run the test on the cluster
ssh "${CLUSTER_HOST}" "cd ${CLUSTER_DIR} && julia --project=. test/test_enhanced_metrics_cluster.jl"

TEST_EXIT_CODE=$?

echo
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}=== ✅ Cluster Test PASSED ===${NC}"
else
    echo -e "${RED}=== ❌ Cluster Test FAILED ===${NC}"
    exit 1
fi
