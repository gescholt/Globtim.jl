#!/usr/bin/env python3

"""
Update Remaining Submission Scripts for NFS Integration
======================================================

This script updates the remaining submission scripts that haven't been
migrated to use the new NFS Julia depot configuration.

Scripts to update:
- submit_globtim_compilation_test.py
- submit_basic_test.py

Usage:
    python update_remaining_scripts.py [--dry-run] [--backup]
"""

import argparse
import shutil
import re
from pathlib import Path
from datetime import datetime

class ScriptUpdater:
    def __init__(self, dry_run=False, backup=True):
        self.dry_run = dry_run
        self.backup = backup
        self.submission_dir = Path("hpc/jobs/submission")
        
        # Scripts that need updating
        self.scripts_to_update = [
            "submit_globtim_compilation_test.py",
            "submit_basic_test.py"
        ]
        
        # NFS configuration template
        self.nfs_config_template = '''# Source NFS Julia configuration script
echo "=== Configuring Julia for NFS ==="
source ./setup_nfs_julia.sh

# Verify NFS depot is accessible
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ NFS Julia depot configured: $JULIA_DEPOT_PATH"
else
    echo "❌ NFS Julia depot not accessible: $JULIA_DEPOT_PATH"
    exit 1
fi'''
        
    def log(self, message, level="INFO"):
        """Log message with timestamp"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        prefix = "DRY-RUN: " if self.dry_run else ""
        print(f"[{timestamp}] {prefix}{level}: {message}")
        
    def backup_file(self, file_path):
        """Create backup of file"""
        if not self.backup:
            return
            
        backup_path = file_path.with_suffix(f".backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.py")
        
        if not self.dry_run:
            shutil.copy2(file_path, backup_path)
            
        self.log(f"Created backup: {backup_path}")
        
    def update_globtim_compilation_test(self):
        """Update submit_globtim_compilation_test.py"""
        file_path = self.submission_dir / "submit_globtim_compilation_test.py"
        
        if not file_path.exists():
            self.log(f"File not found: {file_path}", "ERROR")
            return False
            
        self.log(f"Updating {file_path.name}...")
        
        # Read current content
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Create backup
        self.backup_file(file_path)
        
        # Replace old depot configuration
        old_pattern = r'# Environment setup\nexport JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK\nexport JULIA_DEPOT_PATH="\$HOME/globtim_hpc/\.julia:\$JULIA_DEPOT_PATH"'
        
        new_config = f'''# Environment setup with NFS Julia configuration
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

{self.nfs_config_template}'''
        
        # Perform replacement
        updated_content = re.sub(old_pattern, new_config, content, flags=re.MULTILINE)
        
        if updated_content == content:
            self.log("No changes needed - pattern not found", "WARNING")
            return False
            
        # Write updated content
        if not self.dry_run:
            with open(file_path, 'w') as f:
                f.write(updated_content)
                
        self.log(f"✅ Updated {file_path.name}")
        return True
        
    def update_basic_test(self):
        """Update submit_basic_test.py"""
        file_path = self.submission_dir / "submit_basic_test.py"
        
        if not file_path.exists():
            self.log(f"File not found: {file_path}", "ERROR")
            return False
            
        self.log(f"Updating {file_path.name}...")
        
        # Read current content
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Create backup
        self.backup_file(file_path)
        
        # Replace old depot configuration in SLURM script
        old_pattern1 = r'# Environment setup with quota workaround\nexport JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK\nexport JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:\$JULIA_DEPOT_PATH"'
        
        new_config1 = f'''# Environment setup with NFS Julia configuration
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

{self.nfs_config_template}'''
        
        # Replace old depot configuration in direct test
        old_pattern2 = r'export JULIA_DEPOT_PATH="\{self\.depot_path\}:\$JULIA_DEPOT_PATH"'
        new_config2 = '''# Source NFS Julia configuration
source ./setup_nfs_julia.sh

# Verify NFS depot is accessible
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ NFS Julia depot configured: $JULIA_DEPOT_PATH"
else
    echo "❌ NFS Julia depot not accessible: $JULIA_DEPOT_PATH"
    exit 1
fi'''
        
        # Perform replacements
        updated_content = re.sub(old_pattern1, new_config1, content, flags=re.MULTILINE)
        updated_content = re.sub(old_pattern2, new_config2, updated_content, flags=re.MULTILINE)
        
        # Also update the depot_path initialization to use NFS
        old_depot_init = r'self\.depot_path = "/tmp/julia_depot_globtim_persistent"'
        new_depot_init = 'self.depot_path = "NFS_CONFIGURED"  # Will be set by setup_nfs_julia.sh'
        updated_content = re.sub(old_depot_init, new_depot_init, updated_content)
        
        if updated_content == content:
            self.log("No changes needed - patterns not found", "WARNING")
            return False
            
        # Write updated content
        if not self.dry_run:
            with open(file_path, 'w') as f:
                f.write(updated_content)
                
        self.log(f"✅ Updated {file_path.name}")
        return True
        
    def verify_updates(self):
        """Verify that updates were applied correctly"""
        self.log("🔍 Verifying updates...")
        
        verification_results = {}
        
        for script_name in self.scripts_to_update:
            file_path = self.submission_dir / script_name
            
            if not file_path.exists():
                verification_results[script_name] = {"exists": False}
                continue
                
            with open(file_path, 'r') as f:
                content = f.read()
                
            # Check for NFS configuration
            has_nfs_config = "source ./setup_nfs_julia.sh" in content
            has_old_config = "/tmp/julia_depot_globtim_persistent" in content or "$HOME/globtim_hpc/.julia" in content
            
            verification_results[script_name] = {
                "exists": True,
                "has_nfs_config": has_nfs_config,
                "has_old_config": has_old_config,
                "status": "UPDATED" if has_nfs_config and not has_old_config else "NEEDS_UPDATE"
            }
            
        return verification_results
        
    def generate_report(self, verification_results):
        """Generate update report"""
        print("\n" + "="*60)
        print("  SUBMISSION SCRIPT UPDATE REPORT")
        print("="*60)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Mode: {'DRY-RUN' if self.dry_run else 'LIVE UPDATE'}")
        print()
        
        for script_name, results in verification_results.items():
            if not results["exists"]:
                print(f"❌ {script_name}: FILE NOT FOUND")
                continue
                
            status = results["status"]
            emoji = "✅" if status == "UPDATED" else "❌"
            print(f"{emoji} {script_name}: {status}")
            
            if results["has_nfs_config"]:
                print(f"   ✅ Has NFS configuration")
            else:
                print(f"   ❌ Missing NFS configuration")
                
            if results["has_old_config"]:
                print(f"   ⚠️  Still has old configuration")
            else:
                print(f"   ✅ Old configuration removed")
                
        print()
        
        updated_count = sum(1 for r in verification_results.values() 
                          if r.get("status") == "UPDATED")
        total_count = len([r for r in verification_results.values() if r.get("exists", False)])
        
        if updated_count == total_count:
            print("🎉 ALL SCRIPTS SUCCESSFULLY UPDATED")
            print("All submission scripts now use NFS configuration!")
        else:
            print(f"⚠️  UPDATE INCOMPLETE: {updated_count}/{total_count} scripts updated")
            print("Some scripts may need manual review.")
            
        print("="*60)
        
    def run_updates(self):
        """Run all updates"""
        self.log("🚀 Starting submission script updates...")
        
        if self.dry_run:
            self.log("Running in DRY-RUN mode - no files will be modified")
            
        # Update each script
        update_results = {}
        
        try:
            update_results["submit_globtim_compilation_test.py"] = self.update_globtim_compilation_test()
            update_results["submit_basic_test.py"] = self.update_basic_test()
            
        except Exception as e:
            self.log(f"Error during updates: {e}", "ERROR")
            return False
            
        # Verify updates
        verification_results = self.verify_updates()
        
        # Generate report
        self.generate_report(verification_results)
        
        # Return success status
        all_updated = all(r.get("status") == "UPDATED" 
                         for r in verification_results.values() 
                         if r.get("exists", False))
        
        return all_updated

def main():
    parser = argparse.ArgumentParser(description="Update remaining submission scripts for NFS integration")
    parser.add_argument("--dry-run", action="store_true", 
                       help="Show what would be changed without making changes")
    parser.add_argument("--no-backup", action="store_true",
                       help="Don't create backup files")
    
    args = parser.parse_args()
    
    print("🔧 Submission Script NFS Integration Updater")
    print(f"Mode: {'DRY-RUN' if args.dry_run else 'LIVE UPDATE'}")
    print(f"Backup: {'No' if args.no_backup else 'Yes'}")
    print()
    
    updater = ScriptUpdater(dry_run=args.dry_run, backup=not args.no_backup)
    
    try:
        success = updater.run_updates()
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n⚠️ Update interrupted by user")
        return 1
    except Exception as e:
        print(f"\n❌ Update failed with error: {e}")
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(main())
