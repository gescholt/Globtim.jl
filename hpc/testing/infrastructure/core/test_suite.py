"""
GlobTim HPC Test Suite Manager
Manages collections of tests and benchmarks
"""

import json
import yaml
from pathlib import Path
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
import hashlib

from .job_manager import JobManager, JobConfig


@dataclass
class TestCase:
    """Definition of a single test case"""
    name: str
    type: str  # 'unit', 'integration', 'benchmark', 'stress'
    script: str  # Julia script or code to run
    timeout: str = "00:30:00"
    memory: str = "8G"
    expected_outcome: Dict[str, Any] = field(default_factory=dict)
    parameters: Dict[str, Any] = field(default_factory=dict)
    tags: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    
    def generate_id(self) -> str:
        """Generate unique ID for this test"""
        content = f"{self.name}_{self.type}_{self.script}"
        return hashlib.md5(content.encode()).hexdigest()[:8]


@dataclass
class TestSuite:
    """Collection of test cases"""
    name: str
    description: str = ""
    tests: List[TestCase] = field(default_factory=list)
    config: Dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)
    
    def add_test(self, test: TestCase) -> None:
        """Add a test to the suite"""
        self.tests.append(test)
    
    def filter_by_tags(self, tags: List[str]) -> List[TestCase]:
        """Filter tests by tags"""
        return [t for t in self.tests if any(tag in t.tags for tag in tags)]
    
    def filter_by_type(self, test_type: str) -> List[TestCase]:
        """Filter tests by type"""
        return [t for t in self.tests if t.type == test_type]
    
    def save(self, filepath: str) -> None:
        """Save suite definition to file"""
        data = {
            'name': self.name,
            'description': self.description,
            'created_at': self.created_at.isoformat(),
            'config': self.config,
            'tests': [
                {
                    'name': t.name,
                    'type': t.type,
                    'script': t.script,
                    'timeout': t.timeout,
                    'memory': t.memory,
                    'expected_outcome': t.expected_outcome,
                    'parameters': t.parameters,
                    'tags': t.tags,
                    'dependencies': t.dependencies
                }
                for t in self.tests
            ]
        }
        
        with open(filepath, 'w') as f:
            yaml.dump(data, f, default_flow_style=False)
    
    @classmethod
    def load(cls, filepath: str) -> 'TestSuite':
        """Load suite definition from file"""
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
        
        suite = cls(
            name=data['name'],
            description=data.get('description', ''),
            config=data.get('config', {}),
            created_at=datetime.fromisoformat(data.get('created_at', datetime.now().isoformat()))
        )
        
        for test_data in data.get('tests', []):
            test = TestCase(**test_data)
            suite.add_test(test)
        
        return suite


