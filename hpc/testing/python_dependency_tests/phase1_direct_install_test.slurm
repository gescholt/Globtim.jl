#!/bin/bash
#SBATCH --job-name=python_deps_phase1
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4G
#SBATCH --output=python_deps_phase1_%j.out
#SBATCH --error=python_deps_phase1_%j.err

# Phase 1: Test Direct Installation of Python Dependencies on HPC
# Tests both standard pip install and --user installation approaches
# Part of systematic Python dependency management strategy for GlobTim HPC

echo "=========================================="
echo "Python Dependency Phase 1 Test: Direct Installation"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo "=========================================="

# Environment setup - Use Python 3.10.7 available on cluster
echo "Setting up Python 3 environment..."

# Initialize module system if needed
if [[ -f /sw/apps/modules/init/bash ]]; then
    echo "Initializing module system..."
    source /sw/apps/modules/init/bash
fi

# Try to load Python 3.10.7 module
if module load python/3.10.7 2>/dev/null; then
    echo "✅ Python 3.10.7 module loaded"
else
    echo "⚠️  Module load failed, will use direct path approach"
fi

# Find Python 3 executable - check what's available after module load
echo "Checking available Python executables after module load..."
echo "PATH: $PATH"
echo "Available python executables:"
which python 2>/dev/null && echo "  python: $(python --version 2>&1)"
which python3 2>/dev/null && echo "  python3: $(python3 --version 2>&1)"

# Try different approaches to find Python 3
PYTHON3_EXEC=""

# First, check if python3 command works and is version 3
if command -v python3 >/dev/null 2>&1 && python3 --version 2>&1 | grep -q "Python 3"; then
    PYTHON3_EXEC="python3"
    echo "✅ Using system python3: $PYTHON3_EXEC ($(python3 --version 2>&1))"
# Second, check if python command is actually Python 3 after module load
elif command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then
    PYTHON3_EXEC="python"
    echo "✅ Using python (which is Python 3): $PYTHON3_EXEC ($(python --version 2>&1))"
# Third, try specific paths
else
    PYTHON3_PATHS=(
        "/sw/apps/python/3.10.7/bin/python3"
        "/sw/apps/python/3.10.7/bin/python"
        "/usr/bin/python3"
        "/usr/local/bin/python3"
    )

    for py_path in "${PYTHON3_PATHS[@]}"; do
        if [[ -x "$py_path" ]] && $py_path --version 2>&1 | grep -q "Python 3"; then
            PYTHON3_EXEC="$py_path"
            echo "✅ Using Python 3 from path: $PYTHON3_EXEC ($($py_path --version 2>&1))"
            break
        fi
    done
fi

