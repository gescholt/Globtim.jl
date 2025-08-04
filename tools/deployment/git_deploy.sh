#!/bin/bash

# Git-based deployment script (if git is available on fileserver)
# This pushes to a git repository and pulls on the remote server

REMOTE_HOST="scholten@fileserver-ssh"
REMOTE_PATH="~/globtim"

echo "Git-based deployment to cluster..."

# Commit current changes
echo "Committing current changes..."
git add .
git commit -m "Auto-commit for cluster deployment $(date)"

# Push to remote repository (if configured)
if git remote get-url origin >/dev/null 2>&1; then
    echo "Pushing to remote repository..."
    git push origin main
    
    # Pull on remote server
    echo "Pulling changes on remote server..."
    ssh "${REMOTE_HOST}" "cd ${REMOTE_PATH} && git pull origin main"
else
    echo "No git remote configured. Using direct rsync fallback..."
    ./upload_to_cluster.sh
fi
