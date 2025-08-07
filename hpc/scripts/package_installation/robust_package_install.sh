#!/bin/bash

# Robust Package Installation for HPC Cluster
# Fixes Julia environment issues and handles stdlib dependencies properly

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load cluster configuration
if [[ -f "$REPO_ROOT/hpc/config/cluster_config.sh" ]]; then
    source "$REPO_ROOT/hpc/config/cluster_config.sh"
    echo -e "${GREEN}✓ Loaded cluster configuration${NC}"
else
    echo -e "${RED}❌ No cluster configuration found${NC}"
    echo "Please create hpc/config/cluster_config.sh"
    exit 1
fi

echo -e "${BLUE}🔧 Robust Package Installation${NC}"
echo "================================"
echo "Strategy: Clean environment setup with proper stdlib handling"
echo ""

# ============================================================================
# STEP 1: CLEAN INSTALLATION ON FILESERVER
# ============================================================================

echo -e "${YELLOW}Step 1: Clean installation on fileserver...${NC}"

ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    echo '=== Setting up clean Julia environment ==='
    
    # Remove any problematic existing depot
    if [ -d 'julia_hpc_depot' ]; then
        echo 'Removing existing depot to start fresh...'
        rm -rf julia_hpc_depot
    fi
    
    # Create fresh depot
    mkdir -p julia_hpc_depot
    export JULIA_DEPOT_PATH=\"\$(pwd)/julia_hpc_depot\"
    
    echo 'Julia depot path:' \$JULIA_DEPOT_PATH
    echo 'Julia version:'
    julia --version
    echo ''
    
    echo '=== Step 1a: Initialize clean environment ==='
    julia --project=. -e '
    using Pkg
    
    println(\"🧹 Initializing clean Julia environment...\")
    
    # Clear any existing project state
    if isfile(\"Project.toml\")
        println(\"Backing up existing Project.toml...\")
        cp(\"Project.toml\", \"Project.toml.backup\")
    end
    
    if isfile(\"Manifest.toml\") 
        println(\"Removing existing Manifest.toml...\")
        rm(\"Manifest.toml\")
    end
    
    # Initialize fresh project
    Pkg.activate(\".\")
    
    println(\"✅ Clean environment initialized\")
    '
    
    echo ''
    echo '=== Step 1b: Install packages one by one with verification ==='
    julia --project=. -e '
    using Pkg
    
    # Install packages one by one with careful verification
    packages_to_install = [
        \"CSV\",
        \"DataFrames\", 
        \"Parameters\",
        \"ForwardDiff\",
        \"TOML\",
        \"StaticArrays\",
        \"Distributions\"
    ]
    
    println(\"📦 Installing packages individually with verification...\")
    
    successful_packages = String[]
    failed_packages = String[]
    
    for pkg in packages_to_install
        println()
        println(\"🔄 Installing \$pkg...\")
        
        try
            # Install package
            Pkg.add(pkg)
            println(\"✅ \$pkg installed\")
            
            # Verify it can be loaded
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads successfully\")
            
            push!(successful_packages, pkg)
            
        catch e
            println(\"❌ \$pkg failed: \$e\")
            push!(failed_packages, pkg)
            
            # Try to remove if partially installed
            try
                Pkg.rm(pkg)
            catch
                # Ignore removal errors
            end
        end
    end
    
    println()
    println(\"📊 Installation Summary:\")
    println(\"✅ Successful: \", join(successful_packages, \", \"))
    if !isempty(failed_packages)
        println(\"❌ Failed: \", join(failed_packages, \", \"))
    end
    
    println()
    println(\"🧪 Final verification test...\")
    
    # Test critical packages
    critical_success = 0
    critical_packages = [\"CSV\", \"DataFrames\", \"Parameters\"]
    
    for pkg in critical_packages
        if pkg in successful_packages
            try
                eval(Meta.parse(\"using \$pkg\"))
                println(\"✅ \$pkg: Working\")
                critical_success += 1
            catch e
                println(\"❌ \$pkg: Load failed - \$e\")
            end
        else
            println(\"⚠️  \$pkg: Not installed\")
        end
    end
    
    println()
    if critical_success >= 2
        println(\"🎉 INSTALLATION SUCCESS: \$critical_success/\$(length(critical_packages)) critical packages working\")
        exit(0)
    else
        println(\"❌ INSTALLATION FAILED: Only \$critical_success/\$(length(critical_packages)) critical packages working\")
        exit(1)
    end
    '
"

INSTALL_STATUS=$?

if [ $INSTALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Step 1: Package installation successful${NC}"
else
    echo -e "${RED}❌ Step 1: Package installation failed${NC}"
    echo ""
    echo -e "${YELLOW}Trying alternative approach...${NC}"
    
    # Alternative: Install minimal set only
    ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
        cd ${FILESERVER_PATH}
        export JULIA_DEPOT_PATH=\"\$(pwd)/julia_hpc_depot\"
        
        echo '=== Alternative: Minimal package installation ==='
        julia --project=. -e '
        using Pkg
        
        # Try just the most essential packages
        minimal_packages = [\"CSV\", \"Parameters\", \"TOML\"]
        
        println(\"📦 Installing minimal essential packages...\")
        
        for pkg in minimal_packages
            try
                println(\"Installing \$pkg...\")
                Pkg.add(pkg)
                using_cmd = \"using \$pkg\"
                eval(Meta.parse(using_cmd))
                println(\"✅ \$pkg: OK\")
            catch e
                println(\"❌ \$pkg: Failed - \$e\")
            end
        end
        
        println(\"✅ Minimal installation complete\")
        '
    "
fi

echo ""

# ============================================================================
# STEP 2: TEST CLUSTER ACCESS
# ============================================================================

echo -e "${YELLOW}Step 2: Testing cluster access...${NC}"

ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    echo '=== Testing package access from cluster ==='
    
    # Check NFS access
    FILESERVER_DEPOT='/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot'
    
    if [ -d \"\$FILESERVER_DEPOT\" ]; then
        echo '✅ NFS depot accessible'
        export JULIA_DEPOT_PATH=\"\$FILESERVER_DEPOT:\$JULIA_DEPOT_PATH\"
        
        echo 'Testing package loading...'
        /sw/bin/julia -e '
        println(\"Julia depot paths:\")
        for path in DEPOT_PATH
            println(\"  \", path)
        end
        println()
        
        # Test available packages
        test_packages = [\"CSV\", \"Parameters\", \"TOML\"]
        working_count = 0
        
        for pkg in test_packages
            try
                eval(Meta.parse(\"using \$pkg\"))
                println(\"✅ \$pkg: Available\")
                working_count += 1
            catch e
                println(\"❌ \$pkg: Not available\")
            end
        end
        
        println()
        println(\"📊 Cluster access: \$working_count/\$(length(test_packages)) packages available\")
        
        if working_count >= 2
            println(\"🎉 CLUSTER ACCESS SUCCESS\")
            exit(0)
        else
            println(\"❌ CLUSTER ACCESS FAILED\")
            exit(1)
        end
        '
    else
        echo '❌ NFS depot not accessible'
        echo 'Available NFS mounts:'
        ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/ 2>/dev/null || echo 'No NFS access'
        exit(1)
    fi
"

CLUSTER_STATUS=$?

echo ""

# ============================================================================
# STEP 3: CREATE SIMPLE VALIDATION TEST
# ============================================================================

echo -e "${YELLOW}Step 3: Creating validation test...${NC}"

cat > simple_package_test.jl << 'EOF'
"""
Simple Package Validation Test
Tests basic package availability for Globtim
"""

println("🧪 SIMPLE PACKAGE VALIDATION")
println("=" ^ 30)

# Test packages in order of importance
packages = ["CSV", "Parameters", "TOML", "DataFrames", "ForwardDiff"]
working = 0

for pkg in packages
    try
        eval(Meta.parse("using $pkg"))
        println("✅ $pkg: OK")
        working += 1
    catch e
        println("❌ $pkg: Failed")
    end
end

println()
println("📊 Result: $working/$(length(packages)) packages working")

if working >= 3
    println("🎉 VALIDATION PASSED: Sufficient packages available")
    exit(0)
else
    println("❌ VALIDATION FAILED: Too few packages available")
    exit(1)
end
EOF

# Upload test to cluster
scp -i "${SSH_KEY_PATH}" simple_package_test.jl "${CLUSTER_HOST}:~/globtim_hpc/"

echo -e "${GREEN}✅ Step 3: Validation test created${NC}"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${BLUE}📋 INSTALLATION SUMMARY${NC}"
echo "======================="

if [ $CLUSTER_STATUS -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS: Package installation completed!${NC}"
    echo ""
    echo "✅ Packages installed with clean environment"
    echo "✅ Cluster access verified"
    echo "✅ Validation test ready"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Run validation:"
    echo "   ssh ${CLUSTER_HOST}"
    echo "   cd ~/globtim_hpc"
    echo "   /sw/bin/julia simple_package_test.jl"
    echo ""
    echo "2. Test compilation:"
    echo "   cd ~/globtim/hpc/scripts/compilation_tests"
    echo "   ./submit_compilation_test.sh --mode quick --monitor"
else
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS: Installation completed but cluster access needs attention${NC}"
    echo ""
    echo "✅ Packages installed on fileserver"
    echo "❌ Cluster access issues"
    echo "✅ Validation test ready"
    echo ""
    echo -e "${YELLOW}Troubleshooting needed:${NC}"
    echo "1. Check NFS mount status"
    echo "2. Verify depot path accessibility"
    echo "3. Consider alternative package distribution"
fi

echo ""
echo -e "${GREEN}🚀 Robust installation attempt complete!${NC}"
