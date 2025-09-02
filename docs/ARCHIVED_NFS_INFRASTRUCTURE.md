# ARCHIVED: Legacy NFS Infrastructure Documentation

**Status:** ARCHIVED - Superseded by direct r04n02 compute node access  
**Archive Date:** September 2, 2025  
**Reason:** Infrastructure modernization - direct node access eliminates NFS complexity

## Legacy NFS Fileserver Workflow (HISTORICAL)

### Overview
This document preserves the historical NFS-based workflow that was used before the implementation of direct r04n02 compute node access. This approach is no longer recommended but is archived for reference.

### Legacy File Transfer Path
```
Local Development → NFS Fileserver (mack) → Shared /home/scholten/ → HPC Cluster (falcon)
```

### Legacy Constraints
- **Home directory quota**: 1GB on falcon cluster  
- **NFS shared space**: Unlimited via mack fileserver
- **Compute nodes**: No internet access, air-gapped
- **Transfer limit**: 1GB direct transfer limit to falcon

### Legacy Commands
```bash
# Transfer bundle to cluster (via NFS)
scp bundle.tar.gz scholten@mack:/home/scholten/

# Access from cluster (same path)
ssh scholten@falcon
ls ~/bundle.tar.gz  # Available immediately
```

### Legacy Bundle Approaches
- Bundle creation with Julia depot
- Offline package management
- Complex environment variable configuration
- Manifest.toml synchronization challenges

### Why This Was Replaced
1. **Quota Constraints**: 1GB home directory limit was restrictive
2. **Complexity**: Multi-step file transfer process was error-prone
3. **Bundle Issues**: Cross-platform compilation problems (macOS to Linux)
4. **Package Compatibility**: Only ~50% success rate with bundled packages
5. **Maintenance Burden**: Constant workarounds for architecture differences

### Migration to Modern Infrastructure
The modern r04n02 direct node access provides:
- Direct SSH access to compute node
- Native Julia package installation (~90% success rate)
- Direct Git repository cloning
- No quota constraints in `/tmp/`
- Simplified deployment workflow

## Related Historical Documents
- Various bundle creation scripts (removed)
- Legacy deployment scripts (archived)
- NFS transfer procedures (superseded)

---
*This documentation is archived and should not be used for current HPC operations. Refer to the main CLAUDE.md file for current procedures.*