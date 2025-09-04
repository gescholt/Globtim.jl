#!/bin/bash
# HPC Performance Regression Detection System
# ==========================================
#
# Advanced performance monitoring and regression detection system for
# GlobTim polynomial approximation experiments. Tracks performance
# metrics across experiment runs to detect regressions and optimizations.
#
# Features:
# - Experiment performance baseline establishment
# - Regression detection across similar experiment configurations
# - Performance trend analysis and reporting
# - Memory usage pattern analysis
# - Execution time tracking and comparison
# - Integration with HPC Resource Monitor Hook system
#
# Performance Metrics Tracked:
# - Execution time by experiment type and configuration
# - Memory usage patterns (peak, average, variance)
# - CPU utilization efficiency
# - Convergence rates and iteration counts
# - Error rates and success/failure ratios
#
# Usage:
#   tools/hpc/monitoring/performance_tracker.sh --baseline experiment_type degree dimension
#   tools/hpc/monitoring/performance_tracker.sh --track session_name
#   tools/hpc/monitoring/performance_tracker.sh --detect-regression
#   tools/hpc/monitoring/performance_tracker.sh --report --format json
#
# Author: Claude Code HPC monitoring system
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
RESOURCE_HOOK="$HOME/.claude/hooks/hpc-resource-monitor.sh"
PERFORMANCE_DB_DIR="$PROJECT_ROOT/hpc/performance_data"
BASELINE_DB="$PERFORMANCE_DB_DIR/baselines.jsonl"
METRICS_DB="$PERFORMANCE_DB_DIR/metrics.jsonl"
REGRESSION_REPORT="$PERFORMANCE_DB_DIR/regression_report.json"

# Performance thresholds
REGRESSION_TIME_THRESHOLD=1.5      # 50% increase in execution time
REGRESSION_MEMORY_THRESHOLD=1.3    # 30% increase in memory usage
REGRESSION_ERROR_THRESHOLD=2.0     # 100% increase in error rate
MIN_BASELINE_RUNS=3                 # Minimum runs needed for baseline

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

function log_performance_event() {
    local level="$1"
    local message="$2"
    local metric_type="${3:-general}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$PERFORMANCE_DB_DIR"
    
    local log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "metric_type": "$metric_type",
  "message": "$message"
}
EOF
)
    
    echo "$log_entry" >> "$PERFORMANCE_DB_DIR/performance_tracker.jsonl"
    
    # Console output
    local color="$NC"
    case "$level" in
        "ERROR") color="$RED" ;;
        "WARNING") color="$YELLOW" ;;
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "REGRESSION") color="$MAGENTA" ;;
    esac
    
    echo -e "${color}[$timestamp] [$level]${NC} $message"
}

function usage() {
    cat <<EOF
HPC Performance Regression Detection System
==========================================

Advanced performance monitoring and regression detection for GlobTim experiments.

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  --baseline TYPE DEGREE DIM   Establish baseline for experiment type
  --track SESSION_NAME         Track performance of running experiment
  --analyze-session SESSION    Analyze completed experiment session
  --detect-regression [TYPE]   Detect performance regressions
  --report                     Generate performance analysis report
  --compare SESSION1 SESSION2  Compare two experiment sessions
  --trends [DAYS]             Show performance trends over time
  --reset-baselines           Reset all baseline measurements

Options:
  --format FORMAT             Output format: json, text, csv (default: text)
  --threshold-time FACTOR     Time regression threshold (default: $REGRESSION_TIME_THRESHOLD)
  --threshold-memory FACTOR   Memory regression threshold (default: $REGRESSION_MEMORY_THRESHOLD)
  --threshold-error FACTOR    Error regression threshold (default: $REGRESSION_ERROR_THRESHOLD)
  --min-baseline-runs N       Minimum runs for baseline (default: $MIN_BASELINE_RUNS)
  --days N                    Days of history to analyze (default: 30)
  --help                     Show this help

Performance Metrics:
  - Execution time (total, per-iteration)
  - Memory usage (peak, average, efficiency)
  - CPU utilization and load patterns  
  - Convergence rates and iteration counts
  - Success/failure rates and error patterns
  - Resource efficiency ratios

Experiment Types:
  - parameter_estimation (Lotka-Volterra, etc.)
  - polynomial_approximation (various degrees/dimensions)
  - homotopy_continuation (polynomial system solving)
  - optimization (gradient descent, etc.)

Examples:
  # Establish baseline for 4D degree 12 parameter estimation
  $0 --baseline parameter_estimation 12 4

  # Track currently running experiment
  $0 --track globtim_4d_20250904_143022

  # Detect all regressions
  $0 --detect-regression

  # Generate comprehensive report
  $0 --report --format json

  # Compare two experiment sessions
  $0 --compare session1 session2

  # Show trends over last 7 days
  $0 --trends 7

Integration:
  - Uses HPC Resource Monitor Hook for real-time metrics
  - Integrates with tmux session monitoring
  - Coordinates with experiment result analysis

Files:
  Baseline DB: $BASELINE_DB
  Metrics DB: $METRICS_DB
  Reports: $PERFORMANCE_DB_DIR/reports/

EOF
}

