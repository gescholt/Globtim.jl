#!/bin/bash
# collect_test_results.sh - Collect and analyze test outputs

echo "=== Collecting Compilation Test Results ==="
echo "Timestamp: $(date)"
echo ""

# Create results directory
RESULTS_DIR="results_$(date +%Y%m%d_%H%M%S)"
mkdir -p $RESULTS_DIR

echo "Collecting outputs to: $RESULTS_DIR/"
echo ""

# Collect all test outputs
echo "Downloading test outputs..."
scp scholten@falcon:~/bundle_verify_*.out $RESULTS_DIR/ 2>/dev/null
scp scholten@falcon:~/bundle_verify_*.err $RESULTS_DIR/ 2>/dev/null
scp scholten@falcon:~/toy_compile_*.out $RESULTS_DIR/ 2>/dev/null
scp scholten@falcon:~/toy_compile_*.err $RESULTS_DIR/ 2>/dev/null
scp scholten@falcon:~/bottleneck_*.out $RESULTS_DIR/ 2>/dev/null
scp scholten@falcon:~/bottleneck_*.err $RESULTS_DIR/ 2>/dev/null

echo ""
echo "Files collected:"
ls -la $RESULTS_DIR/
echo ""

# Analyze results
echo "=== Quick Analysis ==="
echo ""

# Check for successful package loads
echo "Package Loading Status:"
echo "-----------------------"
grep -h "✅" $RESULTS_DIR/*.out 2>/dev/null | sort -u
echo ""

# Check for failures
echo "Identified Failures:"
echo "--------------------"
grep -h "❌" $RESULTS_DIR/*.out 2>/dev/null | sort -u
echo ""

# Check for specific errors
echo "Error Messages:"
echo "---------------"
grep -h -i "error" $RESULTS_DIR/*.err 2>/dev/null | head -10
echo ""

# Look for path issues
echo "Path Configuration:"
echo "------------------"
grep -h "JULIA_DEPOT_PATH" $RESULTS_DIR/*.out 2>/dev/null | head -5
grep -h "JULIA_PROJECT" $RESULTS_DIR/*.out 2>/dev/null | head -5
echo ""

# Generate summary report
cat > $RESULTS_DIR/ANALYSIS_SUMMARY.md << 'EOF'
# Compilation Test Results Analysis
EOF

echo "Date: $(date)" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md

# Bundle verification results
if ls $RESULTS_DIR/bundle_verify_*.out 1> /dev/null 2>&1; then
    echo "## Bundle Verification Test" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    
    if grep -q "✅ Bundle verification PASSED" $RESULTS_DIR/bundle_verify_*.out 2>/dev/null; then
        echo "**Status**: ✅ PASSED" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    else
        echo "**Status**: ❌ FAILED" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    fi
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    
    echo "### Key Findings:" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    grep "JULIA_DEPOT_PATH=" $RESULTS_DIR/bundle_verify_*.out | head -1 >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    grep "Total packages:" $RESULTS_DIR/bundle_verify_*.out | head -1 >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

# Toy compilation results
if ls $RESULTS_DIR/toy_compile_*.out 1> /dev/null 2>&1; then
    echo "## Toy Package Compilation Test" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    
    if grep -q "✅ Package loaded successfully" $RESULTS_DIR/toy_compile_*.out 2>/dev/null; then
        echo "**Simple Package Loading**: ✅ SUCCESS" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    else
        echo "**Simple Package Loading**: ❌ FAILED" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    fi
    
    if grep -q "✅ Pkg loaded" $RESULTS_DIR/toy_compile_*.out 2>/dev/null; then
        echo "**Bundle Package Loading**: ✅ SUCCESS" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    else
        echo "**Bundle Package Loading**: ❌ FAILED" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    fi
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

# Bottleneck analysis results
if ls $RESULTS_DIR/bottleneck_*.out 1> /dev/null 2>&1; then
    echo "## Bottleneck Analysis" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    
    echo "### Package Loading Results:" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
    for pkg in "Pkg" "ForwardDiff" "StaticArrays" "TimerOutputs"; do
        if grep -q "✅ $pkg loaded successfully" $RESULTS_DIR/bottleneck_*.out 2>/dev/null; then
            echo "- $pkg: ✅ SUCCESS" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
        else
            echo "- $pkg: ❌ FAILED" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
        fi
    done
    echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

# Add recommendations
echo "## Recommendations" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md

if grep -q "Package not found in current path" $RESULTS_DIR/*.out 2>/dev/null; then
    echo "1. **Path Issue Detected**: Update JULIA_DEPOT_PATH to correct bundle location" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

if grep -q "No compiled cache for current Julia version" $RESULTS_DIR/*.out 2>/dev/null; then
    echo "2. **Version Mismatch**: Rebuild bundle with cluster Julia version" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

if grep -q "Package source NOT found" $RESULTS_DIR/*.out 2>/dev/null; then
    echo "3. **Missing Packages**: Bundle may be incomplete, rebuild required" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
fi

echo "" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
echo "---" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md
echo "Full outputs available in: $RESULTS_DIR/" >> $RESULTS_DIR/ANALYSIS_SUMMARY.md

# Display summary
echo "=== Analysis Summary ==="
cat $RESULTS_DIR/ANALYSIS_SUMMARY.md
echo ""

echo "Results saved to: $RESULTS_DIR/"
echo "Summary report: $RESULTS_DIR/ANALYSIS_SUMMARY.md"