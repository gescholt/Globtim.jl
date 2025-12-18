#!/bin/bash
#
# Setup npm for documentation enhancements
#
# This script initializes npm in the docs directory and installs
# useful tools for documentation building and optimization
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up npm for documentation tools...${NC}"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    echo "Please install Node.js and npm first:"
    echo "  - macOS: brew install node"
    echo "  - Ubuntu: sudo apt install nodejs npm"
    echo "  - Or visit: https://nodejs.org/"
    exit 1
fi

# Navigate to docs directory
cd docs || { echo -e "${RED}Error: docs directory not found${NC}"; exit 1; }

# Check if package.json already exists
if [ -f "package.json" ]; then
    echo -e "${YELLOW}package.json already exists. Updating dependencies...${NC}"
    npm install
else
    echo -e "${GREEN}Initializing npm in docs directory...${NC}"
    
    # Copy example package.json
    if [ -f "package.json.example" ]; then
        cp package.json.example package.json
        echo -e "${GREEN}Created package.json from example${NC}"
    else
        # Initialize with basic config
        npm init -y
        
        # Install useful documentation tools
        echo -e "${GREEN}Installing documentation tools...${NC}"
        
        # Development tools
        npm install --save-dev \
            prettier \
            eslint \
            terser \
            clean-css-cli \
            http-server
        
        # Optional: visualization libraries
        read -p "Install visualization libraries (d3, plotly)? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            npm install --save \
                d3 \
                plotly.js-dist
        fi
    fi
    
    # Install dependencies
    npm install
fi

# Create .gitignore for node_modules if it doesn't exist
if ! grep -q "node_modules" ../.gitignore 2>/dev/null; then
    echo -e "\n# Node.js dependencies\ndocs/node_modules/\ndocs/package-lock.json" >> ../.gitignore
    echo -e "${GREEN}Added node_modules to .gitignore${NC}"
fi

# Create example scripts directory
mkdir -p scripts

# Create example visualization script
cat > scripts/example-plot.js << 'EOF'
// Example: Generate interactive plot for polynomial approximation
const fs = require('fs');
const d3 = require('d3');

console.log('This is an example script for generating interactive visualizations');
console.log('You can extend this to create D3.js visualizations from Julia data');
EOF

echo -e "${GREEN}✅ npm setup complete!${NC}"
echo -e "\nAvailable npm scripts (run from docs directory):"
echo -e "  ${YELLOW}npm run build${NC}      - Optimize documentation assets"
echo -e "  ${YELLOW}npm run lint${NC}       - Lint JavaScript files"
echo -e "  ${YELLOW}npm run format:md${NC}  - Format Markdown files"
echo -e "  ${YELLOW}npm run serve${NC}      - Serve docs locally"
echo -e "\nTo add to CI/CD, see: ${YELLOW}.gitlab-ci.yml.npm-example${NC}"