# Project Management Quick Reference

## 🚀 Daily Commands

```bash
# View current sprint status
./scripts/sprint-dashboard.sh

# Check epic progress
./scripts/epic-progress.sh

# Quick project overview
./scripts/gitlab-explore.sh

# View sprint details
./scripts/sprint-status.sh
```

## 📋 Issue Management Cheat Sheet

### Creating Issues
1. Go to GitLab → Issues → New Issue
2. Apply labels: `status::ready`, `Priority::High`, `Type::Feature`
3. Assign to current milestone
4. Add epic label if applicable: `epic::mathematical-core`

### Status Progression
```
backlog → ready → in-progress → review → testing → done
```

### Required Labels
- **Status**: `status::*` (always required)
- **Priority**: `Priority::Critical|High|Medium|Low`
- **Type**: `Type::Bug|Feature|Enhancement|Documentation|Test`

### Optional Labels
- **Epic**: `epic::*` (max one per issue)

## 🏃‍♂️ Sprint Workflow

### Start New Sprint
```bash
# 1. Create milestone
./scripts/create-sprint-milestone.sh

# 2. Update environment
echo "CURRENT_MILESTONE_ID=new-id" >> .env.gitlab

# 3. Plan issues
# - Assign issues to milestone
# - Set sprint goals in milestone description
```

### During Sprint
```bash
# Daily check
./scripts/sprint-dashboard.sh

# Update issue status by moving on GitLab boards or changing labels
```

### End Sprint
```bash
# 1. Generate report
./scripts/sprint-dashboard.sh > sprint-review.md

# 2. Move incomplete issues to next sprint
# 3. Close milestone in GitLab
```

## 🎯 Epic Management

### Epic Labels
- `epic::mathematical-core` - Core math functionality
- `epic::test-framework` - Testing infrastructure
- `epic::julia-optimization` - Performance improvements
- `epic::documentation` - Docs and guides
- `epic::advanced-features` - Next-gen capabilities

### Update Epic Progress
1. Run: `./scripts/epic-progress.sh`
2. Update: `wiki/Planning/EPICS.md`
3. Track completion in epic document

## 🔧 Setup Commands

### Initial Setup
```bash
# Set environment variables
export GITLAB_PROJECT_ID="your-id"
export GITLAB_PRIVATE_TOKEN="your-token"

# Create labels
./scripts/setup-gitlab-labels.sh

# Test connection
./scripts/gitlab-explore.sh
```

### Environment File (.env.gitlab)
```bash
GITLAB_PROJECT_ID=your-project-id
GITLAB_PRIVATE_TOKEN=your-token
GITLAB_API_URL=https://gitlab.com/api/v4
CURRENT_MILESTONE_ID=current-sprint-id
```

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

## 🚨 Troubleshooting

### Common Fixes
```bash
# API connection issues
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

## 📈 Metrics & Reporting

### Sprint Metrics
- **Velocity**: Story points completed per sprint
- **Burndown**: Daily progress tracking
- **Cycle Time**: Issue start to completion
- **Completion Rate**: Percentage of planned work finished

### Epic Metrics
- **Progress**: Features completed vs. planned
- **Timeline**: Epic duration and milestones
- **Scope**: Feature additions/removals

## 🎨 Status Indicators

### Visual Status Guide
- 🟢 **Complete**: Feature ready and tested
- 🟡 **In Progress**: Active development
- 🔴 **Planned**: Future work
- ⚪ **Backlog**: Identified but not prioritized

### Priority Levels
- 🔴 **Critical**: Blocking other work
- 🟡 **High**: Important for sprint goals
- 🔵 **Medium**: Standard priority
- 🟢 **Low**: Nice to have

## 📝 Templates

### Issue Title Format
```
[Type] Brief description of the work
Examples:
- [Feature] Implement 4D adaptive precision testing
- [Bug] Fix memory leak in polynomial evaluation
- [Docs] Update API documentation for L2 norm functions
```

### Sprint Goal Template
```
## Sprint Goals
1. Primary objective with success criteria
2. Secondary objective with deliverables
3. Stretch goal if capacity allows

## Focus Areas
- Technical area 1
- Technical area 2
- Quality/testing priorities
```

### Epic Description Template
```
## Epic: [Name]
**Goal**: Clear objective statement
**Status**: 🟡 In Progress (X/Y features complete)

### Key Features
- [x] Completed feature
- [/] In progress feature  
- [ ] Planned feature

### Success Criteria
- Measurable outcome 1
- Measurable outcome 2
```

## 🔗 Quick Links

- **GitLab Project**: [Your GitLab URL]
- **Sprint Planning**: `wiki/Planning/SPRINTS.md`
- **Epic Tracking**: `wiki/Planning/EPICS.md`
- **Project Status**: `PROJECT_STATUS_ANALYSIS.md`
- **Full Guide**: `PROJECT_MANAGEMENT_USER_GUIDE.md`
