#!/bin/bash

# Validate Package Access on HPC Cluster
# Tests if packages installed on fileserver are accessible from compute nodes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 PACKAGE ACCESS VALIDATION${NC}"
echo "=============================="
echo "Testing package accessibility from HPC compute nodes"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load cluster configuration
if [[ -f "$REPO_ROOT/hpc/config/cluster_config.sh" ]]; then
    source "$REPO_ROOT/hpc/config/cluster_config.sh"
    echo -e "${GREEN}✓ Loaded cluster configuration${NC}"
else
    echo -e "${RED}❌ No cluster configuration found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Phase 1: Testing NFS depot access from compute node...${NC}"

# Test NFS access from compute node
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" 'srun --partition=batch --time=5:00 --ntasks=1 --pty bash -c "
    echo \"=== Testing NFS Depot Access ===\"
    echo \"Node: \$(hostname)\"
    echo \"User: \$(whoami)\"
    echo \"\"
    
    FILESERVER_DEPOT=\"/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot\"
    
    if [ -d \"\$FILESERVER_DEPOT\" ]; then
        echo \"✅ NFS depot directory exists\"
        echo \"Contents:\"
        ls -la \"\$FILESERVER_DEPOT\" | head -10
        echo \"\"
        
        # Test package directory access
        if [ -d \"\$FILESERVER_DEPOT/packages\" ]; then
            echo \"✅ Packages directory accessible\"
            echo \"Package count: \$(ls \$FILESERVER_DEPOT/packages | wc -l)\"
            echo \"Sample packages:\"
            ls \"\$FILESERVER_DEPOT/packages\" | head -5
        else
            echo \"❌ Packages directory not accessible\"
        fi
    else
        echo \"❌ NFS depot directory not accessible\"
        echo \"Available NFS mounts:\"
        ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/ 2>/dev/null || echo \"No NFS access\"
    fi
    
    echo \"\"
    echo \"=== Testing Julia Package Loading ===\"
    export JULIA_DEPOT_PATH=\"\$FILESERVER_DEPOT:\$JULIA_DEPOT_PATH\"
    
    /sw/bin/julia -e \"
    println(\\\"Julia depot paths:\\\")
    for path in DEPOT_PATH
        println(\\\"  \\\", path)
    end
    println()
    
    # Test critical packages
    test_packages = [\\\"CSV\\\", \\\"DataFrames\\\", \\\"Parameters\\\", \\\"ForwardDiff\\\", \\\"TOML\\\"]
    working = 0
    
    for pkg in test_packages
        try
            eval(Meta.parse(\\\"using \$pkg\\\"))
            println(\\\"✅ \$pkg: Available\\\")
            working += 1
        catch e
            println(\\\"❌ \$pkg: Not available - \$e\\\")
        end
    end
    
    println()
    println(\\\"📊 Package access: \$working/\$(length(test_packages)) packages available\\\")
    
    if working >= 3
        println(\\\"🎉 PACKAGE ACCESS SUCCESS\\\")
        exit(0)
    else
        println(\\\"❌ PACKAGE ACCESS FAILED\\\")
        exit(1)
    end
    \"
"'

NFS_TEST_STATUS=$?

echo ""
if [ $NFS_TEST_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Phase 1: NFS depot access successful${NC}"
else
    echo -e "${YELLOW}⚠️  Phase 1: NFS depot access failed - trying alternatives${NC}"
    
    echo ""
    echo -e "${YELLOW}Phase 2: Testing alternative package locations...${NC}"
    
    # Test alternative locations
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" 'srun --partition=batch --time=5:00 --ntasks=1 --pty bash -c "
        echo \"=== Testing Alternative Package Locations ===\"
        
        # Test home directory depot
        HOME_DEPOT=\"\$HOME/julia_cluster_depot\"
        if [ -d \"\$HOME_DEPOT\" ]; then
            echo \"✅ Home depot exists: \$HOME_DEPOT\"
            export JULIA_DEPOT_PATH=\"\$HOME_DEPOT:\$JULIA_DEPOT_PATH\"
        else
            echo \"❌ Home depot not found: \$HOME_DEPOT\"
        fi
        
        # Test project-local packages
        cd \$HOME/globtim_hpc
        if [ -f \"Project.toml\" ]; then
            echo \"✅ Project.toml found\"
            /sw/bin/julia --project=. -e \"
            using Pkg
            println(\\\"Project status:\\\")
            Pkg.status()
            
            println()
            println(\\\"Testing package loading:\\\")
            test_packages = [\\\"CSV\\\", \\\"DataFrames\\\", \\\"Parameters\\\"]
            working = 0
            
            for pkg in test_packages
                try
                    eval(Meta.parse(\\\"using \$pkg\\\"))
                    println(\\\"✅ \$pkg: Available\\\")
                    working += 1
                catch e
                    println(\\\"❌ \$pkg: Not available\\\")
                end
            end
            
            println()
            if working >= 2
                println(\\\"🎉 ALTERNATIVE ACCESS SUCCESS\\\")
                exit(0)
            else
                println(\\\"❌ ALTERNATIVE ACCESS FAILED\\\")
                exit(1)
            end
            \"
        else
            echo \"❌ No Project.toml found\"
            exit(1)
        fi
    "'
    
    ALT_TEST_STATUS=$?
    
    if [ $ALT_TEST_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Phase 2: Alternative package access successful${NC}"
    else
        echo -e "${RED}❌ Phase 2: Alternative package access failed${NC}"
    fi
fi

echo ""
echo -e "${BLUE}📋 VALIDATION SUMMARY${NC}"
echo "===================="

if [ $NFS_TEST_STATUS -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS: Packages accessible via NFS depot${NC}"
    echo ""
    echo "✅ NFS depot accessible from compute nodes"
    echo "✅ Packages can be loaded during job execution"
    echo "✅ Ready for Globtim compilation testing"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Run Globtim compilation test:"
    echo "   ./submit_compilation_test.sh --mode standard --monitor"
    echo ""
    echo "2. Test specific Globtim functionality:"
    echo "   ./validate_globtim_modules.sh"
    
elif [ $ALT_TEST_STATUS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS: Packages accessible via alternative method${NC}"
    echo ""
    echo "✅ Packages available through project environment"
    echo "❌ NFS depot not accessible from compute nodes"
    echo "⚠️  May need to install packages locally on cluster"
    echo ""
    echo -e "${YELLOW}Recommended Actions:${NC}"
    echo "1. Install packages directly on cluster:"
    echo "   ssh ${CLUSTER_HOST} 'cd ~/globtim_hpc && julia --project=. -e \"using Pkg; Pkg.add([\\\"CSV\\\", \\\"DataFrames\\\", \\\"Parameters\\\", \\\"ForwardDiff\\\"])\"'"
    echo ""
    echo "2. Test compilation after package installation"
    
else
    echo -e "${RED}❌ FAILURE: Packages not accessible from compute nodes${NC}"
    echo ""
    echo "❌ NFS depot not accessible"
    echo "❌ Alternative package locations not working"
    echo "❌ Packages need to be installed on cluster"
    echo ""
    echo -e "${YELLOW}Required Actions:${NC}"
    echo "1. Install packages on cluster:"
    echo "   ssh ${CLUSTER_HOST} 'cd ~/globtim_hpc && julia --project=. -e \"using Pkg; Pkg.add([\\\"CSV\\\", \\\"DataFrames\\\", \\\"Parameters\\\", \\\"ForwardDiff\\\", \\\"StaticArrays\\\", \\\"Distributions\\\"])\"'"
    echo ""
    echo "2. Or fix NFS access to fileserver depot"
    echo "3. Re-run this validation test"
fi

echo ""
echo -e "${GREEN}🚀 Package access validation complete!${NC}"
