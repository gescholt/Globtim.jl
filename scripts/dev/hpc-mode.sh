#!/bin/bash

# HPC Environment Activation Script  
# Usage: ./scripts/hpc-mode.sh

echo "🖥️  Starting Julia with HPC environment..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Start Julia with HPC environment
julia --project="$PROJECT_ROOT/environments/hpc" -e "
using Pkg
Pkg.instantiate()
println(\"✅ HPC environment ready!\")
println(\"💡 Minimal dependencies for maximum performance\")
println(\"💡 Use 'using Globtim' to load the package\")
"

# Start interactive Julia session
julia --project="$PROJECT_ROOT/environments/hpc"
