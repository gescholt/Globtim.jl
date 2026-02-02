#!/bin/bash
# Globtim.jl Push Helper Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to show usage
usage() {
    echo "Usage: ./push.sh [gitlab|github]"
    echo ""
    echo "Options:"
    echo "  gitlab    Push main branch to GitLab (private development)"
    echo "  github    Push github-release branch to GitHub (public release)"
    echo ""
    echo "Examples:"
    echo "  ./push.sh gitlab    # Push current work to GitLab"
    echo "  ./push.sh github    # Push public release to GitHub"
}

# Check if argument provided
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

case "$1" in
    gitlab)
        echo -e "${GREEN}Pushing to GitLab (private development)...${NC}"
        if [ "$CURRENT_BRANCH" != "main" ]; then
            echo -e "${YELLOW}Warning: You're not on main branch. Current branch: $CURRENT_BRANCH${NC}"
            read -p "Do you want to continue? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        git push origin main
        ;;

    github)
        echo -e "${GREEN}Pushing to GitHub (public release)...${NC}"
        if [ "$CURRENT_BRANCH" != "github-release" ]; then
            echo -e "${RED}ERROR: You must be on github-release branch to push to GitHub${NC}"
            echo -e "${YELLOW}Current branch: $CURRENT_BRANCH${NC}"
            echo ""
            echo "To switch to github-release branch:"
            echo "  git checkout github-release"
            exit 1
        fi

        # Check for private files that shouldn't be in public release
        if [ -f "Examples/Notebooks/AnisotropicGridComparison.ipynb" ]; then
            echo -e "${RED}ERROR: Private file detected in github-release branch!${NC}"
            echo "  Examples/Notebooks/AnisotropicGridComparison.ipynb"
            echo ""
            echo "This file should not exist in the public release."
            echo "Please remove it before pushing to GitHub."
            exit 1
        fi

        git push github github-release
        ;;

    *)
        echo -e "${RED}Invalid option: $1${NC}"
        usage
        exit 1
        ;;
esac
