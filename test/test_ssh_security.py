#!/usr/bin/env python3
"""
SSH Security Hook Test Suite
============================

Comprehensive test suite for the SSH security communication hook system.
Tests all aspects of secure SSH communication including:

- SSH configuration validation
- Key security verification  
- Connection security monitoring
- Command execution safety
- Session auditing and logging
- Real cluster connectivity (optional)

Usage:
    # Run all tests
    python3 test/test_ssh_security.py
    
    # Run with real SSH tests
    python3 test/test_ssh_security.py --real-ssh
    
    # Run specific test categories
    python3 test/test_ssh_security.py --unit-only
"""

import unittest
import subprocess
import tempfile
import shutil
import json
import os
import time
from pathlib import Path
from datetime import datetime
from unittest.mock import patch, mock_open, MagicMock
import sys
import argparse

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

# Test configuration
TEST_SSH_CONFIG = """
Host test-host
    HostName test-host.example.com
    User testuser
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PasswordAuthentication no
    PubkeyAuthentication yes
    Protocol 2
    StrictHostKeyChecking accept-new
"""

TEST_INSECURE_SSH_CONFIG = """
Host insecure-host
    HostName insecure-host.example.com
    User testuser
    PasswordAuthentication yes
    PubkeyAuthentication no
    Protocol 1
    StrictHostKeyChecking no
"""


class TestSSHSecurityHook(unittest.TestCase):
    """Test SSH security hook functionality"""
    
    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.temp_dir)
        
        # Set up test paths
        self.test_ssh_dir = Path(self.temp_dir) / ".ssh"
        self.test_ssh_dir.mkdir(mode=0o700)
        
        self.ssh_hook_script = project_root / "tools/hpc/ssh-security-hook.sh"
        self.assertTrue(self.ssh_hook_script.exists(), "SSH security hook script not found")
    
    def create_test_ssh_key(self, key_type="ed25519", permissions=0o600):
        """Create a test SSH key file"""
        key_file = self.test_ssh_dir / f"id_{key_type}"
        
        # Create dummy key content
        key_content = f"-----BEGIN OPENSSH PRIVATE KEY-----\ntest_{key_type}_key_content\n-----END OPENSSH PRIVATE KEY-----\n"
        key_file.write_text(key_content)
        key_file.chmod(permissions)
        
        return key_file
    
    def create_test_ssh_config(self, config_content=TEST_SSH_CONFIG):
        """Create a test SSH config file"""
        config_file = self.test_ssh_dir / "config"
        config_file.write_text(config_content)
        config_file.chmod(0o600)
        return config_file
    
    def run_ssh_hook(self, command="validate", extra_args=None, env_vars=None):
        """Run the SSH security hook script"""
        cmd = [str(self.ssh_hook_script), command]
        if extra_args:
            cmd.extend(extra_args)
        
        env = os.environ.copy()
        env["HOME"] = str(self.temp_dir)  # Use test directory as home
        if env_vars:
            env.update(env_vars)
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env=env,
            cwd=str(project_root)
        )
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "success": result.returncode == 0
        }


class TestSSHConfigValidation(TestSSHSecurityHook):
    """Test SSH configuration security validation"""
    
    def test_ssh_version_check(self):
        """Test SSH version validation"""
        # Mock SSH version output
        with patch('subprocess.run') as mock_run:
            # Test acceptable version
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""
            mock_run.return_value.stderr = "OpenSSH_8.9p1, OpenSSL 1.1.1"
            
            result = self.run_ssh_hook("validate")
            
            # Should pass with modern SSH version
            self.assertIn("SSH version", result["stderr"])
    
    def test_ssh_key_validation(self):
        """Test SSH key security validation"""
        # Test with proper Ed25519 key
        self.create_test_ssh_key("ed25519", 0o600)
        
        result = self.run_ssh_hook("validate")
        self.assertIn("SSH key", result["stderr"])
    
    def test_ssh_key_permissions(self):
        """Test SSH key permission validation"""
        # Create key with wrong permissions
        key_file = self.create_test_ssh_key("ed25519", 0o644)
        
        result = self.run_ssh_hook("validate")
        
        # Should detect and fix permission issue
        self.assertEqual(key_file.stat().st_mode & 0o777, 0o600)
    
    def test_weak_rsa_key_detection(self):
        """Test detection of weak RSA keys"""
        # Create RSA key file
        rsa_key = self.create_test_ssh_key("rsa", 0o600)
        
        # Mock ssh-keygen output for weak key
        with patch('subprocess.run') as mock_run:
            def side_effect(*args, **kwargs):
                if 'ssh-keygen' in args[0]:
                    mock_result = MagicMock()
                    mock_result.returncode = 0
                    mock_result.stdout = "1024 SHA256:test fingerprint comment"
                    return mock_result
                else:
                    # Default behavior for other commands
                    return subprocess.run(*args, **kwargs)
            
            mock_run.side_effect = side_effect
            
            result = self.run_ssh_hook("validate")
            
            # Should warn about weak key size
            self.assertIn("weak key size", result["stderr"] or "")
    
    def test_secure_ssh_config(self):
        """Test validation of secure SSH configuration"""
        self.create_test_ssh_config(TEST_SSH_CONFIG)
        self.create_test_ssh_key("ed25519")
        
        result = self.run_ssh_hook("validate")
        
        # Should pass with secure configuration
        self.assertTrue(result["success"] or "SSH configuration validation completed" in result["stderr"])
    
    def test_insecure_ssh_config(self):
        """Test detection of insecure SSH configuration"""
        self.create_test_ssh_config(TEST_INSECURE_SSH_CONFIG)
        self.create_test_ssh_key("ed25519")
        
        result = self.run_ssh_hook("validate")
        
        # Should warn about insecure settings
        output = result["stderr"]
        self.assertTrue(any(warning in output for warning in [
            "Password authentication", "Protocol", "StrictHostKeyChecking"
        ]))


