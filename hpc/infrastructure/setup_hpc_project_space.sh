#!/bin/bash

# Setup HPC Project Space for Globtim
# Helps with requesting and configuring /projects space

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== HPC Project Space Setup for Globtim ===${NC}"

echo -e "${YELLOW}Based on the HPC documentation, you need to request a /projects space.${NC}"
echo ""
echo -e "${YELLOW}Email template for hpcsupport:${NC}"
echo "----------------------------------------"
echo "Subject: Project Space Request - Globtim Research"
echo ""
echo "Dear HPC Support Team,"
echo ""
echo "I would like to request a project space for my Globtim research project."
echo ""
echo "Project Details:"
echo "• Project Name: globtim"
echo "• Description: Global optimization and polynomial approximation research"
echo "• Estimated Size: 10-20 GB (Julia packages, data, results)"
echo "• Users: scholten (add others if needed)"
echo "• Timeframe: 12 months (adjust as needed)"
echo ""
echo "The project involves:"
echo "• Julia computational mathematics"
echo "• Benchmark function analysis"
echo "• Polynomial approximation algorithms"
echo "• Test data and results storage"
echo ""
echo "Thank you for your assistance."
echo ""
echo "Best regards,"
echo "Your Name"
echo "----------------------------------------"
echo ""

echo -e "${YELLOW}After you get the project space approved, run this script with --configure${NC}"

if [ "$1" = "--configure" ]; then
    echo -e "${YELLOW}Configuring HPC environment...${NC}"
    
    # Load configuration
    if [ -f "cluster_config.sh" ]; then
        source cluster_config.sh
    else
        echo -e "${RED}Error: cluster_config.sh not found${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Setting up directories on HPC cluster...${NC}"
    
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
        echo 'Setting up HPC directories...'
        
        # Check if /projects/globtim exists
        if [ -d '/projects/globtim' ]; then
            echo '✓ /projects/globtim already exists'
        else
            echo '✗ /projects/globtim does not exist yet'
            echo 'Please contact hpcsupport to create the project space first'
            exit 1
        fi
        
        # Create small config directory in home
        mkdir -p ${CLUSTER_HOME_PATH}
        echo '✓ Created config directory in home'
        
        # Check available space
        echo 'Available space:'
        df -h /projects/globtim 2>/dev/null || echo 'Project space not accessible'
        df -h ~ | head -2
        
        # Check for Julia
        echo 'Checking for Julia...'
        module avail julia 2>&1 | head -5 || echo 'No module system found'
        which julia || echo 'Julia not in PATH'
        
        echo 'HPC environment check completed'
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ HPC environment configured${NC}"
        echo -e "${YELLOW}You can now run: ./deploy_to_hpc.sh --setup${NC}"
    else
        echo -e "${RED}✗ Configuration failed. Check the output above.${NC}"
    fi
fi

echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Email hpcsupport with the project space request above"
echo "2. Wait for project space approval"
echo "3. Run: ./setup_hpc_project_space.sh --configure"
echo "4. Run: ./deploy_to_hpc.sh --setup"