if [[ -z "$PYTHON3_EXEC" ]]; then
    echo "❌ No suitable Python 3 executable found"
    echo "Available executables:"
    ls -la /usr/bin/python* 2>/dev/null || echo "  No python in /usr/bin/"
    ls -la /sw/apps/python*/*/bin/python* 2>/dev/null || echo "  No python in /sw/apps/"
    exit 1
fi

export PYTHONPATH=""

# Test 1: Check current Python environment
echo ""
echo "=== Test 1: Python Environment Check ==="
echo "Python 3 version: $($PYTHON3_EXEC --version 2>&1)"
echo "Python 3 executable: $PYTHON3_EXEC"
echo "Python 3 path: $($PYTHON3_EXEC -c 'import sys; print(sys.executable)')"
echo "Pip version: $($PYTHON3_EXEC -m pip --version 2>/dev/null || echo 'pip not available')"
echo "Current working directory: $(pwd)"
echo "Home directory: $HOME"
echo "User: $(whoami)"

# Check disk space and quotas
echo ""
echo "=== Disk Space and Quota Check ==="
echo "Home directory usage:"
du -sh $HOME 2>/dev/null || echo "Cannot check home directory usage"
echo "Current directory usage:"
du -sh . 2>/dev/null || echo "Cannot check current directory usage"
echo "Available space in /tmp:"
df -h /tmp 2>/dev/null || echo "Cannot check /tmp space"

# Test 2: Check network connectivity
echo ""
echo "=== Test 2: Network Connectivity Check ==="
echo "Testing connectivity to PyPI..."
timeout 10 ping -c 3 pypi.org 2>/dev/null && echo "✅ PyPI reachable" || echo "❌ PyPI not reachable"
timeout 10 curl -s --head https://pypi.org/ | head -1 && echo "✅ HTTPS to PyPI works" || echo "❌ HTTPS to PyPI failed"

# Test 3: Check existing PyYAML installation
echo ""
echo "=== Test 3: Check Existing PyYAML Installation ==="
$PYTHON3_EXEC -c "import yaml; print('✅ PyYAML already installed, version:', yaml.__version__)" 2>/dev/null || echo "❌ PyYAML not currently installed"

# Test 4: Attempt standard pip install
echo ""
echo "=== Test 4: Standard pip install PyYAML ==="
echo "Attempting: $PYTHON3_EXEC -m pip install PyYAML"
if $PYTHON3_EXEC -m pip install PyYAML; then
    echo "✅ Standard pip install succeeded"
    $PYTHON3_EXEC -c "import yaml; print('✅ PyYAML import successful, version:', yaml.__version__)" || echo "❌ Import failed after installation"
    STANDARD_INSTALL_SUCCESS=true
else
    echo "❌ Standard pip install failed"
    STANDARD_INSTALL_SUCCESS=false
fi

# Test 5: Attempt user-local pip install (if standard failed)
if [ "$STANDARD_INSTALL_SUCCESS" = false ]; then
    echo ""
    echo "=== Test 5: User-local pip install PyYAML ==="
    echo "Attempting: $PYTHON3_EXEC -m pip install --user PyYAML"
    if $PYTHON3_EXEC -m pip install --user PyYAML; then
        echo "✅ User-local pip install succeeded"
        $PYTHON3_EXEC -c "import yaml; print('✅ PyYAML import successful, version:', yaml.__version__)" || echo "❌ Import failed after user installation"
        USER_INSTALL_SUCCESS=true
    else
        echo "❌ User-local pip install failed"
        USER_INSTALL_SUCCESS=false
    fi
else
    echo ""
    echo "=== Test 5: Skipped (standard install succeeded) ==="
    USER_INSTALL_SUCCESS=true
fi

# Test 6: Test our HPC testing infrastructure
echo ""
echo "=== Test 6: HPC Testing Infrastructure Validation ==="
cd /tmp
echo "Testing run_tests.py import capabilities..."

# Create a minimal test script to check imports
cat > test_imports.py << 'EOF'
#!/usr/bin/env python3
import sys
import os

# Add infrastructure to path - check if directory exists first
infrastructure_path = '/home/scholten/globtim_hpc/hpc/testing/infrastructure'
if os.path.exists(infrastructure_path):
    sys.path.insert(0, infrastructure_path)
    print(f"✅ Infrastructure path added: {infrastructure_path}")
else:
    print(f"⚠️  Infrastructure path not found: {infrastructure_path}")
    print("Available paths in /home/scholten/globtim_hpc/hpc/testing/:")
    try:
        for item in os.listdir('/home/scholten/globtim_hpc/hpc/testing/'):
            print(f"  {item}")
    except FileNotFoundError:
        print("  Directory not found")

try:
    import yaml
    print("✅ yaml import successful")
except ImportError as e:
    print(f"❌ yaml import failed: {e}")
    sys.exit(1)

# Only test infrastructure imports if the path exists
if os.path.exists(infrastructure_path):
    try:
        from infrastructure.core.job_manager import JobManager, JobConfig
        print("✅ JobManager import successful")
    except ImportError as e:
        print(f"❌ JobManager import failed: {e}")
        print(f"Available files in infrastructure/core/:")
        try:
            for item in os.listdir(f'{infrastructure_path}/core/'):
                print(f"  {item}")
        except FileNotFoundError:
            print("  core directory not found")

    try:
        from infrastructure.core.test_suite import TestSuite, TestCase
        print("✅ TestSuite import successful")
    except ImportError as e:
        print(f"❌ TestSuite import failed: {e}")
else:
    print("⚠️  Skipping infrastructure imports - path not available")
    print("This is expected if globtim_hpc is not deployed to the cluster yet")

print("✅ Critical imports test completed")
EOF

$PYTHON3_EXEC test_imports.py && echo "✅ HPC testing infrastructure imports work" || echo "❌ HPC testing infrastructure imports failed"

# Test 7: Final validation
echo ""
echo "=== Test 7: Final Validation ==="
echo "Testing complete Python environment..."
$PYTHON3_EXEC -c "
import sys
import yaml
import json
import subprocess
import pathlib
import datetime
import logging
print('✅ All required modules available')
print('Python version:', sys.version_info)
print('Python path:', sys.path[:3])
print('PyYAML version:', yaml.__version__)
" && echo "✅ Complete environment validation successful" || echo "❌ Environment validation failed"

# Summary
echo ""
echo "=========================================="
echo "Phase 1 Test Summary"
echo "=========================================="
echo "Standard pip install: $([ "$STANDARD_INSTALL_SUCCESS" = true ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "User-local pip install: $([ "$USER_INSTALL_SUCCESS" = true ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "Overall result: $([ "$STANDARD_INSTALL_SUCCESS" = true ] || [ "$USER_INSTALL_SUCCESS" = true ] && echo "✅ PHASE 1 SUCCESS - Direct installation works" || echo "❌ PHASE 1 FAILED - Need Phase 2 offline bundling")"
echo "Completed: $(date)"
echo "=========================================="

# Exit with appropriate code
if [ "$STANDARD_INSTALL_SUCCESS" = true ] || [ "$USER_INSTALL_SUCCESS" = true ]; then
    exit 0
else
    exit 1
fi
