#!/usr/bin/env python3
"""
GlobTim HPC Testing Infrastructure
Main command-line interface for running tests and benchmarks
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import datetime
import logging

# Add infrastructure to path
sys.path.insert(0, str(Path(__file__).parent / 'infrastructure'))

from infrastructure.core.job_manager import JobManager, JobConfig
from infrastructure.core.test_suite import TestSuite, TestCase, TestSuiteRunner, create_standard_suites
from infrastructure.core.reporter import HTMLReporter, MarkdownReporter


def setup_logging(verbose: bool = False):
    """Setup logging configuration"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def cmd_run_test(args):
    """Run a single test"""
    print(f"Running test: {args.test_name}")
    
    # Initialize job manager
    manager = JobManager(args.config)
    
    # Create test case
    if args.script:
        with open(args.script, 'r') as f:
            script_content = f.read()
    else:
        script_content = f"""
            println("Running test: {args.test_name}")
            # Default test placeholder
            @test true
        """
    
    test = TestCase(
        name=args.test_name,
        type=args.type,
        script=script_content,
        timeout=args.timeout,
        memory=args.memory,
        tags=args.tags.split(',') if args.tags else []
    )
    
    # Create minimal suite with single test
    suite = TestSuite(name=f"single_test_{args.test_name}")
    suite.add_test(test)
    
    # Run test
    runner = TestSuiteRunner(manager)
    results = runner.run_suite(suite)
    
    # Save results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"Results saved to: {args.output}")
    
    # Print summary
    print("\n" + "="*60)
    print("Test Results Summary")
    print("="*60)
    print(json.dumps(results['summary'], indent=2))
    
    return 0 if results['summary']['failed'] == 0 else 1


def cmd_run_suite(args):
    """Run a test suite"""
    print(f"Running test suite: {args.suite}")
    
    # Initialize job manager
    manager = JobManager(args.config)
    
    # Load or create suite
    if Path(args.suite).exists():
        suite = TestSuite.load(args.suite)
    else:
        # Try to load from standard suites
        standard_suites = create_standard_suites()
        if args.suite in standard_suites:
            suite = standard_suites[args.suite]
        else:
            print(f"Error: Suite '{args.suite}' not found")
            print(f"Available standard suites: {list(standard_suites.keys())}")
            return 1
    
    # Filter tests if requested
    if args.filter_tags:
        original_count = len(suite.tests)
        suite.tests = suite.filter_by_tags(args.filter_tags.split(','))
        print(f"Filtered from {original_count} to {len(suite.tests)} tests")
    
    if args.filter_type:
        original_count = len(suite.tests)
        suite.tests = suite.filter_by_type(args.filter_type)
        print(f"Filtered from {original_count} to {len(suite.tests)} tests")
    
    # Run suite
    runner = TestSuiteRunner(manager)
    results = runner.run_suite(suite, parallel=args.parallel)
    
    # Generate reports
    if args.html_report:
        reporter = HTMLReporter()
        reporter.generate(results, args.html_report)
        print(f"HTML report saved to: {args.html_report}")
    
    if args.markdown_report:
        reporter = MarkdownReporter()
        reporter.generate(results, args.markdown_report)
        print(f"Markdown report saved to: {args.markdown_report}")
    
    # Save raw results
    results_file = args.output or f"results_{suite.name}_{datetime.now():%Y%m%d_%H%M%S}.json"
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    print(f"Results saved to: {results_file}")
    
    # Print summary
    print("\n" + "="*60)
    print("Test Suite Results Summary")
    print("="*60)
    print(f"Suite: {suite.name}")
    print(f"Total tests: {results['summary']['total_tests']}")
    print(f"Passed: {results['summary']['passed']}")
    print(f"Failed: {results['summary']['failed']}")
    print(f"Total runtime: {results['summary']['total_runtime']:.2f} seconds")
    
    if results['summary']['by_type']:
        print("\nResults by type:")
        for test_type, stats in results['summary']['by_type'].items():
            print(f"  {test_type}: {stats['passed']}/{stats['count']} passed")
    
    return 0 if results['summary']['failed'] == 0 else 1


def cmd_monitor(args):
    """Monitor running jobs"""
    print("Monitoring HPC jobs...")
    
    manager = JobManager(args.config)
    
    # Get current job status
    if args.job_id:
        # Monitor specific job
        status = manager.get_job_status(args.job_id)
        print(f"Job {args.job_id}: {status.state}")
        if status.state == "COMPLETED":
            results = manager.collect_results(args.job_id)
            print(f"Exit code: {results['exit_code']}")
            print(f"Runtime: {results['runtime']:.2f} seconds")
    else:
        # Monitor all active jobs
        manager.monitor_jobs(interval=args.interval)
    
    return 0


