#!/usr/bin/env python3

"""
Globtim HPC Directory Cleanup and Organization
==============================================

Cleans up and organizes the ~/globtim_hpc directory on the fileserver.
Creates proper directory structure and archives old files.

Usage:
    python cleanup_globtim_hpc.py [--dry-run] [--archive-old]
"""

import argparse
import subprocess
import os
from datetime import datetime

class GlobtimHPCCleaner:
    def __init__(self):
        self.fileserver_host = "scholten@mack"
        self.remote_dir = "~/globtim_hpc"
        
        # Target directory structure
        self.target_structure = {
            "results": "Job results organized by date and type",
            "slurm_scripts": "SLURM job scripts organized by type",
            "logs": "Job logs and monitoring outputs", 
            "temp": "Temporary files and working directories",
            "archive": "Archived old files and completed jobs",
            "archive/old_files": "Old scattered files from cleanup",
            "archive/completed_jobs": "Completed job results by date"
        }
    
    def create_directory_structure(self, dry_run=False):
        """Create organized directory structure"""
        print("🏗️  Creating organized directory structure...")
        
        for dir_path, description in self.target_structure.items():
            cmd = f"ssh {self.fileserver_host} 'cd {self.remote_dir} && mkdir -p {dir_path}'"
            
            if dry_run:
                print(f"  [DRY RUN] Would create: {dir_path} - {description}")
            else:
                print(f"  Creating: {dir_path} - {description}")
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                if result.returncode != 0:
                    print(f"    ❌ Failed to create {dir_path}: {result.stderr}")
                else:
                    print(f"    ✅ Created {dir_path}")
    
    def analyze_current_files(self):
        """Analyze current file distribution"""
        print("📊 Analyzing current file distribution...")
        
        analysis_cmd = f"""ssh {self.fileserver_host} 'cd {self.remote_dir} && 
echo "=== Current File Analysis ==="
echo "SLURM scripts (.slurm): $(find . -maxdepth 1 -name "*.slurm" | wc -l)"
echo "Output files (.out): $(find . -maxdepth 1 -name "*.out" | wc -l)" 
echo "Error files (.err): $(find . -maxdepth 1 -name "*.err" | wc -l)"
echo "Log files (.log): $(find . -maxdepth 1 -name "*.log" | wc -l)"
echo "Temporary files (.tmp): $(find . -maxdepth 1 -name "*.tmp" | wc -l)"
echo ""
echo "=== File Age Analysis ==="
echo "Files older than 7 days: $(find . -maxdepth 1 -name "*.slurm" -o -name "*.out" -o -name "*.err" -mtime +7 | wc -l)"
echo "Files from today: $(find . -maxdepth 1 -name "*.slurm" -o -name "*.out" -o -name "*.err" -mtime -1 | wc -l)"
echo ""
echo "=== Disk Usage ==="
du -sh .
echo ""
echo "=== Recent Files (last 5) ==="
ls -lt *.slurm *.out *.err 2>/dev/null | head -5
'"""
        
        result = subprocess.run(analysis_cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"❌ Analysis failed: {result.stderr}")
    
    def archive_old_files(self, dry_run=False):
        """Archive old scattered files"""
        print("📦 Archiving old scattered files...")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        archive_dir = f"archive/old_files/{timestamp}"
        
        archive_cmd = f"""ssh {self.fileserver_host} 'cd {self.remote_dir} && 
mkdir -p {archive_dir}

echo "Moving old files to archive..."
# Move SLURM scripts
find . -maxdepth 1 -name "*.slurm" -exec mv {{}} {archive_dir}/ \\;
echo "SLURM scripts moved: $(ls {archive_dir}/*.slurm 2>/dev/null | wc -l)"

# Move output files  
find . -maxdepth 1 -name "*.out" -exec mv {{}} {archive_dir}/ \\;
echo "Output files moved: $(ls {archive_dir}/*.out 2>/dev/null | wc -l)"

# Move error files
find . -maxdepth 1 -name "*.err" -exec mv {{}} {archive_dir}/ \\;
echo "Error files moved: $(ls {archive_dir}/*.err 2>/dev/null | wc -l)"

# Move any other scattered files
find . -maxdepth 1 -name "*.log" -exec mv {{}} {archive_dir}/ \\; 2>/dev/null || true
find . -maxdepth 1 -name "*.tmp" -exec mv {{}} {archive_dir}/ \\; 2>/dev/null || true

echo "Total files archived: $(ls {archive_dir}/ | wc -l)"
'"""
        
        if dry_run:
            print(f"  [DRY RUN] Would archive old files to: {archive_dir}")
            # Show what would be moved
            preview_cmd = f"""ssh {self.fileserver_host} 'cd {self.remote_dir} && 
echo "Files that would be archived:"
find . -maxdepth 1 -name "*.slurm" -o -name "*.out" -o -name "*.err" | head -10
echo "... and $(find . -maxdepth 1 -name "*.slurm" -o -name "*.out" -o -name "*.err" | wc -l) total files"
'"""
            result = subprocess.run(preview_cmd, shell=True, capture_output=True, text=True)
            print(result.stdout)
        else:
            print(f"  Archiving to: {archive_dir}")
            result = subprocess.run(archive_cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print(result.stdout)
                print("  ✅ Old files archived successfully")
            else:
                print(f"  ❌ Archiving failed: {result.stderr}")
    
    def create_maintenance_scripts(self, dry_run=False):
        """Create maintenance scripts for ongoing organization"""
        print("🔧 Creating maintenance scripts...")
        
        # Create a simple cleanup script on the fileserver
        cleanup_script = '''#!/bin/bash
# Globtim HPC Maintenance Script
# Run this periodically to keep directory organized

cd ~/globtim_hpc

echo "=== Globtim HPC Maintenance ==="
echo "Date: $(date)"
echo ""

# Archive completed jobs older than 7 days
echo "📦 Archiving old completed jobs..."
find results/ -name "*" -type d -mtime +7 -exec mv {} archive/completed_jobs/ \\; 2>/dev/null || true

# Clean up temporary files older than 1 day
echo "🧹 Cleaning temporary files..."
find temp/ -name "*" -mtime +1 -delete 2>/dev/null || true

# Organize recent SLURM scripts
echo "📋 Organizing SLURM scripts..."
find . -maxdepth 1 -name "*.slurm" -mtime -7 -exec mv {} slurm_scripts/ \\; 2>/dev/null || true

# Organize recent log files
echo "📝 Organizing log files..."
find . -maxdepth 1 -name "*.out" -o -name "*.err" -mtime -7 -exec mv {} logs/ \\; 2>/dev/null || true

echo ""
echo "=== Current Status ==="
echo "Results directories: $(find results/ -type d | wc -l)"
echo "SLURM scripts: $(find slurm_scripts/ -name "*.slurm" | wc -l)"
echo "Log files: $(find logs/ -name "*.out" -o -name "*.err" | wc -l)"
echo "Archived items: $(find archive/ -type f | wc -l)"
echo ""
echo "✅ Maintenance completed"
'''
        
        if dry_run:
            print("  [DRY RUN] Would create maintenance script")
        else:
            # Create the maintenance script on fileserver
            create_script_cmd = f"""ssh {self.fileserver_host} 'cd {self.remote_dir} && 
cat > maintain_globtim_hpc.sh << "EOF"
{cleanup_script}
EOF
chmod +x maintain_globtim_hpc.sh
echo "✅ Maintenance script created: maintain_globtim_hpc.sh"
'"""
            
            result = subprocess.run(create_script_cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print("  ✅ Maintenance script created")
                print("  📋 Run with: ssh scholten@mack '~/globtim_hpc/maintain_globtim_hpc.sh'")
            else:
                print(f"  ❌ Failed to create maintenance script: {result.stderr}")
    
    def create_readme(self, dry_run=False):
        """Create README for directory organization"""
        readme_content = '''# Globtim HPC Directory Organization

This directory is organized for efficient HPC workflow management.

## Directory Structure

- **src/**: Source code (Globtim modules)
- **Examples/**: Benchmark examples and test cases
- **results/**: Current job results organized by date/type
- **slurm_scripts/**: SLURM job scripts organized by type
- **logs/**: Job output and error logs
- **temp/**: Temporary files and working directories
- **archive/**: Archived completed jobs and old files

## Workflow

### Submitting Jobs
```bash
# Jobs create results in results/job_type_timestamp/
python submit_deuflhard_fileserver.py --mode quick
```

### Monitoring
```bash
# Check job status
squeue -u scholten

# View recent results
ls -la results/
```

### Maintenance
```bash
# Run periodic cleanup
./maintain_globtim_hpc.sh
```

## File Organization Rules

1. **New jobs**: Results go to `results/job_type_timestamp/`
2. **SLURM scripts**: Stored in `slurm_scripts/` by type
3. **Logs**: Job outputs in `logs/` with job ID
4. **Temporary**: Use `temp/` for intermediate files
5. **Archive**: Old completed jobs moved to `archive/`

## Disk Usage

- Current usage: Run `du -sh .` to check
- Quota limit: 1GB for home directory (but globtim_hpc has space)
- Archive policy: Jobs older than 30 days moved to archive

Last updated: ''' + datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        if dry_run:
            print("  [DRY RUN] Would create README.md")
        else:
            create_readme_cmd = f"""ssh {self.fileserver_host} 'cd {self.remote_dir} && 
cat > README.md << "EOF"
{readme_content}
EOF
echo "✅ README.md created"
'"""
            
            result = subprocess.run(create_readme_cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print("  ✅ README.md created")
            else:
                print(f"  ❌ Failed to create README: {result.stderr}")

def main():
    parser = argparse.ArgumentParser(description="Clean up and organize globtim_hpc directory")
    parser.add_argument("--dry-run", action="store_true", 
                       help="Show what would be done without making changes")
    parser.add_argument("--archive-old", action="store_true",
                       help="Archive old scattered files")
    parser.add_argument("--analyze-only", action="store_true",
                       help="Only analyze current state, don't make changes")
    
    args = parser.parse_args()
    
    cleaner = GlobtimHPCCleaner()
    
    print("🧹 Globtim HPC Directory Cleanup and Organization")
    print("=" * 50)
    
    # Always analyze first
    cleaner.analyze_current_files()
    
    if args.analyze_only:
        print("\n📊 Analysis complete. Use --archive-old to proceed with cleanup.")
        return
    
    # Create directory structure
    cleaner.create_directory_structure(dry_run=args.dry_run)
    
    # Archive old files if requested
    if args.archive_old:
        cleaner.archive_old_files(dry_run=args.dry_run)
    
    # Create maintenance tools
    cleaner.create_maintenance_scripts(dry_run=args.dry_run)
    cleaner.create_readme(dry_run=args.dry_run)
    
    if args.dry_run:
        print("\n🔍 DRY RUN COMPLETE - No changes made")
        print("Run without --dry-run to execute the cleanup")
    else:
        print("\n✅ CLEANUP COMPLETE")
        print("📋 Next steps:")
        print("  1. Test job submission with new structure")
        print("  2. Run periodic maintenance with: ~/globtim_hpc/maintain_globtim_hpc.sh")
        print("  3. Update submission scripts to use new paths")

if __name__ == "__main__":
    main()
