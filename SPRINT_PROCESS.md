# Sprint Process Guide

## Sprint Cadence
- **Duration**: 2 weeks
- **Start**: Monday
- **End**: Friday (second week)

## Sprint Events

### 1. Sprint Planning (Day 1)
- **Duration**: 2 hours
- **Agenda**:
  1. Review previous sprint outcomes
  2. Define sprint goal
  3. Select items from backlog
  4. Break down into tasks
  5. Assign ownership

### 2. Daily Standups
- **Duration**: 15 minutes
- **Format**: Async updates in GitLab
- **Questions**:
  - What did I complete yesterday?
  - What will I work on today?
  - Any blockers?

### 3. Sprint Review (Day 10)
- **Duration**: 1 hour
- **Agenda**:
  1. Demo completed features
  2. Review metrics
  3. Gather feedback

### 4. Sprint Retrospective (Day 10)
- **Duration**: 45 minutes
- **Format**:
  - What went well?
  - What could improve?
  - Action items

## Issue Workflow

### Status Progression
```
backlog → ready → in-progress → review → testing → done
```

### Definition of Done
- [ ] Code complete and pushed
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] Code reviewed and approved
- [ ] Merged to main branch

## Roles

### Product Owner
- Maintains backlog
- Defines acceptance criteria
- Prioritizes work

### Scrum Master
- Facilitates ceremonies
- Removes blockers
- Tracks metrics

### Developers
- Implement features
- Write tests
- Review code

## Metrics to Track

1. **Velocity**: Story points completed
2. **Burndown**: Daily progress
3. **Cycle Time**: Issue start to done
4. **Code Coverage**: Test percentage

## GitLab Setup

### Milestones
- One per sprint
- Named: "Sprint YYYY-MM"
- Include goals in description

### Labels
- **Status**: Track workflow state
- **Priority**: P0 (critical) to P3 (low)
- **Type**: Feature, bug, test, docs
- **Epic**: Group related work

### Boards
1. **Development Board**
   - Columns by status label
   - Filter by current milestone

2. **Priority Board**
   - Columns by priority
   - Identify critical path

## Commands

```bash
# Create new sprint
./scripts/create-sprint-milestone.sh

# Add sprint issues
./scripts/create-sprint-issues.sh

# View sprint progress
./scripts/sprint-status.sh
```

## Best Practices

1. **Keep issues small**: 1-3 days of work
2. **Update daily**: Move cards, add comments
3. **Block early**: Raise impediments ASAP
4. **Demo everything**: Even small changes
5. **Automate metrics**: Use GitLab insights
