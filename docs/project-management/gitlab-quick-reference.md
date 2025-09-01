# GitLab Workflow Quick Reference

## 🚀 Setup (One-time)

```bash
# 1. Configure GitLab
cp tools/gitlab/config.json.template tools/gitlab/config.json
# Edit with your project ID and access token

# 2. Install hooks
./tools/gitlab/install_hooks.sh install

# 3. Migrate existing tasks
./tools/gitlab/migrate_tasks.sh full
```

## 📋 Daily Commands

### Start Work on Issue
```bash
# Method 1: Manual
python3 tools/gitlab/task_sync.py start 123

# Method 2: Create branch (recommended)
python3 tools/gitlab/task_sync.py create-branch 123
# Creates branch: issue-123-title-slug
```

### Commit Work
```bash
# Regular commit (auto-adds issue reference)
git commit -m "Fix memory leak"
# → Becomes: "Fix memory leak\n\nRefs #123"

# Closing commit
git commit -m "Complete implementation, closes #123"
```

### Complete Work
```bash
# Automatic (via commit message)
git commit -m "Final fix, closes #123"

# Manual
python3 tools/gitlab/task_sync.py complete 123
```

## 🏷️ Required Labels

Every issue needs:
- **Status**: `status::backlog|ready|in-progress|review|testing|done`
- **Priority**: `Priority::Critical|High|Medium|Low`
- **Type**: `Type::Bug|Feature|Enhancement|Documentation|Test`

## 📝 Issue Templates

- **Feature**: `.gitlab/issue_templates/feature.md`
- **Bug**: `.gitlab/issue_templates/bug.md`
- **Task Migration**: `.gitlab/issue_templates/task-migration.md`
- **Epic**: `.gitlab/issue_templates/epic.md`

## 🔄 Status Flow

```
backlog → ready → in-progress → review → testing → done
```

## 🌿 Branch Naming

```bash
issue-123-fix-memory-leak
issue-456-add-tests
feature-789-new-algorithm
bugfix-321-hpc-deployment
```

## 💬 Commit Messages

### Keywords that close issues:
- `closes #123`
- `fixes #123`
- `resolves #123`

### Keywords that reference issues:
- `refs #123`
- `implements #123`
- `#123` (simple reference)

## 🛠️ Troubleshooting

### Check Status
```bash
./tools/gitlab/install_hooks.sh status
```

### Reinstall Hooks
```bash
./tools/gitlab/install_hooks.sh uninstall
./tools/gitlab/install_hooks.sh install
```

### Test GitLab Connection
```bash
python3 tools/gitlab/gitlab_manager.py \
    --config tools/gitlab/config.json \
    --tasks /dev/null \
    --dry-run
```

### Manual Sync
```bash
python3 tools/gitlab/task_sync.py sync-status --dry-run
```

## 📊 GitLab Boards

### Issue Board Lists
- Backlog (`status::backlog`)
- Ready (`status::ready`)
- In Progress (`status::in-progress`)
- Review (`status::review`)
- Testing (`status::testing`)
- Done (`status::done`)

### Epic Board Lists
- Mathematical Core (`epic::mathematical-core`)
- Test Framework (`epic::test-framework`)
- Performance (`epic::performance`)
- Documentation (`epic::documentation`)
- HPC Deployment (`epic::hpc-deployment`)

## 🔧 Advanced Commands

### Bulk Migration
```bash
# Extract tasks only
./tools/gitlab/migrate_tasks.sh extract

# Dry run only
./tools/gitlab/migrate_tasks.sh dry-run

# Migrate only
./tools/gitlab/migrate_tasks.sh migrate
```

### Custom Task Extraction
```bash
python3 tools/gitlab/task_extractor.py \
    --repo-root . \
    --output custom_tasks.json \
    --summary
```

### Sync Commands
```bash
# Start work
python3 tools/gitlab/task_sync.py start 123

# Complete work
python3 tools/gitlab/task_sync.py complete 123

# Sync from commit
python3 tools/gitlab/task_sync.py sync-commit

# Sync current status
python3 tools/gitlab/task_sync.py sync-status
```

## 📁 File Locations

- **Config**: `tools/gitlab/config.json`
- **Migration Tools**: `tools/gitlab/`
- **Documentation**: `docs/project-management/`
- **Issue Templates**: `.gitlab/issue_templates/`
- **Git Hooks**: `.git/hooks/`

## 🎯 Best Practices

1. **Always create branches from issues**
2. **Use descriptive commit messages**
3. **Reference issues in commits**
4. **Update issue status regularly**
5. **Apply all required labels**
6. **Write clear acceptance criteria**
7. **Close completed work promptly**

## 🆘 Emergency Procedures

### Disable Hooks Temporarily
```bash
chmod -x .git/hooks/post-commit
chmod -x .git/hooks/prepare-commit-msg
chmod -x .git/hooks/commit-msg
```

### Re-enable Hooks
```bash
chmod +x .git/hooks/post-commit
chmod +x .git/hooks/prepare-commit-msg
chmod +x .git/hooks/commit-msg
```

### Rollback Migration
```bash
# Migration creates issues but doesn't delete local tasks
# To rollback: manually close/delete GitLab issues
# Local tasks remain in original documentation
```

---

**For detailed information, see**: `docs/project-management/gitlab-workflow-guide.md`
