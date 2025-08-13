"""
GlobTim HPC Test Report Generators
Generate reports in various formats
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any
import html


class ReportGenerator:
    """Base class for report generators"""
    
    def generate(self, results: Dict, output_path: str) -> None:
        """Generate report from test results"""
        raise NotImplementedError


class HTMLReporter(ReportGenerator):
    """Generate HTML reports"""
    
    def generate(self, results: Dict, output_path: str) -> None:
        """Generate HTML report"""
        html_content = self._generate_html(results)
        
        with open(output_path, 'w') as f:
            f.write(html_content)
    
    def _generate_html(self, results: Dict) -> str:
        """Generate HTML content"""
        summary = results.get('summary', {})
        tests = results.get('tests', [])
        
        # Calculate pass rate
        total = summary.get('total_tests', 0)
        passed = summary.get('passed', 0)
        pass_rate = (passed / total * 100) if total > 0 else 0
        
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>GlobTim Test Report - {results.get('suite_name', 'Unknown')}</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }}
        .header h1 {{
            margin: 0;
            font-size: 2em;
        }}
        .summary {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .metric {{
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .metric .value {{
            font-size: 2em;
            font-weight: bold;
            color: #333;
        }}
        .metric .label {{
            color: #666;
            margin-top: 5px;
        }}
        .metric.passed {{ border-left: 4px solid #10b981; }}
        .metric.failed {{ border-left: 4px solid #ef4444; }}
        .metric.time {{ border-left: 4px solid #3b82f6; }}
        .tests {{
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
        }}
        th {{
            background: #f9fafb;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #374151;
            border-bottom: 1px solid #e5e7eb;
        }}
        td {{
            padding: 12px;
            border-bottom: 1px solid #f3f4f6;
        }}
        tr:hover {{
            background: #f9fafb;
        }}
        .status {{
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.875em;
            font-weight: 500;
        }}
        .status.passed {{
            background: #d1fae5;
            color: #065f46;
        }}
        .status.failed {{
            background: #fee2e2;
            color: #991b1b;
        }}
        .progress-bar {{
            width: 100%;
            height: 30px;
            background: #e5e7eb;
            border-radius: 15px;
            overflow: hidden;
            margin: 20px 0;
        }}
        .progress-fill {{
            height: 100%;
            background: linear-gradient(90deg, #10b981 0%, #059669 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            transition: width 0.5s ease;
        }}
        .timestamp {{
            color: #6b7280;
            font-size: 0.875em;
            margin-top: 10px;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 {results.get('suite_name', 'Test Suite')} - Test Report</h1>
        <div class="timestamp">Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
    </div>
    
    <div class="progress-bar">
        <div class="progress-fill" style="width: {pass_rate}%">
            {pass_rate:.1f}% Passed
        </div>
    </div>
    
    <div class="summary">
        <div class="metric passed">
            <div class="value">{summary.get('passed', 0)}</div>
            <div class="label">Tests Passed</div>
        </div>
        <div class="metric failed">
            <div class="value">{summary.get('failed', 0)}</div>
            <div class="label">Tests Failed</div>
        </div>
        <div class="metric time">
            <div class="value">{summary.get('total_runtime', 0):.1f}s</div>
            <div class="label">Total Runtime</div>
        </div>
        <div class="metric">
            <div class="value">{summary.get('total_tests', 0)}</div>
            <div class="label">Total Tests</div>
        </div>
    </div>
    
    <div class="tests">
        <table>
            <thead>
                <tr>
                    <th>Test Name</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Runtime</th>
                    <th>Job ID</th>
                </tr>
            </thead>
            <tbody>
"""
        
        for test in tests:
            status = "passed" if test.get('exit_code') == 0 else "failed"
            runtime = test.get('runtime', 0)
            
            html_content += f"""
                <tr>
                    <td>{html.escape(test.get('name', 'Unknown'))}</td>
                    <td>{html.escape(test.get('type', 'unknown'))}</td>
                    <td><span class="status {status}">{status.upper()}</span></td>
                    <td>{runtime:.2f}s</td>
                    <td>{html.escape(test.get('job_id', 'N/A'))}</td>
                </tr>
"""
        
        html_content += """
            </tbody>
        </table>
    </div>
    
    <div class="timestamp" style="text-align: center; margin-top: 30px;">
        Report generated by GlobTim HPC Testing Infrastructure
    </div>
</body>
</html>
"""
        
        return html_content


