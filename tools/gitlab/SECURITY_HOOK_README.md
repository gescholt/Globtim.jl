# GitLab Security Hook for Claude Code

This security hook ensures all GitLab operations use verified, secure configuration before execution.

## 🔒 **What It Does**

The security hook automatically validates your `.gitlab_config` file before any GitLab operations:

- ✅ **Validates file exists** and is readable
- ✅ **Checks file permissions** (auto-fixes to 600 if needed)  
- ✅ **Verifies required variables** are present and valid
- ✅ **Validates URL format** (must start with http/https)
- ✅ **Checks token length** (basic validation)
- ✅ **Logs all security events** for audit trail
- ❌ **Blocks operations** if validation fails

## 🎯 **Trigger Conditions**

The hook activates when:
- Claude Task tool uses `project-task-updater` subagent
- Claude context mentions "GitLab" 
- Hook is called with `--force` flag

## 📁 **Files Created**

```
tools/gitlab/
├── gitlab-security-hook.sh          # Main security hook script
├── test-gitlab-security-hook.sh     # Comprehensive test suite
├── SECURITY_HOOK_README.md          # This documentation
└── .gitlab_hook.log                 # Security event log (auto-created)
```

## 🚀 **Installation**

### 1. **Verify Hook is Ready**
```bash
cd /Users/ghscholt/globtim
ls -la tools/gitlab/gitlab-security-hook.sh
# Should show executable permissions (rwx------)
```

### 2. **Test the Hook**
```bash
# Test with current config
./tools/gitlab/gitlab-security-hook.sh --force

# Run full test suite
./tools/gitlab/test-gitlab-security-hook.sh
```

### 3. **Configure Claude Hooks** (Manual Step)
Add to your Claude Code hooks configuration:

```bash
# In your Claude Code hooks directory (~/.claude/hooks/)
# Create or add to pre-tool-execution hook:

#!/bin/bash
if [[ "$CLAUDE_TOOL_NAME" == "Task" && "$CLAUDE_SUBAGENT_TYPE" == "project-task-updater" ]]; then
    cd /Users/ghscholt/globtim
    ./tools/gitlab/gitlab-security-hook.sh
    if [[ $? -ne 0 ]]; then
        echo "❌ GitLab security validation failed - blocking operation"
        exit 1
    fi
fi
```

## 🧪 **Testing Results**

### ✅ **Successful Test Scenarios**
- **Valid Configuration**: ✅ Passes validation
- **Auto-Fix Permissions**: ✅ Fixes 644 → 600 automatically  
- **Claude Context Trigger**: ✅ Detects GitLab mentions
- **Agent Integration**: ✅ Works with project-task-updater
- **Skip When Not Triggered**: ✅ No unnecessary validation

### ❌ **Security Blocks (As Designed)**
- **Missing .gitlab_config**: ❌ Blocks with clear error
- **Missing Required Variables**: ❌ Lists missing variables
- **Invalid URL Format**: ❌ Validates URL structure
- **Short/Invalid Token**: ❌ Basic token validation
- **Unreadable Config**: ❌ Handles permission issues

## 📊 **Usage Examples**

### **Manual Testing**
```bash
# Force validation (for testing)
./tools/gitlab/gitlab-security-hook.sh --force

# Check logs
tail -f .gitlab_hook.log
```

### **Simulated Claude Triggers**
```bash
# Simulate project-task-updater agent
CLAUDE_TOOL_NAME="Task" CLAUDE_SUBAGENT_TYPE="project-task-updater" \
./tools/gitlab/gitlab-security-hook.sh

# Simulate GitLab context mention
CLAUDE_CONTEXT="Update the GitLab issue" \
./tools/gitlab/gitlab-security-hook.sh
```

### **GitLab API Integration Test**
```bash
# Test complete workflow
python3 -c "
from gitlab_api import GitLabAPI
import os

# Security validation first
result = os.system('./tools/gitlab/gitlab-security-hook.sh --force')
if result == 0:
    api = GitLabAPI()
    issues = api.list_issues()
    print(f'✅ Secure GitLab access: {len(issues)} issues found')
"
```

## 🔍 **Security Event Logging**

All security events are logged to `.gitlab_hook.log`:

```bash
[2025-09-04 14:30:15] [INFO] Starting GitLab configuration validation
[2025-09-04 14:30:15] [WARN] Insecure file permissions: 644 (fixing to 600)
[2025-09-04 14:30:15] [INFO] Fixed file permissions to 600
[2025-09-04 14:30:15] [INFO] GitLab configuration validation successful
```

## 🛡️ **Security Features**

- **No Secrets in Code**: All configuration in `.gitlab_config` file
- **Secure Permissions**: Auto-fixes to 600 (owner read/write only)
- **Input Validation**: URL format and token length checks  
- **Audit Trail**: Complete logging of all security events
- **Fail-Safe**: Blocks operations when validation fails
- **Environment Isolation**: Uses project-specific configuration

## 🚨 **Troubleshooting**

### **"Missing .gitlab_config file"**
```bash
# Create the required configuration file:
cat > .gitlab_config << 'EOF'
GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=your-token-here  
GITLAB_PROJECT_PATH=scholten/globtim
EOF
chmod 600 .gitlab_config
```

### **"Missing required variables"** 
Check that `.gitlab_config` contains all three required variables:
- `GITLAB_URL`
- `GITLAB_TOKEN` 
- `GITLAB_PROJECT_PATH`

### **"Invalid URL format"**
Ensure `GITLAB_URL` starts with `http://` or `https://`

### **Permission Issues**
The hook will automatically fix permissions, but you can manually set:
```bash
chmod 600 .gitlab_config
```

## 🔄 **Next Steps**

1. **✅ Core Security Hook**: COMPLETE
2. **⏳ Agent-Specific Hooks**: Design hooks for other agents
3. **⏳ Experiment Tracking**: HPC node operation logging
4. **⏳ Folder Organization**: Automated cleanup hooks
5. **⏳ Claude Integration**: Full hook system deployment

---

**Status**: Production Ready ✅  
**Last Updated**: September 4, 2025  
**Version**: 1.0