def cmd_benchmark(args):
    """Run performance benchmarks"""
    print("Running benchmarks...")
    
    # Initialize job manager
    manager = JobManager(args.config)
    
    # Create benchmark suite
    if args.preset:
        if args.preset == "quick":
            suite = TestSuite(name="quick_benchmark")
            suite.add_test(TestCase(
                name="deuflhard_small",
                type="benchmark",
                script="include('test/benchmarks/deuflhard_benchmark.jl'); run_deuflhard_benchmark(5)",
                timeout="00:30:00",
                memory="8G"
            ))
        elif args.preset == "full":
            suite = create_standard_suites()['benchmarks']
        else:
            print(f"Unknown preset: {args.preset}")
            return 1
    else:
        # Custom benchmark
        suite = TestSuite(name="custom_benchmark")
        suite.add_test(TestCase(
            name=args.name or "custom",
            type="benchmark",
            script=args.script,
            timeout=args.timeout,
            memory=args.memory,
            parameters={'iterations': args.iterations}
        ))
    
    # Run benchmarks
    runner = TestSuiteRunner(manager)
    results = runner.run_suite(suite)
    
    # Analyze performance
    print("\n" + "="*60)
    print("Benchmark Results")
    print("="*60)
    
    for test_result in results['tests']:
        print(f"\n{test_result['name']}:")
        if 'metrics' in test_result:
            for metric, value in test_result['metrics'].items():
                print(f"  {metric}: {value}")
    
    # Save results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\nResults saved to: {args.output}")
    
    # Compare with baseline if provided
    if args.baseline:
        with open(args.baseline, 'r') as f:
            baseline = json.load(f)
        
        print("\n" + "="*60)
        print("Performance Comparison")
        print("="*60)
        
        for i, test_result in enumerate(results['tests']):
            if i < len(baseline['tests']):
                baseline_test = baseline['tests'][i]
                print(f"\n{test_result['name']}:")
                
                if 'runtime' in test_result and 'runtime' in baseline_test:
                    current = test_result['runtime']
                    base = baseline_test['runtime']
                    diff = ((current - base) / base) * 100
                    symbol = "🔺" if diff > 5 else "🔻" if diff < -5 else "✅"
                    print(f"  Runtime: {current:.2f}s (baseline: {base:.2f}s, {diff:+.1f}%) {symbol}")
    
    return 0


def cmd_create_suite(args):
    """Create a new test suite"""
    print(f"Creating test suite: {args.name}")
    
    suite = TestSuite(
        name=args.name,
        description=args.description or f"Test suite created on {datetime.now()}"
    )
    
    # Add tests from file if provided
    if args.tests_file:
        with open(args.tests_file, 'r') as f:
            tests_data = json.load(f)
            for test_data in tests_data:
                test = TestCase(**test_data)
                suite.add_test(test)
    
    # Save suite
    output_file = args.output or f"{args.name}_suite.yaml"
    suite.save(output_file)
    print(f"Suite saved to: {output_file}")
    
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="GlobTim HPC Testing Infrastructure",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run a single test
  %(prog)s run-test my_test --script test.jl --type unit
  
  # Run a test suite
  %(prog)s run-suite benchmarks --parallel
  
  # Monitor jobs
  %(prog)s monitor --watch
  
  # Run benchmarks
  %(prog)s benchmark --preset quick
  
  # Create a new suite
  %(prog)s create-suite my_suite --description "My custom tests"
        """
    )
    
    parser.add_argument('--config', default=None, help='Configuration file')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # run-test command
    test_parser = subparsers.add_parser('run-test', help='Run a single test')
    test_parser.add_argument('test_name', help='Name of the test')
    test_parser.add_argument('--script', help='Path to test script')
    test_parser.add_argument('--type', default='unit', choices=['unit', 'integration', 'benchmark', 'stress'])
    test_parser.add_argument('--timeout', default='00:30:00', help='Job timeout')
    test_parser.add_argument('--memory', default='8G', help='Memory allocation')
    test_parser.add_argument('--tags', help='Comma-separated tags')
    test_parser.add_argument('--output', help='Output file for results')
    test_parser.set_defaults(func=cmd_run_test)
    
    # run-suite command
    suite_parser = subparsers.add_parser('run-suite', help='Run a test suite')
    suite_parser.add_argument('suite', help='Suite name or path to suite file')
    suite_parser.add_argument('--parallel', action='store_true', help='Run tests in parallel')
    suite_parser.add_argument('--filter-tags', help='Filter tests by tags')
    suite_parser.add_argument('--filter-type', help='Filter tests by type')
    suite_parser.add_argument('--output', help='Output file for results')
    suite_parser.add_argument('--html-report', help='Generate HTML report')
    suite_parser.add_argument('--markdown-report', help='Generate Markdown report')
    suite_parser.set_defaults(func=cmd_run_suite)
    
    # monitor command
    monitor_parser = subparsers.add_parser('monitor', help='Monitor jobs')
    monitor_parser.add_argument('--job-id', help='Specific job ID to monitor')
    monitor_parser.add_argument('--interval', type=int, default=10, help='Update interval in seconds')
    monitor_parser.add_argument('--watch', action='store_true', help='Continuous monitoring')
    monitor_parser.set_defaults(func=cmd_monitor)
    
    # benchmark command
    bench_parser = subparsers.add_parser('benchmark', help='Run benchmarks')
    bench_parser.add_argument('--preset', choices=['quick', 'full'], help='Use preset benchmark suite')
    bench_parser.add_argument('--name', help='Benchmark name')
    bench_parser.add_argument('--script', help='Path to benchmark script')
    bench_parser.add_argument('--iterations', type=int, default=10, help='Number of iterations')
    bench_parser.add_argument('--timeout', default='01:00:00', help='Job timeout')
    bench_parser.add_argument('--memory', default='16G', help='Memory allocation')
    bench_parser.add_argument('--output', help='Output file for results')
    bench_parser.add_argument('--baseline', help='Baseline results for comparison')
    bench_parser.set_defaults(func=cmd_benchmark)
    
    # create-suite command
    create_parser = subparsers.add_parser('create-suite', help='Create a new test suite')
    create_parser.add_argument('name', help='Suite name')
    create_parser.add_argument('--description', help='Suite description')
    create_parser.add_argument('--tests-file', help='JSON file with test definitions')
    create_parser.add_argument('--output', help='Output file path')
    create_parser.set_defaults(func=cmd_create_suite)
    
    args = parser.parse_args()
    
    # Setup logging
    setup_logging(args.verbose)
    
    # Execute command
    if hasattr(args, 'func'):
        sys.exit(args.func(args))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()