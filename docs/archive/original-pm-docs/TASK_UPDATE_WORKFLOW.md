# Task Update Workflow & Standards

## Overview

This document defines the standardized process for updating tasks, maintaining project status, and ensuring consistent project management practices across the Globtim project.

## Task Update Standards

### 1. Status Definitions

| Status | Symbol | Description | When to Use |
|--------|--------|-------------|-------------|
| Not Started | `[ ]` | Task identified but not begun | Initial state, backlog items |
| In Progress | `[/]` | Currently being worked on | Active development |
| Complete | `[x]` | Finished and verified | Work done and tested |
| Cancelled | `[-]` | No longer relevant | Scope changes, deprioritized |

### 2. Task Naming Convention

**Format**: `[Category] Specific Action or Deliverable`

**Examples**:
- `[Feature] Implement 4D adaptive precision framework`
- `[Bug] Fix memory leak in polynomial evaluation`
- `[Docs] Update API documentation for L2 norm functions`
- `[Test] Create integration tests for anisotropic grids`
- `[Refactor] Optimize coefficient storage for large polynomials`

### 3. Task Description Standards

**Required Elements**:
- Clear objective statement
- Acceptance criteria (what defines "done")
- Dependencies (if any)
- Estimated effort (time or complexity)

**Template**:
```
**Objective**: [What needs to be accomplished]
**Acceptance Criteria**: 
- [ ] Specific deliverable 1
- [ ] Specific deliverable 2
- [ ] Testing completed
- [ ] Documentation updated

**Dependencies**: [List any blocking tasks]
**Effort**: [Small/Medium/Large or time estimate]
```

## Daily Task Management

### Morning Routine (5 minutes)
1. **Check Sprint Dashboard**:
   ```bash
   ./scripts/sprint-dashboard.sh
   ```

2. **Review Your Active Tasks**:
   - Identify tasks marked `[/]` (in progress)
   - Plan daily priorities
   - Note any blockers

3. **Update Task Status**:
   - Move completed work to `[x]`
   - Start new tasks by changing to `[/]`
   - Add comments on progress

### Evening Routine (3 minutes)
1. **Update Progress**:
   - Mark completed tasks as `[x]`
   - Update in-progress tasks with status comments
   - Identify tomorrow's priorities

2. **Log Blockers**:
   - Document any impediments
   - Create follow-up tasks if needed
   - Update task descriptions with new information

## Weekly Task Review

### Sprint Planning (Monday)
1. **Review Previous Sprint**:
   ```bash
   ./scripts/sprint-dashboard.sh > last-sprint-review.md
   ```

2. **Plan Current Sprint**:
   - Move incomplete tasks to new sprint
   - Estimate new work
   - Set sprint goals
   - Update milestone assignments

3. **Update Epic Progress**:
   ```bash
   ./scripts/epic-progress.sh
   # Update wiki/Planning/EPICS.md with current status
   ```

### Mid-Sprint Check (Wednesday)
1. **Progress Assessment**:
   - Review sprint burndown
   - Identify at-risk deliverables
   - Adjust scope if necessary

2. **Task Refinement**:
   - Break down large tasks
   - Add missing dependencies
   - Update effort estimates

### Sprint Review (Friday)
1. **Completion Review**:
   - Verify all `[x]` tasks meet acceptance criteria
   - Demo completed features
   - Gather feedback

2. **Retrospective**:
   - What went well?
   - What could improve?
   - Action items for next sprint

## Task Update Procedures

### Creating New Tasks

#### Using GitLab Interface
1. **Navigate**: Issues → New Issue
2. **Template**: Select appropriate issue template
3. **Labels**: Apply required labels
   - Status: `status::ready`
   - Priority: `Priority::High|Medium|Low`
   - Type: `Type::Feature|Bug|Enhancement|Documentation|Test`
   - Epic: `epic::*` (if applicable)
4. **Milestone**: Assign to current sprint
5. **Description**: Use standard template

#### Using Scripts
```bash
# Create sprint issues from template
./scripts/create-sprint-issues.sh

# Create milestone for new sprint
./scripts/create-sprint-milestone.sh
```

### Updating Existing Tasks

#### Status Changes
1. **Manual Update**:
   - Edit issue in GitLab
   - Change status label
   - Add progress comment

2. **Board Movement**:
   - Drag issue between board columns
   - Status label updates automatically