class TestSuiteRunner:
    """Runs test suites on HPC"""
    
    def __init__(self, job_manager: JobManager):
        self.job_manager = job_manager
        self.results = []
        
    def run_suite(self, suite: TestSuite, parallel: bool = False) -> Dict:
        """Run all tests in a suite"""
        print(f"Running test suite: {suite.name}")
        print(f"Total tests: {len(suite.tests)}")
        print("="*60)
        
        suite_results = {
            'suite_name': suite.name,
            'start_time': datetime.now().isoformat(),
            'tests': [],
            'summary': {}
        }
        
        job_ids = []
        
        # Submit all tests
        for test in suite.tests:
            print(f"\nSubmitting test: {test.name}")
            
            # Generate test script
            test_script = self._generate_test_script(test)
            script_path = f"/tmp/test_{test.generate_id()}.jl"
            
            with open(script_path, 'w') as f:
                f.write(test_script)
            
            # Create job configuration
            job_config = JobConfig(
                name=f"test_{test.name}",
                script_path=script_path,
                time=test.timeout,
                memory=test.memory,
                parameters=test.parameters,
                dependencies=test.dependencies if not parallel else []
            )
            
            # Submit job
            job_id = self.job_manager.submit_job(job_config)
            job_ids.append(job_id)
            
            suite_results['tests'].append({
                'name': test.name,
                'type': test.type,
                'job_id': job_id,
                'status': 'submitted'
            })
        
        # Monitor jobs
        print("\nMonitoring test execution...")
        self.job_manager.monitor_jobs(interval=10)
        
        # Collect results
        print("\nCollecting results...")
        for i, job_id in enumerate(job_ids):
            test_result = self.job_manager.collect_results(job_id)
            suite_results['tests'][i].update(test_result)
            
            # Check against expected outcome
            if suite.tests[i].expected_outcome:
                suite_results['tests'][i]['validation'] = self._validate_result(
                    test_result,
                    suite.tests[i].expected_outcome
                )
        
        # Generate summary
        suite_results['end_time'] = datetime.now().isoformat()
        suite_results['summary'] = self._generate_summary(suite_results)
        
        return suite_results
    
    def _generate_test_script(self, test: TestCase) -> str:
        """Generate Julia script for test execution"""
        script = f"""
# Test: {test.name}
# Type: {test.type}
# Generated: {datetime.now().isoformat()}

using Pkg
using Test
using TimerOutputs

const to = TimerOutput()

@timeit to "test_setup" begin
    println("Setting up test: {test.name}")
    println("="*60)
    
    # Load required packages
    using Pkg
    Pkg.instantiate()
end

# Test parameters
parameters = {json.dumps(test.parameters)}

@timeit to "test_execution" begin
"""
        
        # Add the actual test code
        if Path(test.script).exists():
            with open(test.script, 'r') as f:
                script += f.read()
        else:
            script += test.script
        
        script += """
end

# Output timing information
println()
println("="*60)
println("Timing Report:")
show(to, allocations=true, sortby=:time)
println()

# Output metrics for parsing
println()
println("METRICS_START")
println("total_time: ", TimerOutputs.tottime(to) / 1e9, " seconds")
println("allocations: ", TimerOutputs.totallocated(to) / 1e6, " MB")
println("METRICS_END")
"""
        
        return script
    
    def _validate_result(self, result: Dict, expected: Dict) -> Dict:
        """Validate test result against expected outcome"""
        validation = {
            'passed': True,
            'checks': []
        }
        
        for key, expected_value in expected.items():
            if key == 'exit_code':
                actual = result.get('exit_code', -1)
                passed = actual == expected_value
                validation['checks'].append({
                    'name': 'exit_code',
                    'expected': expected_value,
                    'actual': actual,
                    'passed': passed
                })
                if not passed:
                    validation['passed'] = False
                    
            elif key == 'max_runtime':
                actual = result.get('runtime', float('inf'))
                passed = actual <= expected_value
                validation['checks'].append({
                    'name': 'max_runtime',
                    'expected': f"<= {expected_value}s",
                    'actual': f"{actual}s",
                    'passed': passed
                })
                if not passed:
                    validation['passed'] = False
                    
            elif key in result.get('metrics', {}):
                actual = result['metrics'][key]
                if isinstance(expected_value, dict):
                    if 'min' in expected_value:
                        passed = actual >= expected_value['min']
                    elif 'max' in expected_value:
                        passed = actual <= expected_value['max']
                    else:
                        passed = actual == expected_value.get('value')
                else:
                    passed = actual == expected_value
                    
                validation['checks'].append({
                    'name': key,
                    'expected': expected_value,
                    'actual': actual,
                    'passed': passed
                })
                if not passed:
                    validation['passed'] = False
        
        return validation
    
    def _generate_summary(self, results: Dict) -> Dict:
        """Generate summary statistics"""
        tests = results['tests']
        
        summary = {
            'total_tests': len(tests),
            'passed': sum(1 for t in tests if t.get('exit_code') == 0),
            'failed': sum(1 for t in tests if t.get('exit_code', -1) != 0),
            'total_runtime': sum(t.get('runtime', 0) for t in tests),
            'validation_passed': sum(
                1 for t in tests 
                if t.get('validation', {}).get('passed', False)
            ),
            'by_type': {}
        }
        
        # Group by test type
        for test in tests:
            test_type = test.get('type', 'unknown')
            if test_type not in summary['by_type']:
                summary['by_type'][test_type] = {
                    'count': 0,
                    'passed': 0,
                    'failed': 0,
                    'runtime': 0
                }
            
            summary['by_type'][test_type]['count'] += 1
            if test.get('exit_code') == 0:
                summary['by_type'][test_type]['passed'] += 1
            else:
                summary['by_type'][test_type]['failed'] += 1
            summary['by_type'][test_type]['runtime'] += test.get('runtime', 0)
        
        return summary


# Predefined test suites
def create_standard_suites() -> Dict[str, TestSuite]:
    """Create standard test suites for GlobTim"""
    suites = {}
    
    # Quick validation suite
    quick_suite = TestSuite(
        name="quick_validation",
        description="Quick validation of GlobTim installation"
    )
    
    quick_suite.add_test(TestCase(
        name="package_loading",
        type="unit",
        script="""
            println("Testing package loading...")
            using ForwardDiff
            using HomotopyContinuation
            using StaticArrays
            println("✅ All packages loaded successfully")
        """,
        timeout="00:05:00",
        memory="4G",
        expected_outcome={'exit_code': 0},
        tags=['quick', 'validation']
    ))
    
    quick_suite.add_test(TestCase(
        name="basic_computation",
        type="unit",
        script="""
            println("Testing basic GlobTim computation...")
            include("src/Globtim.jl")
            using .Globtim
            
            # Simple test computation
            result = Globtim.test_function()
            println("Result: ", result)
            @assert result == expected_value
            println("✅ Basic computation passed")
        """,
        timeout="00:10:00",
        memory="8G",
        expected_outcome={'exit_code': 0},
        tags=['quick', 'computation']
    ))
    
    suites['quick_validation'] = quick_suite
    
    # Benchmark suite
    benchmark_suite = TestSuite(
        name="benchmarks",
        description="Performance benchmarks for GlobTim"
    )
    
    benchmark_suite.add_test(TestCase(
        name="deuflhard_benchmark",
        type="benchmark",
        script="""
            include("test/benchmarks/deuflhard_benchmark.jl")
            run_deuflhard_benchmark(iterations=10)
        """,
        timeout="01:00:00",
        memory="16G",
        expected_outcome={
            'exit_code': 0,
            'max_runtime': 3600
        },
        parameters={'iterations': 10},
        tags=['benchmark', 'deuflhard']
    ))
    
    benchmark_suite.add_test(TestCase(
        name="scaling_test",
        type="benchmark",
        script="""
            include("test/benchmarks/scaling_test.jl")
            run_scaling_test(sizes=[100, 500, 1000, 5000])
        """,
        timeout="02:00:00",
        memory="32G",
        expected_outcome={'exit_code': 0},
        tags=['benchmark', 'scaling']
    ))
    
    suites['benchmarks'] = benchmark_suite
    
    # Regression test suite
    regression_suite = TestSuite(
        name="regression",
        description="Regression tests for GlobTim"
    )
    
    # Add regression tests...
    # (Similar pattern as above)
    
    suites['regression'] = regression_suite
    
    return suites