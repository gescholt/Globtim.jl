#!/bin/bash
# Setup GPG key integration with GitLab

echo "=== GitLab GPG Key Integration Setup ==="
echo

# Check current Git configuration
echo "Current Git configuration:"
git config user.name
git config user.email
git config user.signingkey
echo

# List available GPG keys
echo "Available GPG keys:"
gpg --list-secret-keys --keyid-format=long
echo

# Get the current signing key
CURRENT_KEY=$(git config user.signingkey)
if [ -n "$CURRENT_KEY" ]; then
    echo "Currently configured signing key: $CURRENT_KEY"
    
    # Export the public key
    echo
    echo "Exporting public key for GitLab..."
    echo "Copy the following public key and add it to your GitLab profile:"
    echo "https://gitlab.com/-/profile/gpg_keys"
    echo
    echo "========== BEGIN GPG PUBLIC KEY =========="
    gpg --armor --export $CURRENT_KEY
    echo "========== END GPG PUBLIC KEY =========="
    echo
    
    # Verify GPG agent is running
    echo "Checking GPG agent status..."
    if gpg-agent --version >/dev/null 2>&1; then
        echo "✅ GPG agent is available"
        
        # Ensure GPG uses the correct TTY
        export GPG_TTY=$(tty)
        echo "export GPG_TTY=\$(tty)" >> ~/.bashrc 2>/dev/null || echo "export GPG_TTY=\$(tty)" >> ~/.zshrc 2>/dev/null
        
        # Test signing
        echo
        echo "Testing GPG signing..."
        echo "test" | gpg --clearsign >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ GPG signing works!"
        else
            echo "❌ GPG signing failed. You may need to:"
            echo "   1. Restart your terminal"
            echo "   2. Run: gpg --edit-key $CURRENT_KEY trust"
            echo "   3. Set ultimate trust (5) and save"
        fi
    else
        echo "⚠️  GPG agent not found"
    fi
    
    echo
    echo "=== Git Configuration Summary ==="
    echo "Email: $(git config user.email)"
    echo "Name: $(git config user.name)"
    echo "Signing Key: $(git config user.signingkey)"
    echo "Auto-sign commits: $(git config commit.gpgsign)"
    echo
    echo "=== Next Steps ==="
    echo "1. Copy the public key above"
    echo "2. Go to https://gitlab.com/-/profile/gpg_keys"
    echo "3. Click 'Add new GPG key' and paste the public key"
    echo "4. Verify the email matches: scholten@mpi-cbg.de"
    echo
    echo "To verify a signed commit:"
    echo "  git log --show-signature -1"
    echo
    echo "To sign a specific commit manually:"
    echo "  git commit -S -m 'Your message'"
    echo
else
    echo "❌ No GPG signing key configured"
    echo "To configure one:"
    echo "  git config user.signingkey YOUR_KEY_ID"
    echo "  git config commit.gpgsign true"
fi