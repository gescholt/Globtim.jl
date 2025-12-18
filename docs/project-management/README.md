# Project Management Documentation

This directory contains all project management documentation for Globtim.jl development.

## 🚀 GitLab Workflow (Current System)

### Quick Start
```bash
# 1. Setup GitLab integration
cp tools/gitlab/config.json.template tools/gitlab/config.json
# Edit with your GitLab project ID and access token

# 2. Install automation hooks
./tools/gitlab/install_hooks.sh install

# 3. Migrate existing tasks
./tools/gitlab/migrate_tasks.sh full
```

### Daily Commands
```bash
# Start work on issue
python3 tools/gitlab/task_sync.py create-branch 123

# Commit work (auto-syncs with GitLab)
git commit -m "Fix bug, closes #123"

# Check status
./tools/gitlab/install_hooks.sh status
```

### 📋 Project Boards
- **[Development Workflow](https://git.mpi-cbg.de/globaloptim/globtimcore/-/boards)** - Daily task management
- **[Epic Progress](https://git.mpi-cbg.de/globaloptim/globtimcore/-/boards)** - Strategic project tracking
- **[Priority Focus](https://git.mpi-cbg.de/globaloptim/globtimcore/-/boards)** - Urgency-based prioritization

### Issue Management Workflow
```
backlog → ready → in-progress → review → testing → done
```

**Required Labels:**
- **Status**: `status::backlog|ready|in-progress|review|testing|done`
- **Priority**: `Priority::Critical|High|Medium|Low`
- **Type**: `Type::Bug|Feature|Enhancement|Documentation|Test`

## 📚 Documentation Structure

### GitLab Workflow (Current System)
- **[GitLab Workflow Guide](gitlab-workflow-guide.md)** - Complete workflow documentation
- **[GitLab Quick Reference](gitlab-quick-reference.md)** - Daily commands and shortcuts
- **[GitLab Issue Structure](gitlab-issue-structure.md)** - Labels, templates, and standards
- **[GitLab Boards Guide](gitlab-boards-guide.md)** - Project boards usage and management
- **[Boards Quick Reference](boards-quick-reference.md)** - Board links and quick actions
- **[Task Landscape Analysis](task-landscape-analysis.md)** - Migration planning analysis

### Migration Tools
- **[Migration Tools README](../../tools/gitlab/README.md)** - Tool documentation
- **Task Extractor**: `tools/gitlab/task_extractor.py` - Extract tasks from repository
- **GitLab Manager**: `tools/gitlab/gitlab_manager.py` - Create/manage GitLab issues
- **Task Sync**: `tools/gitlab/task_sync.py` - Sync development work with issues
- **Migration Script**: `tools/gitlab/migrate_tasks.sh` - Complete migration workflow

### Legacy Documentation
- **[GitLab Workflow](gitlab-workflow.md)** - Original GitLab setup guide
- **[Sprint Process](sprint-process.md)** - Sprint planning procedures
- **[Task Management](task-management.md)** - Original issue management guide

## 🚀 Getting Started

### Initial Setup
```bash
# Set environment variables
export GITLAB_PROJECT_ID="2859"
export GITLAB_PRIVATE_TOKEN="your-token"

# Create labels
./scripts/setup-gitlab-labels.sh

# Test connection
./scripts/gitlab-explore.sh
```

### Environment File (.env.gitlab)
```bash
GITLAB_PROJECT_ID=2859
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

- **GitLab Project**: https://git.mpi-cbg.de/globaloptim/globtimcore
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
