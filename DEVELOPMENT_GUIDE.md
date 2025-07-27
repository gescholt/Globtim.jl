# Globtim.jl Development Guide

## Repository Structure

This project uses a dual-repository approach:
- **GitLab**: Private development repository (main branch)
- **GitHub**: Public release repository (github-release branch)

## Branch Management

### Main Branch (GitLab - Private)
- Contains all development work, experimental features, and work-in-progress
- Includes files not ready for public release (e.g., AnisotropicGridComparison.ipynb)
- This is where all development happens

### GitHub-Release Branch (GitHub - Public)
- Clean version for public consumption and Julia package registry
- Excludes experimental/development files
- Should be the default branch on GitHub

## Daily Development Workflow

### Using the Push Script

A helper script `push.sh` is provided to ensure correct pushing:

```bash
# For daily development (push to GitLab)
./push.sh gitlab

# For public releases (push to GitHub)
./push.sh github
```

The script includes safety checks:
- Warns if you're not on the correct branch
- Prevents pushing main to GitHub
- Checks for private files in github-release branch

### Manual Push Commands

If not using the script:

```bash
# Push to GitLab (private)
git push origin main

# Push to GitHub (public) - ONLY from github-release branch!
git checkout github-release
git push github github-release
```

## Workflow for Public Releases

1. Develop features on `main` branch
2. When ready for public release:
   ```bash
   git checkout github-release
   git merge main --no-ff
   # Remove any files that should stay private
   git rm Examples/Notebooks/AnisotropicGridComparison.ipynb  # if it was accidentally merged
   git commit -m "Prepare for public release"
   ./push.sh github  # or: git push github github-release
   ```

## Files Excluded from Public Release

The following files/directories exist only in the private `main` branch:
- `Examples/Notebooks/AnisotropicGridComparison.ipynb` - Experimental anisotropic grid functionality

## Adding New Private Content

When adding content that should remain private:
1. Add it only to the `main` branch
2. Document it in this file under "Files Excluded from Public Release"
3. Ensure it's not present in `github-release` branch

## Checking Branch Differences

To see what files differ between branches:
```bash
git diff --name-only main github-release
```

To verify a file doesn't exist in github-release:
```bash
git checkout github-release
ls path/to/file  # Should show "No such file or directory"
```
