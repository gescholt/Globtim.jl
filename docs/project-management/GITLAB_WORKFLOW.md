# GitLab Project Management

Complete guide to GitLab-based project management for Globtim development.

## Interaction Methods

### MCP GitLab Tools (Primary - Recommended)

**IMPORTANT**: Use MCP GitLab integration tools for all GitLab operations. These tools are available in Claude Code and provide direct API access without requiring local authentication setup.

**Available Projects**:
- `globaloptim/globtimcore` - Core optimization library
- `globaloptim/GlobTimRL` - Reinforcement learning components
- `globaloptim/globtimplots` - Plotting utilities
- `globaloptim/globtimpostprocessing` - Post-processing tools
- `globaloptim/globtim-integration-tests` - Integration tests
- `globaloptim/globtim_results` - Results repository

**Common Operations**:
```julia
# View an issue
mcp__gitlab__get_issue(project_id="globaloptim/globtimcore", issue_iid="153")

# List issues
mcp__gitlab__list_issues(
    project_id="globaloptim/globtimcore",
    state="opened",
    assignee_id="@me"
)

# Create a comment/note
mcp__gitlab__create_issue_note(
    project_id="globaloptim/globtimcore",
    issue_iid="153",
    body="Comment text"
)

# Update issue (e.g., change status)
mcp__gitlab__update_issue(
    project_id="globaloptim/globtimcore",
    issue_iid="153",
    state_event="close"  # or "reopen"
)

# Create merge request
mcp__gitlab__create_merge_request(
    project_id="globaloptim/globtimcore",
    title="Fix bug",
    source_branch="feature-branch",
    target_branch="master"
)

# Get merge request
mcp__gitlab__get_merge_request(
    project_id="globaloptim/GlobTimRL",
    merge_request_iid="42"
)
```

**Key Notes**:
- ✅ Use full project paths: `globaloptim/globtimcore` (not just `globtimcore`)
- ✅ MCP tools work from any directory (no `cd` needed)
- ✅ All operations are type-safe and validated
- ✅ Automatic handling of GitLab API authentication
- ✅ No local configuration files required

### CLI Wrapper (Legacy - For Automation Scripts Only)

For automated scripts and CI/CD pipelines:
```bash
# Use the multi-repo wrapper
/Users/ghscholt/GlobalOptim/scripts/glab-multi-repo.sh globtimcore issue view 153
/Users/ghscholt/GlobalOptim/scripts/glab-multi-repo.sh GlobTimRL issue note 42 -m "Comment"
```

**NEVER**:
- ❌ Use `glab` commands directly without the wrapper
- ❌ Use short project names with MCP (use `globaloptim/project` format)
- ❌ Guess project IDs - always use full paths

## Quick Start

### Initial Setup (One-time)
```bash
# 1. Install Git hooks for automatic sync (optional)
./tools/gitlab/install_hooks.sh install

# 2. Verify setup
./tools/gitlab/install_hooks.sh status
```

**Note**: MCP tools don't require configuration files. The legacy config.json is only needed for the Python automation scripts.

### Daily Workflow

**Using MCP Tools (Recommended)**:
```julia
# View open issues
mcp__gitlab__list_issues(
    project_id="globaloptim/globtimcore",
    state="opened"
)

# Comment on issue
mcp__gitlab__create_issue_note(
    project_id="globaloptim/globtimcore",
    issue_iid="123",
    body="Working on this now"
)

# Close issue when done
mcp__gitlab__update_issue(
    project_id="globaloptim/globtimcore",
    issue_iid="123",
    state_event="close"
)
```

**Using Git Hooks (Legacy)**:
```bash
# Start work on an issue
python3 tools/gitlab/task_sync.py create-branch 123

# Work normally - hooks handle sync automatically
git commit -m "Fix memory leak, refs #123"
git commit -m "Complete implementation, closes #123"

# Check status
./tools/gitlab/install_hooks.sh status
```

## Issue Management

### Required Labels

Every issue must have these labels:

**Status** (required):
- `status::backlog` - Identified but not prioritized
- `status::ready` - Ready for development
- `status::in-progress` - Actively being worked on
- `status::review` - Code complete, awaiting review
- `status::testing` - Under testing/validation
- `status::done` - Complete and accepted
- `status::blocked` - Cannot proceed due to dependencies

**Priority** (required):
- `Priority::Critical` - Blocking, immediate attention
- `Priority::High` - Important for current goals
- `Priority::Medium` - Standard priority
- `Priority::Low` - Nice to have, low urgency

**Type** (required):
- `Type::Bug` - Defect or error
- `Type::Feature` - New functionality
- `Type::Enhancement` - Improvement to existing
- `Type::Documentation` - Documentation work
- `Type::Test` - Testing work
- `Type::Research` - Investigation/analysis
- `Type::Infrastructure` - DevOps/tooling
- `Type::Maintenance` - Cleanup/refactoring

