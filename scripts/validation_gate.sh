#!/bin/bash
# Validation Gate Script for Dialyzer Sprint
# Ensures zero compilation warnings and tracks dialyzer error reduction

set -e

echo "=== Dialyzer Sprint Validation Gate ==="
echo "Running at: $(date)"
echo ""

# Check for compilation warnings
echo "1. Checking compilation warnings..."
WARNING_OUTPUT=$(mix compile 2>&1 | grep "warning:" || true)
WARNING_COUNT=$(echo "$WARNING_OUTPUT" | grep -c "warning:" || echo "0")

if [ "$WARNING_COUNT" -gt 0 ]; then
    echo "❌ VALIDATION FAILED: $WARNING_COUNT compilation warnings found"
    echo ""
    echo "Warnings found:"
    echo "$WARNING_OUTPUT"
    exit 1
fi

# Ensure clean compilation
echo "2. Ensuring clean compilation..."
if ! mix compile > /dev/null 2>&1; then
    echo "❌ VALIDATION FAILED: Compilation errors found"
    exit 1
fi

echo "✅ Zero warnings, clean compilation"

# Check dialyzer errors if requested
if [ "$1" == "--check-dialyzer" ]; then
    echo ""
    echo "3. Checking dialyzer errors..."
    
    # Run dialyzer and capture output
    mix dialyzer --format short > dialyzer_output.txt 2>&1 || true
    
    # Count errors
    ERROR_COUNT=$(grep -c "Total errors:" dialyzer_output.txt || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        TOTAL_ERRORS=$(grep "Total errors:" dialyzer_output.txt | sed 's/Total errors: //')
        echo "📊 Current dialyzer errors: $TOTAL_ERRORS"
        
        # Check against baseline
        BASELINE=1840
        if [ "$TOTAL_ERRORS" -le "$BASELINE" ]; then
            REDUCTION=$((BASELINE - TOTAL_ERRORS))
            PERCENTAGE=$((REDUCTION * 100 / BASELINE))
            echo "✅ Error reduction: $REDUCTION errors ($PERCENTAGE% reduction from baseline)"
        else
            echo "⚠️  Errors above baseline of $BASELINE"
        fi
    else
        echo "⚠️  Could not determine dialyzer error count"
    fi
    
    rm -f dialyzer_output.txt
fi

echo ""
echo "=== Validation Complete ==="