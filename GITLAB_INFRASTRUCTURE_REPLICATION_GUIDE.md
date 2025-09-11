# GitLab Infrastructure Replication Guide

**Purpose**: Complete setup guide to replicate the sophisticated GitLab infrastructure and workflow management system from this repository in a new project.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Core Infrastructure Setup](#core-infrastructure-setup)
4. [Authentication & Security](#authentication--security)
5. [Issue Management System](#issue-management-system)
6. [Project Boards & Visual Management](#project-boards--visual-management)
7. [Automation & Hooks](#automation--hooks)
8. [Task Migration Tools](#task-migration-tools)
9. [Development Workflow Integration](#development-workflow-integration)
10. [Testing & Validation](#testing--validation)
11. [Advanced Features](#advanced-features)
12. [Troubleshooting](#troubleshooting)

## Overview

This repository implements a comprehensive GitLab-based project management system featuring:

- **Secure API Access**: Multi-layered token management (environment variables, Git credential helper, macOS Keychain)
- **Automated Issue Tracking**: Git hooks that automatically update GitLab issues from commit messages
- **Comprehensive Label System**: 95+ labels across priority, type, epic, and status dimensions
- **Visual Project Management**: Multiple GitLab boards for different workflow perspectives
- **Task Migration**: Automated extraction and migration of local tasks to GitLab issues
- **Security Framework**: Comprehensive security validation and monitoring
- **Claude Code Integration**: Specialized agents for automated GitLab operations

## Prerequisites

### Required Software
- **Git** (2.30+)
- **curl** (for API calls)
- **jq** (for JSON processing) - `brew install jq` (macOS) or `apt-get install jq` (Linux)
- **Python 3.7+** (for advanced tooling)
- **Bash 4.0+** (for automation scripts)

### GitLab Requirements
- GitLab project (GitLab.com or self-hosted)
- Developer/Maintainer role on the project
- API access enabled

### Python Dependencies
```bash
pip install requests  # For GitLab API interactions
```

## Core Infrastructure Setup

### 1. Create Directory Structure

```bash
# Navigate to your repository root
cd /path/to/your/repository

# Create GitLab tools directory structure
mkdir -p tools/gitlab
mkdir -p docs/project-management
mkdir -p tests/gitlab_api

# Create hooks directory
mkdir -p .git/hooks
```

### 2. Copy Core Files

Copy these essential files from this repository to your new repository:

#### Essential Scripts
```bash
# Core API and configuration tools
tools/gitlab/get-token.sh
tools/gitlab/get-token-noninteractive.sh
tools/gitlab/gitlab-api.sh
tools/gitlab/claude-agent-gitlab.sh
tools/gitlab/setup-secure-config.sh
tools/gitlab/setup-env-token.sh
tools/gitlab/gitlab-security-hook.sh

# Configuration templates
tools/gitlab/config.json.template

# Task migration system
tools/gitlab/task_extractor.py
tools/gitlab/task_sync.py
tools/gitlab/gitlab_manager.py
tools/gitlab/migrate_tasks.sh
tools/gitlab/secure_config.py
tools/gitlab/secure_gitlab_wrapper.py

# Board management
tools/gitlab/setup-boards.sh

# Security and validation
tools/gitlab/validate-security.sh
tools/gitlab/test-gitlab-security-hook.sh
```

#### Documentation Templates
```bash
# Workflow and process documentation
docs/project-management/gitlab-workflow-guide.md
docs/project-management/gitlab-issue-structure.md
docs/project-management/gitlab-boards-guide.md
docs/project-management/gitlab-quick-reference.md

# Security documentation will be auto-generated
```

### 3. Set File Permissions

```bash
# Make scripts executable
chmod +x tools/gitlab/*.sh

# Secure sensitive scripts (execute only by owner)
chmod 700 tools/gitlab/get-token*.sh
chmod 700 tools/gitlab/gitlab-api.sh
chmod 700 tools/gitlab/setup-secure-config.sh

# Secure Python modules
chmod 600 tools/gitlab/secure_config.py
chmod 600 tools/gitlab/secure_gitlab_wrapper.py
```

## Authentication & Security

### 1. Initial Security Setup

```bash
# Run the secure configuration setup
./tools/gitlab/setup-secure-config.sh setup
```

This will:
- Configure Git credential helper for GitLab
- Create secure environment file (`.env.gitlab.local`)
- Generate secure API configuration (`config.json`)
- Set up token management scripts
- Create comprehensive security documentation

### 2. Configure GitLab Project Details

Edit the generated configuration or run setup interactively:

```bash
# Your GitLab project details
PROJECT_ID="your-project-id"        # Found in GitLab → Project → Settings → General
GITLAB_URL="https://gitlab.com"     # Or your GitLab instance URL
MILESTONE_ID="current-milestone"    # Optional: current milestone ID
```

### 3. Token Storage Options

Choose your preferred secure token storage method:

#### Option A: Environment Variable (Recommended for Development)
```bash
# Add to ~/.bashrc, ~/.zshrc, etc.
export GITLAB_PRIVATE_TOKEN='your-gitlab-api-token'
```

#### Option B: Git Credential Helper (Recommended for Production)
```bash
./tools/gitlab/setup-secure-config.sh credentials
# Follow prompts to store token securely
```

#### Option C: macOS Keychain (macOS Only)
```bash
security add-generic-password -a "$(whoami)" -s "gitlab-api-token" -w "your-token"
```

### 4. Validate Security Setup

```bash
# Test all security components
./tools/gitlab/setup-secure-config.sh test

# Validate GitLab API access
./tools/gitlab/gitlab-api.sh GET "/projects/$PROJECT_ID"
```

## Issue Management System

### 1. Create Label System

Create the comprehensive label taxonomy in your GitLab project:

#### Priority Labels (4 labels)
- `priority::critical` - Blocking, immediate attention required
- `priority::high` - Important for current milestone/goals
- `priority::medium` - Standard priority level
- `priority::low` - Nice to have, low urgency

#### Type Labels (9 labels)
- `type::feature` - New functionality or capabilities
- `type::enhancement` - Improvements to existing features
- `type::bug` - Defects, errors, or incorrect behavior
- `type::maintenance` - Code cleanup, refactoring, technical debt
- `type::documentation` - Documentation work
- `type::test` - Testing infrastructure and test cases
- `type::performance` - Performance optimization work
- `type::research` - Investigation, analysis, prototyping
- `type::review` - Code review, audit, or assessment work

#### Status Labels (10 labels)
- `status::backlog` - Identified but not yet prioritized
- `status::ready` - Ready for development work
- `status::in-progress` - Actively being worked on
- `status::review` - Code complete, awaiting review
- `status::testing` - Under testing/validation
- `status::validated` - Testing complete, ready for release
- `status::done` - Complete and accepted
- `status::blocked` - Cannot proceed due to dependencies
- `status::ongoing` - Continuous/maintenance work
- `status::cancelled` - Work cancelled or deprecated

#### Epic Labels (Customize for Your Project)
```bash
# Mathematical/Scientific Projects
epic::mathematical-core
epic::numerical-algorithms
epic::data-processing

# Software Development Projects  
epic::frontend
epic::backend
epic::database
epic::api

# Infrastructure Projects
epic::deployment
epic::monitoring
epic::security
epic::performance

# General Purpose
epic::documentation
epic::testing
epic::user-experience
epic::analytics
```

#### Component Labels (Customize for Your Project)
```bash
# Technical Components
component::core
component::api
component::database
component::frontend
component::backend
component::infrastructure
component::security
component::testing
component::documentation

# Domain-Specific Components (Examples)
component::authentication
component::payment
component::reporting
component::notifications
component::integration
```

### 2. Create Labels via GitLab API

```bash
# Script to create all labels programmatically
cat > create_labels.sh << 'EOF'
#!/bin/bash

# Priority Labels
./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"priority::critical","color":"#d73a4a","description":"Blocking, immediate attention required"}'

./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"priority::high","color":"#fb8500","description":"Important for current milestone"}'

./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"priority::medium","color":"#0969da","description":"Standard priority level"}'

./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"priority::low","color":"#54aeff","description":"Nice to have, low urgency"}'

# Type Labels  
./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"type::feature","color":"#1f883d","description":"New functionality"}'

./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"type::bug","color":"#d73a4a","description":"Defects or errors"}'

./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"type::enhancement","color":"#8250df","description":"Improvements to existing features"}'

# Add remaining labels...
EOF

chmod +x create_labels.sh
./create_labels.sh
```

### 3. Create Issue Templates

Create issue templates in your GitLab project:

#### Navigate to GitLab → Project → Settings → Repository → Issue templates

**Feature Template** (`.gitlab/issue_templates/Feature.md`):
```markdown
## Summary
Brief description of the feature

## Problem Statement
What problem does this solve?

## Proposed Solution
Describe the proposed implementation

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Additional Context
Any additional information, mockups, or references

---
**Labels**: type::feature, priority::medium
**Epic**: epic::your-epic
**Milestone**: Current Milestone
```

**Bug Template** (`.gitlab/issue_templates/Bug.md`):
```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: 
- Browser/Version: 
- Other relevant details:

## Additional Information
Screenshots, logs, or other helpful information

---
**Labels**: type::bug, priority::high
```

## Project Boards & Visual Management

### 1. Create Development Workflow Board

1. Navigate to **GitLab → Project → Boards**
2. Create **"Development Workflow"** board
3. Add lists for each status label:
   - **Backlog** (filter: `status::backlog`)
   - **Ready** (filter: `status::ready`)
   - **In Progress** (filter: `status::in-progress`)
   - **Review** (filter: `status::review`)
   - **Testing** (filter: `status::testing`)
   - **Done** (filter: `status::done`)
   - **Blocked** (filter: `status::blocked`)

### 2. Create Epic Progress Board

1. Create **"Epic Progress"** board
2. Add lists for each epic:
   - **Epic 1** (filter: `epic::your-first-epic`)
   - **Epic 2** (filter: `epic::your-second-epic`)
   - **Epic 3** (filter: `epic::your-third-epic`)
   - Continue for all your epics...

### 3. Create Priority Focus Board

1. Create **"Priority Focus"** board
2. Add lists for priorities:
   - **Critical** (filter: `priority::critical`)
   - **High** (filter: `priority::high`)
   - **Medium** (filter: `priority::medium`)
   - **Low** (filter: `priority::low`)

### 4. Board Management Tools

```bash
# Analyze current issues for board readiness
./tools/gitlab/setup-boards.sh analyze

# Show board configuration recommendations
./tools/gitlab/setup-boards.sh config

# Display board URLs and access links
./tools/gitlab/setup-boards.sh urls

# Validate board setup
./tools/gitlab/setup-boards.sh validate
```

## Automation & Hooks

### 1. Git Hooks Setup

```bash
# Install GitLab integration hooks
./tools/gitlab/install_hooks.sh install

# Check hook status
./tools/gitlab/install_hooks.sh status
```

### 2. Claude Code Agents Integration

If using Claude Code, set up the specialized agents:

#### GitLab Agent Configuration
```bash
# Test the GitLab agent wrapper
./tools/gitlab/claude-agent-gitlab.sh test

# Get specific issue
./tools/gitlab/claude-agent-gitlab.sh get-issue 123

# List issues
./tools/gitlab/claude-agent-gitlab.sh list-issues opened

# Create issue
./tools/gitlab/claude-agent-gitlab.sh create-issue "Fix authentication" "Resolve GitLab auth issues" "type::bug,priority::high"
```

### 3. Security Hook Integration

```bash
# Test security hook
./tools/gitlab/test-gitlab-security-hook.sh

# Manual security validation
./tools/gitlab/gitlab-security-hook.sh --force
```

## Task Migration Tools

### 1. Initial Task Discovery

```bash
# Extract all tasks from repository
./tools/gitlab/migrate_tasks.sh extract

# View discovered tasks
cat tools/gitlab/extracted_tasks.json | jq '.[] | {title, priority, epic, source_file}'
```

### 2. Migration Process

```bash
# Complete migration workflow
./tools/gitlab/migrate_tasks.sh full
```

This will:
1. Extract all tasks from the repository
2. Show task summary
3. Perform dry run migration (preview)
4. Ask for confirmation
5. Create actual GitLab issues
6. Generate migration report

### 3. Selective Migration

```bash
# Dry run only (safe preview)
./tools/gitlab/migrate_tasks.sh dry-run

# Extract from specific files
python3 tools/gitlab/task_extractor.py \
  --repo-root . \
  --output specific_tasks.json

# Migrate specific task file
python3 tools/gitlab/gitlab_manager.py \
  --config tools/gitlab/config.json \
  --tasks specific_tasks.json \
  --migrate
```

## Development Workflow Integration

### 1. Branch Naming Convention

Use issue-based branch naming:
```bash
# Recommended patterns
git checkout -b issue-123-implement-authentication
git checkout -b issue-456-fix-database-bug  
git checkout -b feature-789-user-dashboard
git checkout -b bugfix-321-api-timeout
```

### 2. Commit Message Integration

The Git hooks automatically handle GitLab integration:

```bash
# Reference an issue
git commit -m "Add user authentication, refs #123"

# Close an issue when merged
git commit -m "Fix database connection bug, closes #456"

# Multiple issues
git commit -m "Refactor API endpoints, refs #123, #456"
```

### 3. Manual Task Sync

```bash
# Start work on issue
python3 tools/gitlab/task_sync.py start 123

# Update work status
python3 tools/gitlab/task_sync.py sync-status

# Complete work  
python3 tools/gitlab/task_sync.py complete 123

# Create branch for issue
python3 tools/gitlab/task_sync.py create-branch 123
```

## Testing & Validation

### 1. Infrastructure Tests

```bash
# Test GitLab API connectivity
./tools/gitlab/setup-secure-config.sh test

# Validate security configuration
./tools/gitlab/validate-security.sh

# Test GitLab security hook
./tools/gitlab/test-gitlab-security-hook.sh
```

### 2. Token Management Tests

```bash
# Check environment token status
./tools/gitlab/setup-env-token.sh status

# Test token retrieval methods
./tools/gitlab/get-token-noninteractive.sh
```

### 3. Board Validation

```bash
# Analyze issue labeling for boards
./tools/gitlab/setup-boards.sh analyze

# Validate board configuration
./tools/gitlab/setup-boards.sh validate
```

## Advanced Features

### 1. Bulk Operations

```bash
# Update multiple issues
python3 tools/gitlab/gitlab_manager.py bulk-update \
  --issues 123,456,789 \
  --add-label "priority::high"
```

### 2. Custom Workflows

Create specialized Git hooks for your project:

```bash
# Custom pre-commit validation
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run your project-specific validations
./scripts/lint-check.sh
./scripts/test-runner.sh
EOF

chmod +x .git/hooks/pre-commit
```

### 3. API Integration Examples

```bash
# List all open issues
./tools/gitlab/gitlab-api.sh GET "/projects/$PROJECT_ID/issues?state=opened"

# Get project milestones
./tools/gitlab/claude-agent-gitlab.sh list-milestones

# Create milestone
./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/milestones" \
  -d '{"title":"Sprint 1","description":"First development sprint"}'
```

## Troubleshooting

### Common Issues

#### 1. "Token not found" Error
```bash
# Check all token sources
echo $GITLAB_PRIVATE_TOKEN                    # Environment variable
./tools/gitlab/get-token.sh                   # All sources
./tools/gitlab/setup-env-token.sh status      # Detailed status
```

#### 2. "403 Forbidden" API Errors
```bash
# Verify project access
./tools/gitlab/gitlab-api.sh GET "/projects/$PROJECT_ID"

# Check project ID is correct (GitLab → Project → Settings → General)
```

#### 3. Labels Not Created
```bash
# Check label creation
./tools/gitlab/gitlab-api.sh GET "/projects/$PROJECT_ID/labels"

# Manually create missing labels
./tools/gitlab/gitlab-api.sh POST "/projects/$PROJECT_ID/labels" \
  -d '{"name":"your-label","color":"#FF5733"}'
```

#### 4. Hooks Not Working
```bash
# Check hook installation
./tools/gitlab/install_hooks.sh status

# Reinstall hooks
./tools/gitlab/install_hooks.sh uninstall
./tools/gitlab/install_hooks.sh install

# Test hook manually
.git/hooks/post-commit
```

#### 5. Migration Issues
```bash
# Validate extracted tasks
python3 tools/gitlab/task_extractor.py \
  --repo-root . \
  --output debug_tasks.json \
  --summary

# Check Python dependencies
pip install requests
python3 -c "import requests; print('OK')"
```

### Getting Help

1. **Review documentation**: Check `tools/gitlab/README.md`
2. **Check logs**: Look for error messages in command output
3. **Test with dry runs**: Always test before making changes
4. **Validate setup**: Use `./tools/gitlab/setup-secure-config.sh test`
5. **Check GitLab permissions**: Ensure you have Developer/Maintainer role

## Customization Guide

### 1. Adapt Label System

Modify the label creation script for your project type:

- **Web Development**: `frontend`, `backend`, `database`, `ui/ux`
- **Data Science**: `data-collection`, `analysis`, `modeling`, `visualization`
- **DevOps**: `infrastructure`, `monitoring`, `deployment`, `security`
- **Mobile**: `ios`, `android`, `cross-platform`, `native`

### 2. Customize Epic Structure

Define epics that match your project phases:
```bash
# Product Development
epic::research-phase
epic::design-phase  
epic::development-phase
epic::testing-phase
epic::launch-phase

# Feature Categories
epic::core-functionality
epic::user-interface
epic::integrations
epic::performance
epic::security
```

### 3. Tailor Automation

Modify hooks and automation scripts for your workflow:
- Add project-specific validations
- Customize commit message patterns
- Add integrations with other tools (Slack, JIRA, etc.)
- Create custom CI/CD triggers

## Conclusion

This guide provides a complete framework for replicating the sophisticated GitLab infrastructure from this repository. The system provides:

- **Secure API Management**: Multiple fallback token storage methods
- **Comprehensive Issue Tracking**: 95+ labels and structured workflow
- **Visual Project Management**: Multiple board perspectives for different needs
- **Automated Workflows**: Git hooks and Claude Code agent integration  
- **Task Migration**: Seamless transition from local task management
- **Security Framework**: Comprehensive validation and monitoring

Follow this guide step-by-step to establish a production-ready GitLab-based project management system that scales with your development needs.

---

**Generated from**: GlobTim Project GitLab Infrastructure Analysis  
**Last Updated**: September 9, 2025  
**Repository**: https://git.mpi-cbg.de/scholten/globtim