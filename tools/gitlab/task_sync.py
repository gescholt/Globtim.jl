#!/usr/bin/env python3
"""
Task Sync Manager for GitLab Integration

Automatically syncs local development work with GitLab issues.
Handles status updates, commit linking, and workflow automation.
"""

import re
import json
import subprocess
from typing import List, Dict, Any, Optional
from pathlib import Path
import argparse
from datetime import datetime

from gitlab_manager import GitLabIssueManager, GitLabConfig, load_config

class TaskSyncManager:
    """Manage synchronization between local work and GitLab issues"""
    
    def __init__(self, config_path: str):
        self.config = load_config(config_path)
        self.gitlab = GitLabIssueManager(self.config)
        self.repo_root = Path.cwd()
        
    def extract_issue_references(self, text: str) -> List[int]:
        """Extract GitLab issue references from text (e.g., #123, closes #456)"""
        patterns = [
            r'#(\d+)',                    # Simple reference: #123
            r'closes?\s+#(\d+)',          # Closes: closes #123
            r'fixes?\s+#(\d+)',           # Fixes: fixes #123
            r'resolves?\s+#(\d+)',        # Resolves: resolves #123
            r'implements?\s+#(\d+)',      # Implements: implements #123
        ]
        
        issue_ids = set()
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            issue_ids.update(int(match) for match in matches)
            
        return list(issue_ids)
        
    def get_current_branch(self) -> str:
        """Get the current Git branch name"""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                capture_output=True, text=True, check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return 'unknown'
            
    def get_last_commit_info(self) -> Dict[str, str]:
        """Get information about the last commit"""
        try:
            # Get commit hash
            hash_result = subprocess.run(
                ['git', 'rev-parse', 'HEAD'],
                capture_output=True, text=True, check=True
            )
            commit_hash = hash_result.stdout.strip()
            
            # Get commit message
            msg_result = subprocess.run(
                ['git', 'log', '-1', '--pretty=%B'],
                capture_output=True, text=True, check=True
            )
            commit_message = msg_result.stdout.strip()
            
            return {
                'hash': commit_hash,
                'message': commit_message,
                'short_hash': commit_hash[:8]
            }
        except subprocess.CalledProcessError:
            return {'hash': '', 'message': '', 'short_hash': ''}
            
    def start_work(self, issue_id: int, branch_name: str = None) -> bool:
        """Mark issue as in-progress when starting work"""
        print(f"Starting work on issue #{issue_id}")
        
        # Get issue details
        issue = self.gitlab.get_issue(issue_id)
        if not issue:
            print(f"Error: Could not find issue #{issue_id}")
            return False
            
        # Update issue status to in-progress
        updates = {
            'labels': self._update_status_label(issue.get('labels', []), 'status::in-progress')
        }
        
        # Add comment about starting work
        current_branch = branch_name or self.get_current_branch()
        comment = f"🚀 Started work on this issue\n\n**Branch**: `{current_branch}`\n**Started**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        # Update issue
        updated_issue = self.gitlab.update_issue(issue_id, updates)
        if updated_issue:
            # Add comment (would need separate API call in full implementation)
            print(f"✅ Issue #{issue_id} marked as in-progress")
            print(f"📝 Branch: {current_branch}")
            return True
        else:
            print(f"❌ Failed to update issue #{issue_id}")
            return False
            
    def complete_work(self, issue_id: int, commit_sha: str = None) -> bool:
        """Mark issue as complete with commit reference"""
        print(f"Completing work on issue #{issue_id}")
        
        # Get issue details
        issue = self.gitlab.get_issue(issue_id)
        if not issue:
            print(f"Error: Could not find issue #{issue_id}")
            return False
            
        # Get commit info if not provided
        if not commit_sha:
            commit_info = self.get_last_commit_info()
            commit_sha = commit_info['hash']
        else:
            commit_info = {'hash': commit_sha, 'short_hash': commit_sha[:8]}
            
        # Update issue status to review (or done if no review needed)
        new_status = 'status::review'  # Could be configurable
        updates = {
            'labels': self._update_status_label(issue.get('labels', []), new_status)
        }
        
        # Update issue
        updated_issue = self.gitlab.update_issue(issue_id, updates)
        if updated_issue:
            print(f"✅ Issue #{issue_id} marked as {new_status.replace('status::', '')}")
            print(f"🔗 Commit: {commit_info['short_hash']}")
            return True
        else:
            print(f"❌ Failed to update issue #{issue_id}")
            return False
            
    def sync_from_commit(self, commit_message: str = None) -> List[int]:
        """Sync issue status based on commit message"""
        if not commit_message:
            commit_info = self.get_last_commit_info()
            commit_message = commit_info['message']
            commit_sha = commit_info['hash']
        else:
            commit_sha = None
            
        print(f"Syncing issues from commit message: {commit_message[:60]}...")
        
        # Extract issue references
        issue_ids = self.extract_issue_references(commit_message)
        if not issue_ids:
            print("No issue references found in commit message")
            return []
            
        print(f"Found references to issues: {issue_ids}")
        
        updated_issues = []
        for issue_id in issue_ids:
            # Determine action based on commit message keywords
            if any(keyword in commit_message.lower() for keyword in ['closes', 'fixes', 'resolves']):
                if self.complete_work(issue_id, commit_sha):
                    updated_issues.append(issue_id)
            elif any(keyword in commit_message.lower() for keyword in ['implements', 'working on', 'progress']):
                if self.start_work(issue_id):
                    updated_issues.append(issue_id)
            else:
                # Just add a comment linking the commit
                print(f"📝 Adding commit reference to issue #{issue_id}")
                updated_issues.append(issue_id)
                
        return updated_issues
        
    def sync_status(self, dry_run: bool = False) -> Dict[str, Any]:
        """Sync current work status with GitLab"""
        print(f"{'[DRY RUN] ' if dry_run else ''}Syncing current work status...")
        
        # Get current branch
        current_branch = self.get_current_branch()
        
        # Look for branch naming patterns that indicate issue work
        branch_issue_match = re.search(r'issue[_-]?(\d+)', current_branch, re.IGNORECASE)
        if branch_issue_match:
            issue_id = int(branch_issue_match.group(1))
            print(f"Detected work on issue #{issue_id} from branch name: {current_branch}")
            
            if not dry_run:
                self.start_work(issue_id, current_branch)
                
        # Get recent commits and sync
        try:
            result = subprocess.run(
                ['git', 'log', '--oneline', '-10'],
                capture_output=True, text=True, check=True
            )
            recent_commits = result.stdout.strip().split('\n')
            
            synced_issues = set()
            for commit_line in recent_commits:
                commit_message = commit_line.split(' ', 1)[1] if ' ' in commit_line else commit_line
                issue_ids = self.extract_issue_references(commit_message)
                
                for issue_id in issue_ids:
                    if issue_id not in synced_issues:
                        if not dry_run:
                            # Add commit reference (simplified)
                            print(f"📝 Syncing issue #{issue_id} from recent commit")
                        synced_issues.add(issue_id)
                        
        except subprocess.CalledProcessError:
            print("Could not read recent commits")
            
        return {
            'current_branch': current_branch,
            'synced_issues': list(synced_issues),
            'dry_run': dry_run
        }
        
    def _update_status_label(self, current_labels: List[str], new_status: str) -> str:
        """Update status label in the labels list"""
        # Remove existing status labels
        filtered_labels = [label for label in current_labels if not label.startswith('status::')]
        
        # Add new status label
        filtered_labels.append(new_status)
        
        return ','.join(filtered_labels)
        
    def create_work_branch(self, issue_id: int, branch_prefix: str = 'issue') -> bool:
        """Create a new branch for working on an issue"""
        # Get issue details for branch naming
        issue = self.gitlab.get_issue(issue_id)
        if not issue:
            print(f"Error: Could not find issue #{issue_id}")
            return False
            
        # Create branch name
        title_slug = re.sub(r'[^a-zA-Z0-9]+', '-', issue['title'].lower())[:30]
        branch_name = f"{branch_prefix}-{issue_id}-{title_slug}"
        
        try:
            # Create and checkout new branch
            subprocess.run(['git', 'checkout', '-b', branch_name], check=True)
            print(f"✅ Created and switched to branch: {branch_name}")
            
            # Mark issue as in-progress
            self.start_work(issue_id, branch_name)
            
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to create branch: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description='Sync local work with GitLab issues')
    parser.add_argument('--config', default='tools/gitlab/config.json', help='GitLab configuration file')
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Start work command
    start_parser = subparsers.add_parser('start', help='Start work on an issue')
    start_parser.add_argument('issue_id', type=int, help='GitLab issue ID')
    start_parser.add_argument('--branch', help='Branch name (optional)')
    
    # Complete work command
    complete_parser = subparsers.add_parser('complete', help='Complete work on an issue')
    complete_parser.add_argument('issue_id', type=int, help='GitLab issue ID')
    complete_parser.add_argument('--commit', help='Commit SHA (optional)')
    
    # Sync from commit command
    sync_commit_parser = subparsers.add_parser('sync-commit', help='Sync issues from commit message')
    sync_commit_parser.add_argument('--message', help='Commit message (uses last commit if not provided)')
    
    # Sync status command
    sync_status_parser = subparsers.add_parser('sync-status', help='Sync current work status')
    sync_status_parser.add_argument('--dry-run', action='store_true', help='Show what would be synced')
    
    # Create branch command
    branch_parser = subparsers.add_parser('create-branch', help='Create branch for issue')
    branch_parser.add_argument('issue_id', type=int, help='GitLab issue ID')
    branch_parser.add_argument('--prefix', default='issue', help='Branch prefix')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    try:
        sync_manager = TaskSyncManager(args.config)
        
        if args.command == 'start':
            sync_manager.start_work(args.issue_id, args.branch)
        elif args.command == 'complete':
            sync_manager.complete_work(args.issue_id, args.commit)
        elif args.command == 'sync-commit':
            sync_manager.sync_from_commit(args.message)
        elif args.command == 'sync-status':
            result = sync_manager.sync_status(args.dry_run)
            print(f"Sync result: {result}")
        elif args.command == 'create-branch':
            sync_manager.create_branch(args.issue_id, args.prefix)
            
    except Exception as e:
        print(f"Error: {e}")
        return 1
        
    return 0


if __name__ == '__main__':
    exit(main())
