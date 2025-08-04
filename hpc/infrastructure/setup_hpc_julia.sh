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