function extract_experiment_config() {
    local session_name="$1"
    
    # Extract experiment configuration from session name
    # Format: globtim_type_YYYYMMDD_HHMMSS or custom patterns
    
    local config="{}"
    
    if command -v python3 >/dev/null 2>&1; then
        config=$(python3 -c "
import re, json
session = '$session_name'

# Default values
experiment_type = 'unknown'
degree = 0
dimension = 0
date_str = ''
time_str = ''

# Extract experiment type
if '_4d_' in session:
    experiment_type = 'parameter_estimation'
    dimension = 4
elif '_3d_' in session:
    experiment_type = 'parameter_estimation' 
    dimension = 3
elif 'polynomial' in session:
    experiment_type = 'polynomial_approximation'
elif 'homotopy' in session:
    experiment_type = 'homotopy_continuation'
elif 'optimization' in session:
    experiment_type = 'optimization'

# Extract date/time if present
date_match = re.search(r'(\d{8})_(\d{6})', session)
if date_match:
    date_str = date_match.group(1)
    time_str = date_match.group(2)

# Try to extract degree from session name or logs
degree_match = re.search(r'deg(\d+)|degree[\s_]*(\d+)|d(\d+)', session.lower())
if degree_match:
    degree = int([g for g in degree_match.groups() if g][0])

# Try to extract dimension if not already set
if dimension == 0:
    dim_match = re.search(r'(\d+)d', session.lower())
    if dim_match:
        dimension = int(dim_match.group(1))

config = {
    'session_name': session,
    'experiment_type': experiment_type,
    'degree': degree,
    'dimension': dimension,
    'date_str': date_str,
    'time_str': time_str,
    'config_key': f'{experiment_type}_{degree}_{dimension}'
}

print(json.dumps(config, indent=2))
")
    else
        # Fallback bash parsing
        local experiment_type="unknown"
        local degree=0
        local dimension=0
        
        if [[ "$session_name" == *"4d"* ]]; then
            dimension=4
            experiment_type="parameter_estimation"
        fi
        
        config="{\"session_name\":\"$session_name\",\"experiment_type\":\"$experiment_type\",\"degree\":$degree,\"dimension\":$dimension}"
    fi
    
    echo "$config"
}

function collect_session_metrics() {
    local session_name="$1"
    
    log_performance_event "INFO" "Collecting performance metrics for session: $session_name" "collection"
    
    # Get experiment configuration
    local config
    config=$(extract_experiment_config "$session_name")
    
    # Initialize metrics structure
    local metrics_json="{}"
    
    if command -v python3 >/dev/null 2>&1; then
        metrics_json=$(python3 -c "
import json, os, time, re
from datetime import datetime

session_name = '$session_name'
globtim_dir = '$GLOBTIM_DIR'
config = json.loads('''$config''')

# Initialize metrics
metrics = {
    'session_name': session_name,
    'timestamp': datetime.now().isoformat(),
    'config': config,
    'execution_metrics': {},
    'memory_metrics': {},
    'cpu_metrics': {},
    'convergence_metrics': {},
    'error_metrics': {},
    'resource_efficiency': {}
}

# Look for experiment output directory
output_dirs = [
    f'{globtim_dir}/hpc_results/{session_name}',
    f'{globtim_dir}/node_experiments/outputs/{session_name}',
    f'{globtim_dir}/node_experiments/outputs/globtim_{session_name}'
]

output_dir = None
for dir_path in output_dirs:
    if os.path.exists(dir_path):
        output_dir = dir_path
        break

if not output_dir:
    metrics['status'] = 'no_output_directory'
    print(json.dumps(metrics, indent=2))
    exit()

# Get directory statistics
try:
    dir_stat = os.stat(output_dir)
    dir_size = sum(os.path.getsize(os.path.join(dirpath, filename))
                   for dirpath, dirnames, filenames in os.walk(output_dir)
                   for filename in filenames)
    
    metrics['output_directory'] = {
        'path': output_dir,
        'size_bytes': dir_size,
        'created': dir_stat.st_ctime,
        'modified': dir_stat.st_mtime
    }
except:
    pass

# Analyze log files for performance data
log_files = []
for ext in ['*.log', '*.out', '*.err']:
    import glob
    log_files.extend(glob.glob(f'{output_dir}/{ext}'))

execution_start_time = None
execution_end_time = None
peak_memory = 0
iteration_count = 0
error_count = 0
convergence_rate = 0.0

for log_file in log_files:
    try:
        with open(log_file, 'r') as f:
            content = f.read()
            
            # Extract execution times
            start_match = re.search(r'(?:start|begin).*?(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', content, re.IGNORECASE)
            if start_match:
                execution_start_time = start_match.group(1)
                
            end_match = re.search(r'(?:end|complete|finish).*?(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', content, re.IGNORECASE)
            if end_match:
                execution_end_time = end_match.group(1)
            
            # Extract memory usage
            memory_matches = re.findall(r'(\d+\.?\d*)\s*(?:MB|GB|GiB)', content)
            for match in memory_matches:
                try:
                    mem_val = float(match)
                    if 'GB' in content or 'GiB' in content:
                        mem_val *= 1024  # Convert to MB
                    peak_memory = max(peak_memory, mem_val)
                except:
                    pass
            
            # Extract iteration counts
            iter_matches = re.findall(r'iteration[\s:]*(\d+)', content, re.IGNORECASE)
            iteration_count = max([int(m) for m in iter_matches] + [iteration_count])
            
            # Count errors
            error_count += len(re.findall(r'error|fail|exception', content, re.IGNORECASE))
            
            # Extract convergence information
            conv_matches = re.findall(r'converge.*?(\d+\.?\d*)', content, re.IGNORECASE)
            if conv_matches:
                try:
                    convergence_rate = float(conv_matches[-1])  # Use last convergence value
                except:
                    pass
                    
    except Exception as e:
        continue

# Calculate execution time
execution_time_seconds = 0
if execution_start_time and execution_end_time:
    try:
        from datetime import datetime
        start_dt = datetime.fromisoformat(execution_start_time.replace(' ', 'T'))
        end_dt = datetime.fromisoformat(execution_end_time.replace(' ', 'T'))
        execution_time_seconds = (end_dt - start_dt).total_seconds()
    except:
        pass

# Populate metrics
metrics['execution_metrics'] = {
    'total_time_seconds': execution_time_seconds,
    'start_time': execution_start_time,
    'end_time': execution_end_time,
    'time_per_iteration': execution_time_seconds / max(iteration_count, 1) if execution_time_seconds > 0 else 0
}

metrics['memory_metrics'] = {
    'peak_memory_mb': peak_memory,
    'estimated_efficiency': min(1.0, peak_memory / 1000) if peak_memory > 0 else 0  # Simple efficiency estimate
}

metrics['convergence_metrics'] = {
    'iteration_count': iteration_count,
    'convergence_rate': convergence_rate,
    'iterations_per_second': iteration_count / max(execution_time_seconds, 1) if execution_time_seconds > 0 else 0
}

metrics['error_metrics'] = {
    'error_count': error_count,
    'error_rate': error_count / max(iteration_count, 1) if iteration_count > 0 else 0
}

# Resource efficiency calculation
if execution_time_seconds > 0 and peak_memory > 0:
    # Simple efficiency score: work done per resource unit per time
    efficiency_score = iteration_count / (execution_time_seconds * (peak_memory / 1000))
    metrics['resource_efficiency'] = {
        'score': efficiency_score,
        'time_efficiency': iteration_count / execution_time_seconds if execution_time_seconds > 0 else 0,
        'memory_efficiency': iteration_count / (peak_memory / 1000) if peak_memory > 0 else 0
    }

metrics['status'] = 'success' if error_count == 0 and iteration_count > 0 else 'partial' if iteration_count > 0 else 'failed'

print(json.dumps(metrics, indent=2))
")
    else
        # Fallback basic metrics
        metrics_json="{\"session_name\":\"$session_name\",\"status\":\"python_unavailable\",\"config\":$config}"
    fi
    
    echo "$metrics_json"
}

function store_metrics() {
    local metrics_json="$1"
    
    # Ensure database directory exists
    mkdir -p "$PERFORMANCE_DB_DIR"
    
    # Append metrics to database
    echo "$metrics_json" >> "$METRICS_DB"
    
    log_performance_event "SUCCESS" "Metrics stored to database" "storage"
}

function establish_baseline() {
    local experiment_type="$1"
    local degree="$2"
    local dimension="$3"
    
    log_performance_event "INFO" "Establishing baseline for: $experiment_type degree=$degree dimension=$dimension" "baseline"
    
    local config_key="${experiment_type}_${degree}_${dimension}"
    
    # Look for existing measurements for this configuration
    local existing_metrics=()
    
    if [[ -f "$METRICS_DB" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            local baseline_data
            baseline_data=$(python3 -c "
import json
config_key = '$config_key'
matching_metrics = []

try:
    with open('$METRICS_DB', 'r') as f:
        for line in f:
            if line.strip():
                try:
                    metric = json.loads(line)
                    if metric.get('config', {}).get('config_key') == config_key:
                        matching_metrics.append(metric)
                except:
                    continue

    if len(matching_metrics) >= $MIN_BASELINE_RUNS:
        # Calculate baseline statistics
        exec_times = [m['execution_metrics']['total_time_seconds'] for m in matching_metrics 
                     if m.get('execution_metrics', {}).get('total_time_seconds', 0) > 0]
        peak_memories = [m['memory_metrics']['peak_memory_mb'] for m in matching_metrics 
                        if m.get('memory_metrics', {}).get('peak_memory_mb', 0) > 0]
        error_rates = [m['error_metrics']['error_rate'] for m in matching_metrics 
                      if 'error_metrics' in m]
        
        baseline = {
            'config_key': config_key,
            'experiment_type': '$experiment_type',
            'degree': $degree,
            'dimension': $dimension,
            'baseline_runs': len(matching_metrics),
            'established': '$(date -Iseconds)',
            'execution_time': {
                'mean': sum(exec_times) / len(exec_times) if exec_times else 0,
                'min': min(exec_times) if exec_times else 0,
                'max': max(exec_times) if exec_times else 0,
                'samples': len(exec_times)
            },
            'memory_usage': {
                'mean': sum(peak_memories) / len(peak_memories) if peak_memories else 0,
                'min': min(peak_memories) if peak_memories else 0,
                'max': max(peak_memories) if peak_memories else 0,
                'samples': len(peak_memories)
            },
            'error_rate': {
                'mean': sum(error_rates) / len(error_rates) if error_rates else 0,
                'samples': len(error_rates)
            }
        }
        
        print(json.dumps(baseline, indent=2))
    else:
        print(f'{{\"error\": \"Insufficient data\", \"found_runs\": {len(matching_metrics)}, \"required_runs\": $MIN_BASELINE_RUNS}}')
        
except Exception as e:
    print(f'{{\"error\": \"Failed to process metrics\", \"details\": \"{e}\"}}')
")
            
            if [[ "$baseline_data" == *"\"error\""* ]]; then
                echo -e "${YELLOW}⚠️  Cannot establish baseline: $(echo "$baseline_data" | python3 -c "import json, sys; print(json.loads(sys.stdin.read()).get('error', 'Unknown error'))")"
                local found_runs=$(echo "$baseline_data" | python3 -c "import json, sys; print(json.loads(sys.stdin.read()).get('found_runs', 0))" 2>/dev/null || echo "0")
                echo "   Found $found_runs runs, need at least $MIN_BASELINE_RUNS"
                return 1
            else
                # Store baseline
                echo "$baseline_data" >> "$BASELINE_DB"
                
                echo -e "${GREEN}✅ Baseline established for $config_key${NC}"
                
                # Show baseline summary
                if command -v python3 >/dev/null 2>&1; then
                    python3 -c "
import json
baseline = json.loads('''$baseline_data''')
exec_time = baseline['execution_time']['mean']
memory = baseline['memory_usage']['mean']
runs = baseline['baseline_runs']

print(f'   Execution Time: {exec_time:.1f}s (avg over {runs} runs)')
print(f'   Memory Usage: {memory:.1f}MB (avg)')
print(f'   Based on {runs} experiment runs')
"
                fi
                
                log_performance_event "SUCCESS" "Baseline established for $config_key with $found_runs runs" "baseline"
                return 0
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  No metrics database found. Run some experiments first.${NC}"
        return 1
    fi
}

function detect_regressions() {
    local experiment_type="${1:-all}"
    
    log_performance_event "INFO" "Detecting performance regressions for type: $experiment_type" "regression"
    
    if [[ ! -f "$BASELINE_DB" || ! -f "$METRICS_DB" ]]; then
        echo -e "${YELLOW}⚠️  Baseline or metrics database not found${NC}"
        return 1
    fi
    
    if command -v python3 >/dev/null 2>&1; then
        local regression_report
        regression_report=$(python3 -c "
import json
from datetime import datetime, timedelta

# Load baselines
baselines = {}
try:
    with open('$BASELINE_DB', 'r') as f:
        for line in f:
            if line.strip():
                try:
                    baseline = json.loads(line)
                    config_key = baseline.get('config_key')
                    if config_key:
                        baselines[config_key] = baseline
                except:
                    continue
except:
    pass

# Load recent metrics (last 7 days)
recent_cutoff = datetime.now() - timedelta(days=7)
recent_metrics = []

try:
    with open('$METRICS_DB', 'r') as f:
        for line in f:
            if line.strip():
                try:
                    metric = json.loads(line)
                    metric_time = datetime.fromisoformat(metric.get('timestamp', ''))
                    if metric_time >= recent_cutoff:
                        recent_metrics.append(metric)
                except:
                    continue
except:
    pass

# Detect regressions
regressions = []
time_threshold = $REGRESSION_TIME_THRESHOLD
memory_threshold = $REGRESSION_MEMORY_THRESHOLD
error_threshold = $REGRESSION_ERROR_THRESHOLD

for metric in recent_metrics:
    config_key = metric.get('config', {}).get('config_key', '')
    if not config_key or config_key not in baselines:
        continue
        
    if '$experiment_type' != 'all' and metric.get('config', {}).get('experiment_type') != '$experiment_type':
        continue
    
    baseline = baselines[config_key]
    session_name = metric.get('session_name', 'unknown')
    
    # Check execution time regression
    current_time = metric.get('execution_metrics', {}).get('total_time_seconds', 0)
    baseline_time = baseline.get('execution_time', {}).get('mean', 0)
    
    if current_time > 0 and baseline_time > 0:
        time_ratio = current_time / baseline_time
        if time_ratio > time_threshold:
            regressions.append({
                'type': 'execution_time',
                'severity': 'high' if time_ratio > 2.0 else 'medium',
                'session': session_name,
                'config_key': config_key,
                'current_value': current_time,
                'baseline_value': baseline_time,
                'ratio': time_ratio,
                'message': f'Execution time increased by {((time_ratio - 1) * 100):.1f}% ({current_time:.1f}s vs {baseline_time:.1f}s baseline)'
            })
    
    # Check memory regression
    current_memory = metric.get('memory_metrics', {}).get('peak_memory_mb', 0)
    baseline_memory = baseline.get('memory_usage', {}).get('mean', 0)
    
    if current_memory > 0 and baseline_memory > 0:
        memory_ratio = current_memory / baseline_memory
        if memory_ratio > memory_threshold:
            regressions.append({
                'type': 'memory_usage',
                'severity': 'high' if memory_ratio > 2.0 else 'medium',
                'session': session_name,
                'config_key': config_key,
                'current_value': current_memory,
                'baseline_value': baseline_memory,
                'ratio': memory_ratio,
                'message': f'Memory usage increased by {((memory_ratio - 1) * 100):.1f}% ({current_memory:.1f}MB vs {baseline_memory:.1f}MB baseline)'
            })
    
    # Check error rate regression
    current_error_rate = metric.get('error_metrics', {}).get('error_rate', 0)
    baseline_error_rate = baseline.get('error_rate', {}).get('mean', 0)
    
    if current_error_rate > baseline_error_rate * error_threshold:
        regressions.append({
            'type': 'error_rate',
            'severity': 'critical',
            'session': session_name,
            'config_key': config_key,
            'current_value': current_error_rate,
            'baseline_value': baseline_error_rate,
            'ratio': current_error_rate / max(baseline_error_rate, 0.01),
            'message': f'Error rate increased significantly ({current_error_rate:.3f} vs {baseline_error_rate:.3f} baseline)'
        })

# Generate report
report = {
    'timestamp': datetime.now().isoformat(),
    'analysis_period_days': 7,
    'total_regressions': len(regressions),
    'regressions_by_severity': {
        'critical': len([r for r in regressions if r['severity'] == 'critical']),
        'high': len([r for r in regressions if r['severity'] == 'high']),
        'medium': len([r for r in regressions if r['severity'] == 'medium'])
    },
    'regressions_by_type': {
        'execution_time': len([r for r in regressions if r['type'] == 'execution_time']),
        'memory_usage': len([r for r in regressions if r['type'] == 'memory_usage']),
        'error_rate': len([r for r in regressions if r['type'] == 'error_rate'])
    },
    'regressions': regressions,
    'baselines_checked': len(baselines),
    'recent_metrics_analyzed': len(recent_metrics)
}

print(json.dumps(report, indent=2))
")
        
        # Store regression report
        echo "$regression_report" > "$REGRESSION_REPORT"
        
        # Display regression summary
        if command -v python3 >/dev/null 2>&1; then
            local summary
            summary=$(echo "$regression_report" | python3 -c "
import json, sys
report = json.loads(sys.stdin.read())

total = report['total_regressions']
by_severity = report['regressions_by_severity']

print(f'Performance Regression Analysis')
print(f'===============================')
print(f'Total Regressions Found: {total}')

if total > 0:
    print(f'  Critical: {by_severity[\"critical\"]}')
    print(f'  High: {by_severity[\"high\"]}')
    print(f'  Medium: {by_severity[\"medium\"]}')
    print()
    
    print('Recent Regressions:')
    for regression in report['regressions'][:5]:  # Show top 5
        severity = regression['severity'].upper()
        reg_type = regression['type'].replace('_', ' ').title()
        session = regression['session']
        message = regression['message']
        
        print(f'  [{severity}] {reg_type}: {session}')
        print(f'    {message}')
        
else:
    print('✅ No performance regressions detected')
")
            echo "$summary"
        fi
        
        # Log results
        local total_regressions=$(echo "$regression_report" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['total_regressions'])" 2>/dev/null || echo "0")
        
        if [[ $total_regressions -gt 0 ]]; then
            log_performance_event "REGRESSION" "$total_regressions performance regressions detected" "regression"
        else
            log_performance_event "SUCCESS" "No performance regressions detected" "regression"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Python3 required for regression detection${NC}"
        return 1
    fi
}

function track_session_performance() {
    local session_name="$1"
    
    log_performance_event "INFO" "Tracking performance for session: $session_name" "tracking"
    
    echo -e "${BLUE}🔍 Performance Tracking: $session_name${NC}"
    
    # Collect current metrics
    local metrics
    metrics=$(collect_session_metrics "$session_name")
    
    if [[ "$metrics" == *"no_output_directory"* ]]; then
        echo -e "${YELLOW}⚠️  No output directory found for session${NC}"
        return 1
    fi
    
    # Store metrics
    store_metrics "$metrics"
    
    # Display performance summary
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
metrics = json.loads('''$metrics''')

config = metrics.get('config', {})
exec_metrics = metrics.get('execution_metrics', {})
memory_metrics = metrics.get('memory_metrics', {})
conv_metrics = metrics.get('convergence_metrics', {})
error_metrics = metrics.get('error_metrics', {})

print(f'📊 Performance Summary for {config.get(\"session_name\", \"unknown\")}')
print('═' * 60)
print(f'Experiment Type: {config.get(\"experiment_type\", \"unknown\")}')
print(f'Configuration: Degree {config.get(\"degree\", 0)}, Dimension {config.get(\"dimension\", 0)}')
print()

exec_time = exec_metrics.get('total_time_seconds', 0)
if exec_time > 0:
    print(f'⏱️  Execution Time: {exec_time:.1f} seconds')
    time_per_iter = exec_metrics.get('time_per_iteration', 0)
    if time_per_iter > 0:
        print(f'   Time per Iteration: {time_per_iter:.3f} seconds')
else:
    print('⏱️  Execution Time: Not available (still running?)')

peak_mem = memory_metrics.get('peak_memory_mb', 0)
if peak_mem > 0:
    print(f'💾 Peak Memory: {peak_mem:.1f} MB')
    if peak_mem > 1024:
        print(f'   ({peak_mem/1024:.2f} GB)')
else:
    print('💾 Memory Usage: Not available')

iter_count = conv_metrics.get('iteration_count', 0)
if iter_count > 0:
    print(f'🔄 Iterations: {iter_count}')
    iter_per_sec = conv_metrics.get('iterations_per_second', 0)
    if iter_per_sec > 0:
        print(f'   Rate: {iter_per_sec:.2f} iterations/second')
        
conv_rate = conv_metrics.get('convergence_rate', 0)
if conv_rate > 0:
    print(f'📈 Convergence Rate: {conv_rate:.6f}')

error_count = error_metrics.get('error_count', 0)
error_rate = error_metrics.get('error_rate', 0)
print(f'⚠️  Errors: {error_count} (rate: {error_rate:.3f})')

status = metrics.get('status', 'unknown')
status_icon = '✅' if status == 'success' else '⚠️' if status == 'partial' else '❌'
print(f'{status_icon} Status: {status.upper()}')
"
    fi
    
    log_performance_event "SUCCESS" "Performance tracking completed for session: $session_name" "tracking"
}

function generate_performance_report() {
    local format="${1:-text}"
    local days="${2:-30}"
    
    log_performance_event "INFO" "Generating performance report (format: $format, days: $days)" "report"
    
    if [[ ! -f "$METRICS_DB" ]]; then
        echo -e "${YELLOW}⚠️  No metrics database found${NC}"
        return 1
    fi
    
    local report_file="$PERFORMANCE_DB_DIR/reports/performance_report_$(date +%Y%m%d_%H%M%S).$format"
    mkdir -p "$(dirname "$report_file")"
    
    if command -v python3 >/dev/null 2>&1; then
        local report_data
        report_data=$(python3 -c "
import json
from datetime import datetime, timedelta
from collections import defaultdict

days = int('$days')
cutoff_date = datetime.now() - timedelta(days=days)

# Load metrics
metrics = []
try:
    with open('$METRICS_DB', 'r') as f:
        for line in f:
            if line.strip():
                try:
                    metric = json.loads(line)
                    metric_time = datetime.fromisoformat(metric.get('timestamp', ''))
                    if metric_time >= cutoff_date:
                        metrics.append(metric)
                except:
                    continue
except:
    pass

# Analyze metrics
experiment_types = defaultdict(list)
daily_stats = defaultdict(lambda: {'count': 0, 'total_time': 0, 'total_memory': 0, 'errors': 0})

for metric in metrics:
    exp_type = metric.get('config', {}).get('experiment_type', 'unknown')
    experiment_types[exp_type].append(metric)
    
    # Daily aggregation
    date_str = metric.get('timestamp', '')[:10]  # YYYY-MM-DD
    daily_stats[date_str]['count'] += 1
    
    exec_time = metric.get('execution_metrics', {}).get('total_time_seconds', 0)
    if exec_time > 0:
        daily_stats[date_str]['total_time'] += exec_time
        
    memory = metric.get('memory_metrics', {}).get('peak_memory_mb', 0)
    if memory > 0:
        daily_stats[date_str]['total_memory'] += memory
        
    error_count = metric.get('error_metrics', {}).get('error_count', 0)
    daily_stats[date_str]['errors'] += error_count

# Generate report
report = {
    'generated': datetime.now().isoformat(),
    'period_days': days,
    'total_experiments': len(metrics),
    'experiment_types': {},
    'daily_statistics': dict(daily_stats),
    'performance_trends': {},
    'top_performers': [],
    'problem_areas': []
}

# Analyze by experiment type
for exp_type, type_metrics in experiment_types.items():
    exec_times = [m['execution_metrics']['total_time_seconds'] 
                 for m in type_metrics 
                 if m.get('execution_metrics', {}).get('total_time_seconds', 0) > 0]
    
    memories = [m['memory_metrics']['peak_memory_mb'] 
               for m in type_metrics 
               if m.get('memory_metrics', {}).get('peak_memory_mb', 0) > 0]
    
    success_count = len([m for m in type_metrics if m.get('status') == 'success'])
    
    report['experiment_types'][exp_type] = {
        'count': len(type_metrics),
        'success_rate': success_count / len(type_metrics) if type_metrics else 0,
        'avg_execution_time': sum(exec_times) / len(exec_times) if exec_times else 0,
        'avg_memory_usage': sum(memories) / len(memories) if memories else 0,
        'fastest_time': min(exec_times) if exec_times else 0,
        'slowest_time': max(exec_times) if exec_times else 0
    }

print(json.dumps(report, indent=2))
")
        
        if [[ "$format" == "json" ]]; then
            echo "$report_data" > "$report_file"
            echo "$report_data"
        elif [[ "$format" == "text" ]]; then
            # Convert to text format
            local text_report
            text_report=$(echo "$report_data" | python3 -c "
import json, sys
report = json.loads(sys.stdin.read())

print('HPC Performance Analysis Report')
print('=' * 50)
print(f'Generated: {report[\"generated\"]}')
print(f'Period: {report[\"period_days\"]} days')
print(f'Total Experiments: {report[\"total_experiments\"]}')
print()

print('Performance by Experiment Type:')
print('-' * 30)
for exp_type, stats in report['experiment_types'].items():
    print(f'{exp_type}:')
    print(f'  Experiments: {stats[\"count\"]}')
    print(f'  Success Rate: {stats[\"success_rate\"]:.1%}')
    if stats['avg_execution_time'] > 0:
        print(f'  Avg Time: {stats[\"avg_execution_time\"]:.1f}s')
        print(f'  Range: {stats[\"fastest_time\"]:.1f}s - {stats[\"slowest_time\"]:.1f}s')
    if stats['avg_memory_usage'] > 0:
        print(f'  Avg Memory: {stats[\"avg_memory_usage\"]:.1f}MB')
    print()

print('Daily Activity Summary:')
print('-' * 22)
for date_str, stats in sorted(report['daily_statistics'].items())[-7:]:  # Last 7 days
    print(f'{date_str}: {stats[\"count\"]} experiments, {stats[\"errors\"]} errors')
    if stats['total_time'] > 0:
        avg_time = stats['total_time'] / stats['count']
        print(f'  Avg time: {avg_time:.1f}s')
")
            echo "$text_report" > "$report_file"
            echo "$text_report"
        fi
        
        echo -e "${GREEN}✅ Report saved to: $report_file${NC}"
        log_performance_event "SUCCESS" "Performance report generated: $report_file" "report"
    else
        echo -e "${RED}❌ Python3 required for report generation${NC}"
        return 1
    fi
}

function main() {
    # Ensure performance database directory exists
    mkdir -p "$PERFORMANCE_DB_DIR/reports"
    
    # Parse command line arguments
    local command=""
    local experiment_type=""
    local degree=""
    local dimension=""
    local session_name=""
    local format="text"
    local days="30"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --baseline)
                command="baseline"
                experiment_type="$2"
                degree="$3"
                dimension="$4"
                shift 4
                ;;
            --track)
                command="track"
                session_name="$2"
                shift 2
                ;;
            --analyze-session)
                command="analyze"
                session_name="$2"
                shift 2
                ;;
            --detect-regression)
                command="regression"
                experiment_type="${2:-all}"
                shift 2
                ;;
            --report)
                command="report"
                shift
                ;;
            --compare)
                command="compare"
                session_name="$2"
                # session2 would be $3, but we'll handle this in the future
                shift 3
                ;;
            --trends)
                command="trends"
                days="${2:-30}"
                shift 2
                ;;
            --reset-baselines)
                command="reset"
                shift
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --days)
                days="$2"
                shift 2
                ;;
            --threshold-time)
                REGRESSION_TIME_THRESHOLD="$2"
                shift 2
                ;;
            --threshold-memory)
                REGRESSION_MEMORY_THRESHOLD="$2"
                shift 2
                ;;
            --threshold-error)
                REGRESSION_ERROR_THRESHOLD="$2"
                shift 2
                ;;
            --min-baseline-runs)
                MIN_BASELINE_RUNS="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        "baseline")
            if [[ -n "$experiment_type" && -n "$degree" && -n "$dimension" ]]; then
                establish_baseline "$experiment_type" "$degree" "$dimension"
            else
                echo -e "${RED}❌ Baseline requires experiment_type, degree, and dimension${NC}"
                usage
                exit 1
            fi
            ;;
        "track")
            if [[ -n "$session_name" ]]; then
                track_session_performance "$session_name"
            else
                echo -e "${RED}❌ Track requires session name${NC}"
                exit 1
            fi
            ;;
        "analyze")
            if [[ -n "$session_name" ]]; then
                local metrics
                metrics=$(collect_session_metrics "$session_name")
                echo "$metrics" | jq '.' 2>/dev/null || echo "$metrics"
            else
                echo -e "${RED}❌ Analyze requires session name${NC}"
                exit 1
            fi
            ;;
        "regression")
            detect_regressions "$experiment_type"
            ;;
        "report")
            generate_performance_report "$format" "$days"
            ;;
        "reset")
            if [[ -f "$BASELINE_DB" ]]; then
                mv "$BASELINE_DB" "${BASELINE_DB}.backup.$(date +%Y%m%d_%H%M%S)"
                echo -e "${GREEN}✅ Baselines reset (backup created)${NC}"
                log_performance_event "INFO" "Baselines reset" "reset"
            else
                echo -e "${YELLOW}⚠️  No baselines to reset${NC}"
            fi
            ;;
        "trends")
            generate_performance_report "text" "$days"
            ;;
        *)
            echo -e "${RED}❌ No command specified${NC}"
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"