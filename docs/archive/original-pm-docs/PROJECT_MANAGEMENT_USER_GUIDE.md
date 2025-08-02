# Globtim Project Management User Guide

## Overview

This guide provides step-by-step instructions for using the Globtim project management system, which integrates GitLab's native features with custom automation scripts for efficient project tracking and task management.

## Quick Start

### 1. Initial Setup

First, configure your GitLab environment:

```bash
# Set up environment variables (add to your ~/.bashrc or ~/.zshrc)
export GITLAB_PROJECT_ID="your-project-id"
export GITLAB_PRIVATE_TOKEN="your-personal-access-token"
export GITLAB_API_URL="https://gitlab.com/api/v4"

# Or create a .env.gitlab file in the project root
echo "GITLAB_PROJECT_ID=your-project-id" > .env.gitlab
echo "GITLAB_PRIVATE_TOKEN=your-token" >> .env.gitlab
echo "GITLAB_API_URL=https://gitlab.com/api/v4" >> .env.gitlab
echo "CURRENT_MILESTONE_ID=current-sprint-id" >> .env.gitlab
```

### 2. Set Up GitLab Labels

Run the label setup script to create the standard label taxonomy:

```bash
./scripts/setup-gitlab-labels.sh
```

This creates labels for:
- **Status**: `status::backlog`, `status::ready`, `status::in-progress`, `status::review`, `status::testing`, `status::done`
- **Priority**: `Priority::Critical`, `Priority::High`, `Priority::Medium`, `Priority::Low`
- **Type**: `Type::Bug`, `Type::Feature`, `Type::Enhancement`, `Type::Documentation`, `Type::Test`
- **Epic**: `epic::test-framework`, `epic::julia-optimization`, `epic::mathematical-core`, etc.

## Daily Workflow

### Viewing Project Status

#### Sprint Dashboard
Get a comprehensive overview of the current sprint:

```bash
./scripts/sprint-dashboard.sh
```

This displays:
- Sprint progress with visual progress bar
- Issues by priority and type
- Team velocity metrics
- Quick action suggestions

#### Epic Progress
Track progress across all epics:

```bash
./scripts/epic-progress.sh
```

#### General Project Exploration
Get detailed project information:

```bash
./scripts/gitlab-explore.sh
```

### Creating and Managing Issues

#### Creating New Issues

1. **Using GitLab Web Interface**:
   - Go to Issues → New Issue
   - Use issue templates from `.gitlab/issue_templates/`
   - Apply appropriate labels (status, priority, type, epic)
   - Assign to current sprint milestone

2. **Using Scripts**:
   ```bash
   # Create sprint issues from a predefined list
   ./scripts/create-sprint-issues.sh
   ```

#### Issue Labeling Best Practices

**Required Labels for Every Issue**:
- **Status Label**: Always start with `status::backlog` or `status::ready`
- **Priority Label**: Assign based on urgency and impact
- **Type Label**: Categorize the work type

**Optional but Recommended**:
- **Epic Label**: Group related work (max one epic per issue)
- **Milestone**: Assign to current or future sprint

**Example Issue Labels**:
```
Labels: status::ready, Priority::High, Type::Feature, epic::mathematical-core
Milestone: Sprint 2024-31
```

### Task Status Management

#### Status Workflow
Issues follow this progression:
```
backlog → ready → in-progress → review → testing → done
```

#### Updating Issue Status

1. **Manual Updates**:
   - Edit issue in GitLab
   - Remove old status label
   - Add new status label

2. **Automated Transitions**:
   - Moving issues on GitLab boards automatically updates labels
   - Merge requests can auto-close issues with keywords

#### Status Definitions

- **`status::backlog`**: Identified work, not yet prioritized
- **`status::ready`**: Prioritized and ready to start
- **`status::in-progress`**: Currently being worked on
- **`status::review`**: Code complete, awaiting review
- **`status::testing`**: Under testing/validation
- **`status::done`**: Complete and verified

## Sprint Management

### Creating a New Sprint

1. **Create Milestone**:
   ```bash
   ./scripts/create-sprint-milestone.sh
   ```
   Or manually in GitLab:
   - Go to Issues → Milestones → New Milestone
   - Name: "Sprint YYYY-WW" (e.g., "Sprint 2024-31")
   - Duration: 2 weeks
   - Add sprint goals in description

