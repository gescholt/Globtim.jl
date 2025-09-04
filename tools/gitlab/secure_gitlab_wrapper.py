#!/usr/bin/env python3
"""
Secure GitLab API Wrapper for Python Scripts
============================================

This wrapper ensures all Python GitLab operations go through the security hook system
and never handle tokens directly. All Python scripts should use this instead of 
handling GitLab tokens themselves.

Usage:
    from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI
    
    api = SecureGitLabAPI()
    response = api.get_issue(26)
"""

import subprocess
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Any


class GitLabSecurityError(Exception):
    """Raised when GitLab security validation fails"""
    pass


class SecureGitLabAPI:
    """
    Secure GitLab API wrapper that uses the security hook system.
    
    This class ensures that:
    1. All operations go through the security hook validation
    2. No tokens are handled directly by Python code
    3. All API calls use the validated gitlab-api.sh script
    """
    
    def __init__(self):
        """Initialize and validate GitLab security configuration"""
        self.project_root = self._find_project_root()
        self.gitlab_api_script = self.project_root / "tools/gitlab/gitlab-api.sh"
        self.security_hook = self.project_root / "tools/gitlab/gitlab-security-hook.sh"
        
        # Validate that required scripts exist
        if not self.gitlab_api_script.exists():
            raise GitLabSecurityError(f"GitLab API script not found: {self.gitlab_api_script}")
        
        if not self.security_hook.exists():
            raise GitLabSecurityError(f"Security hook not found: {self.security_hook}")
        
        # Run security validation
        self._validate_security()
    
    def _find_project_root(self) -> Path:
        """Find the GlobTim project root directory"""
        current = Path.cwd()
        while current != current.parent:
            if (current / "tools/gitlab").exists():
                return current
            current = current.parent
        
        # Fallback to known location if we can't find it
        fallback = Path("/Users/ghscholt/globtim")
        if fallback.exists():
            return fallback
            
        raise GitLabSecurityError("Could not locate GlobTim project root directory")
    
    def _validate_security(self):
        """Run GitLab security validation through hook system"""
        try:
            # Set environment to trigger security hook
            env = os.environ.copy()
            env["CLAUDE_CONTEXT"] = "Python GitLab API operation"
            
            # Run security validation with shorter timeout
            result = subprocess.run(
                [str(self.security_hook)],
                cwd=self.project_root,
                env=env,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                # If security hook fails, provide helpful error message
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                raise GitLabSecurityError(
                    f"GitLab security validation failed: {error_msg}"
                )
                
        except subprocess.TimeoutExpired:
            # Shorter timeout with fallback suggestion
            raise GitLabSecurityError(
                "GitLab security validation timed out. This may indicate token retrieval issues. "
                "Ensure GitLab token is properly configured via tools/gitlab/setup-secure-config.sh"
            )
        except FileNotFoundError:
            raise GitLabSecurityError(
                f"Security hook script not found: {self.security_hook}"
            )
        except Exception as e:
            raise GitLabSecurityError(f"Security validation error: {e}")
    
    def _call_api(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """
        Make secure GitLab API call through the validated script
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint (e.g., "/projects/2545/issues/26")
            data: Optional JSON data for POST/PUT requests
            
        Returns:
            API response as dictionary
        """
        try:
            cmd = [str(self.gitlab_api_script), method, endpoint]
            
            # Handle data for POST/PUT requests
            input_data = None
            if data:
                input_data = json.dumps(data)
                cmd.extend(["-d", "@-"])  # Read from stdin
            
            # Set environment to prevent interactive prompts
            env = os.environ.copy()
            env["GIT_TERMINAL_PROMPT"] = "0"  # Disable git interactive prompts
            env["GIT_ASKPASS"] = "echo"       # Provide dummy askpass
            
            # Execute API call
            result = subprocess.run(
                cmd,
                cwd=self.project_root,
                input=input_data,
                capture_output=True,
                text=True,
                timeout=30,  # Shorter timeout to avoid hangs
                env=env
            )
            
            if result.returncode != 0:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                raise GitLabSecurityError(
                    f"GitLab API call failed: {error_msg}"
                )
            
            # Parse response
            if result.stdout.strip():
                return json.loads(result.stdout)
            else:
                return {}
                
        except json.JSONDecodeError as e:
            raise GitLabSecurityError(f"Invalid JSON response: {e}")
        except subprocess.TimeoutExpired:
            raise GitLabSecurityError(
                "GitLab API call timed out. This may indicate interactive authentication prompts. "
                "Ensure GitLab token is available in environment variables."
            )
        except Exception as e:
            raise GitLabSecurityError(f"API call error: {e}")
    
    # High-level API methods
    
    def get_issue(self, issue_iid: int) -> Dict:
        """Get issue by IID"""
        return self._call_api("GET", f"/projects/2545/issues/{issue_iid}")
    
    def update_issue(self, issue_iid: int, updates: Dict) -> Dict:
        """Update issue with provided data"""
        return self._call_api("PUT", f"/projects/2545/issues/{issue_iid}", updates)
    
    def add_issue_comment(self, issue_iid: int, comment: str) -> Dict:
        """Add comment to issue"""
        data = {"body": comment}
        return self._call_api("POST", f"/projects/2545/issues/{issue_iid}/notes", data)
    
    def list_issues(self, state: str = "opened", labels: Optional[List[str]] = None) -> List[Dict]:
        """List project issues"""
        endpoint = f"/projects/2545/issues?state={state}"
        if labels:
            endpoint += f"&labels={','.join(labels)}"
        
        response = self._call_api("GET", endpoint)
        return response if isinstance(response, list) else []
    
    def create_issue(self, title: str, description: str = "", labels: Optional[List[str]] = None) -> Dict:
        """Create new issue"""
        data = {
            "title": title,
            "description": description
        }
        if labels:
            data["labels"] = ",".join(labels)
        
        return self._call_api("POST", "/projects/2545/issues", data)
    
    def update_labels(self, issue_iid: int, labels: List[str]) -> Dict:
        """Update issue labels"""
        data = {"labels": ",".join(labels)}
        return self._call_api("PUT", f"/projects/2545/issues/{issue_iid}", data)


def main():
    """Test the secure GitLab API wrapper"""
    print("Testing Secure GitLab API Wrapper")
    print("=" * 35)
    
    try:
        # Initialize API
        api = SecureGitLabAPI()
        print("✅ Security validation passed")
        
        # Test API call
        issues = api.list_issues()
        print(f"✅ Successfully retrieved {len(issues)} issues")
        
        print("\n✅ Secure GitLab API is ready for use")
        
    except GitLabSecurityError as e:
        print(f"❌ Security error: {e}")
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())