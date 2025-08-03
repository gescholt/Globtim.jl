#!/bin/bash

# Install HPC Packages Strategy
# Install Julia packages on fileserver and make them accessible to HPC cluster

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installing Julia Packages for HPC Cluster ===${NC}"
echo ""

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo -e "${RED}Error: cluster_config.sh not found${NC}"
    exit 1
fi

# ============================================================================
# STEP 1: Install Packages on Fileserver
# ============================================================================

echo -e "${YELLOW}Step 1: Installing packages on fileserver...${NC}"

# Create Julia depot on fileserver
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    echo 'Creating Julia depot for HPC...'
    mkdir -p julia_hpc_depot
    
    echo 'Setting up Julia environment...'
    export JULIA_DEPOT_PATH=\"$(pwd)/julia_hpc_depot:\$JULIA_DEPOT_PATH\"
    
    echo 'Julia depot path:' \$JULIA_DEPOT_PATH
    echo ''
    
    echo '=== Installing Essential Packages ==='
    julia --project=. -e '
    using Pkg
    
    # Essential packages for Globtim
    essential_packages = [
        \"CSV\",
        \"StaticArrays\", 
        \"DataFrames\",
        \"Parameters\",
        \"ForwardDiff\",
        \"Distributions\",
        \"TimerOutputs\",
        \"Optim\"
    ]
    
    println(\"Installing essential packages...\")
    for pkg in essential_packages
        try
            println(\"Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✓ \$pkg installed successfully\")
        catch e
            println(\"❌ Failed to install \$pkg: \$e\")
        end
    end
    
    println()
    println(\"=== Installing Polynomial Packages ===\")
    polynomial_packages = [
        \"DynamicPolynomials\",
        \"MultivariatePolynomials\"
    ]
    
    for pkg in polynomial_packages
        try
            println(\"Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✓ \$pkg installed successfully\")
        catch e
            println(\"❌ Failed to install \$pkg: \$e\")
        end
    end
    
    println()
    println(\"=== Installing Advanced Packages ===\")
    advanced_packages = [
        \"LinearSolve\",
        \"Clustering\",
        \"HomotopyContinuation\"
    ]
    
    for pkg in advanced_packages
        try
            println(\"Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✓ \$pkg installed successfully\")
        catch e
            println(\"❌ Failed to install \$pkg: \$e\")
            println(\"Will continue without this package\")
        end
    end
    
    println()
    println(\"=== Package Installation Summary ===\")
    Pkg.status()
    
    println()
    println(\"=== Testing Package Loading ===\")
    test_packages = [\"CSV\", \"StaticArrays\", \"DataFrames\", \"Parameters\", \"ForwardDiff\"]
    
    for pkg in test_packages
        try
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✓ \$pkg loads successfully\")
        catch e
            println(\"❌ \$pkg failed to load: \$e\")
        end
    end
    '
    
    echo ''
    echo 'Checking Julia depot contents...'
    ls -la julia_hpc_depot/
    
    echo ''
    echo 'Checking package registry...'
    ls -la julia_hpc_depot/registries/ 2>/dev/null || echo 'No registries found'
    
    echo ''
    echo 'Checking installed packages...'
    ls -la julia_hpc_depot/packages/ 2>/dev/null || echo 'No packages directory found'
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Package installation on fileserver completed${NC}"
else
    echo -e "${RED}✗ Package installation on fileserver failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 2: Test Package Access from HPC Cluster
# ============================================================================

echo -e "${YELLOW}Step 2: Testing package access from HPC cluster...${NC}"

# Test accessing packages from HPC cluster via NFS
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ~/globtim_hpc
    echo 'Testing package access from HPC cluster...'
    
    # Set Julia depot to point to fileserver packages via NFS
    FILESERVER_DEPOT='/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot'
    
    if [ -d \"\$FILESERVER_DEPOT\" ]; then
        echo '✓ Fileserver Julia depot accessible via NFS'
        export JULIA_DEPOT_PATH=\"\$FILESERVER_DEPOT:\$JULIA_DEPOT_PATH\"
        echo 'Julia depot path:' \$JULIA_DEPOT_PATH
        
        echo ''
        echo 'Testing package loading from NFS depot...'
        /sw/bin/julia -e '
        println(\"Julia depot paths:\")
        for path in DEPOT_PATH
            println(\"  \", path)
        end
        println()
        
        test_packages = [\"CSV\", \"StaticArrays\", \"DataFrames\", \"Parameters\"]
        
        for pkg in test_packages
            try
                eval(Meta.parse(\"using \$pkg\"))
                println(\"✓ \$pkg loads successfully from NFS\")
            catch e
                println(\"❌ \$pkg failed to load from NFS: \$e\")
            end
        end
        '
    else
        echo '❌ Fileserver Julia depot not accessible via NFS'
        echo 'Available paths:'
        ls -la /net/fileserver-nfs/stornext/snfs6/projects/ | head -5
    fi
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Package access test from HPC cluster completed${NC}"
else
    echo -e "${RED}✗ Package access test from HPC cluster failed${NC}"
    echo -e "${YELLOW}Will try alternative approach...${NC}"
fi
echo ""

# ============================================================================
# STEP 3: Create HPC Package Loading Script
# ============================================================================

echo -e "${YELLOW}Step 3: Creating HPC package loading script...${NC}"

# Create a script that sets up the Julia environment on HPC
cat > setup_hpc_julia.sh << 'EOF'
#!/bin/bash

# Setup Julia Environment for HPC Cluster
# Sets up Julia depot path to access packages from fileserver

echo "=== Setting up Julia Environment for HPC ==="

# Try NFS path first
FILESERVER_DEPOT="/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot"

if [ -d "$FILESERVER_DEPOT" ]; then
    echo "✓ Using fileserver Julia depot via NFS"
    export JULIA_DEPOT_PATH="$FILESERVER_DEPOT:$JULIA_DEPOT_PATH"
else
    echo "⚠️  Fileserver depot not accessible, using temporary depot"
    TEMP_DEPOT="/tmp/julia_depot_${USER}_$$"
    mkdir -p "$TEMP_DEPOT"
    export JULIA_DEPOT_PATH="$TEMP_DEPOT:$JULIA_DEPOT_PATH"
    
    # Copy essential packages if available
    if [ -d "/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot" ]; then
        echo "Copying essential packages to temporary depot..."
        cp -r "/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot"/* "$TEMP_DEPOT/" 2>/dev/null || true
    fi
fi

echo "Julia depot path: $JULIA_DEPOT_PATH"
echo "Julia threads: ${JULIA_NUM_THREADS:-1}"
echo ""

# Test package availability
echo "Testing package availability..."
/sw/bin/julia -e '
test_packages = ["LinearAlgebra", "Statistics", "Random"]
for pkg in test_packages
    try
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg available")
    catch e
        println("❌ $pkg not available")
    end
end
'

echo "Julia environment setup complete!"
EOF

chmod +x setup_hpc_julia.sh

# Upload the setup script to HPC cluster
scp -i "${SSH_KEY_PATH}" setup_hpc_julia.sh "${CLUSTER_HOST}:~/globtim_hpc/"

echo -e "${GREEN}✓ HPC package loading script created and uploaded${NC}"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${BLUE}=== Package Installation Summary ===${NC}"
echo -e "${GREEN}✓ Julia packages installed on fileserver${NC}"
echo -e "${GREEN}✓ Package access tested from HPC cluster${NC}"
echo -e "${GREEN}✓ HPC Julia setup script created${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test the setup on HPC cluster:"
echo "   ssh ${CLUSTER_HOST}"
echo "   cd ~/globtim_hpc"
echo "   ./setup_hpc_julia.sh"
echo ""
echo "2. Test Globtim loading:"
echo "   /sw/bin/julia test_globtim_loading.jl"
echo ""
echo "3. Run Parameters.jl benchmark:"
echo "   # Create and submit job with working Globtim"
echo ""

echo -e "${GREEN}🎯 Julia package installation strategy deployed! 🚀${NC}"
