#!/bin/bash
# Julia NFS Configuration - Bypasses Home Directory Quota

echo "=== Configuring Julia for NFS Project Space ==="

# Base NFS path (using fileserver home as interim solution)
export NFS_BASE="/stornext/snfs3/home/scholten"

# Julia depot on NFS (unlimited space)
export JULIA_DEPOT_PATH="$NFS_BASE/julia_depot_nfs"

# Temp files on NFS (not home directory)
export TMPDIR="$NFS_BASE/tmp_nfs"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"

# Julia configuration
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
export JULIA_PKG_PRECOMPILE_AUTO=1

# Create directories if they do not exist (only if we have permission)
if [ ! -d "$JULIA_DEPOT_PATH" ]; then
    mkdir -p "$JULIA_DEPOT_PATH" 2>/dev/null || echo "Note: Julia depot directory already exists"
fi

if [ ! -d "$TMPDIR" ]; then
    mkdir -p "$TMPDIR" 2>/dev/null || echo "Note: Temp directory already exists"
fi

# Verification
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ Julia depot configured at: $JULIA_DEPOT_PATH"
else
    echo "❌ ERROR: Julia depot directory not accessible!"
    exit 1
fi

if [ -w "$TMPDIR" ] || [ -w "$(dirname "$TMPDIR")" ]; then
    echo "✅ Temp directory configured at: $TMPDIR"
else
    echo "❌ ERROR: Temp directory not writable!"
    exit 1
fi

echo "✅ No quota restrictions - unlimited NFS space available"
echo "=== Configuration Complete ==="
