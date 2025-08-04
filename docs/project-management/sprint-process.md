# Sprint Process Guide

## Sprint Overview

### Sprint Cadence
- **Duration**: 2 weeks
- **Start**: Monday
- **End**: Friday (second week)
- **Naming**: "Sprint YYYY-MM" (e.g., "Sprint 2025-01")

### Sprint Goals
Each sprint should have:
1. **Primary objective** with clear success criteria
2. **Secondary objective** with specific deliverables
3. **Stretch goal** if capacity allows

## Sprint Events

### 1. Sprint Planning (Day 1)
**Duration**: 2-4 hours
**Participants**: Full team

**Agenda**:
1. Review previous sprint outcomes and metrics
2. Define sprint goal and success criteria
3. Select items from product backlog
4. Break down epics into implementable tasks
5. Assign ownership and estimate effort
6. Commit to sprint backlog

**Deliverables**:
- Sprint goal documented in milestone description
- Issues assigned to sprint milestone
- Tasks estimated and assigned

### 2. Daily Standups
**Format**: Asynchronous updates in GitLab issues
**Frequency**: Daily during sprint

**Update Template**:
```
## Daily Update - [Date]
**Completed**: What I finished yesterday
**Today**: What I'm working on today  
**Blockers**: Any impediments or help needed
```

### 3. Sprint Review (Day 10)
**Duration**: 1-2 hours
**Participants**: Team + stakeholders

**Agenda**:
1. Demo completed features and functionality
2. Review sprint metrics and velocity
3. Gather feedback from stakeholders
4. Update product backlog based on learnings

### 4. Sprint Retrospective (Day 10)
**Duration**: 1 hour
**Participants**: Development team only

**Format**:
- **What went well?** - Celebrate successes
- **What could improve?** - Identify pain points
- **Action items** - Concrete steps for next sprint

## Issue Workflow

### Status Progression
```
backlog → ready → in-progress → review → testing → done
```

### Status Definitions
- **backlog**: Identified but not yet prioritized
- **ready**: Prioritized and ready for development
- **in-progress**: Actively being worked on
- **review**: Code complete, awaiting review
- **testing**: Under testing/validation
- **done**: Complete and accepted

### Definition of Done
Before marking an issue as "done":
- [ ] Code complete and pushed to feature branch
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Documentation updated (if applicable)
- [ ] Code reviewed and approved
- [ ] Merged to main branch
- [ ] Acceptance criteria met

## Sprint Management Commands

### Create New Sprint
```bash
# Create milestone for new sprint
./scripts/create-sprint-milestone.sh

# Update environment with new milestone ID
echo "CURRENT_MILESTONE_ID=new-milestone-id" >> .env.gitlab

# Plan sprint issues
./scripts/create-sprint-issues.sh
```

### Monitor Sprint Progress
```bash
# View current sprint dashboard
./scripts/sprint-dashboard.sh

# Check detailed sprint status
./scripts/sprint-status.sh

# Generate sprint report
./scripts/sprint-dashboard.sh > sprint-review.md
```

### End Sprint
```bash
# Generate final sprint report
./scripts/sprint-dashboard.sh > sprint-$(date +%Y-%m)-review.md

# Move incomplete issues to next sprint
# (Manual process in GitLab UI)

# Close milestone in GitLab
# (Manual process in GitLab UI)
```

## Metrics and Tracking

### Key Metrics
1. **Velocity**: Story points or issues completed per sprint
2. **Burndown**: Daily progress toward sprint goal
3. **Cycle Time**: Average time from "ready" to "done"
4. **Completion Rate**: Percentage of planned work finished

### Sprint Health Indicators
- 🟢 **Healthy**: On track for sprint goal
- 🟡 **At Risk**: Behind schedule but recoverable
- 🔴 **Critical**: Sprint goal in jeopardy

### Tracking Tools
- **GitLab Boards**: Visual workflow management
- **Milestone Progress**: Completion percentage
- **Issue Analytics**: Cycle time and throughput
- **Custom Scripts**: Automated reporting

## Roles and Responsibilities

### Product Owner
- Maintains and prioritizes product backlog
- Defines acceptance criteria for user stories
- Makes decisions on scope and priorities
- Participates in sprint planning and review

### Scrum Master/Facilitator
- Facilitates sprint ceremonies
- Removes blockers and impediments
- Tracks metrics and sprint health
- Coaches team on process improvements

### Development Team
- Implements features and fixes bugs
- Writes tests and documentation
- Reviews code and provides feedback
- Estimates effort and commits to work

## Best Practices

### Sprint Planning
1. **Keep issues small**: 1-3 days of work maximum
2. **Define clear acceptance criteria**: Avoid ambiguity
3. **Consider dependencies**: Plan work order carefully
4. **Leave buffer time**: Account for unexpected issues

### During Sprint
1. **Update status daily**: Keep boards current
2. **Communicate blockers early**: Don't wait for standups
3. **Focus on sprint goal**: Avoid scope creep
4. **Collaborate actively**: Help teammates when possible

### Sprint Review
1. **Demo everything**: Even small improvements
2. **Gather feedback**: Listen to stakeholder input
3. **Be honest about challenges**: Discuss what didn't work
4. **Update backlog**: Incorporate learnings

### Retrospectives
1. **Create safe space**: Encourage honest feedback
2. **Focus on process**: Not individual performance
3. **Generate actionable items**: Specific improvements
4. **Follow up**: Check progress on action items

## Common Challenges

### Scope Creep
- **Problem**: Adding work mid-sprint
- **Solution**: Defer to next sprint unless critical

### Blocked Issues
- **Problem**: Dependencies preventing progress
- **Solution**: Escalate quickly, find alternatives

### Incomplete Work
- **Problem**: Issues not meeting definition of done
- **Solution**: Move to next sprint, improve estimation

### Team Capacity
- **Problem**: Over/under-committing to work
- **Solution**: Track velocity, adjust planning
