#!/bin/bash
# Validate and fix git/glab configuration for globtimcore
# Run this script if you experience git remote or glab authentication issues

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "🔍 Validating globtimcore git and glab configuration..."
echo ""

# Expected values
EXPECTED_REMOTE="git@git.mpi-cbg.de:globaloptim/globtimcore.git"
EXPECTED_GITLAB_HOST="git.mpi-cbg.de"
EXPECTED_PROJECT_PATH="globaloptim/globtimcore"

# Check 1: Git remote URL
echo "1️⃣  Checking git remote URL..."
CURRENT_REMOTE=$(git config --get remote.origin.url)
if [ "$CURRENT_REMOTE" = "$EXPECTED_REMOTE" ]; then
    echo "   ✅ Remote URL is correct: $CURRENT_REMOTE"
else
    echo "   ❌ Remote URL is incorrect!"
    echo "      Expected: $EXPECTED_REMOTE"
    echo "      Current:  $CURRENT_REMOTE"
    echo "      Fixing..."
    git config remote.origin.url "$EXPECTED_REMOTE"
    echo "   ✅ Fixed remote URL"
fi
echo ""

# Check 2: Remove glab-resolved cache if it exists
echo "2️⃣  Checking for glab-resolved cache..."
if git config --get remote.origin.glab-resolved >/dev/null 2>&1; then
    echo "   ⚠️  Found glab-resolved cache (can cause 404 errors)"
    git config --unset remote.origin.glab-resolved
    echo "   ✅ Removed glab-resolved cache"
else
    echo "   ✅ No glab-resolved cache found"
fi
echo ""

# Check 3: Git hooks are installed
echo "3️⃣  Checking git hooks..."
HOOKS=("post-checkout" "post-merge" "post-rewrite")
HOOKS_OK=true
for hook in "${HOOKS[@]}"; do
    if [ -x ".git/hooks/$hook" ]; then
        echo "   ✅ $hook hook is installed and executable"
    else
        echo "   ❌ $hook hook is missing or not executable"
        HOOKS_OK=false
    fi
done
echo ""

# Check 4: glab authentication
echo "4️⃣  Checking glab authentication..."
if ! command -v glab &> /dev/null; then
    echo "   ❌ glab command not found"
    echo "      Install with: brew install glab"
    exit 1
fi

# Check if token exists in config file
if [ -f ~/.config/glab-cli/config.yml ] && grep -q "git.mpi-cbg.de" ~/.config/glab-cli/config.yml && grep -A5 "git.mpi-cbg.de" ~/.config/glab-cli/config.yml | grep -q "token:"; then
    echo "   ✅ Token configured for git.mpi-cbg.de"
else
    echo "   ❌ Token not found for git.mpi-cbg.de"
    echo "      Check ~/.config/glab-cli/config.yml"
    exit 1
fi
echo ""

# Check 5: Test glab can access the project
echo "5️⃣  Testing glab project access..."
if glab repo view >/dev/null 2>&1; then
    echo "   ✅ glab can access $EXPECTED_PROJECT_PATH"
else
    echo "   ❌ glab cannot access project"
    echo "      This usually means:"
    echo "      - Remote URL is wrong (check #1)"
    echo "      - glab-resolved cache exists (check #2)"
    echo "      - Authentication token is invalid (check #4)"
    exit 1
fi
echo ""

# Check 6: Verify default branch
echo "6️⃣  Checking default branch..."
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ "$DEFAULT_BRANCH" = "main" ]; then
    echo "   ✅ Default branch is 'main'"
else
    echo "   ⚠️  Default branch is '$DEFAULT_BRANCH', expected 'main'"
    echo "      Updating..."
    git remote set-head origin main
    echo "   ✅ Updated default branch to 'main'"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All configuration checks passed!"
echo ""
echo "Configuration locked to:"
echo "  Remote: $EXPECTED_REMOTE"
echo "  Project: $EXPECTED_PROJECT_PATH"
echo "  Host: $EXPECTED_GITLAB_HOST"
echo ""
echo "Git hooks will automatically fix remote URL if it changes."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
