#!/bin/bash

# Install git pre-commit hooks for security

echo "Installing security pre-commit hooks..."

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Pre-commit security check
echo "Running security checks before commit..."

# Check for sensitive files
SENSITIVE_FILES=$(git diff --cached --name-only | grep -E '\.(key|pem)$|password|secret|token')
if [ -n "$SENSITIVE_FILES" ]; then
    echo "ERROR: Attempting to commit sensitive files:"
    echo "$SENSITIVE_FILES"
    echo "Commit aborted for security."
    exit 1
fi

# Check for hardcoded credentials
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(sh|jl|py|js|ts)$')
for file in $STAGED_FILES; do
    if git show ":$file" | grep -q -E 'password=|token=|secret=.*[^_]|@.*:.*@'; then
        echo "ERROR: Potential hardcoded credentials found in $file"
        echo "Commit aborted for security."
        exit 1
    fi
done

echo "Security checks passed."
EOF

chmod +x .git/hooks/pre-commit
echo "✓ Pre-commit security hook installed"