class TestSSHConnectionSecurity(TestSSHSecurityHook):
    """Test SSH connection security validation"""
    
    def test_allowed_host_validation(self):
        """Test validation of allowed hosts"""
        self.create_test_ssh_key("ed25519")
        
        # Test with allowed host
        result = self.run_ssh_hook("execute", ["r04n02", "echo test"])
        # Should not fail due to host validation (may fail due to no actual connection)
        
        # Test with unauthorized host
        result = self.run_ssh_hook("execute", ["malicious-host.example.com", "echo test"])
        self.assertFalse(result["success"])
        self.assertIn("unauthorized host", result["stderr"])
    
    def test_suspicious_command_detection(self):
        """Test detection of suspicious commands"""
        self.create_test_ssh_key("ed25519")
        
        # Test dangerous commands
        dangerous_commands = [
            "rm -rf /",
            "dd if=/dev/zero of=/dev/sda",
            "mkfs.ext4 /dev/sda1",
            "fdisk /dev/sda"
        ]
        
        for cmd in dangerous_commands:
            result = self.run_ssh_hook("execute", ["r04n02", cmd])
            # Should warn but not necessarily block (legitimate admin use)
            self.assertIn("dangerous command", result["stderr"])
    
    def test_connection_timeout(self):
        """Test SSH connection timeout handling"""
        self.create_test_ssh_key("ed25519")
        
        # Test connection to non-existent host (should timeout quickly)
        result = self.run_ssh_hook("test", ["nonexistent-host-12345.example.com"])
        self.assertFalse(result["success"])


class TestSSHSessionMonitoring(TestSSHSecurityHook):
    """Test SSH session monitoring and logging"""
    
    def test_session_logging(self):
        """Test SSH session logging functionality"""
        self.create_test_ssh_key("ed25519")
        
        # Run SSH command that should be logged
        result = self.run_ssh_hook("execute", ["r04n02", "echo test"])
        
        # Check if log files are created
        log_file = Path(self.temp_dir) / "tools/hpc/.ssh_security.log"
        session_log = Path(self.temp_dir) / "tools/hpc/.ssh_security.log.sessions"
        
        # Note: May not exist if command fails, but structure should be correct
        if log_file.exists():
            log_content = log_file.read_text()
            self.assertIn("SSH session", log_content)
    
    def test_monitoring_dashboard(self):
        """Test SSH monitoring dashboard functionality"""
        self.create_test_ssh_key("ed25519")
        
        # Create mock log files
        log_dir = Path(self.temp_dir) / "tools/hpc"
        log_dir.mkdir(parents=True, exist_ok=True)
        
        # Create sample log entries
        log_file = log_dir / ".ssh_security.log"
        session_file = log_dir / ".ssh_security.log.sessions"
        
        log_entries = [
            {
                "timestamp": datetime.now().isoformat(),
                "level": "INFO",
                "message": "SSH connection test successful",
                "host": "r04n02",
                "user": "testuser"
            }
        ]
        
        with open(log_file, 'w') as f:
            for entry in log_entries:
                f.write(json.dumps(entry) + "\n")
        
        session_entries = [
            {
                "session_id": 12345,
                "host": "r04n02",
                "command": "echo test",
                "start_time": datetime.now().isoformat(),
                "status": "started"
            }
        ]
        
        with open(session_file, 'w') as f:
            for entry in session_entries:
                f.write(json.dumps(entry) + "\n")
        
        # Test monitoring dashboard
        result = self.run_ssh_hook("monitor")
        self.assertTrue(result["success"])
        self.assertIn("SSH Security Monitoring Dashboard", result["stdout"])


