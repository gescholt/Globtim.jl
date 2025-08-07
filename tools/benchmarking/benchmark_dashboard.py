#!/usr/bin/env python3

"""
Benchmark Dashboard and Sorting Infrastructure

Comprehensive pass/fail testing environment with statistical tracking,
parameter exploration, and automated sorting of benchmark results.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

class BenchmarkDashboard:
    def __init__(self, data_root="./data"):
        self.data_root = Path(data_root)
        self.benchmark_dir = self.data_root / "benchmarks"
        self.passed_dir = self.benchmark_dir / "passed"
        self.failed_dir = self.benchmark_dir / "failed"
        self.analysis_dir = self.benchmark_dir / "analysis"
        
        # Create directories
        for directory in [self.benchmark_dir, self.passed_dir, self.failed_dir, self.analysis_dir]:
            directory.mkdir(parents=True, exist_ok=True)
    
    def load_benchmark_results(self) -> pd.DataFrame:
        """Load all benchmark results from JSON files"""
        results = []
        
        # Load from both passed and failed directories
        for result_dir in [self.passed_dir, self.failed_dir]:
            for json_file in result_dir.glob("*.json"):
                try:
                    with open(json_file, 'r') as f:
                        result = json.load(f)
                        results.append(result)
                except Exception as e:
                    print(f"Warning: Could not load {json_file}: {e}")
        
        if not results:
            print("No benchmark results found")
            return pd.DataFrame()
        
        # Convert to DataFrame
        df = pd.DataFrame(results)
        
        # Add derived columns
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        return df
    
    def sort_results(self, results: List[Dict]) -> Tuple[List[Dict], List[Dict]]:
        """Sort benchmark results into passed and failed categories"""
        passed = []
        failed = []
        
        for result in results:
            if result.get('overall_status') == 'PASS':
                passed.append(result)
            else:
                failed.append(result)
        
        return passed, failed
    
    def save_sorted_results(self, results: List[Dict]):
        """Save results to appropriate directories based on pass/fail status"""
        passed, failed = self.sort_results(results)
        
        # Save passed results
        for i, result in enumerate(passed):
            filename = f"passed_{result.get('function_name', 'unknown')}_{result.get('test_id', i)}.json"
            filepath = self.passed_dir / filename
            with open(filepath, 'w') as f:
                json.dump(result, f, indent=2)
        
        # Save failed results
        for i, result in enumerate(failed):
            filename = f"failed_{result.get('function_name', 'unknown')}_{result.get('test_id', i)}.json"
            filepath = self.failed_dir / filename
            with open(filepath, 'w') as f:
                json.dump(result, f, indent=2)
        
        print(f"✅ Sorted and saved {len(passed)} passed and {len(failed)} failed results")
    
    def generate_summary_statistics(self, df: pd.DataFrame) -> Dict:
        """Generate comprehensive summary statistics"""
        if df.empty:
            return {"error": "No data available"}
        
        stats = {
            "total_tests": len(df),
            "passed_tests": len(df[df['overall_status'] == 'PASS']),
            "failed_tests": len(df[df['overall_status'] == 'FAIL']),
            "success_rate": len(df[df['overall_status'] == 'PASS']) / len(df) * 100,
            "functions_tested": df['function_name'].nunique(),
            "parameter_sets_tested": df['parameter_set_name'].nunique(),
            "avg_quality_score": df['quality_score'].mean(),
            "avg_construction_time": df['construction_time'].mean(),
            "avg_l2_error": df['l2_error_achieved'].mean()
        }
        
        # Function-specific statistics
        function_stats = {}
        for func_name in df['function_name'].unique():
            func_df = df[df['function_name'] == func_name]
            function_stats[func_name] = {
                "total_tests": len(func_df),
                "success_rate": len(func_df[func_df['overall_status'] == 'PASS']) / len(func_df) * 100,
                "avg_quality_score": func_df['quality_score'].mean(),
                "best_distance_to_global": func_df['distances_to_known_global_minima'].apply(
                    lambda x: min(x) if isinstance(x, list) and x else float('inf')
                ).min()
            }
        
        stats["by_function"] = function_stats
        
        # Parameter sensitivity analysis
        if 'domain_size' in df.columns:
            stats["parameter_sensitivity"] = {
                "domain_size_correlation": df[['domain_size', 'quality_score']].corr().iloc[0, 1],
                "degree_correlation": df[['degree', 'quality_score']].corr().iloc[0, 1],
                "sample_count_correlation": df[['sample_count', 'quality_score']].corr().iloc[0, 1]
            }
        
        return stats
    
    def create_comprehensive_dashboard(self, df: pd.DataFrame):
        """Create comprehensive interactive dashboard"""
        if df.empty:
            print("No data available for dashboard")
            return
        
        # Create subplots
        fig = make_subplots(
            rows=3, cols=2,
            subplot_titles=(
                'Success Rate by Function',
                'Quality Score Distribution',
                'Parameter vs Performance',
                'Distance to Global Minimum',
                'Construction Time Analysis',
                'Failure Reasons'
            ),
            specs=[[{"type": "bar"}, {"type": "histogram"}],
                   [{"type": "scatter"}, {"type": "box"}],
                   [{"type": "scatter"}, {"type": "bar"}]]
        )
        
        # 1. Success rate by function
        success_by_func = df.groupby('function_name')['overall_status'].apply(
            lambda x: (x == 'PASS').sum() / len(x) * 100
        ).reset_index()
        success_by_func.columns = ['function_name', 'success_rate']
        
        fig.add_trace(
            go.Bar(x=success_by_func['function_name'], y=success_by_func['success_rate'],
                   name='Success Rate', marker_color='green'),
            row=1, col=1
        )
        
        # 2. Quality score distribution
        fig.add_trace(
            go.Histogram(x=df['quality_score'], name='Quality Score', 
                        marker_color='blue', opacity=0.7),
            row=1, col=2
        )
        
        # 3. Parameter vs Performance (Domain size vs Quality)
        fig.add_trace(
            go.Scatter(x=df['domain_size'], y=df['quality_score'],
                      mode='markers', name='Domain Size vs Quality',
                      marker=dict(color=df['overall_status'].map({'PASS': 'green', 'FAIL': 'red'})),
                      text=df['function_name']),
            row=2, col=1
        )
        
        # 4. Distance to global minimum (box plot by function)
        for func_name in df['function_name'].unique():
            func_df = df[df['function_name'] == func_name]
            distances = []
            for dist_list in func_df['distances_to_known_global_minima']:
                if isinstance(dist_list, list) and dist_list:
                    distances.extend(dist_list)
            
            if distances:
                fig.add_trace(
                    go.Box(y=distances, name=func_name, boxpoints='outliers'),
                    row=2, col=2
                )
        
        # 5. Construction time vs sample count
        fig.add_trace(
            go.Scatter(x=df['sample_count'], y=df['construction_time'],
                      mode='markers', name='Sample Count vs Time',
                      marker=dict(color=df['quality_score'], colorscale='viridis'),
                      text=df['function_name']),
            row=3, col=1
        )
        
        # 6. Failure reasons (if any failed tests)
        failed_df = df[df['overall_status'] == 'FAIL']
        if not failed_df.empty:
            failure_counts = {}
            for reasons in failed_df['failure_reasons']:
                if isinstance(reasons, list):
                    for reason in reasons:
                        failure_counts[reason] = failure_counts.get(reason, 0) + 1
            
            if failure_counts:
                fig.add_trace(
                    go.Bar(x=list(failure_counts.keys()), y=list(failure_counts.values()),
                           name='Failure Reasons', marker_color='red'),
                    row=3, col=2
                )
        
        # Update layout
        fig.update_layout(
            height=1200,
            title_text="🎯 Comprehensive Benchmark Dashboard",
            showlegend=False
        )
        
        # Save dashboard
        dashboard_file = self.analysis_dir / "comprehensive_dashboard.html"
        fig.write_html(str(dashboard_file))
        print(f"📊 Dashboard saved to: {dashboard_file}")
        
        return fig
    
    def analyze_parameter_effectiveness(self, df: pd.DataFrame) -> Dict:
        """Analyze which parameter combinations work best"""
        if df.empty:
            return {}
        
        analysis = {}
        
        # Group by parameter combinations
        param_cols = ['function_name', 'domain_size', 'degree', 'sample_count']
        available_cols = [col for col in param_cols if col in df.columns]
        
        if len(available_cols) >= 2:
            grouped = df.groupby(available_cols).agg({
                'overall_status': lambda x: (x == 'PASS').sum() / len(x),
                'quality_score': 'mean',
                'construction_time': 'mean',
                'l2_error_achieved': 'mean'
            }).reset_index()
            
            grouped.columns = available_cols + ['success_rate', 'avg_quality', 'avg_time', 'avg_l2_error']
            
            # Find best parameter combinations
            best_params = grouped.nlargest(10, 'success_rate')
            analysis['best_parameter_combinations'] = best_params.to_dict('records')
            
            # Find worst parameter combinations
            worst_params = grouped.nsmallest(10, 'success_rate')
            analysis['worst_parameter_combinations'] = worst_params.to_dict('records')
        
        return analysis
    
    def generate_recommendations(self, df: pd.DataFrame) -> List[str]:
        """Generate recommendations based on benchmark results"""
        recommendations = []
        
        if df.empty:
            return ["No data available for recommendations"]
        
        # Success rate analysis
        overall_success_rate = (df['overall_status'] == 'PASS').sum() / len(df) * 100
        
        if overall_success_rate < 50:
            recommendations.append(f"⚠️  Low overall success rate ({overall_success_rate:.1f}%). Consider adjusting default parameters.")
        
        # Function-specific recommendations
        for func_name in df['function_name'].unique():
            func_df = df[df['function_name'] == func_name]
            func_success_rate = (func_df['overall_status'] == 'PASS').sum() / len(func_df) * 100
            
            if func_success_rate < 30:
                recommendations.append(f"🔧 {func_name}: Very low success rate ({func_success_rate:.1f}%). This function may need specialized parameters.")
            elif func_success_rate > 90:
                recommendations.append(f"✅ {func_name}: Excellent success rate ({func_success_rate:.1f}%). Current parameters work well.")
        
        # Parameter recommendations
        if 'domain_size' in df.columns:
            passed_df = df[df['overall_status'] == 'PASS']
            if not passed_df.empty:
                optimal_domain = passed_df['domain_size'].median()
                recommendations.append(f"📏 Optimal domain size appears to be around {optimal_domain:.2f}")
        
        return recommendations
    
    def run_comprehensive_analysis(self):
        """Run complete benchmark analysis pipeline"""
        print("🎯 COMPREHENSIVE BENCHMARK ANALYSIS")
        print("=" * 50)
        
        # Load data
        df = self.load_benchmark_results()
        if df.empty:
            print("❌ No benchmark data found")
            return
        
        print(f"✅ Loaded {len(df)} benchmark results")
        
        # Generate statistics
        stats = self.generate_summary_statistics(df)
        
        # Save statistics
        stats_file = self.analysis_dir / "summary_statistics.json"
        with open(stats_file, 'w') as f:
            json.dump(stats, f, indent=2, default=str)
        
        print(f"📊 Summary Statistics:")
        print(f"   Total Tests: {stats['total_tests']}")
        print(f"   Success Rate: {stats['success_rate']:.1f}%")
        print(f"   Functions Tested: {stats['functions_tested']}")
        print(f"   Avg Quality Score: {stats['avg_quality_score']:.3f}")
        
        # Create dashboard
        self.create_comprehensive_dashboard(df)
        
        # Parameter effectiveness analysis
        param_analysis = self.analyze_parameter_effectiveness(df)
        if param_analysis:
            param_file = self.analysis_dir / "parameter_analysis.json"
            with open(param_file, 'w') as f:
                json.dump(param_analysis, f, indent=2, default=str)
        
        # Generate recommendations
        recommendations = self.generate_recommendations(df)
        
        print(f"\n🎯 RECOMMENDATIONS:")
        for rec in recommendations:
            print(f"   {rec}")
        
        # Save recommendations
        rec_file = self.analysis_dir / "recommendations.txt"
        with open(rec_file, 'w') as f:
            f.write("Benchmark Analysis Recommendations\n")
            f.write("=" * 40 + "\n\n")
            for rec in recommendations:
                f.write(f"{rec}\n")
        
        print(f"\n✅ Analysis complete. Results saved to: {self.analysis_dir}")

if __name__ == "__main__":
    dashboard = BenchmarkDashboard()
    dashboard.run_comprehensive_analysis()
