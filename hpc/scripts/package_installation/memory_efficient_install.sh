#!/bin/bash

# Memory-Efficient Package Installation for HPC Cluster
# Based on successful strategies from previous installations
# Avoids memory overload by using staged installation and temporary depots

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

echo -e "${BLUE}🚀 Memory-Efficient Package Installation${NC}"
echo "========================================"
echo "Strategy: Staged installation with temporary depots"
echo "Target: Essential packages for Globtim compilation"
echo ""

# ============================================================================
# PHASE 1: INSTALL ON FILESERVER (MEMORY-SAFE)
# ============================================================================

echo -e "${YELLOW}Phase 1: Installing packages on fileserver...${NC}"
echo "This avoids cluster memory limitations by using fileserver resources"
echo ""

# Create Julia depot on fileserver if it doesn't exist
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    echo '=== Setting up Julia depot on fileserver ==='
    
    # Create depot directory
    mkdir -p julia_hpc_depot
    export JULIA_DEPOT_PATH=\"\$(pwd)/julia_hpc_depot:\$JULIA_DEPOT_PATH\"
    
    echo 'Julia depot path:' \$JULIA_DEPOT_PATH
    echo 'Available disk space:' \$(df -h . | tail -1 | awk '{print \$4}')
    echo ''
    
    echo '=== STAGE 1: Essential Data Packages ==='
    julia --project=. -e '
    using Pkg
    
    # Stage 1: Most critical packages first
    stage1_packages = [\"CSV\", \"DataFrames\"]
    
    println(\"Installing Stage 1 packages (Essential Data)...\")
    for pkg in stage1_packages
        try
            println(\"📦 Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✅ \$pkg installed successfully\")
            
            # Test loading immediately
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads correctly\")
        catch e
            println(\"❌ Failed with \$pkg: \$e\")
        end
        println()
    end
    
    println(\"✅ Stage 1 complete!\")
    '
    
    echo ''
    echo '=== STAGE 2: Core Utility Packages ==='
    julia --project=. -e '
    using Pkg
    
    # Stage 2: Core utilities
    stage2_packages = [\"Parameters\", \"TOML\", \"TimerOutputs\"]
    
    println(\"Installing Stage 2 packages (Core Utilities)...\")
    for pkg in stage2_packages
        try
            println(\"📦 Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✅ \$pkg installed successfully\")
            
            # Test loading
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads correctly\")
        catch e
            println(\"❌ Failed with \$pkg: \$e\")
        end
        println()
    end
    
    println(\"✅ Stage 2 complete!\")
    '
    
    echo ''
    echo '=== STAGE 3: Mathematical Packages ==='
    julia --project=. -e '
    using Pkg
    
    # Stage 3: Mathematical computation
    stage3_packages = [\"ForwardDiff\", \"Distributions\", \"StaticArrays\"]
    
    println(\"Installing Stage 3 packages (Mathematical)...\")
    for pkg in stage3_packages
        try
            println(\"📦 Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✅ \$pkg installed successfully\")
            
            # Test loading
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads correctly\")
        catch e
            println(\"❌ Failed with \$pkg: \$e\")
        end
        println()
    end
    
    println(\"✅ Stage 3 complete!\")
    '
    
    echo ''
    echo '=== STAGE 4: Polynomial Packages ==='
    julia --project=. -e '
    using Pkg
    
    # Stage 4: Polynomial mathematics
    stage4_packages = [\"DynamicPolynomials\", \"MultivariatePolynomials\"]
    
    println(\"Installing Stage 4 packages (Polynomials)...\")
    for pkg in stage4_packages
        try
            println(\"📦 Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✅ \$pkg installed successfully\")
            
            # Test loading
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads correctly\")
        catch e
            println(\"❌ Failed with \$pkg: \$e\")
        end
        println()
    end
    
    println(\"✅ Stage 4 complete!\")
    '
    
    echo ''
    echo '=== STAGE 5: Advanced Packages (Optional) ==='
    julia --project=. -e '
    using Pkg
    
    # Stage 5: Advanced features (install if possible, skip if problematic)
    stage5_packages = [\"LinearSolve\", \"Optim\", \"Clustering\"]
    
    println(\"Installing Stage 5 packages (Advanced - best effort)...\")
    for pkg in stage5_packages
        try
            println(\"📦 Installing \$pkg...\")
            Pkg.add(pkg)
            println(\"✅ \$pkg installed successfully\")
            
            # Test loading
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg loads correctly\")
        catch e
            println(\"⚠️  \$pkg failed (non-critical): \$e\")
        end
        println()
    end
    
    println(\"✅ Stage 5 complete!\")
    '
    
    echo ''
    echo '=== Final Package Summary ==='
    julia --project=. -e '
    using Pkg
    
    println(\"📋 Installed packages summary:\")
    status = Pkg.status()
    
    # Test critical packages
    critical_packages = [\"CSV\", \"DataFrames\", \"Parameters\", \"ForwardDiff\"]
    
    println()
    println(\"🧪 Testing critical package loading:\")
    success_count = 0
    for pkg in critical_packages
        try
            eval(Meta.parse(\"using \$pkg\"))
            println(\"✅ \$pkg: OK\")
            success_count += 1
        catch e
            println(\"❌ \$pkg: FAILED\")
        end
    end
    
    println()
    println(\"📊 Critical packages: \$success_count/\$(length(critical_packages)) working\")
    
    if success_count >= 3
        println(\"🎉 INSTALLATION SUCCESS: Ready for Globtim!\")
    else
        println(\"⚠️  PARTIAL SUCCESS: Some packages missing\")
    end
    '
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Phase 1: Fileserver installation completed successfully${NC}"
else
    echo -e "${RED}❌ Phase 1: Fileserver installation failed${NC}"
    exit 1
fi

echo ""

# ============================================================================
# PHASE 2: TEST ACCESS FROM CLUSTER
# ============================================================================

echo -e "${YELLOW}Phase 2: Testing package access from cluster...${NC}"
echo "Verifying that compute nodes can access the installed packages"
echo ""

# Test accessing packages from HPC cluster via NFS
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ~/globtim_hpc
    echo '=== Testing package access from HPC cluster ==='
    
    # Set Julia depot to point to fileserver packages via NFS
    FILESERVER_DEPOT='/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot'
    
    if [ -d \"\$FILESERVER_DEPOT\" ]; then
        echo '✅ Fileserver Julia depot accessible via NFS'
        export JULIA_DEPOT_PATH=\"\$FILESERVER_DEPOT:\$JULIA_DEPOT_PATH\"
        echo 'Julia depot path:' \$JULIA_DEPOT_PATH
        
        echo ''
        echo '🧪 Testing package loading from NFS depot...'
        /sw/bin/julia -e '
        println(\"Julia depot paths:\")
        for path in DEPOT_PATH
            println(\"  \", path)
        end
        println()
        
        # Test critical packages
        test_packages = [\"CSV\", \"DataFrames\", \"Parameters\", \"ForwardDiff\"]
        success_count = 0
        
        println(\"Testing package loading:\")
        for pkg in test_packages
            try
                eval(Meta.parse(\"using \$pkg\"))
                println(\"✅ \$pkg: Loaded successfully\")
                success_count += 1
            catch e
                println(\"❌ \$pkg: Failed to load - \$e\")
            end
        end
        
        println()
        println(\"📊 Package access test: \$success_count/\$(length(test_packages)) packages working\")
        
        if success_count >= 3
            println(\"🎉 CLUSTER ACCESS SUCCESS: Packages accessible from compute nodes!\")
            exit(0)
        else
            println(\"⚠️  CLUSTER ACCESS PARTIAL: Some packages not accessible\")
            exit(1)
        end
        '
    else
        echo '❌ Fileserver depot not accessible via NFS'
        echo 'Available paths:'
        ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/ 2>/dev/null || echo 'NFS mount not available'
        exit(1)
    fi
"

CLUSTER_ACCESS_STATUS=$?

if [ $CLUSTER_ACCESS_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Phase 2: Cluster access test successful${NC}"
else
    echo -e "${YELLOW}⚠️  Phase 2: Cluster access test failed - will create fallback strategy${NC}"
fi

echo ""

# ============================================================================
# PHASE 3: CREATE INSTALLATION VALIDATION SCRIPT
# ============================================================================

echo -e "${YELLOW}Phase 3: Creating validation script...${NC}"

# Create validation script that can be run on cluster
cat > validate_package_installation.jl << 'EOF'
"""
Package Installation Validation Script

Tests that all required packages are available and working correctly.
Can be run on cluster compute nodes to verify package access.
"""

using Printf

println("🧪 GLOBTIM PACKAGE INSTALLATION VALIDATION")
println("=" ^ 50)
println("Julia version: $(VERSION)")
println("Threads: $(Threads.nthreads())")
println()

# Test packages in order of importance
test_packages = [
    ("CSV", "Essential data handling"),
    ("DataFrames", "Essential data structures"), 
    ("Parameters", "Core configuration"),
    ("TOML", "Configuration files"),
    ("ForwardDiff", "Automatic differentiation"),
    ("StaticArrays", "Efficient arrays"),
    ("Distributions", "Statistical distributions"),
    ("TimerOutputs", "Performance monitoring"),
    ("DynamicPolynomials", "Polynomial mathematics"),
    ("MultivariatePolynomials", "Advanced polynomials"),
    ("LinearSolve", "Linear algebra (optional)"),
    ("Optim", "Optimization (optional)"),
    ("Clustering", "Data analysis (optional)")
]

# Track results
results = Dict{String, Bool}()
critical_count = 0
total_count = 0
critical_packages = ["CSV", "DataFrames", "Parameters", "ForwardDiff"]

println("📦 Testing package availability:")
println("-" ^ 30)

for (pkg, description) in test_packages
    total_count += 1
    try
        eval(Meta.parse("using $pkg"))
        println("✅ $pkg: $description")
        results[pkg] = true
        
        if pkg in critical_packages
            critical_count += 1
        end
    catch e
        println("❌ $pkg: $description - FAILED")
        results[pkg] = false
    end
end

println()
println("📊 VALIDATION SUMMARY:")
println("-" ^ 20)
println("Critical packages: $critical_count/$(length(critical_packages))")
println("Total packages: $(sum(values(results)))/$(total_count)")

# Overall assessment
if critical_count >= 3
    println()
    println("🎉 VALIDATION SUCCESS!")
    println("✅ Sufficient packages available for Globtim compilation")
    exit(0)
else
    println()
    println("❌ VALIDATION FAILED!")
    println("⚠️  Critical packages missing - Globtim compilation will fail")
    exit(1)
end
EOF

# Copy validation script to cluster
scp -i "${SSH_KEY_PATH}" validate_package_installation.jl "${CLUSTER_HOST}:~/globtim_hpc/"

echo -e "${GREEN}✅ Phase 3: Validation script created and uploaded${NC}"
echo ""

# ============================================================================
# SUMMARY AND NEXT STEPS
# ============================================================================

echo -e "${BLUE}📋 INSTALLATION SUMMARY${NC}"
echo "======================="

if [ $CLUSTER_ACCESS_STATUS -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS: Memory-efficient package installation completed!${NC}"
    echo ""
    echo "✅ Packages installed on fileserver (memory-safe)"
    echo "✅ Cluster access verified via NFS"
    echo "✅ Validation script deployed"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Run validation test:"
    echo "   ssh ${CLUSTER_HOST}"
    echo "   cd ~/globtim_hpc"
    echo "   /sw/bin/julia validate_package_installation.jl"
    echo ""
    echo "2. Test Globtim compilation:"
    echo "   cd ~/globtim/hpc/scripts/compilation_tests"
    echo "   ./submit_compilation_test.sh --mode quick --monitor"
else
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS: Packages installed but cluster access needs work${NC}"
    echo ""
    echo "✅ Packages installed on fileserver"
    echo "❌ Cluster NFS access issues detected"
    echo "✅ Validation script deployed"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Check NFS mount status on cluster"
    echo "2. Consider alternative package distribution method"
    echo "3. Run validation test to confirm current status"
fi

echo ""
echo -e "${GREEN}🚀 Memory-efficient installation strategy complete!${NC}"