**Epic** (optional):
- `epic::mathematical-core` - Core algorithms
- `epic::test-framework` - Testing infrastructure
- `epic::performance` - Performance optimization
- `epic::documentation` - Documentation system
- `epic::hpc-deployment` - HPC cluster work
- `epic::visualization` - Plotting and dashboards
- `epic::advanced-features` - Next-gen capabilities

**Component** (optional):
- `component::core` - Core algorithms
- `component::precision` - AdaptivePrecision system
- `component::grids` - Grid generation
- `component::solvers` - Polynomial solving
- `component::hpc` - HPC deployment
- `component::testing` - Test infrastructure
- `component::plotting` - Visualization

### Issue Lifecycle
```
backlog → ready → in-progress → review → testing → done
             ↓         ↓           ↓         ↓
          blocked ← blocked ← blocked ← blocked
```

### Creating Issues

**Via GitLab Web Interface**:
1. Go to GitLab project → Issues → New Issue
2. Select appropriate template:
   - **Feature**: New functionality
   - **Bug**: Defect reports
   - **Task Migration**: Migrated from local tasks
   - **Epic**: Large initiatives
3. Apply required labels (Status, Priority, Type)
4. Write clear acceptance criteria

**Via Migration Tools**:
```bash
# Migrate all local tasks to GitLab issues
./tools/gitlab/migrate_tasks.sh full

# Selective migration
python3 tools/gitlab/task_extractor.py --repo-root . --output tasks.json
python3 tools/gitlab/gitlab_manager.py --config tools/gitlab/config.json --tasks tasks.json --dry-run
```

## Development Workflow

### Branch Naming Convention
```bash
# Recommended patterns
issue-123-fix-memory-leak
issue-456-add-performance-tests
feature-789-adaptive-precision
bugfix-321-hpc-deployment
```

### Commit Message Conventions

**Format**:
```
<type>: <description>

[optional body]

[optional footer with issue references]
```

**Issue Reference Keywords**:
- `refs #123` - Reference an issue
- `closes #123` - Close an issue when merged
- `fixes #123` - Fix a bug (closes issue)
- `resolves #123` - Resolve an issue
- `implements #123` - Implement a feature

**Examples**:
```bash
# Simple reference
git commit -m "Add memory tracking, refs #123"

# Closing issue
git commit -m "Fix HPC deployment bug, closes #456"

# Multiple issues
git commit -m "Refactor grid generation, refs #123, #456"
```

### Automated Workflows

**Git Hooks** automatically:
1. **prepare-commit-msg**: Add issue references based on branch name
2. **commit-msg**: Validate commit messages and provide feedback
3. **post-commit**: Update GitLab issue status based on commit message

**Manual Sync Commands**:
```bash
# Start work on an issue
python3 tools/gitlab/task_sync.py start 123

# Complete work on an issue
python3 tools/gitlab/task_sync.py complete 123

# Create branch for issue
python3 tools/gitlab/task_sync.py create-branch 123

# Sync issues from commit message
python3 tools/gitlab/task_sync.py sync-commit

# Sync current work status
python3 tools/gitlab/task_sync.py sync-status
```

## GitLab Boards

### Development Workflow Board
**Purpose**: Daily task management and sprint execution

**Columns**:
- 📋 **Backlog** (`status::backlog`) - Identified work not yet started
- 🚀 **Ready** (`status::ready`) - Work ready to begin
- 🔄 **In Progress** (`status::in-progress`) - Active development work
- 👀 **Review** (`status::review`) - Code/work ready for review
- 🧪 **Testing** (`status::testing`) - Work under testing/validation
- ✅ **Done** (`status::done`) - Completed and accepted work
- 🚫 **Blocked** (`status::blocked`) - Work stopped by dependencies

**Usage**:
- **Daily Standup**: Review In Progress and Blocked columns
- **Sprint Planning**: Move items from Backlog to Ready
- **Work Assignment**: Assign yourself to issues when moving to In Progress

### Epic Progress Board
**Purpose**: Strategic view of progress across major project areas

**Columns** (by epic):
- 🧮 **Mathematical Core** (`epic::mathematical-core`)
- 🧪 **Test Framework** (`epic::test-framework`)
- ⚡ **Performance** (`epic::performance`)
- 📚 **Documentation** (`epic::documentation`)
- 🖥️ **HPC Deployment** (`epic::hpc-deployment`)
- 📊 **Visualization** (`epic::visualization`)
- 🚀 **Advanced Features** (`epic::advanced-features`)

**Usage**:
- **Epic Planning**: Balance work across different areas
- **Progress Tracking**: Monitor epic completion percentages
- **Strategic Reviews**: Weekly epic progress assessment

### Priority Focus Board
**Purpose**: Urgency-based work prioritization