2. **Update Environment**:
   ```bash
   # Update .env.gitlab with new milestone ID
   echo "CURRENT_MILESTONE_ID=new-milestone-id" >> .env.gitlab
   ```

### Sprint Planning Process

1. **Review Backlog**: Identify ready issues
2. **Estimate Effort**: Add time estimates to issues
3. **Assign to Sprint**: Add milestone to selected issues
4. **Set Sprint Goals**: Update milestone description
5. **Update Planning Documents**: Modify `wiki/Planning/SPRINTS.md`

### Sprint Monitoring

#### Daily Checks
```bash
# Quick status check
./scripts/sprint-status.sh

# Detailed dashboard
./scripts/sprint-dashboard.sh
```

#### Weekly Reviews
1. Run sprint dashboard
2. Update issue statuses
3. Identify blockers
4. Adjust sprint scope if needed

### Sprint Closure

1. **Complete Sprint Review**:
   ```bash
   ./scripts/sprint-dashboard.sh > sprint-review-YYYY-WW.md
   ```

2. **Move Incomplete Items**:
   - Remove current milestone from incomplete issues
   - Add to next sprint milestone

3. **Close Sprint**:
   - Mark milestone as closed in GitLab
   - Update velocity metrics

## Epic Management

### Epic Structure

Epics are managed using labels and tracked in `wiki/Planning/EPICS.md`:

- **Epic Label**: `epic::name` (e.g., `epic::mathematical-core`)
- **Epic Document**: Detailed progress tracking
- **Epic Issues**: All issues with the epic label

### Updating Epic Progress

1. **Manual Tracking**: Update `wiki/Planning/EPICS.md`
2. **Automated Tracking**: Run `./scripts/epic-progress.sh`

### Epic Workflow

1. **Define Epic**: Create entry in EPICS.md
2. **Create Issues**: Add issues with epic label
3. **Track Progress**: Regular updates to epic document
4. **Close Epic**: When all features complete

## Advanced Features

### Custom Dashboards

Create custom views using GitLab boards:

1. **Development Board**: Filter by current milestone, group by status
2. **Priority Board**: Group by priority labels
3. **Epic Board**: Group by epic labels

### Automation Scripts

#### Available Scripts
- `sprint-dashboard.sh`: Comprehensive sprint overview
- `epic-progress.sh`: Epic completion tracking
- `sprint-status.sh`: Quick sprint status
- `gitlab-explore.sh`: Detailed project analysis
- `create-sprint-milestone.sh`: New sprint creation
- `create-sprint-issues.sh`: Bulk issue creation

#### Script Customization
Scripts can be modified to:
- Add new metrics
- Change reporting format
- Integrate with external tools
- Customize for team needs

## Troubleshooting

### Common Issues

1. **API Token Errors**:
   - Verify token has correct permissions
   - Check token expiration
   - Ensure project access

2. **Label Issues**:
   - Re-run `./scripts/setup-gitlab-labels.sh`
   - Manually create missing labels
   - Check label naming consistency

3. **Milestone Problems**:
   - Verify milestone ID in `.env.gitlab`
   - Check milestone dates
   - Ensure milestone exists

### Getting Help

1. **Check Script Output**: Most scripts provide detailed error messages
2. **Verify Configuration**: Ensure all environment variables are set
3. **Test API Access**: Use `./scripts/gitlab-explore.sh` to verify connectivity
4. **Review Documentation**: Check GitLab API documentation for advanced usage

## Best Practices

### Issue Management
- Keep issues small (1-3 days of work)
- Update status regularly
- Use descriptive titles and clear acceptance criteria
- Link related issues and merge requests

### Sprint Planning
- Plan for 80% capacity (leave buffer for unexpected work)
- Include testing and documentation time
- Review and adjust estimates based on historical data

### Epic Management
- Limit epic scope to quarterly goals
- Regular epic progress reviews
- Clear epic completion criteria

### Team Collaboration
- Use async updates for daily standups
- Document decisions in issue comments
- Share knowledge through examples and documentation

This guide provides the foundation for effective project management in Globtim. Customize the processes and tools to fit your team's specific needs and workflow preferences.
