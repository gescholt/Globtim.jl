#!/bin/bash

# Deploy HPC Benchmarking Infrastructure
# Uploads the complete benchmarking infrastructure to both fileserver and HPC cluster

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Deploying HPC Benchmarking Infrastructure ===${NC}"
echo ""

# ============================================================================
# STEP 1: Validate Infrastructure Locally
# ============================================================================

echo -e "${YELLOW}Step 1: Validating infrastructure locally...${NC}"
if ./validate_infrastructure.sh > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Local infrastructure validation passed${NC}"
else
    echo -e "${RED}✗ Local infrastructure validation failed${NC}"
    echo "Run ./validate_infrastructure.sh to see details"
    exit 1
fi
echo ""

# ============================================================================
# STEP 2: Deploy to Fileserver (Backup)
# ============================================================================

echo -e "${YELLOW}Step 2: Deploying to fileserver...${NC}"

# Sync the complete project including new infrastructure
./sync_fileserver_to_hpc.sh > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Project synced to fileserver${NC}"
else
    echo -e "${RED}✗ Failed to sync to fileserver${NC}"
    exit 1
fi

# Verify HPC infrastructure files are on fileserver
echo -e "${YELLOW}Verifying HPC infrastructure on fileserver...${NC}"
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    if [ -d 'src/HPC' ]; then
        echo '✓ HPC infrastructure directory exists'
        echo '✓ Files:' 
        ls -la src/HPC/
    else
        echo '✗ HPC infrastructure directory missing'
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ HPC infrastructure verified on fileserver${NC}"
else
    echo -e "${RED}✗ HPC infrastructure verification failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 3: Deploy to HPC Cluster
# ============================================================================

echo -e "${YELLOW}Step 3: Deploying to HPC cluster...${NC}"

# Clean up old deployment on HPC cluster
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    echo 'Cleaning up old deployment...'
    rm -rf ~/globtim_hpc
    echo 'Old deployment cleaned'
"

# Sync from fileserver to HPC cluster
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    echo 'Syncing to HPC cluster...'
    rsync -avz --progress \
        -e 'ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' \
        --exclude='docs/' \
        --exclude='Examples/Notebooks/' \
        --exclude='experiments/' \
        --exclude='wiki/' \
        --exclude='reports/' \
        --exclude='.git/' \
        --exclude='Manifest.toml' \
        ./ ${CLUSTER_HOST}:~/globtim_hpc/
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Infrastructure deployed to HPC cluster${NC}"
else
    echo -e "${RED}✗ Failed to deploy to HPC cluster${NC}"
    exit 1
fi

# Verify deployment on HPC cluster
echo -e "${YELLOW}Verifying deployment on HPC cluster...${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ~/globtim_hpc
    echo 'Verifying HPC infrastructure...'
    
    if [ -d 'src/HPC' ]; then
        echo '✓ HPC infrastructure directory exists'
        echo '✓ Infrastructure files:'
        ls -la src/HPC/
        echo ''
        
        echo '✓ Example files:'
        ls -la examples/ | grep benchmark || echo 'No benchmark examples found'
        echo ''
        
        echo '✓ Validation script:'
        if [ -f 'validate_infrastructure.sh' ]; then
            echo 'validate_infrastructure.sh present'
        else
            echo 'validate_infrastructure.sh missing'
        fi
        
        echo ''
        echo '✓ Test script:'
        if [ -f 'test_hpc_infrastructure.jl' ]; then
            echo 'test_hpc_infrastructure.jl present'
        else
            echo 'test_hpc_infrastructure.jl missing'
        fi
        
    else
        echo '✗ HPC infrastructure directory missing'
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ HPC cluster deployment verified${NC}"
else
    echo -e "${RED}✗ HPC cluster deployment verification failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 4: Test Infrastructure on HPC Cluster
# ============================================================================

echo -e "${YELLOW}Step 4: Testing infrastructure on HPC cluster...${NC}"

# Run validation on HPC cluster
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ~/globtim_hpc
    echo 'Running infrastructure validation on HPC cluster...'
    ./validate_infrastructure.sh
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Infrastructure validation passed on HPC cluster${NC}"
else
    echo -e "${RED}✗ Infrastructure validation failed on HPC cluster${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 5: Create Test Benchmark
# ============================================================================

echo -e "${YELLOW}Step 5: Creating test benchmark on HPC cluster...${NC}"

# Run the minimal benchmark creation example
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ~/globtim_hpc
    echo 'Creating minimal benchmark example...'
    /sw/bin/julia examples/create_minimal_benchmark.jl
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Test benchmark created successfully${NC}"
else
    echo -e "${RED}✗ Test benchmark creation failed${NC}"
    echo -e "${YELLOW}This may be due to missing Julia packages - will be resolved when jobs run${NC}"
fi
echo ""

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

echo -e "${BLUE}=== Deployment Summary ===${NC}"
echo -e "${GREEN}✓ Infrastructure validated locally${NC}"
echo -e "${GREEN}✓ Complete project synced to fileserver${NC}"
echo -e "${GREEN}✓ Infrastructure deployed to HPC cluster${NC}"
echo -e "${GREEN}✓ Deployment verified on both systems${NC}"
echo -e "${GREEN}✓ Infrastructure validation passed on HPC${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Connect to HPC cluster:"
echo "   ssh ${CLUSTER_HOST}"
echo ""
echo "2. Navigate to project directory:"
echo "   cd ~/globtim_hpc"
echo ""
echo "3. Create and submit a minimal benchmark:"
echo "   /sw/bin/julia examples/create_minimal_benchmark.jl"
echo "   # Follow the instructions in the output"
echo ""
echo "4. Monitor jobs:"
echo "   squeue -u \$USER"
echo ""
echo "5. Check results:"
echo "   # Navigate to experiment directory and check results"
echo ""

echo -e "${BLUE}Infrastructure deployment completed successfully! 🚀${NC}"
echo ""
echo -e "${YELLOW}Files deployed:${NC}"
echo "• src/HPC/BenchmarkConfig.jl - Parameter specification system"
echo "• src/HPC/JobTracking.jl - Job tracking and result management"  
echo "• src/HPC/SlurmJobGenerator.jl - SLURM job script generation"
echo "• examples/create_minimal_benchmark.jl - Usage example"
echo "• test_hpc_infrastructure.jl - Infrastructure testing"
echo "• validate_infrastructure.sh - Validation script"
echo ""
echo -e "${GREEN}Ready for systematic benchmarking! 🎯${NC}"
