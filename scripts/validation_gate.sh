#!/bin/bash
# validation_gate.sh - MUST PASS before any commit

set -e  # Exit on any error

echo "🔍 SAFETY VALIDATION GATE - No exceptions allowed"

# Step 1: Check for compilation warnings (ZERO TOLERANCE)
echo "Step 1/6: Checking compilation warnings..."
WARNING_COUNT=$(mix compile 2>&1 | grep "warning:" | wc -l)
if [ $WARNING_COUNT -gt 0 ]; then
  echo "❌ CRITICAL FAILURE: $WARNING_COUNT compilation warnings detected"
  echo "MANDATORY FIX: Address these warnings immediately:"
  mix compile 2>&1 | grep -A2 "warning:"
  echo "ROLLBACK REQUIRED: git reset --hard HEAD~1"
  exit 1
fi
echo "✅ Step 1 passed: Zero compilation warnings"

# Step 2: Verify compilation succeeds (MANDATORY)
echo "Step 2/6: Verifying clean compilation..."
if ! mix compile > /dev/null 2>&1; then
  echo "❌ CRITICAL FAILURE: Compilation errors detected"
  echo "IMMEDIATE ACTION: Fix compilation or rollback"
  mix compile
  exit 1
fi
echo "✅ Step 2 passed: Clean compilation"

# Step 3: Check dialyzer PLT integrity (MANDATORY)
echo "Step 3/6: Validating dialyzer PLT..."
if ! mix dialyzer --plt-check > /dev/null 2>&1; then
  echo "❌ CRITICAL FAILURE: Dialyzer PLT corruption detected"
  echo "IMMEDIATE ACTION: Rebuild PLT or rollback changes"
  exit 1
fi
echo "✅ Step 3 passed: Dialyzer PLT healthy"

# Step 4: Run core test suite (MANDATORY)
echo "Step 4/6: Running core functionality tests..."
if ! mix test --only unit > /dev/null 2>&1; then
  echo "❌ CRITICAL FAILURE: Core tests failing"
  echo "IMMEDIATE ACTION: Fix failing tests or rollback"
  mix test --only unit
  exit 1
fi
echo "✅ Step 4 passed: Core tests passing"

# Step 5: Check dialyzer error count (REGRESSION DETECTION)
echo "Step 5/6: Checking dialyzer error count..."
CURRENT_ERRORS=$(mix dialyzer --format short 2>/dev/null | grep "Total errors" | grep -o '[0-9]*' | head -1)
BASELINE_FILE="/workspace/.workstream_coordination/baseline_errors.txt"

if [ -f "$BASELINE_FILE" ]; then
  BASELINE_ERRORS=$(cat "$BASELINE_FILE")
  if [ "$CURRENT_ERRORS" -gt "$BASELINE_ERRORS" ]; then
    echo "❌ CRITICAL FAILURE: Dialyzer errors INCREASED"
    echo "   Baseline: $BASELINE_ERRORS errors"
    echo "   Current:  $CURRENT_ERRORS errors"
    echo "   Increase: $((CURRENT_ERRORS - BASELINE_ERRORS)) errors"
    echo "MANDATORY ROLLBACK: git reset --hard HEAD~1"
    exit 1
  fi
fi
echo "✅ Step 5 passed: No dialyzer regression"

# Step 6: Update baseline if improvement detected
echo "Step 6/6: Recording progress..."
echo "$CURRENT_ERRORS" > "$BASELINE_FILE"
echo "✅ All validation gates passed - SAFE TO COMMIT"
echo "📊 Current error count: $CURRENT_ERRORS"