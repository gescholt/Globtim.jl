# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Globtim.jl project.

## Branch Structure

- **main**: Private development branch (GitLab)
- **github-release**: Public release branch (GitHub) - should be set as default branch on GitHub

## Workflows

### 1. sync-to-github.yml
- **Trigger**: Push to `main` branch or manual dispatch
- **Purpose**: Automatically syncs changes from `main` to `github-release` branch
- **Note**: This ensures the public GitHub branch stays updated with development changes

### 2. release.yml
- **Trigger**: Push to `github-release` branch when `Project.toml` changes
- **Purpose**: Automatically creates a GitHub release when version is bumped
- **Features**:
  - Extracts version from Project.toml
  - Checks if tag already exists
  - Generates release notes from commit history
  - Creates GitHub release with proper tag

### 3. TagBot.yml
- **Trigger**: Issue comments or manual dispatch
- **Purpose**: Handles Julia package registration
- **Note**: Works in conjunction with the release workflow

### 4. test.yml
- **Trigger**: Push to main branches and pull requests
- **Purpose**: Runs the test suite

### 5. documentation.yml
- **Trigger**: Push to main branches and pull requests
- **Purpose**: Builds and deploys documentation to GitHub Pages

### 6. CompatHelper.yml
- **Trigger**: Schedule (daily)
- **Purpose**: Keeps Julia package dependencies up to date

## Release Process

To create a new release:

1. **Bump version** in Project.toml:
   ```bash
   julia bump_version.jl patch  # or minor/major
   ```

2. **Commit and push** to main:
   ```bash
   git add Project.toml
   git commit -m "Bump version to vX.Y.Z"
   git push origin main
   ```

3. **Automatic steps**:
   - sync-to-github.yml syncs to github-release branch
   - release.yml creates GitHub release
   - TagBot handles Julia registry submission

## Important Notes

- Always bump version in Project.toml before pushing for a release
- The github-release branch should be the default branch on GitHub
- Ensure notebooks not ready for public release are in .gitignore
