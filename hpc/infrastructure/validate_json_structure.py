#!/usr/bin/env python3
"""
JSON Structure Validation Script

This script validates the JSON tracking system structure and schemas
without requiring Julia to be installed. It checks:
- JSON schema files are valid
- Example files conform to schemas
- Directory structure is properly organized
- File organization follows the specification
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

def validate_json_file(filepath):
    """Validate that a file contains valid JSON."""
    try:
        with open(filepath, 'r') as f:
            json.load(f)
        return True, None
    except json.JSONDecodeError as e:
        return False, str(e)
    except FileNotFoundError:
        return False, "File not found"

def check_required_fields(data, required_fields, context=""):
    """Check that required fields are present in JSON data."""
    missing = []
    for field in required_fields:
        if isinstance(field, str):
            if field not in data:
                missing.append(field)
        elif isinstance(field, dict):
            for parent, children in field.items():
                if parent not in data:
                    missing.append(parent)
                elif isinstance(children, list):
                    for child in children:
                        if child not in data[parent]:
                            missing.append(f"{parent}.{child}")
    
    if missing:
        print(f"❌ Missing required fields in {context}: {', '.join(missing)}")
        return False
    return True

def validate_input_schema():
    """Validate the input configuration schema and example."""
    print("📋 Validating input configuration schema...")
    
    # Check schema file
    schema_path = "schemas/input_config_schema.json"
    valid, error = validate_json_file(schema_path)
    if not valid:
        print(f"❌ Input schema invalid: {error}")
        return False
    print(f"  ✅ Schema file valid: {schema_path}")
    
    # Check example file
    example_path = "schemas/deuflhard_example_input.json"
    valid, error = validate_json_file(example_path)
    if not valid:
        print(f"❌ Input example invalid: {error}")
        return False
    
    # Load and validate example structure
    with open(example_path, 'r') as f:
        example_data = json.load(f)
    
    required_fields = [
        "metadata",
        "test_input", 
        "polynomial_construction",
        {"metadata": ["computation_id", "function_name"]},
        {"test_input": ["function_name", "dimension", "center", "sample_range"]},
        {"polynomial_construction": ["degree", "basis"]}
    ]
    
    if not check_required_fields(example_data, required_fields, "input example"):
        return False
    
    print(f"  ✅ Example file valid: {example_path}")
    return True

def validate_output_schema():
    """Validate the output results schema and example."""
    print("📊 Validating output results schema...")
    
    # Check schema file
    schema_path = "schemas/output_results_schema.json"
    valid, error = validate_json_file(schema_path)
    if not valid:
        print(f"❌ Output schema invalid: {error}")
        return False
    print(f"  ✅ Schema file valid: {schema_path}")
    
    # Check example file
    example_path = "schemas/deuflhard_example_output.json"
    valid, error = validate_json_file(example_path)
    if not valid:
        print(f"❌ Output example invalid: {error}")
        return False
    
    # Load and validate example structure
    with open(example_path, 'r') as f:
        example_data = json.load(f)
    
    required_fields = [
        "metadata",
        "polynomial_results",
        {"metadata": ["computation_id", "timestamp_start", "timestamp_end", "status"]},
        {"polynomial_results": ["construction_time", "l2_error", "n_coefficients"]}
    ]
    
    if not check_required_fields(example_data, required_fields, "output example"):
        return False
    
    print(f"  ✅ Example file valid: {example_path}")
    return True

def validate_file_structure():
    """Validate the file and directory structure."""
    print("📁 Validating file structure...")
    
    # Check that key files exist
    key_files = [
        "json_io.jl",
        "test_json_tracking.jl", 
        "json_tracking_design.md",
        "file_organization_spec.md",
        "README_JSON_Tracking.md",
        "../jobs/templates/globtim_json_tracking.slurm.template",
        "../jobs/creation/create_json_tracked_job.jl"
    ]
    
    missing_files = []
    for file_path in key_files:
        if not os.path.exists(file_path):
            missing_files.append(file_path)
    
    if missing_files:
        print(f"❌ Missing key files: {', '.join(missing_files)}")
        return False
    
    print("  ✅ All key files present")
    
    # Check schemas directory
    if not os.path.exists("schemas"):
        print("❌ Schemas directory missing")
        return False
    
    schema_files = [
        "schemas/input_config_schema.json",
        "schemas/output_results_schema.json", 
        "schemas/deuflhard_example_input.json",
        "schemas/deuflhard_example_output.json"
    ]
    
    missing_schemas = []
    for schema_file in schema_files:
        if not os.path.exists(schema_file):
            missing_schemas.append(schema_file)
    
    if missing_schemas:
        print(f"❌ Missing schema files: {', '.join(missing_schemas)}")
        return False
    
    print("  ✅ All schema files present")
    return True

def validate_job_templates():
    """Validate job templates and creation scripts."""
    print("🚀 Validating job templates...")
    
    # Check SLURM template
    template_path = "../jobs/templates/globtim_json_tracking.slurm.template"
    if not os.path.exists(template_path):
        print(f"❌ SLURM template missing: {template_path}")
        return False
    
    # Check for required template variables
    with open(template_path, 'r') as f:
        template_content = f.read()
    
    required_vars = [
        "{{JOB_NAME}}", "{{COMPUTATION_ID}}", "{{FUNCTION_NAME}}",
        "{{PARTITION}}", "{{CPUS}}", "{{MEMORY}}", "{{TIME_LIMIT}}", 
        "{{OUTPUT_DIR}}"
    ]
    
    missing_vars = []
    for var in required_vars:
        if var not in template_content:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing template variables: {', '.join(missing_vars)}")
        return False
    
    print("  ✅ SLURM template valid")
    
    # Check job creation script
    creation_script = "../jobs/creation/create_json_tracked_job.jl"
    if not os.path.exists(creation_script):
        print(f"❌ Job creation script missing: {creation_script}")
        return False
    
    print("  ✅ Job creation script present")
    return True

def validate_documentation():
    """Validate documentation files."""
    print("📚 Validating documentation...")
    
    doc_files = [
        "json_tracking_design.md",
        "file_organization_spec.md", 
        "README_JSON_Tracking.md"
    ]
    
    for doc_file in doc_files:
        if not os.path.exists(doc_file):
            print(f"❌ Documentation missing: {doc_file}")
            return False
        
        # Check file is not empty
        if os.path.getsize(doc_file) == 0:
            print(f"❌ Documentation file empty: {doc_file}")
            return False
    
    print("  ✅ All documentation files present and non-empty")
    return True

def main():
    """Run all validation checks."""
    print("🧪 JSON Tracking System Structure Validation")
    print("=" * 50)
    print(f"Started: {datetime.now()}")
    print()
    
    # Change to the infrastructure directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    all_passed = True
    
    # Run validation checks
    checks = [
        ("File Structure", validate_file_structure),
        ("Input Schema", validate_input_schema),
        ("Output Schema", validate_output_schema), 
        ("Job Templates", validate_job_templates),
        ("Documentation", validate_documentation)
    ]
    
    for check_name, check_func in checks:
        try:
            result = check_func()
            if result:
                print(f"✅ {check_name} validation passed")
            else:
                print(f"❌ {check_name} validation failed")
                all_passed = False
        except Exception as e:
            print(f"❌ {check_name} validation error: {e}")
            all_passed = False
        print()
    
    # Final summary
    if all_passed:
        print("🎉 ALL VALIDATIONS PASSED!")
        print("✅ JSON tracking system structure is valid and ready for use")
        print()
        print("Next steps:")
        print("1. Test with Julia: julia test_json_tracking.jl")
        print("2. Create your first job: julia ../jobs/creation/create_json_tracked_job.jl deuflhard quick")
        print("3. Submit to HPC cluster and monitor results")
    else:
        print("❌ Some validations failed")
        print("⚠️  Please fix the issues above before using the system")
    
    print()
    print(f"Validation completed: {datetime.now()}")
    
    return all_passed

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
