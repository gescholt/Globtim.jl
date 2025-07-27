# GitLab Project Management Setup Guide

## Quick Start

### 1. Set Environment Variables
```bash
export GITLAB_PROJECT_ID="your-project-id"
export GITLAB_PRIVATE_TOKEN="your-personal-access-token"
export GITLAB_API_URL="https://gitlab.com/api/v4"  # or self-hosted URL
```

### 2. Run Label Setup
```bash
./scripts/setup-gitlab-labels.sh
```

### 3. Configure GitLab Boards

#### Development Board
- **Lists:** Backlog → Ready → In Progress → Review → Testing → Done
- **Filter:** All issues except epics

#### Epic Board
- **Lists:** One column per epic label
- **Filter:** Group by `epic::*` labels

#### Priority Board
- **Lists:** Critical → High → Medium → Low
- **Filter:** Group by `priority::*` labels

### 4. Create First Sprint Milestone
1. Go to Project → Milestones
2. Create milestone named "Sprint 2024-XX"
3. Set 2-week duration
4. Add sprint goals in description

## Workflow

### Creating Issues
1. Use issue templates in `.gitlab/issue_templates/`
2. Apply appropriate labels
3. Assign to sprint milestone
4. Add time estimate

### During Sprint
1. Move issues through status labels
2. Update progress in comments
3. Link related issues/MRs
4. Close when Definition of Done met

### Sprint Review
1. Generate sprint report
2. Move incomplete items to next sprint
3. Update velocity metrics
4. Plan next sprint

## Automation Scripts

### Coming Soon
- `scripts/epic-progress.sh` - Track epic completion
- `scripts/sprint-report.sh` - Generate sprint summaries
- `scripts/velocity-tracker.sh` - Calculate team velocity

## Best Practices
1. One epic label per issue maximum
2. Always include status label
3. Update labels as work progresses
4. Use milestones for sprint tracking
5. Keep epic descriptions updated

## Troubleshooting
- **Labels not creating:** Check API token permissions
- **Boards not filtering:** Verify label syntax
- **Milestone issues:** Ensure dates don't overlap
