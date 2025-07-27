#!/bin/bash
# Git Safety Setup for Globtim.jl
# Prevents accidentally pushing dev files to public github-release branch

echo "Setting up git safety measures for Globtim.jl..."

# Check if we're in the right directory
if [ ! -f "Project.toml" ] || ! grep -q "name = \"Globtim\"" Project.toml; then
    echo "Error: Run this script from the Globtim.jl root directory"
    exit 1
fi

# Install pre-commit if not already installed
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    pip install pre-commit || pip3 install pre-commit
else
    echo "pre-commit already installed"
fi

# Install git-secrets if not already installed
if ! command -v git-secrets &> /dev/null; then
    echo "Installing git-secrets..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git-secrets
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install git-secrets
    else
        echo "Please install git-secrets manually for your platform"
    fi
else
    echo "git-secrets already installed"
fi

# Set up global gitignore for math/dev patterns
echo "Setting up global gitignore..."
cat >> ~/.gitignore_global << 'EOF'
# Math/Dev specific patterns
*.private.jl
*.private.mpl
*-dev-only.*
*-dev.*
local_tests/
scratch/
.env*
tmp-*
dev-notes*
experiments/
*.backup
*-experimental.*
research/
drafts/
sandbox/
EOF

git config --global core.excludesfile ~/.gitignore_global

# Install git-secrets in this repo
echo "Installing git-secrets hooks..."
git secrets --install -f

# Add patterns to detect private/dev content
echo "Adding git-secrets patterns..."
git secrets --add 'PRIVATE'
git secrets --add 'DEV.?ONLY'
git secrets --add 'EXPERIMENTAL'
git secrets --add 'local_.*\.jl'
git secrets --add 'scratch.*\.jl'
git secrets --add 'test_private.*'

# Install pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

# Create a custom git hook for branch protection
echo "Creating branch protection hook..."
cat > .git/hooks/pre-push << 'HOOK'
#!/bin/bash
# Pre-push hook to prevent accidental pushes to github-release

protected_branch='github-release'
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')
remote="$1"

# Check if pushing to github remote
if [[ "$remote" == *"github"* ]]; then
    while read local_ref local_sha remote_ref remote_sha
    do
        if [[ "$remote_ref" == *"$protected_branch"* ]]; then
            echo "⚠️  WARNING: Pushing to protected branch '$protected_branch' on GitHub"
            echo "This branch should only contain clean, public-ready code."
            echo ""
            echo "Checking for private/experimental files..."

            # Get list of files that would be pushed
            files=$(git diff --name-only $remote_sha..$local_sha)

            # Check for suspicious patterns
            suspicious=0
            for file in $files; do
                if [[ "$file" == *"private"* ]] || [[ "$file" == *"dev-only"* ]] || \
                   [[ "$file" == *"experimental"* ]] || [[ "$file" == *"scratch"* ]]; then
                    echo "❌ Suspicious file: $file"
                    suspicious=1
                fi
            done

            if [ $suspicious -eq 1 ]; then
                echo ""
                echo "Found potentially private files!"
                echo "Abort push? (y/n)"
                read -n 1 -r < /dev/tty
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi

            echo "Proceed with push to $protected_branch? (y/n)"
            read -n 1 -r < /dev/tty
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done
fi

exit 0
HOOK

chmod +x .git/hooks/pre-push

echo "✅ Git safety measures installed successfully!"
echo ""
echo "Features enabled:"
echo "  - Global gitignore for common dev patterns"
echo "  - git-secrets scanning for private content"
echo "  - pre-commit hooks"
echo "  - pre-push protection for github-release branch"
echo ""
echo "Remember:"
echo "  - Always work on 'main' branch for development"
echo "  - Only push clean code to 'github-release'"
echo "  - Run 'git secrets --scan' to check files manually"
