#!/bin/bash

# Simple script to fix Enum piping issues with validation - V2

set -e

echo "=== Simple Enum Pipe Fix V2 ==="
echo

# Record initial state
echo "Recording initial compilation state..."
mix compile 2>&1 > /tmp/compile_before.log || true
COMPILE_BEFORE_SUCCESS=$?
WARNINGS_BEFORE=$(grep -c "warning:" /tmp/compile_before.log || echo "0")
ERRORS_BEFORE=$(grep -c "error:" /tmp/compile_before.log || echo "0")
echo "Initial compilation: exit code=$COMPILE_BEFORE_SUCCESS, errors=$ERRORS_BEFORE, warnings=$WARNINGS_BEFORE"

# Get initial Credo count
echo "Getting initial Credo warnings count..."
CREDO_BEFORE=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "0")
echo "Initial Enum warnings: $CREDO_BEFORE"

# Show what will be fixed
echo
echo "Preview of changes:"
elixir scripts/fix_enum_pipes_v2.exs --dry-run 2>&1 | grep "Fixed" | head -20
TOTAL_TO_FIX=$(elixir scripts/fix_enum_pipes_v2.exs --dry-run 2>&1 | grep "Total fixes:" | awk '{print $3}')
echo "Total fixes to apply: $TOTAL_TO_FIX"

# Ask for confirmation
echo
read -p "Apply these fixes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create backup of files we'll modify
echo
echo "Creating backups..."
mkdir -p /tmp/enum_fix_backup_v2
elixir scripts/fix_enum_pipes_v2.exs --dry-run 2>&1 | grep "Fixed" | awk '{print $6}' | while read file; do
    if [ -f "$file" ]; then
        dir=$(dirname "$file")
        mkdir -p "/tmp/enum_fix_backup_v2/$dir"
        cp "$file" "/tmp/enum_fix_backup_v2/$file"
    fi
done

# Apply the fixes
echo
echo "Applying fixes..."
elixir scripts/fix_enum_pipes_v2.exs

# Validate compilation
echo
echo "Validating compilation..."
if mix compile 2>&1 > /tmp/compile_after.log; then
    COMPILE_AFTER_SUCCESS=0
else
    COMPILE_AFTER_SUCCESS=$?
fi
WARNINGS_AFTER=$(grep -c "warning:" /tmp/compile_after.log || echo "0")
ERRORS_AFTER=$(grep -c "error:" /tmp/compile_after.log || echo "0")

# Get new Credo count
CREDO_AFTER=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "0")

echo
echo "Results:"
echo "  Compilation: before=$COMPILE_BEFORE_SUCCESS, after=$COMPILE_AFTER_SUCCESS (0=success)"
echo "  Errors: before=$ERRORS_BEFORE, after=$ERRORS_AFTER"
echo "  Warnings: before=$WARNINGS_BEFORE, after=$WARNINGS_AFTER"
echo "  Enum warnings: before=$CREDO_BEFORE, after=$CREDO_AFTER"

# Check if we should revert
if [ $ERRORS_AFTER -gt $ERRORS_BEFORE ]; then
    echo
    echo "ERROR: New compilation errors introduced!"
    echo "Reverting all changes..."
    
    # Restore from backups
    cd /tmp/enum_fix_backup_v2
    find . -type f | while read file; do
        cp "$file" "/$file"
    done
    cd - > /dev/null
    
    echo "Changes reverted!"
    
    # Show what went wrong
    echo
    echo "New errors introduced:"
    diff -u /tmp/compile_before.log /tmp/compile_after.log | grep "^\+.*error:" | head -10
    
    exit 1
elif [ $COMPILE_AFTER_SUCCESS -ne 0 ] && [ $COMPILE_BEFORE_SUCCESS -eq 0 ]; then
    echo
    echo "ERROR: Compilation now fails!"
    echo "Reverting all changes..."
    
    # Restore from backups
    cd /tmp/enum_fix_backup_v2
    find . -type f | while read file; do
        cp "$file" "/$file"
    done
    cd - > /dev/null
    
    echo "Changes reverted!"
    exit 1
fi

echo
echo "SUCCESS! Fixes applied and compilation validated."
echo "Reduced Enum warnings by: $((CREDO_BEFORE - CREDO_AFTER))"

# Cleanup
rm -rf /tmp/enum_fix_backup_v2