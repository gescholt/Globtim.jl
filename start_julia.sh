#!/bin/bash
# Start Julia without conda environment interference

# Save current conda environment
CONDA_ENV_BACKUP=$CONDA_DEFAULT_ENV

# Temporarily clear conda from PATH
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
unset CONDA_DEFAULT_ENV
unset CONDA_PREFIX

# Start Julia with the Globtim project
echo "Starting Julia (conda environment temporarily disabled)..."
julia --project=/Users/ghscholt/globtim "$@"

# Note: conda environment will be restored when you exit this script