#### Progress Comments
**Template**:
```
## Progress Update - [Date]

**Completed**:
- [x] Specific accomplishment 1
- [x] Specific accomplishment 2

**In Progress**:
- [/] Current work item 1
- [/] Current work item 2

**Next Steps**:
- [ ] Planned work item 1
- [ ] Planned work item 2

**Blockers**: [None | Description of impediments]
**Notes**: [Additional context or decisions]
```

### Task Closure

#### Definition of Done Checklist
- [ ] **Code Complete**: All functionality implemented
- [ ] **Tests Written**: Unit and integration tests pass
- [ ] **Documentation Updated**: API docs, user guides, examples
- [ ] **Code Reviewed**: Peer review completed and approved
- [ ] **Merged**: Changes integrated to main branch
- [ ] **Verified**: Feature tested in target environment

#### Closure Process
1. **Verify Completion**: Check all acceptance criteria
2. **Update Status**: Change to `[x]` complete
3. **Add Closure Comment**: Summarize what was delivered
4. **Link Artifacts**: Reference PRs, documentation, tests
5. **Close Issue**: Mark as closed in GitLab

## Automation and Tools

### Available Scripts

#### Daily Use
```bash
# Quick status check
./scripts/sprint-status.sh

# Comprehensive dashboard
./scripts/sprint-dashboard.sh

# Epic progress tracking
./scripts/epic-progress.sh
```

#### Weekly Use
```bash
# Project exploration and metrics
./scripts/gitlab-explore.sh

# Sprint transition
./scripts/sprint-transition.sh

# Performance and pipeline status
./scripts/pipeline-status.sh
```

### Custom Automation

#### Task Status Automation
Create custom scripts for:
- Bulk status updates
- Automated progress reporting
- Integration with external tools
- Custom metrics collection

#### Integration Points
- **GitLab API**: Programmatic issue management
- **Git Hooks**: Automatic task updates on commits
- **CI/CD Pipeline**: Task status based on build results
- **External Tools**: Integration with time tracking, etc.

## Quality Assurance

### Task Quality Checklist
- [ ] **Clear Title**: Descriptive and actionable
- [ ] **Detailed Description**: Objective and acceptance criteria
- [ ] **Proper Labels**: Status, priority, type, epic
- [ ] **Milestone Assignment**: Current or future sprint
- [ ] **Effort Estimate**: Size or time estimate
- [ ] **Dependencies**: Linked related issues

### Review Process
1. **Self-Review**: Creator reviews task before assignment
2. **Peer Review**: Team member validates task clarity
3. **Sprint Review**: Product owner approves sprint tasks
4. **Retrospective**: Team reviews task quality and process

## Metrics and Reporting

### Key Metrics
- **Velocity**: Tasks completed per sprint
- **Cycle Time**: Task creation to completion
- **Lead Time**: Task identification to delivery
- **Quality**: Defect rate and rework frequency

### Reporting Schedule
- **Daily**: Personal task status
- **Weekly**: Sprint progress and blockers
- **Monthly**: Epic progress and velocity trends
- **Quarterly**: Project health and process improvements

### Report Templates

#### Daily Standup
```
**Yesterday**: [Completed tasks]
**Today**: [Planned tasks]
**Blockers**: [Impediments or help needed]
```

#### Sprint Review
```
**Sprint Goal**: [Original objective]
**Completed**: [X/Y tasks, story points]
**Velocity**: [Comparison to previous sprints]
**Highlights**: [Key accomplishments]
**Challenges**: [Issues encountered]
**Next Sprint**: [Priorities and focus]
```

## Best Practices

### Task Management
1. **Keep Tasks Small**: 1-3 days of work maximum
2. **Update Frequently**: At least daily status updates
3. **Be Specific**: Clear, measurable acceptance criteria
4. **Link Related Work**: Connect issues, PRs, documentation
5. **Document Decisions**: Capture context and rationale

### Team Collaboration
1. **Async Updates**: Use comments for daily standups
2. **Transparent Progress**: Regular status updates
3. **Early Escalation**: Raise blockers immediately
4. **Knowledge Sharing**: Document solutions and learnings
5. **Continuous Improvement**: Regular process refinement

### Tool Usage
1. **Consistent Labeling**: Follow established taxonomy
2. **Proper Milestones**: Assign to appropriate sprints
3. **Board Hygiene**: Keep boards current and organized
4. **Script Utilization**: Use automation for routine tasks
5. **Data Quality**: Maintain accurate and current information

This workflow ensures consistent, efficient task management while maintaining high visibility into project progress and team productivity.
