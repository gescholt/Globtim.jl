# GitLab Workflow Analysis and Recommendations

## Current Environment Overview

### GitLab Setup
- **Server**: MPI-CBG GitLab (git.mpi-cbg.de)
- **Project**: scholten/globtim (ID: 2545)
- **Visibility**: Private
- **Default Branch**: `clean-version` (not `main`)
- **Team**: 3 members (scholten as owner, alexander.demin as maintainer, plus bot)

### Dual Repository Structure
1. **GitLab (Private)**: git@git.mpi-cbg.de:scholten/globtim.git
   - Private development repository
   - Main branches: `main`, `clean-version`
   - No CI/CD pipelines configured

2. **GitHub (Public)**: git@github.com:gescholt/Globtim.jl.git
   - Public release repository
   - Main branch: `github-release`
   - Has GitHub Actions for CI/CD

### Current Features Status
- ✅ Issues: Enabled (0 open issues)
- ✅ Merge Requests: Enabled (3 closed MRs)
- ✅ Wiki: Enabled
- ✅ Container Registry: Enabled
- ✅ Package Registry: Enabled
- ❌ CI/CD Pipelines: No GitLab CI configured
- ✅ Labels: Full label system now configured
- ❌ Milestones: None created yet
- ✅ Issue Templates: 4 templates available

## Recommended Workflow

### 1. Branch Strategy
```
GitLab (Private Development):
├── clean-version (default/stable)
├── main (development)
└── feature/* branches

GitHub (Public Release):
└── github-release (synced from main)
```

### 2. Development Flow
1. **Create feature branches** from `main` for new work
2. **Open Merge Requests** to `main` for review
3. **Periodically merge** `main` → `clean-version` for stable releases
4. **Auto-sync** `main` → GitHub `github-release` (already configured)

### 3. Issue Management
- Use the new label system:
  - **Epic labels**: For major features (test-framework, julia-optimization, etc.)
  - **Status labels**: Track progress (backlog → ready → in-progress → review → testing → done)
  - **Priority labels**: Prioritize work (critical, high, medium, low)
  - **Type labels**: Categorize work (feature, bug, research, documentation, test)
  - **Component labels**: Identify affected areas

### 4. Sprint Planning
1. Create milestones for 2-week sprints
2. Assign issues to milestones
3. Use boards to visualize workflow

### 5. Missing CI/CD Setup
Consider adding `.gitlab-ci.yml` for:
- Julia package tests
- Documentation building
- Code quality checks

## Immediate Actions Needed

1. **Fix default branch discrepancy**:
   - GitLab default: `clean-version`
   - Active development: `main`
   - Consider aligning these

2. **Create first milestone**:
   ```bash
   # Create via API or web interface
   "Sprint 2025-01" with 2-week duration
   ```

3. **Set up GitLab CI/CD** (optional but recommended)

4. **Create project boards**:
   - Development Board (status-based)
   - Epic Board (epic-based)
   - Priority Board (priority-based)

## Integration Points

1. **GitLab ↔ GitHub Sync**:
   - Already configured via GitHub Actions
   - Pushes to `main` trigger sync to GitHub

2. **Issue Templates**:
   - Available: bug.md, epic.md, feature.md, research.md
   - Use these for consistent issue creation

3. **Protected Branches**:
   - `main` is protected (maintainers only)
   - Consider protecting `clean-version` too

## Best Practices

1. **Commit Messages**: Follow conventional format
2. **MR Process**: Always use MRs for main branch
3. **Labels**: Apply at least status + type labels
4. **Documentation**: Keep README and wikis updated
5. **Reviews**: Require approval before merging to main
