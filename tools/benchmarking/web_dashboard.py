#!/usr/bin/env python3

"""
Web-Based HPC Results Dashboard

Simple Flask web dashboard for visualizing HPC benchmark results.
"""

from flask import Flask, render_template_string, jsonify
import pandas as pd
import json
import plotly.express as px
import plotly.graph_objects as go
from plotly.utils import PlotlyJSONEncoder
import plotly

app = Flask(__name__)

# HTML template for the dashboard
DASHBOARD_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>🎯 HPC Benchmark Results Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                 color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { background: white; padding: 20px; border-radius: 10px; 
                   box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; }
        .plot-container { background: white; padding: 20px; border-radius: 10px; 
                         box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin: 20px 0; }
        .success { color: #28a745; }
        .failed { color: #dc3545; }
        .refresh-btn { background: #007bff; color: white; padding: 10px 20px; 
                      border: none; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎯 HPC Benchmark Results Dashboard</h1>
        <p>Real-time visualization of Globtim benchmark results</p>
        <button class="refresh-btn" onclick="location.reload()">🔄 Refresh Data</button>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <h3>Total Jobs</h3>
            <h2>{{ total_jobs }}</h2>
        </div>
        <div class="stat-box">
            <h3 class="success">Successful</h3>
            <h2 class="success">{{ successful_jobs }}</h2>
            <p>{{ success_rate }}%</p>
        </div>
        <div class="stat-box">
            <h3>Globtim Working</h3>
            <h2>{{ globtim_working }}</h2>
        </div>
        <div class="stat-box">
            <h3>Latest Job</h3>
            <h2>{{ latest_job }}</h2>
        </div>
    </div>
    
    <div class="plot-container">
        <h3>📊 Success Rate Overview</h3>
        <div id="success-plot"></div>
    </div>
    
    <div class="plot-container">
        <h3>🕒 Jobs Timeline</h3>
        <div id="timeline-plot"></div>
    </div>
    
    <div class="plot-container">
        <h3>🎯 4D Benchmark Results</h3>
        <div id="results-plot"></div>
    </div>
    
    <div class="plot-container">
        <h3>📋 Recent Job Details</h3>
        <div id="details-table"></div>
    </div>

    <script>
        // Plot success rate
        var successData = {{ success_plot | safe }};
        Plotly.newPlot('success-plot', successData.data, successData.layout);
        
        // Plot timeline
        var timelineData = {{ timeline_plot | safe }};
        Plotly.newPlot('timeline-plot', timelineData.data, timelineData.layout);
        
        // Plot 4D results
        var resultsData = {{ results_plot | safe }};
        Plotly.newPlot('results-plot', resultsData.data, resultsData.layout);
        
        // Show details table
        var detailsData = {{ details_table | safe }};
        Plotly.newPlot('details-table', detailsData.data, detailsData.layout);
    </script>
</body>
</html>
"""

def load_data():
    """Load HPC results data"""
    try:
        df = pd.read_csv('data/processed/benchmark_results.csv')
        with open('data/processed/collection_summary.json', 'r') as f:
            detailed = json.load(f)
        return df, detailed
    except FileNotFoundError:
        return pd.DataFrame(), {}

def create_success_plot(df):
    """Create success rate pie chart"""
    if len(df) == 0:
        return {"data": [], "layout": {"title": "No data available"}}
    
    success_counts = df['success'].value_counts()
    fig = px.pie(values=success_counts.values, 
                 names=['Failed', 'Success'] if False in success_counts.index else ['Success'],
                 color_discrete_map={'Success': '#28a745', 'Failed': '#dc3545'})
    fig.update_layout(height=400)
    return json.loads(json.dumps(fig, cls=PlotlyJSONEncoder))

def create_timeline_plot(df):
    """Create jobs timeline"""
    if len(df) == 0:
        return {"data": [], "layout": {"title": "No data available"}}
    
    df['collection_datetime'] = pd.to_datetime(df['collection_time'])
    
    fig = px.scatter(df, x='collection_datetime', y='job_id', 
                     color='success', 
                     color_discrete_map={True: '#28a745', False: '#dc3545'},
                     title="Job Execution Timeline")
    fig.update_layout(height=400)
    return json.loads(json.dumps(fig, cls=PlotlyJSONEncoder))

def create_results_plot(detailed):
    """Create 4D results visualization"""
    successful_jobs = []
    for job_id, job_data in detailed.items():
        parsed = job_data.get('parsed_results', {})
        if parsed.get('success', False) and '4d_best_value' in parsed:
            successful_jobs.append({
                'job_id': job_id,
                'best_value': parsed['4d_best_value'],
                'distance': parsed.get('4d_distance_to_origin', 0),
                'min_val': parsed.get('4d_min_value', 0),
                'max_val': parsed.get('4d_max_value', 0)
            })
    
    if not successful_jobs:
        return {"data": [], "layout": {"title": "No 4D results available"}}
    
    df_4d = pd.DataFrame(successful_jobs)
    fig = px.bar(df_4d, x='job_id', y='best_value', 
                 title="4D Benchmark Best Values",
                 hover_data=['distance', 'min_val', 'max_val'])
    fig.update_layout(height=400)
    return json.loads(json.dumps(fig, cls=PlotlyJSONEncoder))

def create_details_table(df, detailed):
    """Create details table"""
    if len(df) == 0:
        return {"data": [], "layout": {"title": "No data available"}}
    
    # Get recent successful jobs
    recent_jobs = df.sort_values('collection_time', ascending=False).head(5)
    
    table_data = []
    for _, job in recent_jobs.iterrows():
        job_details = detailed.get(job['job_id'], {}).get('parsed_results', {})
        table_data.append([
            job['job_id'],
            '✅' if job['success'] else '❌',
            job['function_name'],
            f"{job_details.get('4d_best_value', 'N/A'):.4f}" if job_details.get('4d_best_value') else 'N/A',
            f"{job_details.get('4d_distance_to_origin', 'N/A'):.4f}" if job_details.get('4d_distance_to_origin') else 'N/A'
        ])
    
    fig = go.Figure(data=[go.Table(
        header=dict(values=['Job ID', 'Status', 'Function', '4D Best Value', 'Distance'],
                   fill_color='lightblue'),
        cells=dict(values=list(zip(*table_data)) if table_data else [[], [], [], [], []],
                  fill_color='white'))
    ])
    fig.update_layout(height=300)
    return json.loads(json.dumps(fig, cls=PlotlyJSONEncoder))

@app.route('/')
def dashboard():
    """Main dashboard route"""
    df, detailed = load_data()
    
    # Calculate statistics
    total_jobs = len(df)
    successful_jobs = df['success'].sum() if len(df) > 0 else 0
    success_rate = (successful_jobs / total_jobs * 100) if total_jobs > 0 else 0
    globtim_working = df['globtim_working'].sum() if len(df) > 0 else 0
    latest_job = df['job_id'].iloc[-1] if len(df) > 0 else 'None'
    
    # Create plots
    success_plot = create_success_plot(df)
    timeline_plot = create_timeline_plot(df)
    results_plot = create_results_plot(detailed)
    details_table = create_details_table(df, detailed)
    
    return render_template_string(DASHBOARD_TEMPLATE,
                                total_jobs=total_jobs,
                                successful_jobs=successful_jobs,
                                success_rate=f"{success_rate:.1f}",
                                globtim_working=globtim_working,
                                latest_job=latest_job,
                                success_plot=success_plot,
                                timeline_plot=timeline_plot,
                                results_plot=results_plot,
                                details_table=details_table)

@app.route('/api/data')
def api_data():
    """API endpoint for raw data"""
    df, detailed = load_data()
    return jsonify({
        'total_jobs': len(df),
        'successful_jobs': int(df['success'].sum()) if len(df) > 0 else 0,
        'data': df.to_dict('records') if len(df) > 0 else []
    })

if __name__ == '__main__':
    print("🚀 Starting HPC Results Web Dashboard...")
    print("📊 Dashboard will be available at: http://localhost:5000")
    print("🔄 Refresh the page to update data after running new benchmarks")
    app.run(debug=True, host='0.0.0.0', port=5000)
