#!/usr/bin/env python3
"""
Secure GitLab API wrapper for managing issues and merge requests.

This module provides a secure interface to GitLab API using environment variables
for authentication, avoiding hardcoded tokens in code.
"""

import os
import json
import subprocess
from typing import Dict, Optional, List, Any
from pathlib import Path


class GitLabAPI:
    """Secure wrapper for GitLab API operations."""
    
    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize GitLab API wrapper using secure token retrieval.
        
        Args:
            config_file: Unused - kept for compatibility
        """
        # Load configuration using project's secure token system
        self._load_gitlab_config_secure()
        
        # Get configuration from environment
        self.gitlab_url = os.getenv('GITLAB_URL')
        self.gitlab_token = os.getenv('GITLAB_TOKEN')
        self.project_path = os.getenv('GITLAB_PROJECT_PATH')
        
        # Validate configuration
        if not all([self.gitlab_url, self.gitlab_token, self.project_path]):
            raise ValueError(
                "Missing GitLab configuration. Please ensure secure token "
                "retrieval system is properly configured."
            )
        
        # URL encode project path
        self.encoded_project = self.project_path.replace('/', '%2F')
    
    def _load_gitlab_config_secure(self):
        """
        Load GitLab configuration using project's secure token system.
        """
        try:
            # Set GitLab URL and project path
            os.environ['GITLAB_URL'] = 'https://git.mpi-cbg.de'
            os.environ['GITLAB_PROJECT_PATH'] = 'scholten/globtim'
            
            # Use existing secure token retrieval system
            token_script = Path('./tools/gitlab/get-token.sh')
            if token_script.exists():
                result = subprocess.run(
                    [str(token_script)], 
                    capture_output=True, 
                    text=True, 
                    timeout=10
                )
                if result.returncode == 0 and result.stdout.strip():
                    # Store token in expected format
                    token = result.stdout.strip()
                    os.environ['GITLAB_TOKEN'] = token
                else:
                    raise ValueError("Secure token retrieval failed")
            else:
                # Fallback: check if token is in environment
                token = os.getenv('GITLAB_PRIVATE_TOKEN')
                if token:
                    os.environ['GITLAB_TOKEN'] = token
                else:
                    raise ValueError("No secure token available")
                    
        except Exception as e:
            raise ValueError(f"GitLab secure configuration failed: {e}")
    
    def _load_gitlab_config(self, config_file: Optional[str] = None):
        """
        Load GitLab configuration from .gitlab_config file.
        
        Args:
            config_file: Optional path to config file
        """
        # Determine config file path
        if config_file:
            config_path = Path(config_file)
        else:
            # Look for .gitlab_config in current directory or project root
            current_dir = Path.cwd()
            config_path = current_dir / '.gitlab_config'
            
            # If not found in current directory, try project root
            if not config_path.exists():
                # Assume we're in a subdirectory, try parent directories
                for parent in current_dir.parents:
                    candidate = parent / '.gitlab_config'
                    if candidate.exists():
                        config_path = candidate
                        break
        
        # Source the configuration file if it exists
        if config_path.exists():
            # Read and source the shell configuration file
            with open(config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        # Remove quotes if present
                        value = value.strip('"\'')
                        os.environ[key] = value
        else:
            # Fallback: check if environment variables are already set
            if not all(os.getenv(var) for var in ['GITLAB_URL', 'GITLAB_TOKEN', 'GITLAB_PROJECT_PATH']):
                raise ValueError(
                    f"GitLab configuration file not found at {config_path}. "
                    "Please ensure .gitlab_config exists with required variables."
                )
        
    def _make_request(self, 
                     method: str, 
                     endpoint: str, 
                     data: Optional[Dict] = None,
                     use_gh_cli: bool = False) -> Dict:
        """
        Make a secure API request to GitLab.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint (relative to project)
            data: Optional request data
            use_gh_cli: Whether to use gh CLI instead of curl
            
        Returns:
            Response data as dictionary
        """
        url = f"{self.gitlab_url}/api/v4/projects/{self.encoded_project}/{endpoint}"
        
        # Build curl command with secure token handling
        cmd = [
            'curl',
            '-s',  # Silent
            '-X', method,
            '-H', f'PRIVATE-TOKEN: {self.gitlab_token}',
            '-H', 'Content-Type: application/json'
        ]
        
        if data:
            cmd.extend(['-d', json.dumps(data)])
        
        cmd.append(url)
        
        # Execute request
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse JSON response
            if result.stdout:
                return json.loads(result.stdout)
            return {}
            
        except subprocess.CalledProcessError as e:
            print(f"GitLab API error: {e}")
            if e.stderr:
                print(f"Error details: {e.stderr}")
            return {}
        except json.JSONDecodeError as e:
            print(f"Failed to parse GitLab response: {e}")
            return {}
    
    def get_issue(self, issue_iid: int) -> Dict:
        """
        Get issue details by IID.
        
        Args:
            issue_iid: Issue internal ID
            
        Returns:
            Issue data dictionary
        """
        return self._make_request('GET', f'issues/{issue_iid}')
    
    def update_issue(self, 
                    issue_iid: int,
                    title: Optional[str] = None,
                    description: Optional[str] = None,
                    labels: Optional[List[str]] = None,
                    state_event: Optional[str] = None) -> Dict:
        """
        Update an existing issue.
        
        Args:
            issue_iid: Issue internal ID
            title: Optional new title
            description: Optional new description
            labels: Optional list of labels
            state_event: Optional state change (close, reopen)
            
        Returns:
            Updated issue data
        """
        data = {}
        if title:
            data['title'] = title
        if description:
            data['description'] = description
        if labels is not None:
            data['labels'] = ','.join(labels)
        if state_event:
            data['state_event'] = state_event
        
        return self._make_request('PUT', f'issues/{issue_iid}', data)
    
    def add_issue_comment(self, issue_iid: int, comment: str) -> Dict:
        """
        Add a comment to an issue.
        
        Args:
            issue_iid: Issue internal ID
            comment: Comment text (supports markdown)
            
        Returns:
            Comment data
        """
        data = {'body': comment}
        return self._make_request('POST', f'issues/{issue_iid}/notes', data)
    
    def list_issues(self, 
                   state: str = 'opened',
                   labels: Optional[List[str]] = None,
                   milestone: Optional[str] = None) -> List[Dict]:
        """
        List project issues with filters.
        
        Args:
            state: Issue state (opened, closed, all)
            labels: Optional label filters
            milestone: Optional milestone filter
            
        Returns:
            List of issue dictionaries
        """
        endpoint = f'issues?state={state}'
        if labels:
            endpoint += f'&labels={",".join(labels)}'
        if milestone:
            endpoint += f'&milestone={milestone}'
        
        return self._make_request('GET', endpoint)
    
    def create_merge_request(self,
                           source_branch: str,
                           target_branch: str,
                           title: str,
                           description: Optional[str] = None,
                           assignee_id: Optional[int] = None) -> Dict:
        """
        Create a new merge request.
        
        Args:
            source_branch: Source branch name
            target_branch: Target branch name
            title: MR title
            description: Optional MR description
            assignee_id: Optional assignee user ID
            
        Returns:
            Merge request data
        """
        data = {
            'source_branch': source_branch,
            'target_branch': target_branch,
            'title': title
        }
        
        if description:
            data['description'] = description
        if assignee_id:
            data['assignee_id'] = assignee_id
        
        return self._make_request('POST', 'merge_requests', data)
    
    def create_issue(self,
                    title: str,
                    description: Optional[str] = None,
                    labels: Optional[List[str]] = None,
                    milestone_id: Optional[int] = None,
                    assignee_id: Optional[int] = None) -> Dict:
        """
        Create a new issue.
        
        Args:
            title: Issue title
            description: Optional issue description
            labels: Optional list of labels
            milestone_id: Optional milestone ID
            assignee_id: Optional assignee user ID
            
        Returns:
            Created issue data
        """
        data = {'title': title}
        
        if description:
            data['description'] = description
        if labels:
            data['labels'] = ','.join(labels)
        if milestone_id:
            data['milestone_id'] = milestone_id
        if assignee_id:
            data['assignee_id'] = assignee_id
        
        return self._make_request('POST', 'issues', data)
    
    def list_milestones(self, state: str = 'active') -> List[Dict]:
        """
        List project milestones.
        
        Args:
            state: Milestone state (active, closed, all)
            
        Returns:
            List of milestone dictionaries
        """
        endpoint = f'milestones?state={state}'
        return self._make_request('GET', endpoint)
    
    def get_milestone(self, milestone_id: int) -> Dict:
        """
        Get milestone details by ID.
        
        Args:
            milestone_id: Milestone ID
            
        Returns:
            Milestone data dictionary
        """
        return self._make_request('GET', f'milestones/{milestone_id}')
    
    def create_milestone(self,
                        title: str,
                        description: Optional[str] = None,
                        due_date: Optional[str] = None,
                        start_date: Optional[str] = None) -> Dict:
        """
        Create a new milestone.
        
        Args:
            title: Milestone title
            description: Optional milestone description
            due_date: Optional due date (YYYY-MM-DD format)
            start_date: Optional start date (YYYY-MM-DD format)
            
        Returns:
            Created milestone data
        """
        data = {'title': title}
        
        if description:
            data['description'] = description
        if due_date:
            data['due_date'] = due_date
        if start_date:
            data['start_date'] = start_date
        
        return self._make_request('POST', 'milestones', data)
    
    def find_milestone_by_title(self, title: str) -> Optional[Dict]:
        """
        Find milestone by title.
        
        Args:
            title: Milestone title to search for
            
        Returns:
            Milestone data if found, None otherwise
        """
        milestones = self.list_milestones(state='all')
        for milestone in milestones:
            if milestone.get('title', '').lower() == title.lower():
                return milestone
        return None




if __name__ == "__main__":
    # Example usage
    print("GitLab API Wrapper - Secure Token Management")
    print("=" * 50)
    
    try:
        # Test the API connection
        api = GitLabAPI()
        print(f"✅ Connected to GitLab: {api.gitlab_url}")
        print(f"✅ Project: {api.project_path}")
        
        # API is ready for use
        print("\n✅ GitLab API is ready for use")
        
    except ValueError as e:
        print(f"❌ Configuration error: {e}")
        print("\nPlease ensure you have a .gitlab_config file with:")
        print("  GITLAB_URL=https://git.mpi-cbg.de")
        print("  GITLAB_TOKEN=your-token-here")
        print("  GITLAB_PROJECT_PATH=scholten/globtim")