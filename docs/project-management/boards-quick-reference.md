# GitLab Boards Quick Reference

## 🔗 **Board Links**

| Board | Purpose | URL |
|-------|---------|-----|
| 📋 **Development Workflow** | Daily task management | [View Board](https://git.mpi-cbg.de/scholten/globtim/-/boards) |
| 🎯 **Epic Progress** | Strategic project tracking | [View Board](https://git.mpi-cbg.de/scholten/globtim/-/boards) |
| ⚡ **Priority Focus** | Urgency-based prioritization | [View Board](https://git.mpi-cbg.de/scholten/globtim/-/boards) |

## 📋 **Development Workflow**

### **Column Flow**
```
📋 Backlog → 🚀 Ready → 🔄 In Progress → 👀 Review → 🧪 Testing → ✅ Done
     ↓           ↓           ↓             ↓           ↓
   🚫 Blocked ← Blocked ← Blocked ← Blocked ← Blocked
```

### **Status Labels**
- `status::backlog` - Identified but not started
- `status::ready` - Ready to begin work
- `status::in-progress` - Active development
- `status::review` - Awaiting code/work review
- `status::testing` - Under testing/validation
- `status::done` - Completed and accepted
- `status::blocked` - Stopped by dependencies

## 🎯 **Epic Progress**

### **Epic Categories**
- 🧮 **Mathematical Core** (`epic::mathematical-core`) - Core algorithms
- 🧪 **Test Framework** (`epic::test-framework`) - Testing infrastructure
- ⚡ **Performance** (`epic::performance`) - Optimization work
- 📚 **Documentation** (`epic::documentation`) - User guides, docs
- 🖥️ **HPC Deployment** (`epic::hpc-deployment`) - Cluster work
- 📊 **Visualization** (`epic::visualization`) - Plotting, dashboards
- 🚀 **Advanced Features** (`epic::advanced-features`) - Next-gen capabilities

## ⚡ **Priority Focus**

### **Priority Levels**
- 🔴 **Critical** (`Priority::Critical`) - Blocking, same day response
- 🟡 **High** (`Priority::High`) - Important, 3-day response
- 🔵 **Medium** (`Priority::Medium`) - Standard, 2-week response
- 🟢 **Low** (`Priority::Low`) - Nice to have, when capacity allows

## 🚀 **Quick Actions**

### **Daily Workflow**
1. **Morning**: Check Priority Focus for urgent items
2. **Work**: Use Development Workflow for task management
3. **Planning**: Review Epic Progress for balance
4. **Updates**: Move cards as work progresses

### **Moving Issues**
- **Drag & Drop**: Move cards between columns
- **Auto-Labels**: Labels update automatically
- **Add Comments**: Explain status changes
- **Assign Work**: Assign to yourself when starting

### **Creating Issues**
- **From Board**: Click "+" in any column
- **Auto-Labels**: Column labels applied automatically
- **Set Priority**: Choose appropriate priority level
- **Add Epic**: Assign to relevant epic

## 📊 **Key Metrics**

### **Daily Checks**
- **In Progress**: Keep to 3-4 items per person
- **Blocked**: Address blockers immediately
- **Review**: Don't let items sit too long
- **Done**: Celebrate completed work

### **Weekly Reviews**
- **Throughput**: Items moved to Done
- **Cycle Time**: Ready → Done duration
- **Epic Balance**: Work distribution
- **Priority Mix**: Critical/High vs Medium/Low

## 🎯 **Best Practices**

### **Issue Management**
- ✅ Use clear, actionable titles
- ✅ Apply all required labels
- ✅ Update status as work progresses
- ✅ Add comments for context
- ✅ Define acceptance criteria

### **Board Hygiene**
- ✅ Move cards daily
- ✅ Keep descriptions current
- ✅ Archive completed work
- ✅ Review blocked items weekly

### **Team Collaboration**
- ✅ Assign clear ownership
- ✅ Communicate priority changes
- ✅ Share context in comments
- ✅ Regular team board reviews

## 🔧 **Common Tasks**

### **Start New Work**
1. Check Priority Focus for urgent items
2. Pick item from Ready column
3. Assign to yourself
4. Move to In Progress
5. Create branch: `git checkout -b issue-X-description`

### **Complete Work**
1. Move to Review column
2. Create merge request
3. Link MR to issue
4. Request review from team
5. After approval, move to Done

### **Handle Blockers**
1. Move to Blocked column
2. Add comment explaining blocker
3. Tag relevant people
4. Set up follow-up
5. Move back when unblocked

## 📱 **Mobile Usage**

### **Quick Mobile Actions**
- ✅ Check priority items
- ✅ Update issue status
- ✅ Add progress comments
- ✅ Review team work
- ✅ Move completed items

## 🆘 **Troubleshooting**

### **Common Issues**
| Problem | Solution |
|---------|----------|
| Cards won't move | Check permissions and board config |
| Labels not syncing | Verify label configuration |
| Missing issues | Check filters and search |
| Slow loading | Reduce visible issues |

### **Quick Fixes**
- **Refresh browser** for sync issues
- **Clear filters** to see all issues
- **Check permissions** for access problems
- **Contact admin** for configuration issues

## 📞 **Support**

### **Documentation**
- **Full Guide**: `docs/project-management/gitlab-boards-guide.md`
- **GitLab Docs**: [Official Boards Documentation](https://docs.gitlab.com/ee/user/project/issue_board.html)

### **Team Support**
- **Ask in chat** for quick questions
- **Tag maintainers** for configuration issues
- **Create issue** for board improvements

---

**💡 Pro Tip**: Bookmark this page and the board URLs for quick daily access!
