#!/bin/bash
# Cross-dependency checker for dialyzer sprint
# Checks if a function is used by other modules before removal

MODULE=$1
FUNCTION=$2

if [ -z "$MODULE" ] || [ -z "$FUNCTION" ]; then
    echo "Usage: $0 MODULE FUNCTION"
    echo "Example: $0 EveDmv.Platform.Cache.StaticDataCache get_ship_info"
    exit 1
fi

echo "=== Checking dependencies for $MODULE.$FUNCTION ==="
echo ""

# Check for callers using mix xref
echo "1. Checking mix xref callers..."
mix xref callers "$MODULE.$FUNCTION" 2>/dev/null || echo "No xref data available"

echo ""
echo "2. Searching for direct function calls..."
# Search for function calls in all .ex files
grep -r "\b$FUNCTION(" lib/ test/ --include="*.ex" --include="*.exs" | grep -v "def.*$FUNCTION" | head -20

echo ""
echo "3. Searching for module references..."
# Search for the module being referenced
MODULE_ALIAS=$(echo "$MODULE" | awk -F'.' '{print $NF}')
grep -r "$MODULE_ALIAS\.$FUNCTION" lib/ test/ --include="*.ex" --include="*.exs" | head -10

echo ""
echo "4. Checking if function is exported..."
# Check if the function is public or private
FILE_PATH=$(find lib/ -name "*.ex" -exec grep -l "defmodule $MODULE" {} \; | head -1)
if [ -n "$FILE_PATH" ]; then
    grep -n "def $FUNCTION\|defp $FUNCTION" "$FILE_PATH" | head -5
fi

echo ""
echo "=== Dependency check complete ==="