#!/bin/bash

# Install Julia on the fileserver/cluster
# This installs Julia in the user's home directory

set -e

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found."
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installing Julia on Cluster ===${NC}"

# Julia version to install (LTS version)
JULIA_VERSION="1.10.4"
JULIA_MAJOR="1.10"

echo -e "${YELLOW}Installing Julia ${JULIA_VERSION} on ${REMOTE_HOST}...${NC}"

# Create installation script to run on remote server
cat > /tmp/julia_install.sh << 'EOF'
#!/bin/bash

set -e

JULIA_VERSION="1.10.4"
JULIA_MAJOR="1.10"
JULIA_DIR="$HOME/julia"
JULIA_ARCHIVE="julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_MAJOR}/${JULIA_ARCHIVE}"

echo "Installing Julia ${JULIA_VERSION}..."

# Create julia directory
mkdir -p "$JULIA_DIR"
cd "$JULIA_DIR"

# Download Julia
echo "Downloading Julia..."
wget -q "$JULIA_URL" -O "$JULIA_ARCHIVE"

# Extract Julia
echo "Extracting Julia..."
tar -xzf "$JULIA_ARCHIVE" --strip-components=1

# Clean up archive
rm "$JULIA_ARCHIVE"

# Add Julia to PATH in .bashrc if not already there
if ! grep -q "julia/bin" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Julia installation" >> ~/.bashrc
    echo "export PATH=\"\$HOME/julia/bin:\$PATH\"" >> ~/.bashrc
    echo "Julia PATH added to .bashrc"
fi

# Test Julia installation
echo "Testing Julia installation..."
./bin/julia --version

echo "✓ Julia installation completed successfully!"
echo "✓ Julia binary location: $HOME/julia/bin/julia"
echo "✓ To use Julia in new sessions, run: source ~/.bashrc"
EOF

# Copy and run installation script on remote server
echo -e "${YELLOW}Copying installation script to server...${NC}"
scp -i "${SSH_KEY_PATH}" /tmp/julia_install.sh "${REMOTE_HOST}:~/julia_install.sh"

echo -e "${YELLOW}Running Julia installation on server...${NC}"
ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "chmod +x ~/julia_install.sh && ~/julia_install.sh"

# Clean up
rm /tmp/julia_install.sh
ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "rm ~/julia_install.sh"

# Test Julia installation
echo -e "${YELLOW}Testing Julia installation...${NC}"
ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "source ~/.bashrc && julia --version"

echo -e "${GREEN}✓ Julia installation completed!${NC}"
echo -e "${YELLOW}Now you can run: ./upload_to_cluster.sh --setup${NC}"
