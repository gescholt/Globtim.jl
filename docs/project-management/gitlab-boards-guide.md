# GitLab Boards Usage Guide

## Overview

GitLab boards provide visual project management through customizable kanban-style boards. This guide covers the three main boards configured for the Globtim project.

## 🎛️ **Board System Architecture**

### **Three-Board Strategy**
1. **Development Workflow** - Daily task management
2. **Epic Progress** - Strategic project tracking  
3. **Priority Focus** - Urgency-based work prioritization

## 📋 **Development Workflow Board**

### **Purpose**
Primary board for daily development workflow management and sprint execution.

### **Board URL**
[Development Workflow Board](https://git.mpi-cbg.de/scholten/globtim/-/boards)

### **Column Structure**
| Column | Label | Purpose | Actions |
|--------|-------|---------|---------|
| 📋 **Backlog** | `status::backlog` | Identified work not yet started | Prioritize, refine, assign |
| 🚀 **Ready** | `status::ready` | Work ready to begin | Pick up, start development |
| 🔄 **In Progress** | `status::in-progress` | Active development work | Update progress, collaborate |
| 👀 **Review** | `status::review` | Code/work ready for review | Review, approve, request changes |
| 🧪 **Testing** | `status::testing` | Work under testing/validation | Test, validate, verify |
| ✅ **Done** | `status::done` | Completed and accepted work | Archive, celebrate |
| 🚫 **Blocked** | `status::blocked` | Work stopped by dependencies | Resolve blockers, escalate |

### **Workflow Process**
```
Backlog → Ready → In Progress → Review → Testing → Done
    ↓         ↓         ↓          ↓         ↓
  Blocked ← Blocked ← Blocked ← Blocked ← Blocked
```

### **Usage Guidelines**
- **Daily Standup**: Review In Progress and Blocked columns
- **Sprint Planning**: Move items from Backlog to Ready
- **Work Assignment**: Assign yourself to issues when moving to In Progress
- **Status Updates**: Move cards as work progresses, add comments for context

## 🎯 **Epic Progress Board**

### **Purpose**
Strategic view of progress across major project areas and long-term initiatives.

### **Board URL**
[Epic Progress Board](https://git.mpi-cbg.de/scholten/globtim/-/boards)

### **Column Structure**
| Column | Label | Focus Area | Goals |
|--------|-------|------------|-------|
| 🧮 **Mathematical Core** | `epic::mathematical-core` | Core algorithms | Polynomial solving, critical point analysis |
| 🧪 **Test Framework** | `epic::test-framework` | Testing infrastructure | Comprehensive test coverage, validation |
| ⚡ **Performance** | `epic::performance` | Optimization work | Speed improvements, memory efficiency |
| 📚 **Documentation** | `epic::documentation` | User guides, docs | Installation guides, API documentation |
| 🖥️ **HPC Deployment** | `epic::hpc-deployment` | Cluster work | Furiosa deployment, scaling |
| 📊 **Visualization** | `epic::visualization` | Plotting, dashboards | Result visualization, monitoring |
| 🚀 **Advanced Features** | `epic::advanced-features` | Next-gen capabilities | Future enhancements, research |

### **Usage Guidelines**
- **Epic Planning**: Balance work across different areas
- **Progress Tracking**: Monitor epic completion percentages
- **Resource Allocation**: Ensure adequate attention to each epic
- **Strategic Reviews**: Weekly epic progress assessment

## ⚡ **Priority Focus Board**

### **Purpose**
Urgency-based view to ensure critical and high-priority work gets immediate attention.

### **Board URL**
[Priority Focus Board](https://git.mpi-cbg.de/scholten/globtim/-/boards)

### **Column Structure**
| Column | Label | Urgency Level | Response Time |
|--------|-------|---------------|---------------|
| 🔴 **Critical** | `Priority::Critical` | Blocking, immediate | Same day |
| 🟡 **High** | `Priority::High` | Important for goals | Within 3 days |
| 🔵 **Medium** | `Priority::Medium` | Standard priority | Within 2 weeks |
| 🟢 **Low** | `Priority::Low` | Nice to have | When capacity allows |

### **Usage Guidelines**
- **Daily Priority Check**: Review Critical and High columns first
- **Capacity Planning**: Balance high-priority work with medium/low items
- **Escalation**: Move items up in priority when circumstances change
- **Focus Time**: Dedicate specific time blocks to high-priority work

## 🔧 **Board Management**

### **Creating New Issues from Boards**
1. Click "+" button in any column
2. Fill in issue title and description
3. Labels are automatically applied based on column
4. Assign to team member if known
5. Set milestone if applicable

### **Moving Issues Between Columns**
1. **Drag and Drop**: Simply drag issue cards between columns
2. **Label Updates**: Labels automatically update to match column
3. **Status Sync**: Issue status reflects current column position
4. **History Tracking**: All moves are logged in issue activity

### **Board Filtering and Search**
- **Assignee Filter**: Show only issues assigned to specific person
- **Milestone Filter**: Focus on specific sprint or release
- **Label Filter**: Combine multiple label filters
- **Search**: Find issues by title, description, or ID

## 📊 **Board Analytics and Metrics**

### **Key Metrics to Track**
- **Cycle Time**: Time from Ready to Done
- **Lead Time**: Time from Backlog to Done  
- **Work in Progress**: Number of items in In Progress
- **Blocked Items**: Issues stuck in Blocked status
- **Epic Balance**: Distribution of work across epics
- **Priority Distribution**: Balance of priority levels

### **Weekly Board Review**
1. **Throughput**: How many issues moved to Done?
2. **Bottlenecks**: Which columns have too many items?
3. **Blocked Work**: What's preventing progress?
4. **Epic Progress**: Are we making balanced progress?
5. **Priority Alignment**: Are we working on the right things?

## 🎯 **Best Practices**

### **Issue Management**
- **Clear Titles**: Use descriptive, actionable issue titles
- **Proper Labels**: Ensure all required labels are applied
- **Regular Updates**: Add comments when status changes
- **Acceptance Criteria**: Define clear completion criteria

### **Board Hygiene**
- **Daily Updates**: Move cards as work progresses
- **Clean Descriptions**: Keep issue descriptions current
- **Archive Completed**: Regularly clean up Done column
- **Review Blocked**: Weekly review of blocked items

### **Team Collaboration**
- **Assign Ownership**: Clear assignment of work items
- **Communicate Changes**: Notify team of priority changes
- **Share Context**: Add comments explaining decisions
- **Regular Reviews**: Team board reviews in standups

## 🔗 **Integration with Development Workflow**

### **Git Integration**
- **Branch Naming**: Use issue numbers in branch names (`issue-2-project-boards`)
- **Commit Messages**: Reference issues in commits (`refs #2`, `closes #2`)
- **Merge Requests**: Link MRs to issues for automatic closure

### **Automation**
- **Status Updates**: Git hooks can update issue status
- **Board Sync**: Commits can move issues between columns
- **Notifications**: Team notifications for board changes

## 📱 **Mobile Access**

### **Mobile Usage**
- **Responsive Design**: Boards work on mobile devices
- **Touch Interface**: Drag and drop works on tablets
- **Quick Updates**: Easy status updates on the go
- **Notifications**: Mobile notifications for board changes

## 🆘 **Troubleshooting**

### **Common Issues**
- **Labels Not Syncing**: Check board configuration and label permissions
- **Cards Not Moving**: Verify user permissions and board settings
- **Missing Issues**: Check filters and search settings
- **Performance Issues**: Consider reducing number of visible issues

### **Getting Help**
- **GitLab Documentation**: [GitLab Boards Documentation](https://docs.gitlab.com/ee/user/project/issue_board.html)
- **Team Support**: Ask team members for board usage help
- **Admin Support**: Contact project maintainers for configuration issues

## 🚀 **Quick Start Checklist**

### **For New Team Members**
- [ ] Bookmark all three board URLs
- [ ] Understand column meanings and workflow
- [ ] Practice moving test issues between columns
- [ ] Set up board notifications
- [ ] Review current sprint items in Ready column

### **For Daily Use**
- [ ] Check Priority Focus board for urgent items
- [ ] Review Development Workflow for your assigned work
- [ ] Update issue status as work progresses
- [ ] Add comments when moving items to Review/Testing
- [ ] Move completed work to Done column

This board system provides comprehensive project visibility while maintaining simplicity for daily use. The three-board approach ensures both tactical execution and strategic oversight of the Globtim project.
