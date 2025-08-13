#!/bin/bash
# Test SSH connection using the same configuration as Julia bundling workflow
# This verifies that the SSH key authentication is working correctly

set -e

# SSH Configuration (matching existing Julia bundling workflow)
SSH_KEY="$HOME/.ssh/id_ed25519"
FILESERVER_HOST="scholten@mack"
CLUSTER_HOST="scholten@falcon"
SSH_OPTIONS="-i ${SSH_KEY} -o StrictHostKeyChecking=no"

echo "=========================================="
echo "SSH Connection Test"
echo "=========================================="
echo "SSH key: $SSH_KEY"
echo "Fileserver: $FILESERVER_HOST"
echo "Cluster: $CLUSTER_HOST"
echo "Started: $(date)"
echo ""

# Check SSH key exists
echo "=== Step 1: SSH Key Check ==="
if [[ -f "$SSH_KEY" ]]; then
    echo "✅ SSH key found: $SSH_KEY"
    
    # Check key permissions
    KEY_PERMS=$(stat -f "%A" "$SSH_KEY" 2>/dev/null || stat -c "%a" "$SSH_KEY" 2>/dev/null)
    if [[ "$KEY_PERMS" == "600" ]]; then
        echo "✅ SSH key has correct permissions (600)"
    else
        echo "⚠️  SSH key has permissions: $KEY_PERMS (should be 600)"
        echo "   Fixing permissions..."
        chmod 600 "$SSH_KEY"
        echo "✅ SSH key permissions fixed"
    fi
else
    echo "❌ SSH key not found: $SSH_KEY"
    echo ""
    echo "To generate SSH key:"
    echo "   ssh-keygen -t ed25519 -C 'globtim-hpc-access' -f ~/.ssh/id_ed25519"
    echo ""
    echo "Then copy public key to servers:"
    echo "   ssh-copy-id -i ~/.ssh/id_ed25519.pub scholten@mack"
    echo "   ssh-copy-id -i ~/.ssh/id_ed25519.pub scholten@falcon"
    exit 1
fi

echo ""

# Test connection to fileserver
echo "=== Step 2: Fileserver Connection Test ==="
echo "Testing connection to: $FILESERVER_HOST"
echo "Command: ssh $SSH_OPTIONS $FILESERVER_HOST 'echo \"Connection successful\"'"

if ssh $SSH_OPTIONS $FILESERVER_HOST 'echo "Connection successful"' 2>/dev/null; then
    echo "✅ Fileserver connection successful"
    
    # Test basic commands
    echo "Testing basic commands on fileserver..."
    FILESERVER_INFO=$(ssh $SSH_OPTIONS $FILESERVER_HOST 'hostname && whoami && pwd && date')
    echo "Fileserver info:"
    echo "$FILESERVER_INFO" | sed 's/^/   /'
    
else
    echo "❌ Fileserver connection failed"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if SSH key is added to fileserver:"
    echo "   ssh-copy-id -i ~/.ssh/id_ed25519.pub scholten@mack"
    echo ""
    echo "2. Test manual connection:"
    echo "   ssh -i ~/.ssh/id_ed25519 scholten@mack"
    echo ""
    echo "3. Check network connectivity:"
    echo "   ping mack"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ SSH Connection Test Complete"
echo "=========================================="
echo "SSH connection to fileserver is working."
echo "You can now run the Python dependency tests:"
echo "   ./run_phase1_test.sh"
echo ""
echo "Completed: $(date)"
