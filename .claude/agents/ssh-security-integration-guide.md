---
name: ssh-security-integration-guide
description: Integration guide for SSH security framework across Claude Code agents requiring HPC cluster access
---

# SSH Security Hook Integration Guide for Claude Code Agents

## 🎯 Overview

This guide provides specific implementation instructions for integrating the SSH Security Hook system into Claude Code agents that require HPC cluster access. All agents listed below must use the secure SSH communication framework when interacting with cluster nodes.

## 🔧 Implementation Requirements

### Core Security Hook Integration

All agents requiring cluster access must integrate with:
- **`tools/hpc/ssh-security-hook.sh`** - Main SSH security validation framework
- **`tools/hpc/node-security-hook.sh`** - HPC-specific security policies  
- **`tools/hpc/secure_node_config.py`** - Python secure access wrapper

### Environment Variables Required

When triggering SSH security validation, agents should set:
```bash
export CLAUDE_CONTEXT="[Agent-specific description of operation]"
export CLAUDE_TOOL_NAME="[Tool being used]"  
export CLAUDE_SUBAGENT_TYPE="[agent-name]"
```

## 🤖 Agent-Specific Integration Instructions

### 1. ✅ hpc-cluster-operator (COMPLETED)

**Status**: **Production Ready** - SSH security fully integrated
**Priority**: Core agent - security framework designed around this agent

**Current Integration**:
```markdown
# Already includes SSH security validation in agent description
# Uses SecureNodeAccess wrapper for all operations
# Automatic security hook activation on HPC context detection
```

**No additional changes required** - this agent is the reference implementation.

### 2. 🔧 project-task-updater (HIGH PRIORITY)

**Status**: **Integration Required**
**Priority**: Critical - needs HPC access for deployment status validation

**Required Integration**:
```markdown
# Add to agent description:
When updating issues related to HPC cluster operations, deployment status, 
or node-specific tasks, this agent must validate cluster connectivity and 
status through the SSH security framework before updating GitLab issues.

Examples of HPC-related contexts:
- Deployment completion validation
- Cluster job status verification  
- Node resource status updates
- HPC experiment progress tracking

# Trigger SSH security hook when HPC context detected:
CLAUDE_CONTEXT="GitLab issue update for HPC deployment status"
CLAUDE_TOOL_NAME="gitlab-api" 
CLAUDE_SUBAGENT_TYPE="project-task-updater"
```

**Implementation Steps**:
1. Update agent description to include HPC security validation requirement
2. Add SSH security hook trigger for HPC-related GitLab operations
3. Integrate with `secure_node_config.py` for cluster status validation
4. Test with GitLab Issue #26 updates

### 3. 🧪 julia-test-architect (MEDIUM PRIORITY)

**Status**: **Conditional Integration Required**
**Priority**: Medium - needs HPC access for cluster-specific testing

**Required Integration**:
```markdown
# Add to agent description:
When creating tests that require HPC cluster execution, validation of cluster 
environments, or testing of HPC-specific functionality, this agent must use 
the SSH security framework for secure cluster access.

HPC testing scenarios requiring security validation:
- Cluster-specific test execution
- HPC environment validation tests
- Performance benchmarking on cluster hardware
- Cross-platform test validation (local vs cluster)

# Trigger SSH security hook for HPC testing:
CLAUDE_CONTEXT="Creating HPC cluster tests for [specific functionality]"
CLAUDE_TOOL_NAME="test-creation"
CLAUDE_SUBAGENT_TYPE="julia-test-architect"
```

**Implementation Steps**:
1. Modify agent to detect HPC testing requirements
2. Add SSH security validation for cluster test execution
3. Integrate secure node access for test environment validation
4. Create test templates that use SSH security framework

### 4. 📚 julia-documenter-expert (LOW PRIORITY)

**Status**: **Optional Integration**
**Priority**: Low - minimal HPC interaction but may need cluster examples

**Conditional Integration**:
```markdown
# Add to agent description (optional):
When documenting HPC-specific functionality, cluster deployment procedures, 
or creating examples that demonstrate cluster operations, this agent may 
optionally use the SSH security framework for live validation of 
documentation examples.

Optional HPC documentation scenarios:
- Validating code examples on actual cluster
- Creating cluster deployment documentation
- Documenting HPC-specific configuration

# Optional SSH security hook trigger:
CLAUDE_CONTEXT="Documenting HPC cluster functionality with live validation"
CLAUDE_TOOL_NAME="documentation"
CLAUDE_SUBAGENT_TYPE="julia-documenter-expert"
```

**Implementation Steps** (Optional):
1. Add optional HPC validation capability to agent description
2. Allow SSH security framework usage for live documentation validation
3. Integrate with cluster for real-time example verification

### 5. 🔍 julia-repo-guardian (MINIMAL PRIORITY)

**Status**: **Minimal Integration**  
**Priority**: Very Low - only for cross-environment consistency checking

