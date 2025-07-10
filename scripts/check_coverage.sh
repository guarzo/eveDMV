#!/bin/bash

# Script to check test coverage locally with ratcheting logic
# Usage: ./scripts/check_coverage.sh

set -e

echo "🧪 Running test coverage check..."

# Get baseline coverage
if [ -f coverage_baseline.txt ]; then
  BASELINE=$(cat coverage_baseline.txt)
else
  BASELINE=9.3  # Current baseline
  echo "No baseline found, using default: $BASELINE%"
fi

echo "📊 Baseline coverage: $BASELINE%"

# Run tests with coverage
echo "🔍 Running tests with coverage..."
export MIX_ENV=test
mix test --cover 2>&1 | tee coverage_output.txt

# Check if coverage meets threshold (following plan template)
COVERAGE=$(mix coveralls.json 2>/dev/null | jq -r '.coverage' 2>/dev/null || echo "0")
THRESHOLD=70

# Fallback to parsing from text output if JSON parsing fails
if [ "$COVERAGE" = "0" ] || [ "$COVERAGE" = "null" ]; then
  COVERAGE=$(grep '\[TOTAL\]' coverage_output.txt | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//' || echo "0")
fi

if [ -z "$COVERAGE" ] || [ "$COVERAGE" = "0" ]; then
  echo "❌ Could not parse coverage percentage"
  exit 1
fi

echo "📈 Current coverage: $COVERAGE%"

# Compare with baseline using bc for floating point comparison
if [ "$(echo "$COVERAGE < $BASELINE" | bc -l)" -eq 1 ]; then
  echo "❌ Coverage regression detected!"
  echo "   Current: $COVERAGE%"
  echo "   Baseline: $BASELINE%"
  echo "   Please add tests to maintain or improve coverage."
  exit 1
elif [ "$(echo "$COVERAGE > $BASELINE" | bc -l)" -eq 1 ]; then
  echo "✅ Coverage improved from $BASELINE% to $COVERAGE%"
  echo "   Would you like to update the baseline? (y/N)"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "$COVERAGE" > coverage_baseline.txt
    echo "📝 Baseline updated to $COVERAGE%"
  fi
else
  echo "✅ Coverage maintained at $COVERAGE%"
fi

# Show phase progress
echo ""
echo "🎯 Phase Progress:"
PHASE_1_TARGET=25.0
PHASE_2_TARGET=35.0  
PHASE_3_TARGET=40.0

if [ "$(echo "$COVERAGE >= $PHASE_3_TARGET" | bc -l)" -eq 1 ]; then
  echo "🎉 Phase 3 Complete: Feature Reliability ($COVERAGE% >= $PHASE_3_TARGET%)"
elif [ "$(echo "$COVERAGE >= $PHASE_2_TARGET" | bc -l)" -eq 1 ]; then
  echo "🚀 Phase 2 Complete: Core Business Logic ($COVERAGE% >= $PHASE_2_TARGET%)"
  echo "📋 Next: Phase 3 Target - $PHASE_3_TARGET%"
elif [ "$(echo "$COVERAGE >= $PHASE_1_TARGET" | bc -l)" -eq 1 ]; then
  echo "✅ Phase 1 Complete: Critical Security ($COVERAGE% >= $PHASE_1_TARGET%)"  
  echo "📋 Next: Phase 2 Target - $PHASE_2_TARGET%"
else
  PROGRESS=$(echo "scale=1; $COVERAGE / $PHASE_1_TARGET * 100" | bc -l)
  echo "📈 Phase 1 In Progress: $COVERAGE% / $PHASE_1_TARGET% (${PROGRESS}% complete)"
  echo "🎯 Focus: Authentication & Killmail Pipeline"
fi

echo ""
echo "🔍 Coverage report generated in: cover/"
echo "📄 Raw output saved to: coverage_output.txt"