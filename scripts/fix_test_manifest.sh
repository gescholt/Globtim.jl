#!/bin/bash

# Shell script to fix Julia test manifest inconsistencies
# This removes the test/Manifest.toml and ensures tests use parent manifest

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/test"
TEST_MANIFEST="$TEST_DIR/Manifest.toml"

echo "Fixing Julia test manifest inconsistencies..."

# Remove test manifest if it exists
if [ -f "$TEST_MANIFEST" ]; then
    echo "  Removing test/Manifest.toml..."
    rm "$TEST_MANIFEST"
fi

# Run Julia to properly set up the test environment
echo "  Setting up test environment..."
cd "$PROJECT_ROOT"
julia --project=. -e '
    using Pkg
    Pkg.activate("test")
    Pkg.develop(PackageSpec(path=pwd()))
    Pkg.resolve()
    Pkg.instantiate()
'

echo "✓ Test manifest issues resolved!"
echo "  The test environment now uses the parent project's dependencies."
