#!/bin/bash
#
# Julia code formatting script using JuliaFormatter.jl
#
# Usage:
#   ./scripts/format-julia.sh          # Format all Julia files
#   ./scripts/format-julia.sh --check  # Check formatting without modifying
#   ./scripts/format-julia.sh FILE     # Format specific file
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CHECK_ONLY=false
SPECIFIC_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [FILE]"
            echo ""
            echo "Options:"
            echo "  --check    Check formatting without modifying files"
            echo "  --help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Format all Julia files"
            echo "  $0 --check            # Check formatting only"
            echo "  $0 src/MyFile.jl      # Format specific file"
            exit 0
            ;;
        *)
            SPECIFIC_FILE="$1"
            shift
            ;;
    esac
done

# Check if Julia is available
if ! command -v julia &> /dev/null; then
    echo -e "${RED}Error: Julia is not installed or not in PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Setting up JuliaFormatter...${NC}"

# Create temporary Julia script for formatting
JULIA_SCRIPT=$(mktemp /tmp/julia_formatter_XXXXXX.jl)
trap "rm -f $JULIA_SCRIPT" EXIT

cat > "$JULIA_SCRIPT" << 'EOF'
using Pkg

# Install JuliaFormatter if not already installed
if !haskey(Pkg.project().dependencies, "JuliaFormatter")
    println("Installing JuliaFormatter...")
    Pkg.add("JuliaFormatter")
end

using JuliaFormatter

# Get command line arguments
check_only = "--check" in ARGS
specific_file = ""
for arg in ARGS
    if arg != "--check" && !startswith(arg, "--")
        specific_file = arg
        break
    end
end

# Determine what to format
if !isempty(specific_file)
    targets = [specific_file]
    println("Formatting file: $specific_file")
else
    targets = ["."]
    println("Formatting all Julia files in the project...")
end

# Run formatter
success = true
for target in targets
    if check_only
        if !JuliaFormatter.format(target; verbose=true, overwrite=false)
            success = false
            println("\n❌ Formatting issues found in: $target")
        end
    else
        JuliaFormatter.format(target; verbose=true)
        println("✅ Formatted: $target")
    end
end

# Exit with appropriate code
if check_only && !success
    println("\n❌ Formatting check failed! Run without --check to fix.")
    exit(1)
elseif check_only
    println("\n✅ All files are properly formatted!")
end
EOF

# Build Julia command
JULIA_ARGS="--project=@. $JULIA_SCRIPT"
if [ "$CHECK_ONLY" = true ]; then
    JULIA_ARGS="$JULIA_ARGS --check"
fi
if [ -n "$SPECIFIC_FILE" ]; then
    JULIA_ARGS="$JULIA_ARGS \"$SPECIFIC_FILE\""
fi

# Run Julia formatter
echo -e "${GREEN}Running JuliaFormatter...${NC}"
if eval "julia $JULIA_ARGS"; then
    if [ "$CHECK_ONLY" = true ]; then
        echo -e "${GREEN}✅ Formatting check passed!${NC}"
    else
        echo -e "${GREEN}✅ Formatting complete!${NC}"
    fi
    exit 0
else
    if [ "$CHECK_ONLY" = true ]; then
        echo -e "${RED}❌ Formatting check failed!${NC}"
        echo -e "${YELLOW}Run '$0' without --check to fix formatting issues.${NC}"
    else
        echo -e "${RED}❌ Formatting failed!${NC}"
    fi
    exit 1
fi