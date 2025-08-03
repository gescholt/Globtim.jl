#!/bin/bash

# Secure SSH Configuration Setup
# Run this once to harden your SSH configuration

SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_DIR="$HOME/.ssh"

echo "Setting up secure SSH configuration..."

# Ensure SSH directory exists with correct permissions
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Create or update SSH config with security hardening
cat >> "$SSH_CONFIG_FILE" << 'EOF'

# Globtim Fileserver Configuration
Host fileserver-ssh
    HostName fileserver-ssh
    User scholten
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    # Security hardening
    Protocol 2
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    # Disable less secure authentication methods
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    # Connection multiplexing for efficiency
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

# Globtim HPC Cluster Configuration
Host falcon
    HostName falcon
    User scholten
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    # Security hardening
    Protocol 2
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    # Disable less secure authentication methods
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    # Connection multiplexing for efficiency
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

EOF

# Create socket directory for connection multiplexing
mkdir -p "$SSH_DIR/sockets"
chmod 700 "$SSH_DIR/sockets"

# Set correct permissions on SSH config
chmod 600 "$SSH_CONFIG_FILE"

# Set correct permissions on SSH keys if they exist
if [ -f "$SSH_DIR/id_ed25519" ]; then
    chmod 600 "$SSH_DIR/id_ed25519"
fi
if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
    chmod 644 "$SSH_DIR/id_ed25519.pub"
fi

echo "✓ SSH configuration hardened"
echo "✓ Connection multiplexing enabled for faster subsequent connections"
echo "✓ Password authentication disabled (key-only access)"
