#!/usr/bin/env python3

"""
HPC Results Analysis System

Analyzes collected HPC benchmark results and generates reports.
"""

import json
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from typing import Dict, List
import numpy as np

class HPCResultAnalyzer:
    def __init__(self, data_root="./data"):
        self.data_root = Path(data_root)
        self.processed_dir = self.data_root / "processed"
        self.viz_dir = self.data_root / "visualizations"
        self.summary_file = self.processed_dir / "collection_summary.json"

        # Create visualization directory if it doesn't exist
        self.viz_dir.mkdir(parents=True, exist_ok=True)
        
    def load_results(self) -> Dict:
        """Load collected results from summary file"""
        if not self.summary_file.exists():
            raise FileNotFoundError(f"Results summary not found: {self.summary_file}")
        
        with open(self.summary_file, 'r') as f:
            return json.load(f)
    
    def create_results_dataframe(self, results: Dict) -> pd.DataFrame:
        """Convert results to pandas DataFrame for analysis"""
        rows = []
        
        for job_id, job_data in results.items():
            parsed = job_data.get('parsed_results', {})
            
            row = {
                'job_id': job_id,
                'collection_time': job_data.get('collection_time'),
                'success': parsed.get('success', False),
                'function_name': parsed.get('function_name', 'unknown'),
                'degree': parsed.get('degree'),
                'sample_count': parsed.get('sample_count'),
                'l2_error': parsed.get('l2_error'),
                'critical_points_count': parsed.get('critical_points_count'),
                'minimizers_count': parsed.get('minimizers_count'),
                'min_distance_to_global': parsed.get('min_distance_to_global'),
                'mean_distance_to_global': parsed.get('mean_distance_to_global'),
                'convergence_rate': parsed.get('convergence_rate'),
                'construction_time': parsed.get('construction_time'),
                'globtim_working': parsed.get('globtim_working', False),
                'parameters_jl_system': parsed.get('parameters_jl_system', False)
            }
            rows.append(row)
        
        return pd.DataFrame(rows)
    
    def generate_summary_report(self, df: pd.DataFrame) -> str:
        """Generate text summary report"""
        report = []
        report.append("🎯 HPC BENCHMARK RESULTS ANALYSIS")
        report.append("=" * 50)
        report.append(f"Analysis Date: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Overall statistics
        total_jobs = len(df)
        successful_jobs = df['success'].sum()
        globtim_working = df['globtim_working'].sum()
        
        report.append("📊 OVERALL STATISTICS")
        report.append("-" * 30)
        report.append(f"Total Jobs: {total_jobs}")
        report.append(f"Successful Jobs: {successful_jobs} ({successful_jobs/total_jobs*100:.1f}%)")
        report.append(f"Globtim Working: {globtim_working} ({globtim_working/total_jobs*100:.1f}%)")
        report.append("")
        
        # Function analysis
        if 'function_name' in df.columns:
            functions = df['function_name'].value_counts()
            report.append("🎯 FUNCTIONS TESTED")
            report.append("-" * 30)
            for func, count in functions.items():
                report.append(f"{func}: {count} jobs")
            report.append("")
        
        # Performance metrics for successful jobs
        successful_df = df[df['success'] == True]
        if len(successful_df) > 0:
            report.append("⚡ PERFORMANCE METRICS (Successful Jobs)")
            report.append("-" * 30)
            
            numeric_cols = ['l2_error', 'min_distance_to_global', 'construction_time', 'convergence_rate']
            for col in numeric_cols:
                if col in successful_df.columns and successful_df[col].notna().any():
                    values = successful_df[col].dropna()
                    report.append(f"{col}:")
                    report.append(f"  Mean: {values.mean():.2e}")
                    report.append(f"  Std:  {values.std():.2e}")
                    report.append(f"  Min:  {values.min():.2e}")
                    report.append(f"  Max:  {values.max():.2e}")
                    report.append("")
        
        # Recent jobs
        if 'collection_time' in df.columns:
            recent_df = df.sort_values('collection_time', ascending=False).head(5)
            report.append("🕒 RECENT JOBS")
            report.append("-" * 30)
            for _, row in recent_df.iterrows():
                status = "✅" if row['success'] else "❌"
                report.append(f"{status} Job {row['job_id']}: {row['function_name']} "
                            f"(collected: {row['collection_time'][:19]})")
            report.append("")
        
        return "\n".join(report)
    
    def create_performance_plots(self, df: pd.DataFrame):
        """Create performance visualization plots"""
        successful_df = df[df['success'] == True]
        
        if len(successful_df) == 0:
            print("⚠️  No successful jobs to plot")
            return
        
        fig, axes = plt.subplots(2, 2, figsize=(12, 10))
        fig.suptitle('HPC Benchmark Performance Analysis', fontsize=16)
        
        # Plot 1: L2 Error distribution
        if 'l2_error' in successful_df.columns and successful_df['l2_error'].notna().any():
            l2_errors = successful_df['l2_error'].dropna()
            axes[0, 0].hist(np.log10(l2_errors), bins=10, alpha=0.7, color='blue')
            axes[0, 0].set_xlabel('Log10(L2 Error)')
            axes[0, 0].set_ylabel('Frequency')
            axes[0, 0].set_title('L2 Error Distribution')
        
        # Plot 2: Distance to Global Minimum
        if 'min_distance_to_global' in successful_df.columns and successful_df['min_distance_to_global'].notna().any():
            distances = successful_df['min_distance_to_global'].dropna()
            axes[0, 1].hist(np.log10(distances), bins=10, alpha=0.7, color='green')
            axes[0, 1].set_xlabel('Log10(Min Distance to Global)')
            axes[0, 1].set_ylabel('Frequency')
            axes[0, 1].set_title('Distance to Global Minimum')
        
        # Plot 3: Construction Time
        if 'construction_time' in successful_df.columns and successful_df['construction_time'].notna().any():
            times = successful_df['construction_time'].dropna()
            axes[1, 0].hist(times, bins=10, alpha=0.7, color='orange')
            axes[1, 0].set_xlabel('Construction Time (s)')
            axes[1, 0].set_ylabel('Frequency')
            axes[1, 0].set_title('Globtim Construction Time')
        
        # Plot 4: Success Rate by Function
        if 'function_name' in df.columns:
            success_by_func = df.groupby('function_name')['success'].agg(['count', 'sum'])
            success_by_func['rate'] = success_by_func['sum'] / success_by_func['count']
            
            axes[1, 1].bar(success_by_func.index, success_by_func['rate'], alpha=0.7, color='red')
            axes[1, 1].set_xlabel('Function')
            axes[1, 1].set_ylabel('Success Rate')
            axes[1, 1].set_title('Success Rate by Function')
            axes[1, 1].tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        
        # Save plot to visualizations directory
        plot_file = self.viz_dir / "performance_analysis.png"
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        print(f"📊 Performance plots saved to: {plot_file}")
        
        return fig
    
    def export_results_csv(self, df: pd.DataFrame):
        """Export results to CSV for further analysis"""
        csv_file = self.processed_dir / "benchmark_results.csv"
        df.to_csv(csv_file, index=False)
        print(f"📄 Results exported to CSV: {csv_file}")
    
    def analyze_all(self):
        """Run complete analysis pipeline"""
        print("🔍 Starting HPC results analysis...")
        
        # Load results
        results = self.load_results()
        print(f"✅ Loaded results for {len(results)} jobs")
        
        # Create DataFrame
        df = self.create_results_dataframe(results)
        print(f"✅ Created analysis DataFrame with {len(df)} rows")
        
        # Generate summary report
        report = self.generate_summary_report(df)
        
        # Save report to processed directory
        report_file = self.processed_dir / "analysis_report.txt"
        with open(report_file, 'w') as f:
            f.write(report)
        
        print(f"📋 Analysis report saved to: {report_file}")
        print("\n" + report)
        
        # Create plots
        try:
            self.create_performance_plots(df)
        except Exception as e:
            print(f"⚠️  Error creating plots: {e}")
        
        # Export CSV
        self.export_results_csv(df)
        
        return df, report

if __name__ == "__main__":
    analyzer = HPCResultAnalyzer()
    df, report = analyzer.analyze_all()
