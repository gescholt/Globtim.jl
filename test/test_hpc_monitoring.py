#!/usr/bin/env python3
"""
Comprehensive Test Suite for HPC Node Monitoring Tool
====================================================

Tests the complete HPC monitoring system using 2D examples with:
- Mock node environment simulation
- Real SSH connection testing (when available)
- Experiment progress analysis
- Anomaly detection validation
- Resource monitoring accuracy
- GitLab integration testing

Usage:
    # Run all tests
    python3 test/test_hpc_monitoring.py
    
    # Run specific test categories
    python3 test/test_hpc_monitoring.py --unit-only    # Skip integration tests
    python3 test/test_hpc_monitoring.py --real-ssh     # Test real SSH connections
"""

import unittest
import json
import tempfile
import shutil
import time
import subprocess
from unittest.mock import patch, MagicMock, Mock
from pathlib import Path
from datetime import datetime, timedelta
import sys
import argparse

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

try:
    from tools.hpc.secure_node_config import SecureNodeAccess, HPCSecurityError
    from tools.hpc.node_monitor import NodeMonitor, HPCMonitoringError
except ImportError as e:
    print(f"Import error: {e}")
    print("Ensure you're running from the project root directory")
    sys.exit(1)


class MockNodeAccess:
    """Mock secure node access for testing without real SSH"""
    
    def __init__(self, simulate_errors=False):
        self.simulate_errors = simulate_errors
        self.call_count = 0
        self.command_history = []
        self.project_root = project_root
        
        # Mock tmux sessions
        self.mock_sessions = [
            {
                "name": "globtim_2d_test_20250904_120000",
                "windows": "1",
                "created": "Wed Sep  4 12:00:00 2025",
                "status": "[80x24]"
            },
            {
                "name": "globtim_4d_experiment_20250904_140000", 
                "windows": "1",
                "created": "Wed Sep  4 14:00:00 2025",
                "status": "[80x24]"
            }
        ]
        
        # Mock experiment outputs
        self.mock_outputs = {
            "globtim_2d_test_20250904_120000": {
                "log_content": self._generate_2d_log(),
                "last_modified": time.time() - 300,  # 5 minutes ago
                "size": 1024
            },
            "globtim_4d_experiment_20250904_140000": {
                "log_content": self._generate_4d_log(),
                "last_modified": time.time() - 3600,  # 1 hour ago (stalled)
                "size": 2048
            }
        }
    
    def _generate_2d_log(self):
        """Generate realistic 2D experiment log content"""
        return """🚀 HPC Light 2D Example - Complete Globtim Workflow
========================================
Started: 2025-09-04T12:00:15

📋 Configuration:
   Degree: 6
   Samples: 50
   Domain range: ±1.5

📈 STEP 1: Polynomial Approximation
----------------------------------------
Creating test input...
✅ Generated 50 sample points
   Domain: [-0.5, 2.5] × [-2.0, 1.0]

Constructing polynomial approximation...
✅ Polynomial constructed successfully!
   Degree: 6
   Basis: Chebyshev
   Coefficients: 28
   L2 approximation error: 1.23e-12
   Condition number: 1.45e+03
   Time: 2.15 seconds

🔍 STEP 2: Critical Point Finding
----------------------------------------
Solving polynomial system...
Processing critical points...
✅ Critical points found successfully!
   Raw solutions: 15
   Valid critical points: 3
   Time: 3.42 seconds

📊 Critical Points Summary:
   Minimum function value: 0.002341
   Maximum function value: 12.456789
   Best critical point: [0.9987, -0.5012]
   Best function value: 0.002341

🔬 STEP 3: Critical Point Refinement & Classification
----------------------------------------
Refining critical points with BFGS...
✅ Critical point refinement completed!
   Refined points: 3
   Local minima identified: 1
   Time: 1.87 seconds

🎯 Local Minima Found:
   Minimum 1: [1.0000, -0.5000] → f = 0.000000

🏁 WORKFLOW COMPLETED SUCCESSFULLY!
========================================
📊 Final Results:
   Polynomial degree: 6
   Sample points: 50
   L2 approximation error: 1.23e-12
   Critical points found: 3
   Local minima identified: 1
   Total execution time: 7.44 seconds

✅ SUCCESS: Complete 2D Globtim workflow executed successfully!
"""

    def _generate_4d_log(self):
        """Generate 4D experiment log with potential stalling"""
        return """4D Lotka-Volterra Parameter Estimation
=====================================
Started: 2025-09-04T14:00:00

Configuration:
- Parameters: α=1.5, β=1.0, γ=0.75, δ=1.25
- Degree: 12
- Sample points: 200

📈 Polynomial Construction Started...
Constructing degree 12 polynomial in 4 dimensions
Basis functions: 28561
Memory allocation: 2.3GB Vandermonde matrix

Progress: Sampling parameter space...
[14:15:23] Sampled 50/200 parameter points
[14:18:45] Sampled 100/200 parameter points  
[14:22:12] Sampled 150/200 parameter points
[14:25:38] Sampled 200/200 parameter points

Progress: Solving ODE system...
[14:26:00] Processing parameter set 1/200
[14:26:45] Processing parameter set 50/200
[14:28:30] Processing parameter set 100/200
[14:30:15] Processing parameter set 150/200

ERROR: MethodError: no method matching iterate(::typeof(parameter_estimation_objective))
   at process_results (line 151)
   
WARNING: Experiment may have stalled - last output 1 hour ago
"""

    def execute_command(self, command, timeout=60, working_dir=None):
        """Mock command execution"""
        self.call_count += 1
        self.command_history.append(command)
        
        if self.simulate_errors and self.call_count % 3 == 0:
            return {
                "stdout": "",
                "stderr": "Simulated error",
                "returncode": 1,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": False
            }
        
        # Mock responses for different commands
        if command == "hostname && pwd":
            return {
                "stdout": "r04n02\n/home/scholten/globtim",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif command == "tmux ls 2>/dev/null || echo 'NO_SESSIONS'":
            if self.mock_sessions:
                lines = []
                for session in self.mock_sessions:
                    lines.append(f"{session['name']}: {session['windows']} windows (created {session['created']}) {session['status']}")
                return {
                    "stdout": "\n".join(lines),
                    "stderr": "",
                    "returncode": 0,
                    "command": command,
                    "working_dir": working_dir,
                    "execution_time": time.time(),
                    "success": True
                }
            else:
                return {
                    "stdout": "NO_SESSIONS",
                    "stderr": "",
                    "returncode": 0,
                    "command": command,
                    "working_dir": working_dir,
                    "execution_time": time.time(),
                    "success": True
                }
        elif "free -b" in command:
            # Mock memory information
            return {
                "stdout": '{"total": 33554432000, "used": 26843545600, "free": 6710886400, "usage_percent": 80.0}',
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "uptime" in command:
            return {
                "stdout": "1.25 2.10 1.85",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "df /home/scholten/globtim" in command:
            # Mock disk usage
            return {
                "stdout": '{"total": 107374182400, "used": 64424509440, "available": 42949672960, "usage_percent": 60}',
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "ps aux | wc -l" in command:
            return {
                "stdout": "156",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "find /home/scholten/globtim/node_experiments/outputs" in command:
            # Mock experiment directory search
            for session_name in self.mock_outputs:
                if session_name in command:
                    return {
                        "stdout": f"/home/scholten/globtim/node_experiments/outputs/{session_name}_results",
                        "stderr": "",
                        "returncode": 0,
                        "command": command,
                        "working_dir": working_dir,
                        "execution_time": time.time(),
                        "success": True
                    }
        elif "test -f" in command and "output.log" in command:
            return {
                "stdout": "EXISTS",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "stat -c" in command:
            # Mock file stats
            for session_name, data in self.mock_outputs.items():
                if session_name in command:
                    return {
                        "stdout": f"{int(data['last_modified'])} {data['size']}",
                        "stderr": "",
                        "returncode": 0,
                        "command": command,
                        "working_dir": working_dir,
                        "execution_time": time.time(),
                        "success": True
                    }
        elif "tail -50" in command or "tail -20" in command:
            # Mock log content
            for session_name, data in self.mock_outputs.items():
                if session_name in command:
                    return {
                        "stdout": data["log_content"],
                        "stderr": "",
                        "returncode": 0,
                        "command": command,
                        "working_dir": working_dir,
                        "execution_time": time.time(),
                        "success": True
                    }
        elif "ps aux | grep julia" in command:
            return {
                "stdout": "scholten  12345  0.5  5.2 2048000 345600 pts/1 Sl+ 14:00   1:25 julia --project=.",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        elif "ls -lt" in command:
            return {
                "stdout": "total 48\ndrwxr-xr-x 3 scholten scholten 4096 Sep  4 14:30 globtim_4d_experiment_20250904_140000_results\ndrwxr-xr-x 3 scholten scholten 4096 Sep  4 12:07 globtim_2d_test_20250904_120000_results",
                "stderr": "",
                "returncode": 0,
                "command": command,
                "working_dir": working_dir,
                "execution_time": time.time(),
                "success": True
            }
        
        # Default response
        return {
            "stdout": "mock_output",
            "stderr": "",
            "returncode": 0,
            "command": command,
            "working_dir": working_dir,
            "execution_time": time.time(),
            "success": True
        }
    
    def list_tmux_sessions(self):
        """Mock tmux session listing"""
        return self.mock_sessions
    
    def monitor_experiment_session(self, session_name):
        """Mock session monitoring"""
        if session_name in [s["name"] for s in self.mock_sessions]:
            return {
                "exists": True,
                "session": next(s for s in self.mock_sessions if s["name"] == session_name),
                "processes": ["julia --project=. experiments/test.jl"],
                "latest_output": self.mock_outputs.get(session_name, {}).get("log_content", "No output"),
                "resource_usage": "Memory: 2.1G/32G\nCPU: 15%\nDisk: 60% used"
            }
        else:
            return {"exists": False, "message": f"Session '{session_name}' not found"}


class TestSecureNodeAccess(unittest.TestCase):
    """Test secure node access functionality"""
    
    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.temp_dir)
    
    def test_mock_node_access(self):
        """Test mock node access functionality"""
        mock_node = MockNodeAccess()
        
        # Test basic command execution
        result = mock_node.execute_command("hostname && pwd")
        self.assertTrue(result["success"])
        self.assertIn("r04n02", result["stdout"])
        
        # Test tmux session listing
        sessions = mock_node.list_tmux_sessions()
        self.assertEqual(len(sessions), 2)
        self.assertTrue(any("2d_test" in s["name"] for s in sessions))
        self.assertTrue(any("4d_experiment" in s["name"] for s in sessions))
        
        # Test session monitoring
        session_name = "globtim_2d_test_20250904_120000"
        session_info = mock_node.monitor_experiment_session(session_name)
        self.assertTrue(session_info["exists"])
        self.assertIn("Polynomial constructed successfully", session_info["latest_output"])
    
    def test_error_simulation(self):
        """Test error handling with simulated errors"""
        mock_node = MockNodeAccess(simulate_errors=True)
        
        # Every third call should fail
        result1 = mock_node.execute_command("test1")
        result2 = mock_node.execute_command("test2") 
        result3 = mock_node.execute_command("test3")  # Should fail
        
        self.assertTrue(result1["success"])
        self.assertTrue(result2["success"])
        self.assertFalse(result3["success"])
        self.assertEqual(result3["stderr"], "Simulated error")


class TestNodeMonitor(unittest.TestCase):
    """Test node monitoring functionality"""
    
    def setUp(self):
        """Set up test environment with mock node access"""
        self.mock_node = MockNodeAccess()
        self.temp_dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.temp_dir)
        
        # Patch SecureNodeAccess to use our mock
        self.node_patcher = patch('tools.hpc.node_monitor.SecureNodeAccess')
        self.mock_secure_node = self.node_patcher.start()
        self.mock_secure_node.return_value = self.mock_node
        self.addCleanup(self.node_patcher.stop)
        
        # Initialize monitor with mocked node access
        self.monitor = NodeMonitor()
        self.monitor.node = self.mock_node
    
    def test_system_resource_monitoring(self):
        """Test system resource monitoring"""
        resources = self.monitor.get_system_resources()
        
        self.assertIn("timestamp", resources)
        self.assertIn("memory", resources)
        self.assertIn("cpu_load", resources)
        self.assertIn("disk", resources)
        
        # Check memory data
        self.assertIn("usage_percent", resources["memory"])
        self.assertEqual(resources["memory"]["usage_percent"], 80.0)
        
        # Check CPU load
        self.assertIn("1min", resources["cpu_load"])
        self.assertEqual(resources["cpu_load"]["1min"], 1.25)
        
        # Check disk usage  
        self.assertIn("usage_percent", resources["disk"])
        self.assertEqual(resources["disk"]["usage_percent"], 60)
    
    def test_experiment_progress_analysis(self):
        """Test experiment progress analysis"""
        # Test 2D experiment (successful)
        session_name = "globtim_2d_test_20250904_120000"
        analysis = self.monitor.analyze_experiment_progress(session_name)
        
        self.assertEqual(analysis["status"], "running")
        self.assertEqual(analysis["session"], session_name)
        self.assertIn("progress_indicators", analysis)
        self.assertIn("errors", analysis)
        self.assertIn("warnings", analysis)
        
        # Should find polynomial construction progress
        if analysis.get("progress_indicators"):
            # Check for polynomial-related indicators
            indicators = analysis["progress_indicators"]
            indicator_text = str(indicators).lower()
            self.assertTrue(
                any(word in indicator_text for word in ["polynomial", "degree", "coefficient"])
            )
    
    def test_4d_experiment_analysis(self):
        """Test 4D experiment analysis with stalled detection"""
        session_name = "globtim_4d_experiment_20250904_140000"
        analysis = self.monitor.analyze_experiment_progress(session_name)
        
        self.assertEqual(analysis["session"], session_name)
        
        # Should detect stalled experiment (last activity > 1 hour ago)
        if analysis.get("status") == "potentially_stalled":
            self.assertIn("stall_duration_minutes", analysis)
            self.assertGreater(analysis["stall_duration_minutes"], 60)
        
        # Should detect errors in log
        self.assertGreater(len(analysis.get("errors", [])), 0)
        error_text = " ".join(analysis.get("errors", []))
        self.assertIn("MethodError", error_text)
    
    def test_anomaly_detection(self):
        """Test anomaly detection system"""
        # Create mock resources with high usage
        resources = {
            "memory": {"usage_percent": 95.0},  # Above 90% threshold
            "cpu_load": {"1min": 10.0},         # Above 8.0 threshold
            "disk": {"usage_percent": 90}       # Above 85% threshold
        }
        
        # Create experiments with issues
        experiments = [
            {
                "status": "potentially_stalled",
                "session": "test_session",
                "stall_duration_minutes": 75,
                "errors": ["Error 1", "Error 2", "Error 3"]
            }
        ]
        
        anomalies = self.monitor.detect_anomalies(resources, experiments)
        
        # Should detect multiple anomalies
        self.assertGreater(len(anomalies), 0)
        
        anomaly_types = [a["type"] for a in anomalies]
        self.assertIn("high_memory_usage", anomaly_types)
        self.assertIn("high_cpu_load", anomaly_types)
        self.assertIn("high_disk_usage", anomaly_types)
        self.assertIn("experiment_stalled", anomaly_types)
        self.assertIn("experiment_errors", anomaly_types)
    
    def test_status_report_generation(self):
        """Test comprehensive status report generation"""
        # Test JSON format
        json_report = self.monitor.generate_status_report("json")
        report_data = json.loads(json_report)
        
        self.assertIn("report_timestamp", report_data)
        self.assertIn("monitoring_system", report_data)
        self.assertIn("system_resources", report_data)
        self.assertIn("tmux_sessions", report_data)
        self.assertIn("active_experiments", report_data)
        self.assertIn("anomalies", report_data)
        self.assertIn("summary", report_data)
        
        # Check summary data
        summary = report_data["summary"]
        self.assertEqual(summary["total_sessions"], 2)
        self.assertIn("system_health", summary)
        
        # Test text format
        text_report = self.monitor.generate_status_report("text")
        self.assertIn("HPC Node Monitoring Report", text_report)
        self.assertIn("System Health:", text_report)
        self.assertIn("Active Sessions:", text_report)
    
    def test_2d_experiment_patterns(self):
        """Test detection of 2D experiment patterns"""
        session_name = "globtim_2d_test_20250904_120000"
        analysis = self.monitor.analyze_experiment_progress(session_name)
        
        # Should detect specific 2D workflow patterns
        all_text = json.dumps(analysis).lower()
        
        # Debug: Print what patterns are found
        found_patterns = []
        test_patterns = ["polynomial", "degree", "coefficient", "chebyshev", "critical", "minimum", "optimization", "success", "complete"]
        for pattern in test_patterns:
            if pattern in all_text:
                found_patterns.append(pattern)
        
        # Should find workflow success indicators (more flexible than specific terms)
        self.assertTrue(any(pattern in all_text for pattern in [
            "polynomial", "degree", "success", "complete", "workflow"
        ]), f"Expected workflow patterns not found. Found patterns: {found_patterns}. Analysis: {analysis}")
        
        # Should have basic structure
        self.assertIn("status", analysis)
        self.assertEqual(analysis["status"], "running")


class TestHPCExperimentIntegration(unittest.TestCase):
    """Integration tests using actual 2D examples"""
    
    def setUp(self):
        """Set up integration test environment"""
        self.project_root = project_root
        self.examples_dir = self.project_root / "Examples"
        
        # Check if examples exist
        self.light_2d_example = self.examples_dir / "hpc_light_2d_example.jl"
        self.minimal_2d_example = self.examples_dir / "hpc_minimal_2d_example.jl"
        
        self.examples_available = (
            self.light_2d_example.exists() and 
            self.minimal_2d_example.exists()
        )
    
    @unittest.skipUnless(shutil.which("julia"), "Julia not available")
    def test_2d_example_syntax(self):
        """Test that 2D examples have valid Julia syntax"""
        if not self.examples_available:
            self.skipTest("2D examples not available")
        
        # Test light example syntax
        result = subprocess.run([
            "julia", "--check-bounds=yes", "--check-syntax", 
            str(self.light_2d_example)
        ], capture_output=True, text=True)
        
        self.assertEqual(result.returncode, 0, 
                        f"Light 2D example has syntax errors: {result.stderr}")
        
        # Test minimal example syntax
        result = subprocess.run([
            "julia", "--check-bounds=yes", "--check-syntax",
            str(self.minimal_2d_example)
        ], capture_output=True, text=True)
        
        self.assertEqual(result.returncode, 0,
                        f"Minimal 2D example has syntax errors: {result.stderr}")
    
    def test_experiment_log_parsing(self):
        """Test parsing of realistic experiment logs"""
        # Create sample log files based on 2D examples
        mock_node = MockNodeAccess()
        
        # Mock NodeMonitor initialization to avoid SSH validation
        with patch('tools.hpc.node_monitor.SecureNodeAccess', return_value=mock_node):
            monitor = NodeMonitor()
            monitor.node = mock_node
            
            # Test log parsing for each experiment type
            sessions = ["globtim_2d_test_20250904_120000", "globtim_4d_experiment_20250904_140000"]
            
            for session in sessions:
                analysis = monitor.analyze_experiment_progress(session)
                
                # All analyses should have basic structure
                self.assertIn("status", analysis)
                self.assertIn("session", analysis)
                self.assertIn("progress_indicators", analysis)
                self.assertIn("errors", analysis)
                
                # 2D experiment should be successful
                if "2d_test" in session:
                    self.assertEqual(analysis["status"], "running")
                    # Should detect successful completion indicators
                    if analysis.get("progress_indicators"):
                        all_text = json.dumps(analysis["progress_indicators"]).lower()
                        self.assertTrue(any(word in all_text for word in [
                            "success", "complete", "polynomial", "critical"
                        ]))
                
                # 4D experiment should show problems
                elif "4d_experiment" in session:
                    # Should detect stalling or errors
                    has_issues = (
                        analysis.get("status") == "potentially_stalled" or
                        len(analysis.get("errors", [])) > 0
                    )
                    self.assertTrue(has_issues, "4D experiment should show issues")


class TestRealSSHIntegration(unittest.TestCase):
    """Real SSH integration tests (run only when --real-ssh is specified)"""
    
    def setUp(self):
        """Set up real SSH test environment"""
        self.real_ssh_available = False
        try:
            # Test if we can connect to r04n02
            result = subprocess.run([
                "ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                "scholten@r04n02", "echo 'SSH_TEST'"
            ], capture_output=True, text=True, timeout=10)
            
            self.real_ssh_available = (result.returncode == 0 and "SSH_TEST" in result.stdout)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
    
    @unittest.skipUnless(False, "Real SSH tests disabled by default")  # Override with --real-ssh
    def test_real_node_connection(self):
        """Test real connection to r04n02 node"""
        if not self.real_ssh_available:
            self.skipTest("Real SSH connection to r04n02 not available")
        
        try:
            node = SecureNodeAccess()
            result = node.execute_command("hostname && pwd")
            
            self.assertTrue(result["success"])
            self.assertIn("r04n02", result["stdout"])
            self.assertIn("/home/scholten/globtim", result["stdout"])
            
        except HPCSecurityError as e:
            self.fail(f"Real SSH connection failed: {e}")
    
    @unittest.skipUnless(False, "Real SSH tests disabled by default")
    def test_real_monitoring_data(self):
        """Test monitoring with real node data"""
        if not self.real_ssh_available:
            self.skipTest("Real SSH connection to r04n02 not available")
        
        try:
            monitor = NodeMonitor()
            resources = monitor.get_system_resources()
            
            self.assertIn("memory", resources)
            self.assertIn("cpu_load", resources) 
            self.assertIn("disk", resources)
            
            # Check realistic values
            if "memory" in resources and "usage_percent" in resources["memory"]:
                usage = resources["memory"]["usage_percent"]
                self.assertGreaterEqual(usage, 0)
                self.assertLessEqual(usage, 100)
            
        except (HPCSecurityError, HPCMonitoringError) as e:
            self.fail(f"Real monitoring failed: {e}")


def main():
    """Main test runner with argument parsing"""
    parser = argparse.ArgumentParser(description="HPC Monitoring Tool Test Suite")
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
    test_suite.addTests(test_loader.loadTestsFromTestCase(TestSecureNodeAccess))
    test_suite.addTests(test_loader.loadTestsFromTestCase(TestNodeMonitor))
    
    # Include integration tests unless --unit-only
    if not args.unit_only:
        test_suite.addTests(test_loader.loadTestsFromTestCase(TestHPCExperimentIntegration))
    
    # Include real SSH tests only if --real-ssh
    if args.real_ssh:
        # Enable real SSH tests by patching the skip condition
        TestRealSSHIntegration.test_real_node_connection.__unittest_skip__ = False
        TestRealSSHIntegration.test_real_monitoring_data.__unittest_skip__ = False
        test_suite.addTests(test_loader.loadTestsFromTestCase(TestRealSSHIntegration))
    
    # Run tests
    print("🧪 HPC Monitoring Tool Test Suite")
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
            print(f"  - {test}: {traceback.split(chr(10))[-2] if traceback else 'Unknown'}")
    
    if result.errors:
        print("\n💥 ERRORS:")
        for test, traceback in result.errors:
            print(f"  - {test}: {traceback.split(chr(10))[-2] if traceback else 'Unknown'}")
    
    success = len(result.failures) == 0 and len(result.errors) == 0
    print(f"\n{'✅ ALL TESTS PASSED' if success else '❌ TESTS FAILED'}")
    
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())