#!/usr/bin/env python3
"""
GitLab API Manager for Issue Management

Handles creation, updating, and management of GitLab issues through the API.
Supports bulk operations and rate limiting for large migrations.
"""

import requests
import json
import time
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import argparse
from pathlib import Path

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
    """Securely retrieve GitLab API token from various sources"""
    import os
    import subprocess
    from pathlib import Path

    # Try environment variable first
    token = os.environ.get('GITLAB_PRIVATE_TOKEN')
    if token:
        return token

    # Try Git credential helper via get-token.sh script
    try:
        script_dir = Path(__file__).parent
        token_script = script_dir / 'get-token.sh'
        if token_script.exists():
            result = subprocess.run([str(token_script)],
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass

    raise ValueError("GitLab API token not found. Please set GITLAB_PRIVATE_TOKEN environment variable or run tools/gitlab/setup-secure-config.sh")

def load_config(config_file: str) -> GitLabConfig:
    """Load GitLab configuration from file with secure token handling"""
    try:
        with open(config_file, 'r') as f:
            config_data = json.load(f)

        # Get token securely (not from config file)
        access_token = get_gitlab_token()

        return GitLabConfig(
            project_id=config_data['project_id'],
            access_token=access_token,
            base_url=config_data.get('base_url', 'https://gitlab.com/api/v4'),
            rate_limit_delay=config_data.get('rate_limit_delay', 1.0)
        )

    except Exception as e:
        print(f"Error loading config from {config_file}: {e}")
        raise


def main():
    parser = argparse.ArgumentParser(description='Migrate tasks to GitLab issues')
    parser.add_argument('--config', required=True, help='GitLab configuration file')
    parser.add_argument('--tasks', required=True, help='JSON file with extracted tasks')
    parser.add_argument('--dry-run', action='store_true', help='Simulate migration without creating issues')
    parser.add_argument('--report', help='Output file for migration report')
    
    args = parser.parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    # Create GitLab manager
    manager = GitLabIssueManager(config)
    
    # Migrate tasks
    created_issues = manager.migrate_tasks_from_json(args.tasks, dry_run=args.dry_run)
    
    # Generate report
    report = manager.generate_migration_report(created_issues, args.report)
    print("\n" + report)


if __name__ == '__main__':
    main()