class MarkdownReporter(ReportGenerator):
    """Generate Markdown reports"""
    
    def generate(self, results: Dict, output_path: str) -> None:
        """Generate Markdown report"""
        md_content = self._generate_markdown(results)
        
        with open(output_path, 'w') as f:
            f.write(md_content)
    
    def _generate_markdown(self, results: Dict) -> str:
        """Generate Markdown content"""
        summary = results.get('summary', {})
        tests = results.get('tests', [])
        
        # Calculate pass rate
        total = summary.get('total_tests', 0)
        passed = summary.get('passed', 0)
        pass_rate = (passed / total * 100) if total > 0 else 0
        
        md_content = f"""# GlobTim Test Report: {results.get('suite_name', 'Unknown')}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary

- **Total Tests**: {summary.get('total_tests', 0)}
- **Passed**: {summary.get('passed', 0)} ✅
- **Failed**: {summary.get('failed', 0)} ❌
- **Pass Rate**: {pass_rate:.1f}%
- **Total Runtime**: {summary.get('total_runtime', 0):.2f} seconds

"""
        
        # Add progress bar visualization
        bar_length = 50
        filled = int(bar_length * pass_rate / 100)
        bar = '█' * filled + '░' * (bar_length - filled)
        md_content += f"```\n[{bar}] {pass_rate:.1f}%\n```\n\n"
        
        # Results by type
        if summary.get('by_type'):
            md_content += "## Results by Type\n\n"
            md_content += "| Type | Passed | Failed | Total | Runtime |\n"
            md_content += "|------|--------|--------|-------|----------|\n"
            
            for test_type, stats in summary['by_type'].items():
                md_content += f"| {test_type} | {stats['passed']} | {stats['failed']} | {stats['count']} | {stats['runtime']:.2f}s |\n"
            
            md_content += "\n"
        
        # Detailed test results
        md_content += "## Test Results\n\n"
        md_content += "| Test Name | Type | Status | Runtime | Exit Code | Job ID |\n"
        md_content += "|-----------|------|--------|---------|-----------|--------|\n"
        
        for test in tests:
            status = "✅ Passed" if test.get('exit_code') == 0 else "❌ Failed"
            runtime = test.get('runtime', 0)
            exit_code = test.get('exit_code', 'N/A')
            
            md_content += f"| {test.get('name', 'Unknown')} | {test.get('type', 'unknown')} | {status} | {runtime:.2f}s | {exit_code} | {test.get('job_id', 'N/A')} |\n"
        
        # Failed tests details
        failed_tests = [t for t in tests if t.get('exit_code', -1) != 0]
        if failed_tests:
            md_content += "\n## Failed Tests Details\n\n"
            for test in failed_tests:
                md_content += f"### {test.get('name', 'Unknown')}\n\n"
                md_content += f"- **Job ID**: {test.get('job_id', 'N/A')}\n"
                md_content += f"- **Exit Code**: {test.get('exit_code', 'N/A')}\n"
                md_content += f"- **Runtime**: {test.get('runtime', 0):.2f}s\n"
                
                if test.get('validation'):
                    md_content += f"- **Validation**: {'Passed' if test['validation']['passed'] else 'Failed'}\n"
                    for check in test['validation'].get('checks', []):
                        symbol = "✅" if check['passed'] else "❌"
                        md_content += f"  - {check['name']}: {check['actual']} (expected: {check['expected']}) {symbol}\n"
                
                md_content += "\n"
        
        # Metrics if available
        if any(t.get('metrics') for t in tests):
            md_content += "## Performance Metrics\n\n"
            md_content += "| Test Name | Total Time | Allocations | Custom Metrics |\n"
            md_content += "|-----------|------------|-------------|----------------|\n"
            
            for test in tests:
                if test.get('metrics'):
                    metrics = test['metrics']
                    total_time = metrics.get('total_time', 'N/A')
                    allocations = metrics.get('allocations', 'N/A')
                    
                    # Other metrics
                    other_metrics = []
                    for k, v in metrics.items():
                        if k not in ['total_time', 'allocations']:
                            other_metrics.append(f"{k}: {v}")
                    other_str = ", ".join(other_metrics) if other_metrics else "N/A"
                    
                    md_content += f"| {test['name']} | {total_time} | {allocations} | {other_str} |\n"
        
        md_content += f"""

---

*Report generated by GlobTim HPC Testing Infrastructure*
*Suite: {results.get('suite_name', 'Unknown')}*
*Start: {results.get('start_time', 'Unknown')}*
*End: {results.get('end_time', 'Unknown')}*
"""
        
        return md_content


class JSONReporter(ReportGenerator):
    """Generate JSON reports with additional analysis"""
    
    def generate(self, results: Dict, output_path: str) -> None:
        """Generate enhanced JSON report"""
        enhanced_results = self._enhance_results(results)
        
        with open(output_path, 'w') as f:
            json.dump(enhanced_results, f, indent=2, default=str)
    
    def _enhance_results(self, results: Dict) -> Dict:
        """Add additional analysis to results"""
        enhanced = results.copy()
        
        # Add statistical analysis
        if results.get('tests'):
            runtimes = [t.get('runtime', 0) for t in results['tests'] if t.get('runtime')]
            
            if runtimes:
                enhanced['statistics'] = {
                    'mean_runtime': sum(runtimes) / len(runtimes),
                    'min_runtime': min(runtimes),
                    'max_runtime': max(runtimes),
                    'median_runtime': sorted(runtimes)[len(runtimes) // 2]
                }
        
        # Add performance indicators
        enhanced['performance'] = {
            'efficiency': enhanced['summary']['passed'] / enhanced['summary']['total_tests'] * 100
            if enhanced['summary']['total_tests'] > 0 else 0,
            'avg_test_time': enhanced['summary']['total_runtime'] / enhanced['summary']['total_tests']
            if enhanced['summary']['total_tests'] > 0 else 0
        }
        
        return enhanced