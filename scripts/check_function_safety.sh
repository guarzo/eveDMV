#!/bin/bash
# check_function_safety.sh - Verify function is safe to remove

check_function_safety() {
  local MODULE=$1
  local FUNCTION=$2
  
  echo "🔍 DEPENDENCY SAFETY CHECK: $MODULE.$FUNCTION"
  
  # Check 1: Mix xref callers
  CALLERS=$(mix xref callers $MODULE.$FUNCTION 2>/dev/null | wc -l)
  if [ $CALLERS -gt 0 ]; then
    echo "❌ UNSAFE: Function has $CALLERS callers"
    mix xref callers $MODULE.$FUNCTION
    echo "CANNOT REMOVE: Function is in use"
    return 1
  fi
  
  # Check 2: Grep search across codebase
  MODULE_FILE=$(basename "$MODULE")
  GREP_MATCHES=$(grep -r "$FUNCTION" lib/ test/ --exclude="$MODULE_FILE" | wc -l)
  if [ $GREP_MATCHES -gt 0 ]; then
    echo "❌ UNSAFE: Found $GREP_MATCHES potential references"
    grep -r "$FUNCTION" lib/ test/ --exclude="$MODULE_FILE" | head -5
    echo "MANUAL REVIEW REQUIRED"
    return 1
  fi
  
  # Check 3: Verify function is actually private
  if grep -q "def $FUNCTION" "$MODULE.ex"; then
    echo "❌ UNSAFE: Public function - may have external callers"
    echo "CANNOT REMOVE: Public functions require manual analysis"
    return 1
  fi
  
  echo "✅ SAFE: No dependencies detected for private function $FUNCTION"
  return 0
}

# If called directly with arguments
if [ $# -eq 2 ]; then
  check_function_safety "$1" "$2"
fi