"""
GlobTim HPC Testing Infrastructure Core Components
"""

from .job_manager import JobManager, JobConfig, JobStatus
from .test_suite import TestSuite, TestCase, TestSuiteRunner, create_standard_suites
from .reporter import HTMLReporter, MarkdownReporter, JSONReporter

__all__ = [
    'JobManager',
    'JobConfig',
    'JobStatus',
    'TestSuite',
    'TestCase',
    'TestSuiteRunner',
    'create_standard_suites',
    'HTMLReporter',
    'MarkdownReporter',
    'JSONReporter'
]

__version__ = '1.0.0'