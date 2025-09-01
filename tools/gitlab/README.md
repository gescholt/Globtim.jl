# GitLab Migration Tools

This directory contains tools for migrating local tasks and TODOs to GitLab issues with proper labeling and automation.

## Overview

The migration system consists of three main components:

1. **Task Extractor** (`task_extractor.py`) - Scans repository for tasks and TODOs
2. **GitLab Manager** (`gitlab_manager.py`) - Creates and manages GitLab issues via API
3. **Migration Script** (`migrate_tasks.sh`) - Orchestrates the complete migration workflow

## Quick Start

### 1. Setup Configuration

```bash
# Copy the configuration template
cp tools/gitlab/config.json.template tools/gitlab/config.json

# Edit the configuration with your GitLab details
# You'll need:
# - GitLab project ID (found in project settings)
# - Personal access token with API scope
```

### 2. Run Complete Migration

```bash
# Run the full migration workflow
./tools/gitlab/migrate_tasks.sh full
```

This will:
- Extract all tasks from the repository
- Show a summary of found tasks
- Perform a dry run to preview what will be created
- Ask for confirmation before creating actual GitLab issues
- Generate a migration report

## Detailed Usage

### Extract Tasks Only

```bash
# Extract tasks without creating GitLab issues
./tools/gitlab/migrate_tasks.sh extract
```

This scans the repository for:
- Markdown checklist items (`- [ ]`, `- [x]`, `- [/]`, `- [-]`)
- TODO/FIXME comments in code files
- Structured tasks in roadmap documents

### Validate Extracted Tasks

```bash
# Validate the extracted tasks file
./tools/gitlab/migrate_tasks.sh validate
```

### Dry Run Migration

```bash
# Test the migration without creating real issues
./tools/gitlab/migrate_tasks.sh dry-run
```

### Actual Migration

```bash
# Create real GitLab issues (after dry run)
./tools/gitlab/migrate_tasks.sh migrate
```

## Configuration

### GitLab Configuration (`config.json`)

```json
{
  "project_id": "12345678",
  "access_token": "glpat-xxxxxxxxxxxxxxxxxxxx",
  "base_url": "https://gitlab.com/api/v4",
  "rate_limit_delay": 1.0
}
```

**Required Fields:**
- `project_id`: Your GitLab project ID (numeric)
- `access_token`: Personal access token with `api` scope

**Optional Fields:**
- `base_url`: GitLab API base URL (default: gitlab.com)
- `rate_limit_delay`: Delay between API requests in seconds

### Getting GitLab Credentials

1. **Project ID**: Go to your GitLab project → Settings → General → Project ID
2. **Access Token**: 
   - Go to GitLab → User Settings → Access Tokens
   - Create token with `api` scope
   - Copy the token immediately (it won't be shown again)

## Task Classification

The extractor automatically classifies tasks with appropriate labels:

### Status Labels
- `status::backlog` - New tasks not yet started
- `status::in-progress` - Tasks marked as in progress (`- [/]`)
- `status::done` - Completed tasks (`- [x]`)
- `status::cancelled` - Cancelled tasks (`- [-]`)

### Priority Labels
Automatically assigned based on keywords:
- `Priority::Critical` - "critical", "blocking", "urgent"
- `Priority::High` - "important", "high", "priority"
- `Priority::Medium` - Default priority
- `Priority::Low` - "nice", "low", "future", "optional"

### Epic Labels
Automatically assigned based on content:
- `epic::mathematical-core` - Core algorithms and precision
- `epic::test-framework` - Testing and validation
- `epic::performance` - Performance optimization
- `epic::documentation` - Documentation work
- `epic::hpc-deployment` - HPC cluster work
- `epic::visualization` - Plotting and dashboards

### Component Labels
- `component::core` - Core mathematical algorithms
- `component::precision` - AdaptivePrecision system
- `component::grids` - Grid generation
- `component::solvers` - Polynomial solving
- `component::hpc` - HPC deployment
- `component::testing` - Test infrastructure
- `component::plotting` - Visualization

## Output Files

### Extracted Tasks (`extracted_tasks.json`)
JSON file containing all discovered tasks with metadata:
```json
[
  {
    "title": "Implement memory tracking",
    "description": "Add memory usage tracking to experiment runner",
    "source_file": "src/experiment_runner.jl",
    "source_line": 109,
    "task_type": "todo",
    "status": "not_started",
    "priority": "Medium",
    "epic": "epic::performance",
    "component": "component::core"
  }
]
```

### Migration Report (`migration_report.txt`)
Summary of created GitLab issues:
```
GitLab Migration Report
=======================

Total Issues Created: 45

Created Issues:
  #123: Implement memory tracking
  #124: Fix HPC deployment issues
  #125: Add performance benchmarks
  ...
```

## Advanced Usage

### Custom Extraction

```bash
# Extract tasks with custom patterns
python3 tools/gitlab/task_extractor.py \
    --repo-root . \
    --output custom_tasks.json \
    --summary
```

### Custom Migration

```bash
# Migrate specific tasks file
python3 tools/gitlab/gitlab_manager.py \
    --config tools/gitlab/config.json \
    --tasks custom_tasks.json \
    --dry-run
```

## Troubleshooting

### Common Issues

1. **"Python 3 is required but not installed"**
   - Install Python 3.7+ on your system

2. **"Python 'requests' package is required"**
   ```bash
   pip install requests
   ```

3. **"Configuration file not found"**
   - Copy `config.json.template` to `config.json`
   - Fill in your GitLab project ID and access token

4. **"401 Unauthorized"**
   - Check your access token is correct
   - Ensure token has `api` scope
   - Verify project ID is correct

5. **"403 Forbidden"**
   - Check you have permission to create issues in the project
   - Verify you're a member of the project with appropriate role

### Rate Limiting

The tools include built-in rate limiting to avoid overwhelming the GitLab API:
- Default: 1 second delay between requests
- Configurable via `rate_limit_delay` in config
- Automatic retry on rate limit errors

### Large Migrations

For repositories with many tasks (100+):
- Always run dry-run first
- Consider migrating in batches
- Monitor GitLab API rate limits
- Use higher `rate_limit_delay` if needed

## Integration with Development Workflow

After migration, you can integrate GitLab issues with your development workflow:

1. **Reference issues in commits**: `git commit -m "Fix memory leak, closes #123"`
2. **Link merge requests**: Automatically close issues when MRs are merged
3. **Use GitLab boards**: Organize issues by status and priority
4. **Set up automation**: Use GitLab CI/CD to update issue status

## Support

For issues with the migration tools:
1. Check the troubleshooting section above
2. Review the generated log files
3. Test with a small subset of tasks first
4. Verify GitLab API access manually

The migration tools are designed to be safe and reversible - they only create new issues and don't modify existing repository content.
