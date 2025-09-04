#!/usr/bin/env python3
"""
DEPRECATED: This module is replaced by tools.gitlab.secure_gitlab_wrapper

This file is kept for backward compatibility but redirects to the secure wrapper
that ensures proper security validation through the hook system.

MIGRATION GUIDE:
  OLD: from gitlab_api import GitLabAPI
  NEW: from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI
"""

import os
import json
import subprocess
from typing import Dict, Optional, List, Any
from pathlib import Path

# Redirect to secure wrapper
try:
    from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI, GitLabSecurityError
    
    class GitLabAPI(SecureGitLabAPI):
        """DEPRECATED: Use tools.gitlab.secure_gitlab_wrapper.SecureGitLabAPI instead"""
        
        def __init__(self, config_file: Optional[str] = None):
            print("⚠️  DEPRECATION WARNING: GitLabAPI class is deprecated.")
            print("    Use tools.gitlab.secure_gitlab_wrapper.SecureGitLabAPI instead.")
            print("    This ensures proper security validation through the hook system.")
            super().__init__()
            
except ImportError:
    print("❌ ERROR: Cannot import secure GitLab wrapper")
    print("   Please ensure tools/gitlab/secure_gitlab_wrapper.py exists")
    
    class GitLabAPI:
        """Placeholder to prevent import errors"""
        
        def __init__(self, config_file: Optional[str] = None):
            raise ImportError(
                "GitLabAPI is deprecated. Use tools.gitlab.secure_gitlab_wrapper.SecureGitLabAPI instead. "
                "The secure wrapper ensures proper security validation through the hook system."
            )


if __name__ == "__main__":
    # Example usage with deprecation notice
    print("GitLab API Wrapper - DEPRECATED")
    print("=" * 35)
    print()
    print("⚠️  This script is deprecated. Please use:")
    print("   tools/gitlab/secure_gitlab_wrapper.py")
    print()
    print("The secure wrapper ensures:")
    print("  ✅ Security hook validation")
    print("  ✅ No direct token handling") 
    print("  ✅ Proper audit logging")
    print()
    
    try:
        # Test the secure wrapper
        from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI
        api = SecureGitLabAPI()
        print("✅ Secure GitLab API is ready for use")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nPlease ensure the security hook system is properly configured.")