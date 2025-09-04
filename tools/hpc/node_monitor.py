#!/usr/bin/env python3
"""
Advanced HPC Node Monitoring Tool
=================================

Comprehensive monitoring system for r04n02 compute node with:
- Real-time tmux session monitoring
- Experiment progress tracking
- Resource utilization monitoring
- Automated anomaly detection
- Integration with GitLab issue tracking

This tool builds on the secure node access framework to provide
comprehensive visibility into HPC experiment execution.

Usage:
    # Start monitoring dashboard
    python3 tools/hpc/node_monitor.py --dashboard
    
    # Monitor specific session
    python3 tools/hpc/node_monitor.py --session globtim_4d_20250904
    
    # Generate status report
    python3 tools/hpc/node_monitor.py --report --format json
"""

import argparse
import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from pathlib import Path
import re
import sys

# Add project root to path for imports
sys.path.append(str(Path(__file__).parent.parent.parent))

try:
    from tools.hpc.secure_node_config import SecureNodeAccess, HPCSecurityError
    from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI, GitLabSecurityError
except ImportError as e:
    print(f"Import error: {e}")
    print("Ensure you're running from the project root directory")
    sys.exit(1)


class HPCMonitoringError(Exception):
    """Raised when monitoring operations fail"""
    pass


class NodeMonitor:
    """
    Advanced HPC node monitoring with real-time dashboard capabilities
    """
    
    def __init__(self):
        """Initialize monitoring system with secure access"""
        self.node = SecureNodeAccess()
        self.project_root = self.node.project_root
        self.monitor_log = self.project_root / "tools/hpc/.monitoring.log"
        
        # Monitoring configuration
        self.refresh_interval = 30  # seconds
        self.anomaly_thresholds = {
            "memory_usage_percent": 90,
            "cpu_load_avg": 8.0,
            "disk_usage_percent": 85,
            "experiment_stall_minutes": 60
        }
        
        # Try to initialize GitLab integration (optional)
        self.gitlab = None
        try:
            self.gitlab = SecureGitLabAPI()
        except (GitLabSecurityError, Exception) as e:
            print(f"GitLab integration unavailable: {e}")
    
    def _log_event(self, level: str, message: str, **kwargs):
        """Log monitoring events"""
        timestamp = datetime.now().isoformat()
        log_entry = {
            "timestamp": timestamp,
            "level": level,
            "message": message,
            **kwargs
        }
        
        # Ensure log directory exists
        self.monitor_log.parent.mkdir(parents=True, exist_ok=True)
        
        # Append to monitoring log
        with open(self.monitor_log, 'a') as f:
            f.write(json.dumps(log_entry) + "\n")
    
    def get_system_resources(self) -> Dict[str, Any]:
        """Get comprehensive system resource information"""
        try:
            # Memory information
            memory_cmd = "free -b | awk '/^Mem:/ {printf \"{\\\"total\\\": %s, \\\"used\\\": %s, \\\"free\\\": %s, \\\"usage_percent\\\": %.1f}\", $2, $3, $4, ($3/$2)*100}'"
            memory_result = self.node.execute_command(memory_cmd)
            memory_info = json.loads(memory_result["stdout"]) if memory_result["success"] else {}
            
            # CPU load average
            load_result = self.node.execute_command("uptime | awk -F'load average:' '{print $2}' | sed 's/,//g'")
            load_avg = load_result["stdout"].strip().split() if load_result["success"] else ["0", "0", "0"]
            
            # Disk usage for globtim directory
            disk_cmd = "df /home/scholten/globtim | awk 'NR==2 {printf \"{\\\"total\\\": %s, \\\"used\\\": %s, \\\"available\\\": %s, \\\"usage_percent\\\": %d}\", $2*1024, $3*1024, $4*1024, $5}'"
            disk_result = self.node.execute_command(disk_cmd)
            disk_info = json.loads(disk_result["stdout"]) if disk_result["success"] else {}
            
            # Process count
            process_result = self.node.execute_command("ps aux | wc -l")
            process_count = int(process_result["stdout"].strip()) if process_result["success"] else 0
            
            return {
                "timestamp": datetime.now().isoformat(),
                "memory": memory_info,
                "cpu_load": {
                    "1min": float(load_avg[0]) if len(load_avg) > 0 else 0,
                    "5min": float(load_avg[1]) if len(load_avg) > 1 else 0,
                    "15min": float(load_avg[2]) if len(load_avg) > 2 else 0
                },
                "disk": disk_info,
                "processes": process_count
            }
            
        except Exception as e:
            self._log_event("ERROR", f"Failed to get system resources: {e}")
            return {"error": str(e), "timestamp": datetime.now().isoformat()}
    
    def analyze_experiment_progress(self, session_name: str) -> Dict[str, Any]:
        """Analyze experiment progress from log files"""
        try:
            # Find experiment output directory
            find_cmd = f"find /home/scholten/globtim/node_experiments/outputs -name '*{session_name}*' -type d | head -1"
            find_result = self.node.execute_command(find_cmd)
            
            if not find_result["success"] or not find_result["stdout"].strip():
                return {"status": "no_output_directory", "session": session_name}
            
            output_dir = find_result["stdout"].strip()
            
            # Check for output.log
            log_file = f"{output_dir}/output.log"
            log_check = self.node.execute_command(f"test -f {log_file} && echo 'EXISTS' || echo 'MISSING'")
            
            if log_check["stdout"].strip() != "EXISTS":
                return {"status": "no_log_file", "session": session_name, "output_dir": output_dir}
            
            # Analyze log content
            analysis = {
                "status": "running",
                "session": session_name,
                "output_dir": output_dir,
                "log_file": log_file,
                "progress_indicators": {},
                "last_activity": None,
                "errors": [],
                "warnings": []
            }
            
            # Get log file stats
            stat_cmd = f"stat -c '%Y %s' {log_file} 2>/dev/null || stat -f '%m %z' {log_file}"
            stat_result = self.node.execute_command(stat_cmd)
            if stat_result["success"]:
                stat_parts = stat_result["stdout"].strip().split()
                if len(stat_parts) >= 2:
                    last_modified = int(stat_parts[0])
                    file_size = int(stat_parts[1])
                    analysis["last_activity"] = datetime.fromtimestamp(last_modified).isoformat()
                    analysis["log_size_bytes"] = file_size
            
            # Get recent log content (last 50 lines)
            tail_result = self.node.execute_command(f"tail -50 {log_file}")
            if tail_result["success"]:
                recent_lines = tail_result["stdout"].split('\n')
                
                # Look for progress indicators
                progress_patterns = {
                    "parameter_estimation": r"Parameter estimation.*?(\d+\.?\d*%|\d+/\d+)",
                    "polynomial_construction": r"Polynomial.*?(?:degree|order).*?(\d+)",
                    "homotopy_tracking": r"Tracking.*?(\d+).*?paths?",
                    "convergence": r"Converged.*?(\d+\.?\d*)",
                    "error_rate": r"Error.*?(\d+\.?\d*%)",
                }
                
                for pattern_name, pattern in progress_patterns.items():
                    matches = []
                    for line in recent_lines:
                        match = re.search(pattern, line, re.IGNORECASE)
                        if match:
                            matches.append({
                                "line": line.strip(),
                                "value": match.group(1),
                                "timestamp": self._extract_timestamp(line)
                            })
                    if matches:
                        analysis["progress_indicators"][pattern_name] = matches[-1]  # Most recent
                
                # Look for errors and warnings
                for line in recent_lines:
                    if re.search(r'\berror\b', line, re.IGNORECASE):
                        analysis["errors"].append(line.strip())
                    elif re.search(r'\bwarning\b', line, re.IGNORECASE):
                        analysis["warnings"].append(line.strip())
            
            # Check if experiment appears stalled
            if analysis["last_activity"]:
                last_time = datetime.fromisoformat(analysis["last_activity"])
                time_since_activity = datetime.now() - last_time
                if time_since_activity.total_seconds() > self.anomaly_thresholds["experiment_stall_minutes"] * 60:
                    analysis["status"] = "potentially_stalled"
                    analysis["stall_duration_minutes"] = time_since_activity.total_seconds() / 60
            
            return analysis
            
        except Exception as e:
            self._log_event("ERROR", f"Failed to analyze experiment progress: {e}")
            return {"status": "analysis_error", "error": str(e), "session": session_name}
    
    def _extract_timestamp(self, line: str) -> Optional[str]:
        """Extract timestamp from log line if present"""
        # Common timestamp patterns
        patterns = [
            r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}',  # ISO format
            r'\d{2}:\d{2}:\d{2}',  # Time only
            r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]',  # Bracketed
        ]
        
        for pattern in patterns:
            match = re.search(pattern, line)
            if match:
                return match.group(0)
        
        return None
    
    def detect_anomalies(self, resources: Dict[str, Any], experiments: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect system and experiment anomalies"""
        anomalies = []
        timestamp = datetime.now().isoformat()
        
        # Memory usage anomaly
        if "memory" in resources and "usage_percent" in resources["memory"]:
            memory_usage = resources["memory"]["usage_percent"]
            if memory_usage > self.anomaly_thresholds["memory_usage_percent"]:
                anomalies.append({
                    "type": "high_memory_usage",
                    "severity": "warning",
                    "message": f"Memory usage at {memory_usage:.1f}%",
                    "threshold": self.anomaly_thresholds["memory_usage_percent"],
                    "current_value": memory_usage,
                    "timestamp": timestamp
                })
        
        # CPU load anomaly
        if "cpu_load" in resources and "1min" in resources["cpu_load"]:
            load_1min = resources["cpu_load"]["1min"]
            if load_1min > self.anomaly_thresholds["cpu_load_avg"]:
                anomalies.append({
                    "type": "high_cpu_load",
                    "severity": "warning",
                    "message": f"1-minute load average: {load_1min:.2f}",
                    "threshold": self.anomaly_thresholds["cpu_load_avg"],
                    "current_value": load_1min,
                    "timestamp": timestamp
                })
        
        # Disk usage anomaly
        if "disk" in resources and "usage_percent" in resources["disk"]:
            disk_usage = resources["disk"]["usage_percent"]
            if disk_usage > self.anomaly_thresholds["disk_usage_percent"]:
                anomalies.append({
                    "type": "high_disk_usage", 
                    "severity": "critical",
                    "message": f"Disk usage at {disk_usage}%",
                    "threshold": self.anomaly_thresholds["disk_usage_percent"],
                    "current_value": disk_usage,
                    "timestamp": timestamp
                })
        
        # Experiment anomalies
        for exp in experiments:
            if exp.get("status") == "potentially_stalled":
                stall_duration = exp.get("stall_duration_minutes", 0)
                anomalies.append({
                    "type": "experiment_stalled",
                    "severity": "warning",
                    "message": f"Experiment {exp.get('session', 'unknown')} stalled for {stall_duration:.1f} minutes",
                    "session": exp.get("session"),
                    "stall_duration": stall_duration,
                    "timestamp": timestamp
                })
            
            if len(exp.get("errors", [])) > 0:
                anomalies.append({
                    "type": "experiment_errors",
                    "severity": "error",
                    "message": f"Errors detected in {exp.get('session', 'unknown')}",
                    "session": exp.get("session"),
                    "error_count": len(exp["errors"]),
                    "recent_errors": exp["errors"][-3:],  # Last 3 errors
                    "timestamp": timestamp
                })
        
        return anomalies
    
    def generate_status_report(self, format_type: str = "json") -> str:
        """Generate comprehensive status report"""
        try:
            # Gather all monitoring data
            resources = self.get_system_resources()
            sessions = self.node.list_tmux_sessions()
            
            # Analyze each session
            experiment_analyses = []
            for session in sessions:
                if "globtim" in session["name"].lower():
                    analysis = self.analyze_experiment_progress(session["name"])
                    experiment_analyses.append(analysis)
            
            # Detect anomalies
            anomalies = self.detect_anomalies(resources, experiment_analyses)
            
            # Compile report
            report = {
                "report_timestamp": datetime.now().isoformat(),
                "monitoring_system": {
                    "version": "1.0",
                    "node": "r04n02",
                    "refresh_interval": self.refresh_interval
                },
                "system_resources": resources,
                "tmux_sessions": sessions,
                "active_experiments": experiment_analyses,
                "anomalies": anomalies,
                "summary": {
                    "total_sessions": len(sessions),
                    "active_experiments": len(experiment_analyses),
                    "anomaly_count": len(anomalies),
                    "system_health": "healthy" if len(anomalies) == 0 else "issues_detected"
                }
            }
            
            # Format output
            if format_type.lower() == "json":
                return json.dumps(report, indent=2)
            elif format_type.lower() == "text":
                return self._format_text_report(report)
            else:
                raise ValueError(f"Unsupported format: {format_type}")
                
        except Exception as e:
            self._log_event("ERROR", f"Failed to generate status report: {e}")
            error_report = {
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
            return json.dumps(error_report, indent=2)
    
    def _format_text_report(self, report: Dict[str, Any]) -> str:
        """Format report as human-readable text"""
        lines = [
            "=" * 60,
            f"HPC Node Monitoring Report - {report['report_timestamp']}",
            "=" * 60,
            "",
            f"🖥️  System Health: {report['summary']['system_health'].upper()}",
            f"📊 Active Sessions: {report['summary']['total_sessions']}",
            f"🧪 Experiments: {report['summary']['active_experiments']}",
            f"⚠️  Anomalies: {report['summary']['anomaly_count']}",
            ""
        ]
        
        # System resources
        if "system_resources" in report:
            res = report["system_resources"]
            lines.extend([
                "📈 System Resources:",
                f"   Memory: {res.get('memory', {}).get('usage_percent', 0):.1f}% used",
                f"   CPU Load (1m): {res.get('cpu_load', {}).get('1min', 0):.2f}",
                f"   Disk Usage: {res.get('disk', {}).get('usage_percent', 0)}%",
                ""
            ])
        
        # Active experiments
        if report["active_experiments"]:
            lines.append("🧪 Active Experiments:")
            for exp in report["active_experiments"]:
                status = exp.get("status", "unknown")
                session = exp.get("session", "unnamed")
                lines.append(f"   • {session}: {status}")
                
                if exp.get("progress_indicators"):
                    for indicator, data in exp["progress_indicators"].items():
                        lines.append(f"     - {indicator}: {data.get('value', 'N/A')}")
            lines.append("")
        
        # Anomalies
        if report["anomalies"]:
            lines.append("⚠️  Detected Anomalies:")
            for anomaly in report["anomalies"]:
                severity = anomaly.get("severity", "unknown").upper()
                message = anomaly.get("message", "No message")
                lines.append(f"   [{severity}] {message}")
            lines.append("")
        
        lines.append("=" * 60)
        return "\n".join(lines)
    
    async def run_dashboard(self):
        """Run interactive monitoring dashboard"""
        print("🖥️  Starting HPC Node Monitoring Dashboard")
        print("   Press Ctrl+C to stop\n")
        
        try:
            while True:
                # Clear screen
                print("\033[2J\033[H")
                
                # Generate and display report
                report = self.generate_status_report("text")
                print(report)
                
                # Wait for next refresh
                await asyncio.sleep(self.refresh_interval)
                
        except KeyboardInterrupt:
            print("\n👋 Monitoring dashboard stopped")
    
    def monitor_session(self, session_name: str):
        """Monitor specific tmux session in detail"""
        print(f"🔍 Monitoring session: {session_name}")
        print("   Press Ctrl+C to stop\n")
        
        try:
            while True:
                # Get session details
                session_info = self.node.monitor_experiment_session(session_name)
                
                if not session_info.get("exists", False):
                    print(f"❌ Session '{session_name}' not found")
                    break
                
                # Analyze progress
                analysis = self.analyze_experiment_progress(session_name)
                
                # Display information
                print(f"\n📊 Session Status - {datetime.now().strftime('%H:%M:%S')}")
                print("-" * 40)
                print(f"Status: {analysis.get('status', 'unknown')}")
                
                if analysis.get("last_activity"):
                    print(f"Last Activity: {analysis['last_activity']}")
                
                if analysis.get("progress_indicators"):
                    print("\n📈 Progress Indicators:")
                    for indicator, data in analysis["progress_indicators"].items():
                        print(f"   {indicator}: {data.get('value', 'N/A')}")
                
                if analysis.get("errors"):
                    print(f"\n❌ Recent Errors ({len(analysis['errors'])}):")
                    for error in analysis["errors"][-3:]:  # Last 3 errors
                        print(f"   {error}")
                
                if session_info.get("latest_output"):
                    print("\n📝 Latest Output (last 10 lines):")
                    lines = session_info["latest_output"].split('\n')
                    for line in lines[-10:]:
                        if line.strip():
                            print(f"   {line}")
                
                print("\n" + "=" * 60)
                time.sleep(self.refresh_interval)
                
        except KeyboardInterrupt:
            print(f"\n👋 Stopped monitoring {session_name}")


def main():
    """Main entry point for node monitoring tool"""
    parser = argparse.ArgumentParser(
        description="Advanced HPC Node Monitoring Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Start monitoring dashboard
    python3 tools/hpc/node_monitor.py --dashboard
    
    # Monitor specific session  
    python3 tools/hpc/node_monitor.py --session globtim_4d_20250904
    
    # Generate JSON report
    python3 tools/hpc/node_monitor.py --report --format json
    
    # Generate text report
    python3 tools/hpc/node_monitor.py --report --format text
        """
    )
    
    parser.add_argument("--dashboard", action="store_true",
                       help="Start interactive monitoring dashboard")
    parser.add_argument("--session", type=str, metavar="NAME",
                       help="Monitor specific tmux session")
    parser.add_argument("--report", action="store_true",
                       help="Generate status report")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                       help="Report format (default: text)")
    
    args = parser.parse_args()
    
    try:
        monitor = NodeMonitor()
        
        if args.dashboard:
            asyncio.run(monitor.run_dashboard())
        elif args.session:
            monitor.monitor_session(args.session)
        elif args.report:
            report = monitor.generate_status_report(args.format)
            print(report)
        else:
            # Default: show quick status
            report = monitor.generate_status_report("text")
            print(report)
            
    except HPCSecurityError as e:
        print(f"❌ Security Error: {e}")
        return 1
    except HPCMonitoringError as e:
        print(f"❌ Monitoring Error: {e}")
        return 1
    except KeyboardInterrupt:
        print("\n👋 Monitoring stopped by user")
        return 0
    except Exception as e:
        print(f"❌ Unexpected Error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())