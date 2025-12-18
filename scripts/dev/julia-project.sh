#!/bin/bash

# Julia Project Environment Helper
# This script ensures you always use the correct project environment

# Usage:
#   ./scripts/julia-project.sh                    # Start interactive Julia with project
#   ./scripts/julia-project.sh script.jl          # Run a script with project
#   ./scripts/julia-project.sh -e "using Globtim" # Execute code with project

echo "🔧 Starting Julia with Globtim project environment..."

# Check if we're in the right directory
if [ ! -f "Project.toml" ]; then
    echo "❌ Error: Project.toml not found. Please run this script from the Globtim root directory."
    exit 1
fi

# Show project info
echo "📁 Project: $(pwd)"
echo "🎯 Environment: Project-specific"
echo ""

# Run Julia with project environment
julia --project=. "$@"