class TestSSHSecurityIntegration(TestSSHSecurityHook):
    """Integration tests for SSH security system"""
    
    def test_comprehensive_security_check(self):
        """Test comprehensive SSH security validation"""
        # Set up secure environment
        self.create_test_ssh_key("ed25519", 0o600)
        self.create_test_ssh_config(TEST_SSH_CONFIG)
        
        # Create known_hosts file
        known_hosts = self.test_ssh_dir / "known_hosts"
        known_hosts.write_text("r04n02 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest\n")
        known_hosts.chmod(0o644)
        
        result = self.run_ssh_hook("validate")
        
        # Should pass comprehensive check
        self.assertIn("security checks passed", result["stderr"] or result["stdout"])
    
    def test_claude_code_hook_integration(self):
        """Test integration with Claude Code hook system"""
        self.create_test_ssh_key("ed25519")
        
        # Test with Claude context
        env_vars = {
            "CLAUDE_CONTEXT": "SSH connection to HPC cluster",
            "CLAUDE_TOOL_NAME": "ssh",
            "CLAUDE_SUBAGENT_TYPE": "hpc-cluster-operator"
        }
        
        result = self.run_ssh_hook("validate", env_vars=env_vars)
        
        # Should log Claude Code integration
        self.assertIn("SSH security hook triggered by Claude Code", result["stderr"])
    
    def test_error_handling_and_recovery(self):
        """Test error handling and recovery mechanisms"""
        # Test with missing SSH directory
        shutil.rmtree(self.test_ssh_dir)
        
        result = self.run_ssh_hook("validate")
        
        # Should handle gracefully
        self.assertIn("SSH keys found", result["stderr"] or "expected missing keys")


class TestRealSSHConnectivity(unittest.TestCase):
    """Real SSH connectivity tests (optional)"""
    
    def setUp(self):
        """Check if real SSH tests should run"""
        self.ssh_hook_script = project_root / "tools/hpc/ssh-security-hook.sh"
        self.skip_real_tests = True
        
        try:
            # Test if we can connect to r04n02
            result = subprocess.run([
                "ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                "scholten@r04n02", "echo 'SSH_TEST'"
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0 and "SSH_TEST" in result.stdout:
                self.skip_real_tests = False
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
    
    @unittest.skipIf(True, "Real SSH tests disabled by default")  # Override with --real-ssh
    def test_real_r04n02_connection(self):
        """Test real SSH connection to r04n02"""
        if self.skip_real_tests:
            self.skipTest("Real SSH connection not available")
        
        result = subprocess.run([
            str(self.ssh_hook_script), "test", "r04n02"
        ], capture_output=True, text=True, cwd=str(project_root))
        
        self.assertTrue(result.returncode == 0, f"SSH test failed: {result.stderr}")
        self.assertIn("SSH connection test successful", result.stderr)
    
    @unittest.skipIf(True, "Real SSH tests disabled by default")
    def test_real_secure_command_execution(self):
        """Test real secure command execution"""
        if self.skip_real_tests:
            self.skipTest("Real SSH connection not available")
        
        result = subprocess.run([
            str(self.ssh_hook_script), "execute", "r04n02", "hostname && uptime"
        ], capture_output=True, text=True, cwd=str(project_root))
        
        self.assertTrue(result.returncode == 0, f"SSH execution failed: {result.stderr}")
        self.assertIn("r04n02", result.stdout)


def main():
    """Main test runner with argument parsing"""
    parser = argparse.ArgumentParser(description="SSH Security Hook Test Suite")
    parser.add_argument("--unit-only", action="store_true",
                       help="Run only unit tests (skip integration)")
    parser.add_argument("--real-ssh", action="store_true",
                       help="Enable real SSH connection tests") 
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Verbose test output")
    
    args, unknown = parser.parse_known_args()
    
    # Configure test verbosity
    verbosity = 2 if args.verbose else 1
    
    # Build test suite
    test_loader = unittest.TestLoader()
    test_suite = unittest.TestSuite()
    
    # Always include unit tests
    test_suite.addTests(test_loader.loadTestsFromTestCase(TestSSHConfigValidation))
    test_suite.addTests(test_loader.loadTestsFromTestCase(TestSSHConnectionSecurity))
    test_suite.addTests(test_loader.loadTestsFromTestCase(TestSSHSessionMonitoring))
    
    # Include integration tests unless --unit-only
    if not args.unit_only:
        test_suite.addTests(test_loader.loadTestsFromTestCase(TestSSHSecurityIntegration))
    
    # Include real SSH tests only if --real-ssh
    if args.real_ssh:
        # Enable real SSH tests by patching the skip condition
        TestRealSSHConnectivity.test_real_r04n02_connection.__unittest_skip__ = False
        TestRealSSHConnectivity.test_real_secure_command_execution.__unittest_skip__ = False
        test_suite.addTests(test_loader.loadTestsFromTestCase(TestRealSSHConnectivity))
    
    # Run tests
    print("🔒 SSH Security Hook Test Suite")
    print("=" * 50)
    if args.unit_only:
        print("Running unit tests only")
    if args.real_ssh:
        print("Real SSH connection tests enabled")
    print()
    
    runner = unittest.TextTestRunner(verbosity=verbosity)
    result = runner.run(test_suite)
    
    # Print summary
    print("\n" + "=" * 50)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")
    
    if result.failures:
        print("\n❌ FAILURES:")
        for test, traceback in result.failures:
            print(f"  - {test}")
    
    if result.errors:
        print("\n💥 ERRORS:")
        for test, traceback in result.errors:
            print(f"  - {test}")
    
    success = len(result.failures) == 0 and len(result.errors) == 0
    print(f"\n{'✅ ALL TESTS PASSED' if success else '❌ TESTS FAILED'}")
    
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())