#!/bin/bash
# Setup script for fresh clone of globtimcore repository
# Run this once after cloning to install configuration protection

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "🔧 Setting up globtimcore repository configuration protection..."
echo ""

# Create the git hooks
echo "📝 Installing git hooks..."
EXPECTED_REMOTE="git@git.mpi-cbg.de:globaloptim/globtimcore.git"

for hook in post-checkout post-merge post-rewrite; do
    cat > .git/hooks/$hook << EOF
#!/bin/bash
# Git hook to prevent remote URL from being changed
# This ensures the remote always points to: git@git.mpi-cbg.de:globaloptim/globtimcore.git

EXPECTED_REMOTE="$EXPECTED_REMOTE"
CURRENT_REMOTE=\$(git config --get remote.origin.url)

if [ "\$CURRENT_REMOTE" != "\$EXPECTED_REMOTE" ]; then
    echo "⚠️  WARNING: Remote URL has changed!"
    echo "   Expected: \$EXPECTED_REMOTE"
    echo "   Current:  \$CURRENT_REMOTE"
    echo "   Fixing remote URL..."
    git config remote.origin.url "\$EXPECTED_REMOTE"
    echo "✅ Remote URL restored to correct value"
fi
EOF
    chmod +x .git/hooks/$hook
    echo "   ✅ Installed $hook"
done
echo ""

# Set the remote URL if it's not already correct
echo "🔗 Verifying remote URL..."
CURRENT_REMOTE=$(git config --get remote.origin.url)
if [ "$CURRENT_REMOTE" = "$EXPECTED_REMOTE" ]; then
    echo "   ✅ Remote URL is already correct"
else
    echo "   ⚠️  Fixing remote URL..."
    git config remote.origin.url "$EXPECTED_REMOTE"
    echo "   ✅ Remote URL set to: $EXPECTED_REMOTE"
fi
echo ""

# Remove glab-resolved cache if present
echo "🧹 Cleaning glab cache..."
if git config --get remote.origin.glab-resolved >/dev/null 2>&1; then
    git config --unset remote.origin.glab-resolved
    echo "   ✅ Removed glab-resolved cache"
else
    echo "   ✅ No cache to remove"
fi
echo ""

# Set default branch
echo "🌿 Setting default branch..."
if git remote set-head origin main 2>/dev/null; then
    echo "   ✅ Default branch set to 'main'"
else
    echo "   ⚠️  Could not set default branch (may need to fetch first)"
fi
echo ""

# Run validation
echo "✅ Setup complete! Running validation..."
echo ""
./scripts/validate_git_config.sh
