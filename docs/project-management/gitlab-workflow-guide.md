# GitLab Workflow Guide

## Overview

This guide provides comprehensive documentation for the GitLab-based project management system, including issue management, automated workflows, and development integration.

## Quick Start

### 1. Initial Setup

```bash
# 1. Configure GitLab access
cp tools/gitlab/config.json.template tools/gitlab/config.json
# Edit config.json with your GitLab project ID and access token

# 2. Install Git hooks for automatic sync
./tools/gitlab/install_hooks.sh install

# 3. Verify setup
./tools/gitlab/install_hooks.sh status
```

### 2. Basic Workflow

```bash
# Start work on an issue
python3 tools/gitlab/task_sync.py start 123

# Create a branch for the issue
python3 tools/gitlab/task_sync.py create-branch 123

# Work normally - hooks handle sync automatically
git commit -m "Fix memory leak, refs #123"
git commit -m "Complete implementation, closes #123"
```

## Issue Management

### Issue Creation

#### Using GitLab Web Interface
1. Go to your GitLab project → Issues → New Issue
2. Select appropriate template:
   - **Feature**: New functionality
   - **Bug**: Defect reports
   - **Task Migration**: Migrated from local tasks
   - **Epic**: Large initiatives

#### Using Migration Tools
```bash
# Migrate all local tasks to GitLab issues
./tools/gitlab/migrate_tasks.sh full
```

### Issue Labels

Every issue must have these required labels:

#### Status Labels (Required)
- `status::backlog` - Identified but not prioritized
- `status::ready` - Ready for development
- `status::in-progress` - Actively being worked on
- `status::review` - Code complete, awaiting review
- `status::testing` - Under testing/validation
- `status::done` - Complete and accepted
- `status::blocked` - Cannot proceed due to dependencies
- `status::cancelled` - Work cancelled

#### Priority Labels (Required)
- `Priority::Critical` - Blocking, immediate attention
- `Priority::High` - Important for current goals
- `Priority::Medium` - Standard priority
- `Priority::Low` - Nice to have, low urgency

#### Type Labels (Required)
- `Type::Bug` - Defect or error
- `Type::Feature` - New functionality
- `Type::Enhancement` - Improvement to existing
- `Type::Documentation` - Documentation work
- `Type::Test` - Testing work
- `Type::Research` - Investigation/analysis
- `Type::Infrastructure` - DevOps/tooling
- `Type::Maintenance` - Cleanup/refactoring

#### Epic Labels (Optional)
- `epic::mathematical-core` - Core algorithms
- `epic::test-framework` - Testing infrastructure
- `epic::performance` - Performance optimization
- `epic::documentation` - Documentation system
- `epic::hpc-deployment` - HPC cluster work
- `epic::visualization` - Plotting and dashboards
- `epic::advanced-features` - Next-gen capabilities

#### Component Labels (Optional)
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
             ↓         ↓           ↓
          blocked ← blocked ← blocked
             ↓         ↓           ↓
         cancelled ← cancelled ← cancelled
```

## Development Workflow

### Branch Naming Convention

Use descriptive branch names that include issue numbers:

```bash
# Recommended patterns
issue-123-fix-memory-leak
issue-456-add-performance-tests
feature-789-adaptive-precision
bugfix-321-hpc-deployment

# The hooks will automatically detect issue numbers from branch names
```

### Commit Message Conventions

#### Basic Format
```
<type>: <description>

[optional body]

[optional footer with issue references]
```

#### Issue References
- `refs #123` - Reference an issue
- `closes #123` - Close an issue when merged
- `fixes #123` - Fix a bug (closes issue)
- `resolves #123` - Resolve an issue
- `implements #123` - Implement a feature

#### Examples
```bash
# Simple reference
git commit -m "Add memory tracking, refs #123"

# Closing issue
git commit -m "Fix HPC deployment bug, closes #456"

# Multiple issues
git commit -m "Refactor grid generation, refs #123, #456"
```

### Automated Workflows

#### Git Hooks
The installed hooks automatically:

