# Claude Code Hooks Setup Guide

This document describes the Claude Code hooks system implemented for the GlobTim project.

## 🎯 **Hook System Overview**

The GlobTim project includes a comprehensive Claude Code hooks system that provides:
- **GitLab Security Validation**: Ensures secure GitLab operations
- **HPC Experiment Tracking**: Automated experiment logging and organization  
- **Folder Organization**: Maintains clean project structure and prevents `/tmp` usage

## 📁 **Claude Hooks Location**

The hooks are installed in: `~/.claude/hooks/`

**Files created:**
```
~/.claude/hooks/
├── config.json                        # Hook configuration
├── pre-tool-use-gitlab-security.sh    # GitLab security hook
├── hpc-experiment-tracker.sh          # HPC experiment tracking hook
├── folder-organizer.sh                # Folder organization hook
└── README.md                          # Complete documentation
```

## 🔒 **Security Features**

- **No hardcoded tokens**: Uses secure `tools/gitlab/get-token.sh` system
- **Environment-based**: Requires `GITLAB_PRIVATE_TOKEN` environment variable
- **Automated validation**: Blocks GitLab operations if security checks fail
- **Audit logging**: All security events logged for compliance

## 🧪 **Testing Status**

All hooks tested and operational:
- ✅ GitLab security validation working
- ✅ HPC experiment tracking creating organized directories
- ✅ Folder organization blocking `/tmp` usage
- ✅ End-to-end GitLab API integration confirmed

## 🚀 **Usage**

The hooks activate automatically when:
- **project-task-updater** agent is used (GitLab security validation)
- **hpc-cluster-operator** agent is used (experiment tracking)
- File operations attempted in `/tmp` (folder organization)

## 📋 **Setup Requirements**

To use this system:
1. Ensure `GITLAB_PRIVATE_TOKEN` environment variable is set
2. Verify `tools/gitlab/get-token.sh` is executable
3. Claude Code hooks system must be enabled

## 🔗 **Integration Points**

- **GitLab API**: Secure wrapper in `gitlab_api.py`
- **HPC Infrastructure**: Creates tracking directories in `hpc/experiments/temp/`
- **Project Structure**: Enforces organized file placement

---
**Status**: Production Ready ✅  
**Implementation Date**: September 4, 2025