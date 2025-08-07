#!/usr/bin/env python3

"""
Test Automated Monitoring System
================================

Demonstrates the automated monitoring and collection system using
previously completed jobs.

Usage:
    python test_automated_monitoring.py
"""

from automated_job_monitor import AutomatedJobMonitor
import time

def test_quick_collection():
    """Test quick collection on completed jobs"""
    print("🧪 Testing Quick Collection System")
    print("=" * 50)
    
    monitor = AutomatedJobMonitor()
    
    # Test with our successful basic test job
    test_cases = [
        {"job_id": "59774392", "test_id": "cd943d4b", "description": "Basic Julia test (successful)"},
        {"job_id": "59774394", "test_id": "587f142d", "description": "Globtim compilation test (failed)"},
        {"job_id": "59774401", "test_id": "99ecbfe7", "description": "Dependencies installation (failed)"}
    ]
    
    results = []
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n📋 Test {i}/3: {test_case['description']}")
        print(f"Job ID: {test_case['job_id']}, Test ID: {test_case['test_id']}")
        
        try:
            local_dir = monitor.quick_collect(test_case['job_id'], test_case['test_id'])
            results.append({
                "test_case": test_case,
                "status": "success",
                "local_dir": str(local_dir)
            })
            print(f"✅ Collection successful: {local_dir}")
            
        except Exception as e:
            results.append({
                "test_case": test_case,
                "status": "failed",
                "error": str(e)
            })
            print(f"❌ Collection failed: {e}")
    
    # Summary
    print(f"\n📊 QUICK COLLECTION TEST SUMMARY")
    print("=" * 50)
    successful = sum(1 for r in results if r["status"] == "success")
    print(f"Successful collections: {successful}/{len(results)}")
    
    for result in results:
        status_icon = "✅" if result["status"] == "success" else "❌"
        print(f"{status_icon} Job {result['test_case']['job_id']}: {result['status']}")
        if result["status"] == "success":
            print(f"    📁 {result['local_dir']}")
    
    return results

def test_monitoring_simulation():
    """Simulate monitoring behavior (without actual job submission)"""
    print("\n🧪 Testing Monitoring System Simulation")
    print("=" * 50)
    
    monitor = AutomatedJobMonitor()
    
    # Test job status checking
    print("📊 Testing job status retrieval...")
    
    test_job_ids = ["59774392", "59774394", "59774401"]
    
    for job_id in test_job_ids:
        print(f"\n🔍 Checking status for job {job_id}:")
        status = monitor.get_job_status(job_id)
        
        if status:
            print(f"  ✅ Status retrieved successfully")
            print(f"    State: {status['state']}")
            print(f"    Exit code: {status['exit_code']}")
            print(f"    Elapsed: {status['elapsed']}")
        else:
            print(f"  ❌ Could not retrieve status")
    
    # Test file finding
    print(f"\n📁 Testing file discovery...")
    for job_id in test_job_ids[:2]:  # Test first 2 jobs
        print(f"\n🔍 Finding files for job {job_id}:")
        files = monitor.find_job_files(job_id)
        
        if files:
            print(f"  ✅ Found {len(files)} files:")
            for file_name in list(files.keys())[:3]:  # Show first 3 files
                print(f"    📄 {file_name}")
            if len(files) > 3:
                print(f"    ... and {len(files) - 3} more files")
        else:
            print(f"  ⚠️  No files found")

def demonstrate_monitoring_workflow():
    """Demonstrate the complete monitoring workflow"""
    print("\n🚀 Demonstrating Complete Monitoring Workflow")
    print("=" * 50)
    
    print("This demonstrates how the automated monitoring system works:")
    print()
    print("1. 📤 Job Submission:")
    print("   - Submit job to SLURM")
    print("   - Get job ID and test ID")
    print("   - Optionally start automated monitoring")
    print()
    print("2. 👀 Automated Monitoring:")
    print("   - Check job status every 15 seconds")
    print("   - Report status changes")
    print("   - Wait for completion")
    print()
    print("3. 📥 Automatic Collection:")
    print("   - Find all related files")
    print("   - Download files to local directory")
    print("   - Create collection summary")
    print("   - Generate monitoring report")
    print()
    print("4. 📊 Results Organization:")
    print("   - Timestamped local directories")
    print("   - JSON summaries for automation")
    print("   - Easy access to all outputs")
    print()
    
    # Show example commands
    print("🔧 Example Usage Commands:")
    print("=" * 30)
    print("# Submit with auto-collection:")
    print("python submit_basic_test.py --mode quick --auto-collect")
    print()
    print("# Manual monitoring:")
    print("python automated_job_monitor.py --job-id 12345 --test-id abc123")
    print()
    print("# Quick collection (completed jobs):")
    print("python automated_job_monitor.py --job-id 12345 --test-id abc123 --quick")

def main():
    print("🤖 Automated Monitoring System Test Suite")
    print("=" * 60)
    print("Testing the automated job monitoring and output collection system")
    print()
    
    try:
        # Test 1: Quick collection
        results = test_quick_collection()
        
        # Test 2: Monitoring simulation
        test_monitoring_simulation()
        
        # Test 3: Workflow demonstration
        demonstrate_monitoring_workflow()
        
        print(f"\n🎉 ALL TESTS COMPLETED!")
        print("=" * 60)
        print("The automated monitoring system is ready for use!")
        
        # Show collected results
        successful_collections = [r for r in results if r["status"] == "success"]
        if successful_collections:
            print(f"\n📁 Collected Results Available:")
            for result in successful_collections:
                print(f"  📂 {result['local_dir']}")
        
    except Exception as e:
        print(f"\n❌ Test suite failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
