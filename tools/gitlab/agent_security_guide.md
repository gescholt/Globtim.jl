# GitLab Security Compliance Guide for Agents

## ✅ Security Compliance Status

All GitLab-related scripts and agents have been updated to use the security hook system instead of handling tokens directly.

### Secure Integration Pattern

**✅ CORRECT APPROACH:** Use the security hook system
```bash
# For shell scripts - automatic via security hook
CLAUDE_CONTEXT="GitLab operation" ./tools/gitlab/gitlab-security-hook.sh
./tools/gitlab/gitlab-api.sh GET "/projects/2545/issues"
```

**✅ CORRECT APPROACH:** Use the secure Python wrapper
```python
from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI, GitLabSecurityError

try:
    api = SecureGitLabAPI()  # Automatically validates security
    issues = api.list_issues()
except GitLabSecurityError as e:
    print(f"Security validation failed: {e}")
```

**❌ DEPRECATED APPROACH:** Direct token handling
```python
# DON'T DO THIS - bypasses security validation
token = get_gitlab_token()  # This function now raises an error
```

### Updated Components

#### 1. Python Scripts - SECURED ✅

- **`gitlab_manager.py`**: Updated to use SecureGitLabAPI wrapper
  - Direct token functions now raise deprecation errors
  - All operations go through security validation
  
- **`gitlab_api.py`**: Deprecated and redirected to secure wrapper
  - Backward compatibility maintained
  - Deprecation warnings guide users to secure approach
  
- **`secure_gitlab_wrapper.py`**: NEW security-compliant wrapper
  - Automatic security hook validation
  - Uses gitlab-api.sh for all actual API calls
  - No direct token handling

#### 2. Shell Scripts - COMPLIANT ✅

- **`gitlab-api.sh`**: Uses get-token.sh (secure token retrieval)
- **`gitlab-security-hook.sh`**: Validates all operations
- All existing scripts already follow security pattern

### For Claude Code Agents

**IMPORTANT:** All agents should use this pattern for GitLab operations:

```markdown
## Recommended GitLab Integration for Agents

1. **Direct API Calls (Recommended)**:
   ```bash
   # Security validation happens automatically
   ./tools/gitlab/gitlab-api.sh GET "/projects/2545/issues/26"
   ```

2. **Python Integration (When Needed)**:
   ```python
   from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI
   api = SecureGitLabAPI()  # Security validation automatic
   response = api.get_issue(26)
   ```

3. **NEVER**:
   - Handle tokens directly
   - Use deprecated gitlab_manager.py functions
   - Bypass security validation
```

### Security Validation Features

The security hook system provides:

- ✅ **Token Security**: No tokens in agent configurations or scripts
- ✅ **Audit Trail**: All operations logged to `.gitlab_hook.log`
- ✅ **Validation**: Configuration validated before each operation
- ✅ **Error Prevention**: Invalid configs blocked before API calls
- ✅ **Permission Management**: Automatic file permission fixes

### Troubleshooting

**If GitLab operations fail:**

1. **Check Security Hook**:
   ```bash
   CLAUDE_CONTEXT="Test GitLab" ./tools/gitlab/gitlab-security-hook.sh
   ```

2. **Verify Token Setup**:
   ```bash
   ./tools/gitlab/get-token.sh
   ```

3. **Check Configuration**:
   ```bash
   ls -la .gitlab_config  # Should exist with proper permissions
   ```

**Common Issues:**

- **Token Timeout**: Usually indicates credential helper issues
- **Permission Denied**: Run `tools/gitlab/setup-secure-config.sh` 
- **Configuration Missing**: Ensure `.gitlab_config` exists

### Implementation Status

| Component | Status | Security Compliance |
|-----------|--------|-------------------|
| gitlab-security-hook.sh | ✅ READY | Full validation |
| gitlab-api.sh | ✅ READY | Token via secure script |
| secure_gitlab_wrapper.py | ✅ READY | Hook validation |
| gitlab_manager.py | ✅ SECURED | Deprecated direct access |
| gitlab_api.py | ✅ SECURED | Redirected to secure wrapper |

**Result**: All GitLab operations now require security validation and never handle tokens directly.