**Columns**:
- 🔴 **Critical** (`Priority::Critical`) - Blocking, immediate (same day)
- 🟡 **High** (`Priority::High`) - Important for goals (within 3 days)
- 🔵 **Medium** (`Priority::Medium`) - Standard priority (within 2 weeks)
- 🟢 **Low** (`Priority::Low`) - Nice to have (when capacity allows)

**Usage**:
- **Daily Priority Check**: Review Critical and High columns first
- **Capacity Planning**: Balance high-priority work with medium/low items

### Board Management

**Creating Issues from Boards**:
1. Click "+" button in any column
2. Fill in issue title and description
3. Labels are automatically applied based on column
4. Assign to team member if known

**Moving Issues**:
- Drag and drop between columns
- Labels automatically update to match column
- All moves are logged in issue activity

**Filtering**:
- Filter by assignee, milestone, labels
- Search by title, description, or ID

## Best Practices

### Issue Management
1. **Always use templates** - Ensures consistent information
2. **Apply all required labels** - Status, Priority, Type
3. **Write clear acceptance criteria** - Makes completion obvious
4. **Link related issues** - Use "Related to #123" or "Blocks #456"
5. **Update status regularly** - Keep the board current

### Development Workflow
1. **Create branches from issues** - Use descriptive names with issue numbers
2. **Commit frequently** - Small, focused commits with clear messages
3. **Reference issues in commits** - Enables automatic tracking
4. **Use closing keywords** - Automatically close issues when appropriate
5. **Review before merging** - Ensure quality and completeness

### Team Collaboration
1. **Assign issues clearly** - One person responsible per issue
2. **Use @mentions** - Notify relevant team members
3. **Comment on progress** - Keep stakeholders informed
4. **Update estimates** - Help with planning and velocity tracking
5. **Close completed work** - Keep the backlog clean

### Board Hygiene
- **Daily Updates**: Move cards as work progresses
- **Clean Descriptions**: Keep issue descriptions current
- **Archive Completed**: Regularly clean up Done column
- **Review Blocked**: Weekly review of blocked items

## Troubleshooting

### Hooks Not Working
```bash
# Check hook status
./tools/gitlab/install_hooks.sh status

# Reinstall hooks
./tools/gitlab/install_hooks.sh uninstall
./tools/gitlab/install_hooks.sh install
```

### GitLab API Errors
```bash
# Check configuration
cat tools/gitlab/config.json

# Test API access
python3 -c "
from tools.gitlab.gitlab_manager import load_config, GitLabIssueManager
config = load_config('tools/gitlab/config.json')
manager = GitLabIssueManager(config)
issues = manager.list_issues()
print(f'Found {len(issues)} issues')
"
```

### Task Extraction Issues
```bash
# Run with verbose output
python3 tools/gitlab/task_extractor.py \
    --repo-root . \
    --output debug_tasks.json \
    --summary

# Check specific files
grep -r "TODO\|FIXME" --include="*.jl" --include="*.md" .
```

### Disable Hooks Temporarily
```bash
# Disable
chmod -x .git/hooks/post-commit
chmod -x .git/hooks/prepare-commit-msg
chmod -x .git/hooks/commit-msg

# Re-enable
chmod +x .git/hooks/post-commit
chmod +x .git/hooks/prepare-commit-msg
chmod +x .git/hooks/commit-msg
```

## Key Resources

- **GitLab Project**: https://git.mpi-cbg.de/globaloptim/globtimcore
- **Migration Tools**: `tools/gitlab/`
- **Issue Templates**: `.gitlab/issue_templates/`
- **Tool Documentation**: `tools/gitlab/README.md`

## Advanced Usage

### Custom Issue Templates
Create specialized templates in `.gitlab/issue_templates/`:
- `performance.md` - Performance optimization tasks
- `research.md` - Research and investigation work
- `deployment.md` - HPC deployment tasks

### Bulk Operations
```bash
# Update multiple issues
python3 tools/gitlab/gitlab_manager.py bulk-update \
    --issues 123,456,789 \
    --add-label "Priority::High"
```

### Migration Workflow
```bash
# 1. Extract tasks
./tools/gitlab/migrate_tasks.sh extract

# 2. Review extracted tasks
cat tools/gitlab/extracted_tasks.json | jq '.[] | {title, priority, epic}'

# 3. Dry run
./tools/gitlab/migrate_tasks.sh dry-run

# 4. Review results
cat tools/gitlab/migration_report.txt.dry-run

# 5. Migrate
./tools/gitlab/migrate_tasks.sh migrate

# 6. Verify
cat tools/gitlab/migration_report.txt
```

## Weekly Board Review Checklist

- [ ] **Throughput**: How many issues moved to Done?
- [ ] **Bottlenecks**: Which columns have too many items?
- [ ] **Blocked Work**: What's preventing progress?
- [ ] **Epic Progress**: Are we making balanced progress?
- [ ] **Priority Alignment**: Are we working on the right things?
- [ ] **Cycle Time**: Time from Ready to Done
- [ ] **Work in Progress**: Number of items in In Progress