1. **prepare-commit-msg**: Add issue references based on branch name
2. **commit-msg**: Validate commit messages and provide feedback
3. **post-commit**: Update GitLab issue status based on commit message

#### Manual Sync Commands
```bash
# Start work on an issue
python3 tools/gitlab/task_sync.py start 123

# Complete work on an issue
python3 tools/gitlab/task_sync.py complete 123

# Sync issues from commit message
python3 tools/gitlab/task_sync.py sync-commit

# Sync current work status
python3 tools/gitlab/task_sync.py sync-status

# Create branch for issue
python3 tools/gitlab/task_sync.py create-branch 123
```

## GitLab Boards

### Issue Board Setup

1. Go to GitLab project → Boards
2. Create lists for each status:
   - **Backlog** (status::backlog)
   - **Ready** (status::ready)
   - **In Progress** (status::in-progress)
   - **Review** (status::review)
   - **Testing** (status::testing)
   - **Done** (status::done)

### Epic Board Setup

1. Go to GitLab project → Boards → Epic Board
2. Create lists for each epic:
   - **Mathematical Core** (epic::mathematical-core)
   - **Test Framework** (epic::test-framework)
   - **Performance** (epic::performance)
   - **Documentation** (epic::documentation)
   - **HPC Deployment** (epic::hpc-deployment)

## Migration from Local Tasks

### Complete Migration Workflow

```bash
# 1. Extract all tasks from repository
./tools/gitlab/migrate_tasks.sh extract

# 2. Review extracted tasks
cat tools/gitlab/extracted_tasks.json | jq '.[] | {title, priority, epic}'

# 3. Perform dry run
./tools/gitlab/migrate_tasks.sh dry-run

# 4. Review dry run results
cat tools/gitlab/migration_report.txt.dry-run

# 5. Perform actual migration
./tools/gitlab/migrate_tasks.sh migrate

# 6. Review migration results
cat tools/gitlab/migration_report.txt
```

### Selective Migration

```bash
# Extract tasks from specific files
python3 tools/gitlab/task_extractor.py \
    --repo-root . \
    --output specific_tasks.json

# Migrate specific task file
python3 tools/gitlab/gitlab_manager.py \
    --config tools/gitlab/config.json \
    --tasks specific_tasks.json \
    --dry-run
```

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

## Troubleshooting

### Common Issues

#### "Hooks not working"
```bash
# Check hook status
./tools/gitlab/install_hooks.sh status

# Reinstall hooks
./tools/gitlab/install_hooks.sh uninstall
./tools/gitlab/install_hooks.sh install
```

#### "GitLab API errors"
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

#### "Task extraction issues"
```bash
# Run with verbose output
python3 tools/gitlab/task_extractor.py \
    --repo-root . \
    --output debug_tasks.json \
    --summary

# Check specific files
grep -r "TODO\|FIXME" --include="*.jl" --include="*.md" .
```

### Getting Help

1. **Check tool documentation**: `tools/gitlab/README.md`
2. **Review log files**: Look for error messages in command output
3. **Test with dry runs**: Always test before making changes
4. **Verify GitLab permissions**: Ensure you can create/edit issues
5. **Check Git repository**: Ensure you're in the correct repository

## Advanced Usage

### Custom Workflows

#### Automated Testing Integration
```bash
# In CI/CD pipeline
if [ "$CI_COMMIT_MESSAGE" contains "closes #" ]; then
    # Run extra validation for closing commits
    ./run_comprehensive_tests.sh
fi
```

#### Custom Issue Templates
Create specialized templates in `.gitlab/issue_templates/`:
- `performance.md` - Performance optimization tasks
- `research.md` - Research and investigation work
- `deployment.md` - HPC deployment tasks

#### Bulk Operations
```bash
# Update multiple issues
python3 tools/gitlab/gitlab_manager.py bulk-update \
    --issues 123,456,789 \
    --add-label "Priority::High"
```

This workflow guide provides a complete foundation for GitLab-based project management while maintaining development velocity and ensuring comprehensive task tracking.
