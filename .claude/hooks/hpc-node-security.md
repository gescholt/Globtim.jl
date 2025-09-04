# HPC Node Security Hook Configuration

This hook automatically validates and secures all HPC node operations before execution by Claude Code agents.

## Hook Configuration

```yaml
name: hpc-node-security
events:
  - pre_tool_use
script: tools/hpc/node-security-hook.sh
description: "Validates SSH access, security policies, and experiment environment for HPC operations"
```

## Trigger Conditions

This hook activates when Claude Code detects HPC-related context in:

- **Tool Usage**: Any agent using tools with HPC-related operations
- **Context Keywords**: cluster, hpc, r04n02, ssh, tmux, node, experiment
- **Agent Types**: Particularly hpc-cluster-operator, julia-test-architect, julia-documenter-expert

## Security Validations

### 1. SSH Configuration
- ✅ SSH private key exists (`~/.ssh/id_rsa`)
- ✅ SSH key has correct permissions (600)
- ✅ SSH connection to r04n02 works (non-interactive test)

### 2. Access Security Policies
- ❌ Prevents credential exposure in context
- ❌ Blocks operations in `/tmp` directory (enforces `/home/scholten/globtim/hpc/experiments/temp/`)
- ❌ Detects potentially destructive command patterns

### 3. Experiment Environment
- ✅ Validates secure node configuration wrapper exists
- ✅ Tests Python wrapper functionality
- ✅ Checks agent compliance with security protocols

## Integration with Agents

### Automatic Enforcement
All agents automatically benefit from this security validation:

```python
# When any agent attempts HPC operations, the hook runs automatically
# and provides secure access patterns

# ✅ SECURE: Uses validated SSH access
node = SecureNodeAccess()
result = node.execute_command("ls /home/scholten/globtim")

# ❌ BLOCKED: Direct SSH without validation would trigger security warnings
```

### Agent-Specific Guidance

#### hpc-cluster-operator
- **Primary HPC agent** - Full security validation enforced
- Must use SecureNodeAccess wrapper for all node operations
- Automatic logging and audit trail

#### julia-test-architect, julia-documenter-expert
- Security protocols active when HPC context detected
- Guided to use hpc-cluster-operator for cluster operations

#### Other Agents
- Warning issued if attempting cluster access
- Redirected to use appropriate HPC-specialized agents

## Default Workflow Integration

This hook establishes secure-by-default HPC operations:

1. **Pre-validation**: All HPC operations validated before execution
2. **Secure Access**: Enforces use of SecureNodeAccess wrapper
3. **Audit Logging**: All operations logged to `.node_security.log`
4. **Error Prevention**: Blocks dangerous operations before execution
5. **Agent Guidance**: Provides clear guidance for secure patterns

## Troubleshooting

If HPC operations are blocked:

### SSH Issues
```bash
# Test SSH configuration
CLAUDE_CONTEXT="Test HPC access" ./tools/hpc/node-security-hook.sh

# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Test direct SSH connection
ssh -o ConnectTimeout=5 scholten@r04n02 "echo 'Connected successfully'"
```

### Security Policy Violations
- **"/tmp directory blocked"**: Use `/home/scholten/globtim/hpc/experiments/temp/` instead
- **Credential exposure detected**: Ensure context doesn't contain sensitive data
- **Destructive command pattern**: Review command for potentially dangerous operations

### Python Wrapper Issues
```bash
# Test secure node configuration
cd /path/to/globtim
python3 -c "from tools.hpc.secure_node_config import SecureNodeAccess; print('OK')"
```

## Monitoring Integration

The security hook integrates with the monitoring system:

- **Security Events**: Logged to audit trail
- **Agent Compliance**: Tracked and reported
- **Anomaly Detection**: Security violations trigger monitoring alerts
- **GitLab Integration**: Security events can update project issues

## Benefits

✅ **Zero-Configuration Security**: Agents automatically use secure patterns
✅ **Audit Compliance**: Complete trail of all HPC operations  
✅ **Error Prevention**: Blocks problems before they occur
✅ **Consistency**: All agents follow identical security protocols
✅ **Transparency**: Clear logging and feedback for all operations