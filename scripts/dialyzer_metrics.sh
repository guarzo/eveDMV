#!/bin/bash
# Script to generate detailed dialyzer metrics for tracking progress
# Part of Workstream E: Testing & Validation

set -e

echo "📊 Dialyzer Metrics Report - $(date)"
echo "=================================="

# Run dialyzer and capture output
echo "Running dialyzer analysis..."
mix dialyzer 2>&1 | tee dialyzer_full_output.txt || true

# Create dialyzer.txt for the regression test
cp dialyzer_full_output.txt dialyzer.txt

# Extract key metrics
TOTAL_ERRORS=$(grep "Total errors:" dialyzer_full_output.txt | grep -oE "Total errors: [0-9]+" | grep -oE "[0-9]+")
SKIPPED_ERRORS=$(grep "Total errors:" dialyzer_full_output.txt | grep -oE "Skipped: [0-9]+" | grep -oE "[0-9]+")
UNNECESSARY_SKIPS=$(grep "Total errors:" dialyzer_full_output.txt | grep -oE "Unnecessary Skips: [0-9]+" | grep -oE "[0-9]+")

echo ""
echo "📈 Summary Metrics:"
echo "  - Total Errors: $TOTAL_ERRORS"
echo "  - Skipped Errors: $SKIPPED_ERRORS"
echo "  - Unnecessary Skips: $UNNECESSARY_SKIPS"
echo "  - Net Errors: $((TOTAL_ERRORS - SKIPPED_ERRORS))"

# Categorize errors by type
echo ""
echo "📋 Error Categories:"
grep -E "^lib/.*:[0-9]+:" dialyzer_full_output.txt | grep -oE ":[a-z_]+" | sort | uniq -c | sort -nr | head -20

# Find modules with most errors
echo ""
echo "🔥 Top 10 Modules with Most Errors:"
grep -E "^lib/.*:[0-9]+:" dialyzer_full_output.txt | cut -d: -f1 | sort | uniq -c | sort -nr | head -10

# Check for unused ignore patterns
echo ""
echo "🚮 Unused Ignore Patterns:"
if grep -A 20 "Unused filters:" dialyzer_full_output.txt | grep -v "Unused filters:" | grep -v "unused filters present" | grep -E "~r"; then
    echo "Found unused patterns - these should be removed from .dialyzer_ignore.exs"
else
    echo "No unused patterns found ✓"
fi

# Generate JSON metrics for CI tracking
cat > dialyzer_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_errors": $TOTAL_ERRORS,
  "skipped_errors": $SKIPPED_ERRORS,
  "unnecessary_skips": $UNNECESSARY_SKIPS,
  "net_errors": $((TOTAL_ERRORS - SKIPPED_ERRORS)),
  "target_errors": 200,
  "baseline_errors": 1916
}
EOF

echo ""
echo "✅ Metrics saved to dialyzer_metrics.json"

# Progress tracking
BASELINE=1916
TARGET=200
PROGRESS=$(echo "scale=2; ($BASELINE - $TOTAL_ERRORS) / ($BASELINE - $TARGET) * 100" | bc)

echo ""
echo "📊 Progress Toward Target:"
echo "  Baseline: $BASELINE errors"
echo "  Current:  $TOTAL_ERRORS errors"
echo "  Target:   $TARGET errors"
echo "  Progress: ${PROGRESS}% complete"

# Cleanup
rm -f dialyzer_full_output.txt