# GitLab Workflow Guide

## Repository Structure

### Dual Repository Setup
1. **GitLab (Private)**: git@git.mpi-cbg.de:scholten/globtim.git
   - Private development repository
   - Main branches: `main`, `clean-version`
   - Project ID: 2545
   - Team: 3 members (scholten as owner, alexander.demin as maintainer)

2. **GitHub (Public)**: git@github.com:gescholt/Globtim.jl.git
   - Public release repository
   - Main branch: `github-release`
   - Has GitHub Actions for CI/CD
   - Auto-synced from GitLab main branch

### Branch Strategy
```
GitLab (Private Development):
├── clean-version (default/stable)
├── main (development)
└── feature/* branches

GitHub (Public Release):
└── github-release (synced from main)
```

## Development Workflow

### 1. Feature Development
```bash
# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# Develop and commit
git add .
git commit -m "feat: implement your feature"

# Push and create merge request
git push origin feature/your-feature-name
```

### 2. Merge Request Process
1. **Create MR** to `main` branch
2. **Apply labels**: status, type, priority
3. **Request review** from team members
4. **Address feedback** and update branch
5. **Merge** after approval

### 3. Release Process
1. **Merge** `main` → `clean-version` for stable releases
2. **Auto-sync** triggers GitHub release
3. **Tag releases** for version management

## Issue Management

### Label System
- **Epic labels**: `epic::mathematical-core`, `epic::test-framework`, etc.
- **Status labels**: `status::backlog`, `status::ready`, `status::in-progress`, etc.
- **Priority labels**: `Priority::Critical`, `Priority::High`, `Priority::Medium`, `Priority::Low`
- **Type labels**: `Type::Feature`, `Type::Bug`, `Type::Enhancement`, `Type::Documentation`, `Type::Test`
- **Component labels**: Identify affected code areas

### Issue Templates
Available templates in `.gitlab/issue_templates/`:
- `bug.md` - Bug reports
- `epic.md` - Epic planning
- `feature.md` - Feature requests
- `research.md` - Research tasks

### Issue Workflow
```
backlog → ready → in-progress → review → testing → done
```

## Sprint Management

### Milestones
- One milestone per 2-week sprint
- Named: "Sprint YYYY-MM"
- Include sprint goals in description
- Assign issues to current milestone

### Board Configuration

#### Development Board
- **Columns**: Backlog → Ready → In Progress → Review → Testing → Done
- **Filter**: Current milestone
- **Labels**: Group by status

#### Priority Board
- **Columns**: Critical → High → Medium → Low
- **Filter**: Open issues
- **Labels**: Group by priority

#### Epic Board
- **Columns**: One per epic
- **Filter**: Group by epic labels
- **Labels**: Show epic progress

## CI/CD Setup

### Current Status
- ❌ GitLab CI/CD: Not configured
- ✅ GitHub Actions: Active for public repository

### Recommended GitLab CI Setup
Create `.gitlab-ci.yml` for:
- Julia package tests
- Documentation building
- Code quality checks
- Security scanning

### Example CI Configuration
```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  image: julia:1.11
  script:
    - julia --project=. -e "using Pkg; Pkg.instantiate()"
    - julia --project=. -e "using Pkg; Pkg.test()"
```

## Best Practices

### Commit Messages
Follow conventional commit format:
```
feat: add new feature
fix: resolve bug
docs: update documentation
test: add test coverage
refactor: improve code structure
```

### Code Review
- **Require approval** before merging to main
- **Review checklist**: functionality, tests, documentation
- **Address feedback** promptly
- **Keep MRs small** and focused

### Branch Protection
- `main` branch is protected (maintainers only)
- Consider protecting `clean-version` too
- Require MR approval for protected branches

## Integration Points

### GitLab ↔ GitHub Sync
- Configured via GitHub Actions
- Pushes to `main` trigger sync to GitHub
- Maintains public/private separation

### API Access
- Use GitLab API for automation
- Store tokens securely in environment variables
- Test API access with `./scripts/gitlab-explore.sh`

## Troubleshooting

### Common Issues
1. **Default branch mismatch**: GitLab default is `clean-version`, active development on `main`
2. **API authentication**: Check token permissions and expiration
3. **Sync failures**: Verify GitHub Actions configuration

### Resolution Steps
```bash
# Test GitLab API connection
./scripts/gitlab-explore.sh

# Recreate labels if missing
./scripts/setup-gitlab-labels.sh

# Check current milestone
echo $CURRENT_MILESTONE_ID
```
