# Project Management Documentation

This directory contains all project management documentation for Globtim.jl development.

## 📋 Quick Reference

### Daily Commands
```bash
# View current sprint status
./scripts/sprint-dashboard.sh

# Check epic progress  
./scripts/epic-progress.sh

# Quick project overview
./scripts/gitlab-explore.sh
```

### Issue Management Workflow
```
backlog → ready → in-progress → review → testing → done
```

**Required Labels:**
- **Status**: `status::*` (always required)
- **Priority**: `Priority::Critical|High|Medium|Low` 
- **Type**: `Type::Bug|Feature|Enhancement|Documentation|Test`

## 📚 Documentation Structure

### [GitLab Workflow](gitlab-workflow.md)
Complete guide to GitLab setup, branch strategy, and development workflow including:
- Dual repository structure (GitLab private + GitHub public)
- Branch management and merge request process
- CI/CD setup recommendations

### [Sprint Process](sprint-process.md) 
Detailed sprint management including:
- 2-week sprint cadence and ceremonies
- Issue workflow and definition of done
- Metrics tracking and GitLab board setup

### [Task Management](task-management.md)
Consolidated task and issue management workflows including:
- Issue creation templates and formats
- Epic management and progress tracking
- Troubleshooting common problems

## 🚀 Getting Started

### Initial Setup
```bash
# Set environment variables
export GITLAB_PROJECT_ID="2545"
export GITLAB_PRIVATE_TOKEN="your-token"

# Create labels
./scripts/setup-gitlab-labels.sh

# Test connection
./scripts/gitlab-explore.sh
```

### Environment File (.env.gitlab)
```bash
GITLAB_PROJECT_ID=2545
GITLAB_PRIVATE_TOKEN=your-token
GITLAB_API_URL=https://git.mpi-cbg.de/api/v4
CURRENT_MILESTONE_ID=current-sprint-id
```

## 🎯 Epic Management

### Current Epics
- `epic::mathematical-core` - Core math functionality
- `epic::test-framework` - Testing infrastructure  
- `epic::julia-optimization` - Performance improvements
- `epic::documentation` - Docs and guides
- `epic::advanced-features` - Next-gen capabilities

### Epic Progress Tracking
1. Run: `./scripts/epic-progress.sh`
2. Update: `wiki/Planning/EPICS.md`
3. Track completion in epic documents

## 📊 GitLab Board Setup

### Development Board
- **Columns**: Backlog → Ready → In Progress → Review → Testing → Done
- **Filter**: Current milestone
- **Labels**: Group by status

### Priority Board  
- **Columns**: Critical → High → Medium → Low
- **Filter**: Open issues
- **Labels**: Group by priority

### Epic Board
- **Columns**: One per epic
- **Filter**: Group by epic labels
- **Labels**: Show epic progress

## 🔗 Key Resources

- **GitLab Project**: https://git.mpi-cbg.de/scholten/globtim
- **GitHub Mirror**: https://github.com/gescholt/Globtim.jl
- **Sprint Planning**: `wiki/Planning/SPRINTS.md`
- **Epic Tracking**: `wiki/Planning/EPICS.md`

## 🚨 Troubleshooting

### Common Issues
```bash
# API connection problems
./scripts/gitlab-explore.sh  # Test connection

# Missing labels
./scripts/setup-gitlab-labels.sh  # Recreate labels

# Wrong milestone
# Update CURRENT_MILESTONE_ID in .env.gitlab
```

### Error Messages
- **"API token invalid"**: Check token permissions and expiration
- **"Project not found"**: Verify GITLAB_PROJECT_ID  
- **"Milestone not found"**: Update CURRENT_MILESTONE_ID
