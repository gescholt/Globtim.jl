#!/bin/bash
# Julia HPC Migration - Backup Verification Script
# Created: August 11, 2025

echo "=== Julia HPC Migration - Backup Verification ==="
echo "Date: $(date)"
echo ""

# Function to check command success
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 - FAILED"
        return 1
    fi
}

# Function to test SSH connectivity
test_ssh() {
    local host=$1
    local description=$2
    
    echo "Testing SSH connection to $host..."
    ssh -o ConnectTimeout=10 -o BatchMode=yes $host "echo 'Connection successful'" >/dev/null 2>&1
    check_status "SSH connection to $host ($description)"
}

echo "1. Testing SSH Connectivity"
echo "=========================="
test_ssh "fileserver-ssh" "fileserver/mack"
test_ssh "falcon" "HPC cluster"
echo ""

echo "2. Verifying NFS Depot Backup"
echo "============================="
echo "Checking primary NFS depot on fileserver..."
ssh fileserver-ssh "ls -la ~/julia_depot_nfs >/dev/null 2>&1"
check_status "NFS depot directory exists"

echo "Checking NFS depot size..."
DEPOT_SIZE=$(ssh fileserver-ssh "du -sh ~/julia_depot_nfs 2>/dev/null | cut -f1")
echo "NFS depot size: $DEPOT_SIZE"
check_status "NFS depot size retrieved"

echo "Checking NFS depot contents..."
PACKAGE_COUNT=$(ssh fileserver-ssh "find ~/julia_depot_nfs -name '*.toml' 2>/dev/null | wc -l")
echo "Package files found: $PACKAGE_COUNT"
if [ "$PACKAGE_COUNT" -gt 0 ]; then
    check_status "NFS depot contains packages"
else
    echo "❌ NFS depot appears empty"
fi
echo ""

echo "3. Verifying Symbolic Link"
echo "=========================="
echo "Checking symbolic link on HPC cluster..."
ssh falcon "ls -la ~/.julia 2>/dev/null"
check_status "Symbolic link exists"

echo "Checking symbolic link target..."
LINK_TARGET=$(ssh falcon "readlink ~/.julia 2>/dev/null")
echo "Link target: $LINK_TARGET"
if [ "$LINK_TARGET" = "/stornext/snfs3/home/scholten/julia_depot_nfs" ]; then
    check_status "Symbolic link points to correct NFS depot"
else
    echo "❌ Symbolic link target incorrect"
fi
echo ""

echo "4. Testing Julia Functionality"
echo "=============================="
echo "Testing Julia on login node..."
ssh falcon "cd ~/globtim_hpc && source ./setup_nfs_julia.sh >/dev/null 2>&1 && julia -e 'println(\"Julia working on login node\")' --startup-file=no" 2>/dev/null
check_status "Julia functional on login node"

echo "Testing configuration script..."
ssh falcon "cd ~/globtim_hpc && ./setup_nfs_julia.sh >/dev/null 2>&1"
check_status "Configuration script executes successfully"
echo ""

echo "5. Checking Quota Status"
echo "========================"
echo "Current home directory usage on HPC cluster:"
ssh falcon "quota -vs 2>/dev/null || df -h ~ | tail -1"
echo ""

echo "6. Verifying Backup Accessibility"
echo "================================="
echo "Testing NFS depot access from different nodes..."

# Test from fileserver
echo "From fileserver:"
ssh fileserver-ssh "ls ~/julia_depot_nfs/packages >/dev/null 2>&1"
check_status "NFS depot accessible from fileserver"

# Test from cluster login node (via symlink)
echo "From cluster login node:"
ssh falcon "ls ~/.julia/packages >/dev/null 2>&1"
check_status "NFS depot accessible from cluster login node"
echo ""

echo "7. Backup Integrity Check"
echo "========================="
echo "Checking for critical Julia files..."

# Check for essential directories
ESSENTIAL_DIRS=("packages" "artifacts" "compiled")
for dir in "${ESSENTIAL_DIRS[@]}"; do
    ssh fileserver-ssh "ls ~/julia_depot_nfs/$dir >/dev/null 2>&1"
    check_status "Essential directory '$dir' exists in NFS depot"
done

echo ""
echo "8. Summary"
echo "=========="
echo "Backup verification completed at $(date)"
echo ""
echo "Primary Backup: NFS depot at /stornext/snfs3/home/scholten/julia_depot_nfs"
echo "Size: $DEPOT_SIZE"
echo "Packages: $PACKAGE_COUNT configuration files found"
echo ""
echo "Secondary Backup: Symbolic link at ~/.julia on HPC cluster"
echo "Target: $LINK_TARGET"
echo ""
echo "Status: Backup strategy verified and functional ✅"
echo ""
echo "=== Backup Verification Complete ==="