**Minimal Integration**:
```markdown
# Add to agent description (minimal):
When performing repository consistency checks that span both local and 
cluster environments, this agent may use the SSH security framework to 
validate consistency across environments.

Rare cross-environment scenarios:
- Validating cluster-specific configuration files
- Checking consistency of deployment scripts
- Verifying cluster-specific dependencies

# Minimal SSH security hook trigger:
CLAUDE_CONTEXT="Repository consistency check across cluster environment"
CLAUDE_TOOL_NAME="consistency-check"  
CLAUDE_SUBAGENT_TYPE="julia-repo-guardian"
```

**Implementation Steps** (Minimal):
1. Add optional cluster consistency checking capability
2. Minimal SSH security framework integration for environment validation

## 🔒 Security Hook Integration Patterns

### Pattern 1: Automatic Activation (Recommended)
```bash
# Agent automatically detects HPC context and triggers security validation
if [[ "$CLAUDE_CONTEXT" =~ (cluster|hpc|r04n02|ssh|node|experiment) ]]; then
    ./tools/hpc/ssh-security-hook.sh validate
fi
```

### Pattern 2: Explicit Integration (For specific operations)
```python
from tools.hpc.secure_node_config import SecureNodeAccess

# Always use secure wrapper for cluster operations
node = SecureNodeAccess()  # Automatic security validation
result = node.execute_command("status check command")
```

### Pattern 3: Conditional Security (For optional HPC features)
```bash
# Only use security framework when HPC operations are specifically required
if [[ "$ENABLE_HPC_VALIDATION" == "true" ]]; then
    CLAUDE_CONTEXT="Optional HPC validation" ./tools/hpc/ssh-security-hook.sh
fi
```

## 🧪 Testing Integration

### Integration Test Template
```bash
#!/bin/bash
# Test SSH security integration for [agent-name]

# Set agent context
export CLAUDE_CONTEXT="Test [agent-name] SSH security integration"
export CLAUDE_SUBAGENT_TYPE="[agent-name]"

# Test security validation
echo "Testing SSH security hook integration..."
./tools/hpc/ssh-security-hook.sh validate

# Test secure connection
echo "Testing secure node access..."
./tools/hpc/ssh-security-hook.sh test r04n02

# Test secure command execution
echo "Testing secure command execution..."
./tools/hpc/ssh-security-hook.sh execute r04n02 "echo 'Integration test successful'"

echo "✅ [Agent-name] SSH security integration test completed"
```

## 📊 Integration Priority and Timeline

### Phase 1: Critical Integration (Immediate)
- ✅ **hpc-cluster-operator** - Already complete
- 🔧 **project-task-updater** - Required for GitLab issue validation

### Phase 2: Standard Integration (Week 1)  
- 🧪 **julia-test-architect** - Required for HPC testing scenarios

### Phase 3: Optional Integration (As Needed)
- 📚 **julia-documenter-expert** - Optional for live documentation validation
- 🔍 **julia-repo-guardian** - Minimal for cross-environment consistency

## 🎯 Success Criteria

### Per-Agent Integration Success
- [ ] Agent properly triggers SSH security validation for HPC operations
- [ ] Agent uses `SecureNodeAccess` wrapper for all cluster communications
- [ ] Agent logs are properly integrated with SSH security audit trail
- [ ] Agent operations complete with <100ms security validation overhead

### System-Wide Integration Success  
- [ ] All agents requiring HPC access use SSH security framework
- [ ] No direct SSH operations bypass security validation
- [ ] Complete audit trail captures all agent cluster interactions
- [ ] Security monitoring dashboard shows all agent activities

## 🚀 Deployment Verification

### Post-Integration Testing
```bash
# Verify each agent's SSH security integration
for agent in hpc-cluster-operator project-task-updater julia-test-architect; do
    echo "Testing $agent SSH security integration..."
    CLAUDE_SUBAGENT_TYPE="$agent" ./tools/hpc/ssh-security-hook.sh validate
done

# Check security monitoring dashboard
./tools/hpc/ssh-security-hook.sh monitor

# Verify no direct SSH bypass in agent operations
grep -r "ssh.*r04n02" .claude/agents/ --exclude="*ssh-security*"
```

---

## 📋 Implementation Checklist

### For Each Agent Requiring Integration:
- [ ] Update agent description with SSH security requirements
- [ ] Add appropriate CLAUDE_CONTEXT triggers for HPC operations  
- [ ] Integrate with `secure_node_config.py` wrapper
- [ ] Test security validation and cluster access
- [ ] Verify audit logging captures agent operations
- [ ] Update agent documentation with security examples

### System-Wide Verification:
- [ ] All HPC-related operations use SSH security framework
- [ ] Security monitoring dashboard shows all agent activities  
- [ ] Complete audit trail for forensics and compliance
- [ ] Performance meets <100ms validation overhead requirement

**Status**: SSH Security Framework ready for agent integration deployment