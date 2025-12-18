# GitLab Issue: project-task-updater Authentication Problem

**Issue Type**: Bug  
**Priority**: High  
**Epic**: project-management  
**Milestone**: Immediate Priority  
**Labels**: `type::bug`, `priority::high`, `epic::project-management`, `agent::project-task-updater`

## Problem Description

The `project-task-updater` agent gets stuck requesting GitLab credentials and opens VSCode password prompt windows, blocking automated GitLab operations.

## Current Behavior

1. When `project-task-updater` agent is invoked
2. Agent attempts to connect to GitLab API
3. Authentication fails and triggers interactive credential request
4. VSCode password dialog opens, requiring manual intervention
5. Automated workflow blocked until manual authentication provided

## Expected Behavior

1. Agent should use existing GitLab token from `.gitlab_config` file
2. No interactive credential prompts should appear
3. Automated GitLab operations should work seamlessly
4. Agent should fail gracefully if authentication is unavailable

## Technical Analysis

### Root Causes
1. **Agent Token Access**: `project-task-updater` agent may not be properly accessing the GitLab token
2. **Authentication Method**: Agent might be using git credentials instead of API token
3. **Environment Variables**: Missing or incorrect GitLab environment configuration
4. **API vs Git Auth**: Confusion between Git authentication and GitLab API authentication

### Current Authentication Setup
- **Token Location**: `/Users/ghscholt/globtim/.gitlab_config`
- **Token Value**: `GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R`
- **API Access**: Working with direct curl commands
- **Manual Scripts**: `tools/gitlab/get-token-noninteractive.sh` works correctly

## Impact Assessment

- **Severity**: High - Blocks automated project management
- **Frequency**: Every time project-task-updater agent is used
- **User Experience**: Poor - Requires manual intervention
- **Workflow Disruption**: Prevents automated issue creation and updates

## Investigation Findings

The issue appears to be that the `project-task-updater` agent is:
1. Not using the non-interactive token retrieval script
2. Possibly attempting Git operations instead of API calls
3. May need specific GitLab API configuration for Claude Code agents

## Proposed Solutions

### Solution 1: Agent Configuration Fix (Recommended)
- Update `project-task-updater` agent to use non-interactive authentication
- Configure agent to use `tools/gitlab/get-token-noninteractive.sh`
- Ensure agent uses GitLab API endpoints, not Git operations

### Solution 2: Environment Variable Setup
- Set `GITLAB_PRIVATE_TOKEN` environment variable for agent access
- Configure Claude Code to pass environment variables to agents
- Add fallback authentication methods

### Solution 3: Agent Authentication Wrapper
- Create wrapper script for GitLab operations
- Wrapper handles authentication and passes results to agent
- Isolates authentication complexity from agent logic

## Implementation Plan

### Phase 1: Immediate Fix (1-2 hours)
1. **Investigate Agent Configuration**: Check how project-task-updater accesses GitLab
2. **Test Token Access**: Verify agent can read `.gitlab_config` file
3. **Update Agent**: Modify agent to use non-interactive authentication
4. **Test GitLab Operations**: Verify agent can create/update issues without prompts

### Phase 2: Robust Authentication (2-4 hours)
1. **Implement Fallback Methods**: Multiple authentication approaches
2. **Add Error Handling**: Graceful failure with helpful error messages  
3. **Documentation**: Clear authentication setup instructions
4. **Testing**: Comprehensive testing of all GitLab operations

### Phase 3: Security Hardening (Optional)
1. **Token Security**: Secure token storage and access
2. **Access Control**: Limit agent permissions appropriately
3. **Audit Logging**: Track agent GitLab operations

## Success Criteria

- [ ] `project-task-updater` agent works without manual intervention
- [ ] No VSCode password dialogs appear during automated operations
- [ ] GitLab issues can be created/updated automatically
- [ ] Agent fails gracefully with clear error messages if authentication unavailable
- [ ] Documentation updated with authentication setup instructions

## Testing Requirements

1. **Automated Testing**: Agent creates/updates GitLab issues without prompts
2. **Error Handling**: Agent handles authentication failures gracefully
3. **Integration Testing**: Works with existing monitoring and workflow systems
4. **Security Testing**: Token access is secure and properly controlled

## Dependencies

- Existing GitLab API configuration (`.gitlab_config`)
- Non-interactive token retrieval scripts
- Claude Code agent system
- VSCode integration settings

## Related Issues

- GitLab Visual Project Management Implementation (#9) - COMPLETED
- HPC Resource Monitor Hook (#26) - Uses similar authentication
- Agent Configuration Review & Improvements (#8) - COMPLETED

---

**Urgency**: This issue should be resolved immediately as it blocks automated project management capabilities that are essential for the 3-phase experiment automation implementation.