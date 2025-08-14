#!/bin/bash
# Local script to submit and monitor Phase 1 Python dependency test
# Part of systematic Python dependency management strategy for GlobTim HPC

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HPC_TESTING_DIR="$(dirname "$SCRIPT_DIR")"
HPC_DIR="$(dirname "$HPC_TESTING_DIR")"

# SSH Configuration (matching existing Julia bundling workflow)
SSH_KEY="$HOME/.ssh/id_ed25519"
FILESERVER_HOST="scholten@mack"
CLUSTER_HOST="scholten@falcon"
SSH_OPTIONS="-i ${SSH_KEY} -o StrictHostKeyChecking=no"

echo "=========================================="
echo "Phase 1 Python Dependency Test Runner"
echo "=========================================="
echo "Script directory: $SCRIPT_DIR"
echo "HPC testing directory: $HPC_TESTING_DIR"
echo "HPC directory: $HPC_DIR"
echo "SSH key: $SSH_KEY"
echo "Fileserver: $FILESERVER_HOST"
echo "Cluster: $CLUSTER_HOST"
echo ""

# Check if we're on the right system
if [[ ! -d "/Users/ghscholt/globtim" ]]; then
    echo "❌ This script should be run from the local development machine"
    echo "   Current directory: $(pwd)"
    exit 1
fi

# Check SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ SSH key not found: $SSH_KEY"
    echo "   Please ensure SSH key is set up for HPC access"
    echo "   You can generate one with: ssh-keygen -t ed25519 -C 'globtim-hpc-access'"
    exit 1
fi

# Test SSH connection to fileserver
echo "=== SSH Connection Test ==="
echo "Testing connection to fileserver..."
if ssh $SSH_OPTIONS $FILESERVER_HOST "echo 'SSH connection successful'" >/dev/null 2>&1; then
    echo "✅ SSH connection to fileserver working"
else
    echo "❌ SSH connection to fileserver failed"
    echo "   Host: $FILESERVER_HOST"
    echo "   Key: $SSH_KEY"
    echo "   Please check SSH key setup and network connectivity"
    exit 1
fi

# Ensure we're in the right directory
cd "$SCRIPT_DIR"

echo "=== Step 1: Prepare files for transfer ==="
echo "Creating deployment package..."

# Create a temporary directory for deployment
DEPLOY_DIR="phase1_deploy_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DEPLOY_DIR"

# Copy necessary files
cp phase1_direct_install_test.slurm "$DEPLOY_DIR/"
cp ../requirements.txt "$DEPLOY_DIR/" 2>/dev/null || echo "No requirements.txt found, creating minimal one..."

# Create minimal requirements.txt if it doesn't exist
if [[ ! -f "$DEPLOY_DIR/requirements.txt" ]]; then
    cat > "$DEPLOY_DIR/requirements.txt" << 'EOF'
# Minimal Python dependencies for GlobTim HPC testing
PyYAML>=6.0
EOF
fi

# Copy deployment script template
cp deploy_phase1_template.sh "$DEPLOY_DIR/deploy_and_run.sh"

chmod +x "$DEPLOY_DIR/deploy_and_run.sh"

echo "✅ Deployment package created: $DEPLOY_DIR"
echo ""

echo "=== Step 2: Transfer to fileserver ==="
echo "Transferring files to fileserver (mack)..."

# Transfer to fileserver
if command -v scp >/dev/null 2>&1; then
    echo "Using scp to transfer files..."
    if scp $SSH_OPTIONS -r "$DEPLOY_DIR" $FILESERVER_HOST:~/; then
        echo "✅ Files transferred to fileserver"
    else
        echo "❌ Failed to transfer files to fileserver"
        echo "   Command: scp $SSH_OPTIONS -r $DEPLOY_DIR $FILESERVER_HOST:~/"
        exit 1
    fi
else
    echo "❌ scp not available. Please manually transfer the following directory:"
    echo "   Local: $SCRIPT_DIR/$DEPLOY_DIR"
    echo "   Remote: $FILESERVER_HOST:~/$DEPLOY_DIR"
    echo ""
    echo "Then run on fileserver:"
    echo "   ssh $SSH_OPTIONS $FILESERVER_HOST"
    echo "   cd ~/$DEPLOY_DIR"
    echo "   ./deploy_and_run.sh"
    exit 1
fi

echo ""
echo "=== Step 3: Execute on fileserver ==="
echo "Connecting to fileserver to run deployment..."

# Execute on fileserver
if ssh $SSH_OPTIONS $FILESERVER_HOST "cd ~/$DEPLOY_DIR && ./deploy_and_run.sh"; then
    echo "✅ Phase 1 test execution completed"
else
    echo "❌ Phase 1 test execution failed"
    echo "   Command: ssh $SSH_OPTIONS $FILESERVER_HOST 'cd ~/$DEPLOY_DIR && ./deploy_and_run.sh'"
    exit 1
fi

echo ""
echo "=== Phase 1 Test Complete ==="
echo "Check the output above to determine if Phase 1 succeeded or if Phase 2 is needed."
