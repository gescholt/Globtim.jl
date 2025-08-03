#!/bin/bash

# Setup SSH key authentication for passwordless access
# Run this once to set up automatic authentication for both servers

FILESERVER_HOST="scholten@fileserver-ssh"
CLUSTER_HOST="scholten@falcon"

echo "Setting up SSH key authentication for both servers..."

# Check if SSH key already exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "globtim-hpc-access" -f ~/.ssh/id_ed25519 -N ""
else
    echo "SSH key already exists"
fi

# Function to setup SSH for a host
setup_ssh_for_host() {
    local HOST=$1
    local NAME=$2

    echo ""
    echo "Setting up SSH for ${NAME} (${HOST})..."
    echo "You'll need to enter your password for ${NAME}:"

    # Copy public key to remote server
    ssh-copy-id -i ~/.ssh/id_ed25519.pub "${HOST}"

    # Test the connection
    echo "Testing passwordless connection to ${NAME}..."
    if ssh -o BatchMode=yes "${HOST}" "echo 'SSH key authentication successful for ${NAME}!'" 2>/dev/null; then
        echo "✓ SSH key authentication is working for ${NAME}!"
        return 0
    else
        echo "✗ SSH key authentication failed for ${NAME}. You may need to try again."
        return 1
    fi
}

# Setup SSH for both servers
setup_ssh_for_host "${FILESERVER_HOST}" "fileserver"
setup_ssh_for_host "${CLUSTER_HOST}" "HPC cluster"

echo ""
echo "✓ SSH setup completed for both servers!"
echo "You can now run scripts without entering passwords"
