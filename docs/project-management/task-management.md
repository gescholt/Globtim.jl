# Task Management Guide

## Issue Creation

### Issue Title Format
```
[Type] Brief description of the work

Examples:
- [Feature] Implement 4D adaptive precision testing
- [Bug] Fix memory leak in polynomial evaluation  
- [Docs] Update API documentation for L2 norm functions
- [Test] Add unit tests for sparsification module
```

### Issue Templates
Use GitLab issue templates for consistency:

#### Feature Request Template
```markdown
## Feature Description
Brief description of the requested feature

## Use Case
Why is this feature needed? What problem does it solve?

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Implementation Notes
Technical considerations or constraints

## Definition of Done
- [ ] Code implemented and tested
- [ ] Documentation updated
- [ ] Tests passing
```

#### Bug Report Template
```markdown
## Bug Description
Clear description of the issue

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Julia version:
- Globtim version:
- OS:

## Additional Context
Screenshots, logs, or other relevant information
```

## Label Management

### Required Labels
Every issue must have:
- **Status**: `status::backlog|ready|in-progress|review|testing|done`
- **Type**: `Type::Bug|Feature|Enhancement|Documentation|Test`
- **Priority**: `Priority::Critical|High|Medium|Low`

### Optional Labels
- **Epic**: `epic::mathematical-core|test-framework|julia-optimization|documentation|advanced-features`
- **Component**: Identify affected code areas
- **Effort**: `effort::small|medium|large` (optional estimation)

### Label Definitions

#### Status Labels
- `status::backlog` - Identified but not prioritized
- `status::ready` - Prioritized and ready for development
- `status::in-progress` - Actively being worked on
- `status::review` - Code complete, awaiting review
- `status::testing` - Under testing/validation
- `status::done` - Complete and accepted

#### Priority Labels
- `Priority::Critical` - Blocking other work, immediate attention
- `Priority::High` - Important for current sprint goals
- `Priority::Medium` - Standard priority work
- `Priority::Low` - Nice to have, low urgency

#### Type Labels
- `Type::Bug` - Defect or error in existing functionality
- `Type::Feature` - New functionality or capability
- `Type::Enhancement` - Improvement to existing feature
- `Type::Documentation` - Documentation updates or additions
- `Type::Test` - Test creation or improvement

## Epic Management

### Epic Structure
Epics represent major features or initiatives spanning multiple sprints.

#### Epic Description Template
```markdown
## Epic: [Name]
**Goal**: Clear objective statement
**Status**: 🟡 In Progress (X/Y features complete)

### Key Features
- [x] Completed feature with brief description
- [/] In progress feature with current status
- [ ] Planned feature with acceptance criteria

### Success Criteria
- Measurable outcome 1
- Measurable outcome 2
- Performance or quality targets

### Timeline
- **Start Date**: YYYY-MM-DD
- **Target Completion**: YYYY-MM-DD
- **Dependencies**: List any blocking epics or external factors

### Progress Tracking
- **Completed**: X issues
- **In Progress**: Y issues  
- **Remaining**: Z issues
- **Completion**: XX%
```

### Epic Progress Tracking
```bash
# Generate epic progress report
./scripts/epic-progress.sh

# Update epic documentation
# Edit wiki/Planning/EPICS.md manually

# View epic board in GitLab
# Navigate to Project → Boards → Epic Board
```

### Current Active Epics
- **epic::mathematical-core** - Core mathematical functionality
- **epic::test-framework** - Comprehensive testing infrastructure
- **epic::julia-optimization** - Performance and memory optimization
- **epic::documentation** - User and developer documentation
- **epic::advanced-features** - Next-generation capabilities

## Task Estimation

### Effort Sizing
- **Small** (1-2 days): Bug fixes, minor enhancements
- **Medium** (3-5 days): New features, significant changes
- **Large** (1-2 weeks): Major features, architectural changes

### Estimation Guidelines
1. **Break down large tasks** into smaller, manageable pieces
2. **Consider complexity** and unknowns
3. **Account for testing** and documentation time
4. **Include code review** and iteration cycles

## Workflow Automation

### GitLab Board Configuration

#### Development Board
```
Columns: Backlog | Ready | In Progress | Review | Testing | Done
Filter: Current milestone
Sort: Priority (Critical → Low)
```

#### Priority Board
```
Columns: Critical | High | Medium | Low
Filter: Open issues
Sort: Created date (newest first)
```

#### Epic Board
```
Columns: One per active epic
Filter: Epic labels
Sort: Epic priority
```

### Automated Workflows
- **Status transitions**: Manual via drag-and-drop or label changes
- **Notifications**: GitLab mentions and subscriptions
- **Progress tracking**: Automated via milestone completion
- **Reporting**: Custom scripts in `./scripts/` directory

## Quality Gates

### Code Review Checklist
- [ ] **Functionality**: Code works as intended
- [ ] **Tests**: Adequate test coverage
- [ ] **Documentation**: Code is well-documented
- [ ] **Style**: Follows project conventions
- [ ] **Performance**: No obvious performance issues
- [ ] **Security**: No security vulnerabilities

### Definition of Ready
Before starting work on an issue:
- [ ] **Clear requirements**: Acceptance criteria defined
- [ ] **Estimated effort**: Size/complexity understood
- [ ] **Dependencies resolved**: No blocking issues
- [ ] **Assigned**: Owner identified
- [ ] **Prioritized**: Fits in current sprint

### Definition of Done
Before closing an issue:
- [ ] **Code complete**: All functionality implemented
- [ ] **Tests passing**: Unit and integration tests pass
- [ ] **Code reviewed**: Approved by team member
- [ ] **Documentation updated**: If applicable
- [ ] **Merged**: Changes integrated to main branch
- [ ] **Acceptance criteria met**: All requirements satisfied

## Troubleshooting

### Common Issues

#### Label Problems
```bash
# Missing or incorrect labels
./scripts/setup-gitlab-labels.sh

# Check current label configuration
./scripts/gitlab-explore.sh | grep -i label
```

#### Milestone Issues
```bash
# Wrong milestone assignment
# Update CURRENT_MILESTONE_ID in .env.gitlab

# Create new milestone
./scripts/create-sprint-milestone.sh
```

#### API Access Problems
```bash
# Test GitLab API connection
./scripts/gitlab-explore.sh

# Verify environment variables
echo $GITLAB_PROJECT_ID
echo $GITLAB_PRIVATE_TOKEN
```

### Error Resolution

#### "API token invalid"
- Check token permissions in GitLab settings
- Verify token hasn't expired
- Ensure token has appropriate scopes

#### "Project not found"
- Verify GITLAB_PROJECT_ID is correct (should be 2545)
- Check API URL matches GitLab instance
- Confirm access permissions to project

#### "Milestone not found"
- Update CURRENT_MILESTONE_ID in environment
- Create milestone if it doesn't exist
- Check milestone is in correct project

## Best Practices

### Issue Management
1. **Keep issues focused**: One clear objective per issue
2. **Update regularly**: Change status as work progresses
3. **Use templates**: Ensure consistent information
4. **Link related issues**: Show dependencies and relationships

### Communication
1. **Comment on progress**: Keep stakeholders informed
2. **Tag relevant people**: Use @mentions for notifications
3. **Document decisions**: Record important choices in issues
4. **Share blockers**: Communicate impediments early

### Process Improvement
1. **Review regularly**: Assess workflow effectiveness
2. **Gather feedback**: Ask team for improvement suggestions
3. **Iterate process**: Make small, incremental changes
4. **Measure impact**: Track metrics to validate improvements
