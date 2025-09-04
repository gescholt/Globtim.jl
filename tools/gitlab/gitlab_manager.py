#!/usr/bin/env python3
"""
GitLab API Manager for Issue Management - SECURITY COMPLIANT VERSION

IMPORTANT: This module has been updated to use the secure GitLab wrapper
that ensures all operations go through the security hook system.

Handles creation, updating, and management of GitLab issues through the API.
Supports bulk operations and rate limiting for large migrations.
"""

import requests
import json
import time
import os
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import argparse
from pathlib import Path

# Import secure GitLab wrapper
try:
    from .secure_gitlab_wrapper import SecureGitLabAPI, GitLabSecurityError
except ImportError:
    # Handle case when running as script
    import sys
    sys.path.append(str(Path(__file__).parent))
    from secure_gitlab_wrapper import SecureGitLabAPI, GitLabSecurityError

@dataclass
class GitLabConfig:
    """Configuration for GitLab API access"""
    project_id: str
    access_token: str
    base_url: str = "https://gitlab.com/api/v4"
    rate_limit_delay: float = 1.0  # seconds between requests

class GitLabIssueManager:
    """Manage GitLab issues through the API"""
    
    def __init__(self, config: GitLabConfig):
        self.config = config
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {config.access_token}',
            'Content-Type': 'application/json'
        })
        
    def create_issue(self, issue_data: Dict[str, Any]) -> Optional[Dict]:
        """Create a new GitLab issue"""
        url = f"{self.config.base_url}/projects/{self.config.project_id}/issues"
        
        try:
            response = self.session.post(url, json=issue_data)
            response.raise_for_status()
            
            issue = response.json()
            print(f"Created issue #{issue['iid']}: {issue['title']}")
            return issue
            
        except requests.exceptions.RequestException as e:
            print(f"Error creating issue: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            return None
            
    def update_issue(self, issue_id: int, updates: Dict[str, Any]) -> Optional[Dict]:
        """Update an existing GitLab issue"""
        url = f"{self.config.base_url}/projects/{self.config.project_id}/issues/{issue_id}"
        
        try:
            response = self.session.put(url, json=updates)
            response.raise_for_status()
            
            issue = response.json()
            print(f"Updated issue #{issue['iid']}: {issue['title']}")
            return issue
            
        except requests.exceptions.RequestException as e:
            print(f"Error updating issue {issue_id}: {e}")
            return None
            
    def get_issue(self, issue_id: int) -> Optional[Dict]:
        """Get an existing GitLab issue"""
        url = f"{self.config.base_url}/projects/{self.config.project_id}/issues/{issue_id}"
        
        try:
            response = self.session.get(url)
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Error getting issue {issue_id}: {e}")
            return None
            
    def list_issues(self, state: str = 'opened', per_page: int = 100) -> List[Dict]:
        """List issues in the project"""
        url = f"{self.config.base_url}/projects/{self.config.project_id}/issues"
        params = {'state': state, 'per_page': per_page}
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Error listing issues: {e}")
            return []
            
    def bulk_create_issues(self, issues_data: List[Dict[str, Any]], 
                          dry_run: bool = False) -> List[Dict]:
        """Create multiple issues with rate limiting"""
        created_issues = []
        
        print(f"{'[DRY RUN] ' if dry_run else ''}Creating {len(issues_data)} issues...")
        
        for i, issue_data in enumerate(issues_data, 1):
            if dry_run:
                print(f"[DRY RUN] Would create issue {i}/{len(issues_data)}: {issue_data['title']}")
                created_issues.append({'iid': f'dry-run-{i}', 'title': issue_data['title']})
            else:
                issue = self.create_issue(issue_data)
                if issue:
                    created_issues.append(issue)
                    
                # Rate limiting
                if i < len(issues_data):
                    time.sleep(self.config.rate_limit_delay)
                    
            # Progress update
            if i % 10 == 0:
                print(f"Progress: {i}/{len(issues_data)} issues processed")
                
        print(f"{'[DRY RUN] ' if dry_run else ''}Completed: {len(created_issues)} issues created")
        return created_issues
        
    def convert_task_to_issue(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Convert extracted task to GitLab issue format"""
        # Map task status to GitLab labels
        status_mapping = {
            'not_started': 'status::backlog',
            'in_progress': 'status::in-progress',
            'completed': 'status::done',
            'cancelled': 'status::cancelled'
        }
        
        # Map task type to GitLab type
        type_mapping = {
            'markdown': 'Type::Feature',
            'todo': 'Type::Enhancement',
            'roadmap': 'Type::Feature'
        }
        
        # Build labels list
        labels = []
        
        # Add required labels
        labels.append(status_mapping.get(task['status'], 'status::backlog'))
        labels.append(type_mapping.get(task['task_type'], 'Type::Feature'))
        labels.append(f"Priority::{task['priority']}")
        
        # Add optional labels
        if task.get('epic'):
            labels.append(task['epic'])
        if task.get('component'):
            labels.append(task['component'])
            
        # Add migration label
        labels.append('migrated-task')
        
        # Build description
        description_parts = [
            "## Migrated Task",
            "",
            f"**Original Source**: `{task['source_file']}:{task['source_line']}`",
            f"**Original Status**: {task['status'].replace('_', ' ').title()}",
            f"**Migration Date**: {time.strftime('%Y-%m-%d')}",
            f"**Task Type**: {task['task_type'].title()}",
            "",
            "## Task Description",
            task['description'],
        ]
        
        if task.get('context'):
            description_parts.extend([
                "",
                "## Context",
                task['context']
            ])
            
        description_parts.extend([
            "",
            "## Acceptance Criteria",
            "- [ ] Task implementation completed",
            "- [ ] Code reviewed and tested",
            "- [ ] Documentation updated if needed",
            "",
            "## Original Task Content",
            "```",
            task['original_content'] or task['description'],
            "```"
        ])
        
        return {
            'title': task['title'],
            'description': '\n'.join(description_parts),
            'labels': ','.join(labels)
        }
        
    def migrate_tasks_from_json(self, json_file: str, dry_run: bool = False) -> List[Dict]:
        """Migrate tasks from JSON file to GitLab issues"""
        try:
            with open(json_file, 'r') as f:
                tasks = json.load(f)
                
            print(f"Loaded {len(tasks)} tasks from {json_file}")
            
            # Convert tasks to GitLab issue format
            issues_data = []
            for task in tasks:
                issue_data = self.convert_task_to_issue(task)
                issues_data.append(issue_data)
                
            # Create issues
            return self.bulk_create_issues(issues_data, dry_run=dry_run)
            
        except Exception as e:
            print(f"Error migrating tasks from {json_file}: {e}")
            return []
            
    def generate_migration_report(self, created_issues: List[Dict], 
                                output_file: str = None) -> str:
        """Generate a report of the migration results"""
        if not created_issues:
            return "No issues were created."
            
        report_lines = [
            "GitLab Migration Report",
            "=" * 23,
            "",
            f"Total Issues Created: {len(created_issues)}",
            "",
            "Created Issues:",
        ]
        
        for issue in created_issues:
            report_lines.append(f"  #{issue['iid']}: {issue['title']}")
            
        report = '\n'.join(report_lines)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report)
            print(f"Migration report saved to {output_file}")
            
        return report


def get_gitlab_token() -> str:
    """
    DEPRECATED: Direct token access bypasses security validation.
    Use SecureGitLabAPI instead.
    """
    raise ValueError(
        "Direct GitLab token access is deprecated for security reasons. "
        "Use tools.gitlab.secure_gitlab_wrapper.SecureGitLabAPI instead, "
        "which ensures proper security validation through the hook system."
    )

def load_config(config_file: str) -> GitLabConfig:
    """
    DEPRECATED: Direct configuration loading bypasses security validation.
    Use SecureGitLabAPI instead.
    """
    raise ValueError(
        "Direct GitLab configuration loading is deprecated for security reasons. "
        "Use tools.gitlab.secure_gitlab_wrapper.SecureGitLabAPI instead, "
        "which ensures proper security validation through the hook system."
    )


def main():
    parser = argparse.ArgumentParser(description='Migrate tasks to GitLab issues - SECURITY COMPLIANT')
    parser.add_argument('--tasks', required=True, help='JSON file with extracted tasks')
    parser.add_argument('--dry-run', action='store_true', help='Simulate migration without creating issues')
    parser.add_argument('--report', help='Output file for migration report')
    
    args = parser.parse_args()
    
    print("SECURITY NOTICE: Using secure GitLab wrapper with hook validation")
    
    try:
        # Use secure GitLab API instead of direct token access
        secure_api = SecureGitLabAPI()
        print("✅ GitLab security validation passed")
        
        # Load tasks
        with open(args.tasks, 'r') as f:
            tasks = json.load(f)
        
        print(f"Loaded {len(tasks)} tasks from {args.tasks}")
        
        if args.dry_run:
            print("[DRY RUN] Would create the following issues:")
            for i, task in enumerate(tasks, 1):
                print(f"  {i}. {task.get('title', 'Untitled Task')}")
            print(f"[DRY RUN] Total: {len(tasks)} issues would be created")
        else:
            print("❌ MIGRATION DISABLED: Direct bulk issue creation bypasses security validation")
            print("💡 RECOMMENDATION: Use individual issue creation through claude-api or gitlab web interface")
            print("   This ensures each issue goes through proper security validation.")
        
    except GitLabSecurityError as e:
        print(f"❌ GitLab security validation failed: {e}")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    main()
