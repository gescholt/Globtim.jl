#!/usr/bin/env python3

"""
Quick HPC Results Visualization

Simple command-line tool to quickly visualize HPC benchmark results.
"""

import pandas as pd
import matplotlib.pyplot as plt
import json
import numpy as np
from pathlib import Path
import sys

def load_data():
    """Load HPC results data"""
    try:
        df = pd.read_csv('data/processed/benchmark_results.csv')
        with open('data/processed/collection_summary.json', 'r') as f:
            detailed = json.load(f)
        return df, detailed
    except FileNotFoundError as e:
        print(f"❌ Data files not found: {e}")
        print("💡 Run 'python3 collect_hpc_results.py' first")
        sys.exit(1)

def print_summary(df, detailed):
    """Print text summary of results"""
    print("🎯 HPC BENCHMARK RESULTS SUMMARY")
    print("=" * 50)
    
    total_jobs = len(df)
    successful_jobs = df['success'].sum()
    globtim_working = df['globtim_working'].sum()
    
    print(f"📊 Total Jobs: {total_jobs}")
    print(f"✅ Successful: {successful_jobs} ({successful_jobs/total_jobs*100:.1f}%)")
    print(f"🔧 Globtim Working: {globtim_working} ({globtim_working/total_jobs*100:.1f}%)")
    print()
    
    # Show successful job details
    successful_df = df[df['success'] == True]
    if len(successful_df) > 0:
        print("🎯 SUCCESSFUL JOBS:")
        print("-" * 30)
        for _, job in successful_df.iterrows():
            job_details = detailed.get(job['job_id'], {}).get('parsed_results', {})
            print(f"Job {job['job_id']}: {job['function_name']}")
            
            # Show 4D results if available
            if '4d_best_value' in job_details:
                print(f"  🎯 4D Results:")
                print(f"    Best value: {job_details['4d_best_value']:.4f}")
                print(f"    Distance to origin: {job_details.get('4d_distance_to_origin', 'N/A'):.4f}")
                print(f"    Value range: [{job_details.get('4d_min_value', 'N/A'):.4f}, {job_details.get('4d_max_value', 'N/A'):.4f}]")
            
            # Show simple results if available
            if 'simple_min_value' in job_details:
                print(f"  📊 Simple Results:")
                print(f"    Value range: [{job_details['simple_min_value']:.4f}, {job_details['simple_max_value']:.4f}]")
                print(f"    Mean: {job_details['simple_mean_value']:.4f}")
            print()
    else:
        print("⚠️  No successful jobs found")

def create_quick_plots(df, detailed):
    """Create quick visualization plots"""
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle('🎯 HPC Benchmark Results - Quick View', fontsize=16)
    
    # Plot 1: Success rate pie chart
    success_counts = df['success'].value_counts()
    colors = ['#ff6b6b', '#51cf66']
    axes[0, 0].pie(success_counts.values, labels=['Failed', 'Success'], 
                   autopct='%1.1f%%', colors=colors)
    axes[0, 0].set_title('Overall Success Rate')
    
    # Plot 2: Jobs over time
    df['collection_datetime'] = pd.to_datetime(df['collection_time'])
    df_sorted = df.sort_values('collection_datetime')
    
    success_jobs = df_sorted[df_sorted['success'] == True]
    failed_jobs = df_sorted[df_sorted['success'] == False]
    
    if len(success_jobs) > 0:
        axes[0, 1].scatter(success_jobs['collection_datetime'], 
                          success_jobs['job_id'], c='green', label='Success', s=50)
    if len(failed_jobs) > 0:
        axes[0, 1].scatter(failed_jobs['collection_datetime'], 
                          failed_jobs['job_id'], c='red', label='Failed', s=50)
    
    axes[0, 1].set_title('Jobs Timeline')
    axes[0, 1].set_xlabel('Collection Time')
    axes[0, 1].set_ylabel('Job ID')
    axes[0, 1].legend()
    axes[0, 1].tick_params(axis='x', rotation=45)
    
    # Plot 3: 4D Results (if available)
    successful_4d_jobs = []
    for job_id, job_data in detailed.items():
        parsed = job_data.get('parsed_results', {})
        if parsed.get('success', False) and '4d_best_value' in parsed:
            successful_4d_jobs.append({
                'job_id': job_id,
                'best_value': parsed['4d_best_value'],
                'distance': parsed.get('4d_distance_to_origin', 0),
                'min_val': parsed.get('4d_min_value', 0),
                'max_val': parsed.get('4d_max_value', 0)
            })
    
    if successful_4d_jobs:
        job_ids = [job['job_id'] for job in successful_4d_jobs]
        best_values = [job['best_value'] for job in successful_4d_jobs]
        distances = [job['distance'] for job in successful_4d_jobs]
        
        axes[1, 0].bar(job_ids, best_values, alpha=0.7, color='blue')
        axes[1, 0].set_title('4D Best Values')
        axes[1, 0].set_xlabel('Job ID')
        axes[1, 0].set_ylabel('Best Value')
        
        axes[1, 1].bar(job_ids, distances, alpha=0.7, color='orange')
        axes[1, 1].set_title('4D Distance to Origin')
        axes[1, 1].set_xlabel('Job ID')
        axes[1, 1].set_ylabel('Distance')
    else:
        axes[1, 0].text(0.5, 0.5, 'No 4D Results\nAvailable', 
                       ha='center', va='center', transform=axes[1, 0].transAxes)
        axes[1, 0].set_title('4D Results')
        
        axes[1, 1].text(0.5, 0.5, 'No Distance Data\nAvailable', 
                       ha='center', va='center', transform=axes[1, 1].transAxes)
        axes[1, 1].set_title('Distance Analysis')
    
    plt.tight_layout()
    
    # Save plot to visualizations directory
    Path('data/visualizations').mkdir(parents=True, exist_ok=True)
    output_file = 'data/visualizations/quick_visualization.png'
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"📊 Quick visualization saved to: {output_file}")
    
    return fig

def main():
    """Main visualization function"""
    print("🚀 Quick HPC Results Visualization")
    print("=" * 40)
    
    # Load data
    df, detailed = load_data()
    print(f"✅ Loaded data for {len(df)} jobs")
    print()
    
    # Print summary
    print_summary(df, detailed)
    
    # Create plots
    fig = create_quick_plots(df, detailed)
    
    # Show plot
    plt.show()
    
    print("\n🎯 Visualization Options:")
    print("1. 📊 View: data/visualizations/quick_visualization.png")
    print("2. 📋 Data: data/processed/benchmark_results.csv")
    print("3. 📄 Report: data/processed/analysis_report.txt")
    print("4. 🔬 Interactive: jupyter notebook visualize_hpc_results.ipynb")

if __name__ == "__main__":
    main()
