#!/usr/bin/env python3
"""
Secure GitLab Configuration Manager

Handles secure retrieval of GitLab API tokens and configuration.
"""

import os
import json
import subprocess
from pathlib import Path
from typing import Optional

def get_gitlab_token() -> Optional[str]:
    """Securely retrieve GitLab API token from various sources"""
    
    # Try environment variable first
    token = os.environ.get('GITLAB_PRIVATE_TOKEN')
    if token:
        return token
    
    # Try Git credential helper
    try:
        script_dir = Path(__file__).parent
        token_script = script_dir / 'get-token.sh'
        if token_script.exists():
            result = subprocess.run([str(token_script)], 
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass
    
    return None

def load_secure_config(config_file: str = None) -> dict:
    """Load GitLab configuration with secure token handling"""
    
    if config_file is None:
        script_dir = Path(__file__).parent
        config_file = script_dir / 'config.json'
    
    # Load base configuration
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Get token securely
    token = get_gitlab_token()
    if not token:
        raise ValueError("GitLab API token not found. Please set GITLAB_PRIVATE_TOKEN environment variable or configure Git credential helper.")
    
    config['access_token'] = token
    return config

if __name__ == '__main__':
    try:
        config = load_secure_config()
        print(f"Configuration loaded successfully for project {config['project_id']}")
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
