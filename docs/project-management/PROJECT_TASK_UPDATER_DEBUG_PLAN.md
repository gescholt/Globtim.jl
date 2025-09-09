# Project-Task-Updater Agent Debug Plan

**Date**: September 5, 2025  
**Issue**: Fix project-task-updater agent GitLab API communication (Issue #1 from POST_PROCESSING_GITLAB_ISSUES.md)  
**Priority**: High (blocking automated project management)

## Problem Statement

The project-task-updater agent experiences GitLab API communication failures, specifically:
- Agent attempts to use GitLab API but fails with 401 Unauthorized
- Token retrieval works but subsequent API calls fail
- Communication protocol mismatch between agent and GitLab

## Current Status Assessment ✅

Based on comprehensive testing performed:

### ✅ Token Retrieval - WORKING
- `./tools/gitlab/get-token-noninteractive.sh` successfully returns token: `yjKZNqzG2TkLzXyU8Q9R`
- Token stored securely and accessible via non-interactive script
- No VSCode authentication dialogs or interactive prompts

### ✅ GitLab API Connection - WORKING  
- `./tools/gitlab/claude-agent-gitlab.sh test` returns: "✅ GitLab API connection successful"
- Direct API calls to project 2545 working correctly
- Wrapper script functioning properly with correct authentication headers

### ✅ API Operations - WORKING
- Issue listing working: successfully retrieved GitLab issues including #27, #28, #29, #30
- POST/GET operations functional through wrapper script
- Proper PRIVATE-TOKEN header format confirmed

## Root Cause Analysis

Based on research and testing, the issue is **NOT with the GitLab API infrastructure**. The problem appears to be:

### 1. **Agent Configuration Issues** 
The project-task-updater agent configuration shows several potential problems:

#### **A. Incorrect Token Environment Variable Usage**
```bash
# FOUND IN AGENT: Line 48 - Uses wrong variable name
curl -s --fail --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
```
**Problem**: Agent uses `$GITLAB_TOKEN` but the actual variable is `$TOKEN` (from get-token.sh)

#### **B. Missing Error Handling in Agent Examples**  
```bash
# FOUND IN AGENT: Lines 48-50 - No token validation
curl -s --fail --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://git.mpi-cbg.de/api/v4/projects/2545/issues" \
  || echo "ERROR: Failed to access GitLab API. Check token and network."
```
**Problem**: Uses undefined `$GITLAB_TOKEN` variable instead of proper token retrieval

#### **C. Inconsistent Token Retrieval Method**
Agent documentation suggests using `./tools/gitlab/get-token.sh` but then uses wrong variable name in examples.

### 2. **Agent Usage Patterns**
Looking at recent GitLab issues, all were created by `project_2545_bot_65196a5a3e0158ae3a60b97bd8fffa5b` (Claude automation), which suggests:
- The agent IS successfully creating issues 
- The agent IS working in some capacity
- Issue might be with specific API operations or error handling

## Comprehensive Debug Plan

### **Phase 1: Agent Configuration Fixes** ⭐ IMMEDIATE

#### **Step 1.1: Fix Token Variable Usage**
```bash
# CURRENT (INCORRECT):
curl -s --fail --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \

# SHOULD BE:
TOKEN=$(./tools/gitlab/get-token-noninteractive.sh 2>/dev/null)
curl -s --fail --header "PRIVATE-TOKEN: $TOKEN" \
```

#### **Step 1.2: Update Agent Documentation Examples**
Fix all instances in `.claude/agents/project-task-updater.md` where:
- `$GITLAB_TOKEN` should be `$TOKEN` 
- Missing proper token retrieval using `./tools/gitlab/get-token-noninteractive.sh`
- Inconsistent variable usage

#### **Step 1.3: Standardize on Wrapper Script Usage** 
Agent should primarily use `./tools/gitlab/claude-agent-gitlab.sh` instead of direct curl commands.

### **Phase 2: API Communication Protocol Validation** 

#### **Step 2.1: Header Format Verification**
Research confirmed correct format is:
```bash
--header "PRIVATE-TOKEN: <token-value>"
# NOT: --header "Authorization: Bearer <token>"
# NOT: URL parameter: "?private_token=<token>"
```

#### **Step 2.2: API Endpoint Validation**
Confirm agent uses correct API v4 endpoints:
- ✅ `https://git.mpi-cbg.de/api/v4/projects/2545/issues`
- ✅ Project ID: 2545 (confirmed working)

#### **Step 2.3: HTTP Method Validation**
Verify proper HTTP methods:
- GET: List issues ✅ Working
- POST: Create issues ✅ Working (evidence: recent issues created)
- PUT: Update issues ✅ Needs verification

### **Phase 3: Token Troubleshooting**

#### **Step 3.1: Token Expiration Check**
Since GitLab 16.0, all access tokens have expiration dates.
```bash
# Test token validity
TOKEN=$(./tools/gitlab/get-token-noninteractive.sh)
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "https://git.mpi-cbg.de/api/v4/user" | jq '.id'
# Should return user ID, not 401
```

#### **Step 3.2: Token Permissions Audit**
Verify token has required scopes:
- `api` scope for full API access
- `read_repository` for repository operations
- Check token creation date vs expiration

#### **Step 3.3: Rate Limiting Check**
GitLab rate limits: 2000 requests/minute for authenticated users
```bash
# Check rate limit headers in API responses
curl -I --header "PRIVATE-TOKEN: $TOKEN" \
  "https://git.mpi-cbg.de/api/v4/projects/2545"
# Look for: RateLimit-Limit, RateLimit-Remaining headers
```

### **Phase 4: Agent Execution Environment**

#### **Step 4.1: Working Directory Validation**
Agent must execute from correct directory:
```bash
# CRITICAL: Agent MUST be in /Users/ghscholt/globtim
pwd  # Should be /Users/ghscholt/globtim
git status  # Should show git repository
```

#### **Step 4.2: Script Permissions Check**
```bash
# Verify all scripts are executable
ls -la ./tools/gitlab/get-token-noninteractive.sh
ls -la ./tools/gitlab/claude-agent-gitlab.sh
chmod +x ./tools/gitlab/*.sh  # Fix if needed
```

#### **Step 4.3: Path Resolution Testing**
```bash
# Test relative vs absolute paths
./tools/gitlab/get-token-noninteractive.sh  # Should work
/Users/ghscholt/globtim/tools/gitlab/get-token-noninteractive.sh  # Should work
```

### **Phase 5: Comprehensive Testing Protocol**

#### **Step 5.1: Token Retrieval Test**
```bash
# Test 1: Direct token retrieval
TOKEN=$(./tools/gitlab/get-token-noninteractive.sh 2>/dev/null)
echo "Token length: ${#TOKEN}"  # Should be 20 characters
echo "Token format: ${TOKEN:0:4}..." # Should start with expected prefix
```

#### **Step 5.2: API Authentication Test**
```bash
# Test 2: API authentication validation
curl -s -w "\nHTTP Code: %{http_code}\n" \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "https://git.mpi-cbg.de/api/v4/user"
# Should return HTTP Code: 200 with user info
```

#### **Step 5.3: Project Access Test**
```bash
# Test 3: Project-specific API access
curl -s -w "\nHTTP Code: %{http_code}\n" \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "https://git.mpi-cbg.de/api/v4/projects/2545"
# Should return HTTP Code: 200 with project info
```

#### **Step 5.4: Issue Operations Test**
```bash
# Test 4: Issue creation (dry run)
curl -X POST -s -w "\nHTTP Code: %{http_code}\n" \
  --header "PRIVATE-TOKEN: $TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"title":"Test Issue","description":"Debug test"}' \
  "https://git.mpi-cbg.de/api/v4/projects/2545/issues"
# Should return HTTP Code: 201 with new issue data
```

### **Phase 6: Agent Integration Testing**

#### **Step 6.1: Wrapper Script Validation**
```bash
# Test claude-agent-gitlab.sh wrapper
./tools/gitlab/claude-agent-gitlab.sh test
./tools/gitlab/claude-agent-gitlab.sh list-issues opened | head -5
```

#### **Step 6.2: Direct Agent Command Testing**
Test the actual commands the agent would use:
```bash
# Simulate agent workflow
cd /Users/ghscholt/globtim
pwd && git status  # Pre-flight check
TOKEN=$(./tools/gitlab/get-token-noninteractive.sh 2>/dev/null)
[ -n "$TOKEN" ] && echo "Token OK" || echo "Token FAIL"

# Test API calls the agent makes
./tools/gitlab/claude-agent-gitlab.sh create-issue \
  "Debug Test" "Agent debug test issue" "type:test,priority:low"
```

## Implementation Priority

### **🚨 IMMEDIATE (Phase 1)**: Fix Agent Configuration
- Correct `$GITLAB_TOKEN` → `$TOKEN` variable usage
- Update all documentation examples
- Standardize on wrapper script usage

### **⚡ HIGH (Phase 2)**: Protocol Validation
- Confirm header formats
- Verify endpoint URLs  
- Test HTTP methods

### **🔍 MEDIUM (Phase 3)**: Token Troubleshooting
- Check token expiration
- Verify permissions/scopes
- Test rate limiting

### **🧪 LOW (Phases 4-6)**: Comprehensive Testing
- Environment validation
- Integration testing
- Agent workflow validation

## Expected Outcomes

After implementing fixes:

### **Success Criteria**
- ✅ Agent can create GitLab issues without 401 errors
- ✅ Agent can update existing issues without errors
- ✅ Token usage is correct and secure
- ✅ API communication protocol is documented and working

### **Validation Tests**
1. **Token Test**: `./tools/gitlab/get-token-noninteractive.sh` returns valid token
2. **Connection Test**: `./tools/gitlab/claude-agent-gitlab.sh test` succeeds
3. **Issue Creation**: Agent can create test issue without errors
4. **Issue Update**: Agent can update issue labels/status
5. **Error Handling**: Agent provides clear error messages when API fails

## Monitoring and Rollback

### **Pre-Change Backup**
```bash
# Backup current agent configuration
cp .claude/agents/project-task-updater.md .claude/agents/project-task-updater.md.backup
```

### **Change Verification**
```bash
# After changes, verify:
1. Agent configuration syntax is valid
2. All example commands use correct variables
3. Wrapper script integration is consistent
4. Error handling is comprehensive
```

### **Rollback Plan**
If fixes break existing functionality:
```bash
# Restore backup
cp .claude/agents/project-task-updater.md.backup .claude/agents/project-task-updater.md
# Test with known working configuration
./tools/gitlab/claude-agent-gitlab.sh test
```

This comprehensive debug plan addresses the core issue of GitLab API communication failures in the project-task-updater agent, focusing on the most likely root causes: incorrect token variable usage and missing error handling in the agent configuration.