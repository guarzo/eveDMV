#!/bin/bash

# Simple script to fix Enum piping issues with validation

set -e

echo "=== Simple Enum Pipe Fix ==="
echo

# Record initial state
echo "Recording initial compilation state..."
mix compile 2>&1 > /tmp/compile_before.log || true
COMPILE_BEFORE_SUCCESS=$?
WARNINGS_BEFORE=$(grep -c "warning:" /tmp/compile_before.log || echo "0")
echo "Initial compilation status: $COMPILE_BEFORE_SUCCESS (0=success)"
echo "Initial warnings: $WARNINGS_BEFORE"

# Get initial Credo count
echo "Getting initial Credo warnings count..."
CREDO_BEFORE=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "0")
echo "Initial Enum warnings: $CREDO_BEFORE"

# Create backup of files we'll modify
echo
echo "Creating backups..."
mkdir -p /tmp/enum_fix_backup
elixir scripts/fix_enum_pipes.exs --dry-run 2>&1 | grep "Fixed" | awk '{print $6}' | while read file; do
    if [ -f "$file" ]; then
        cp "$file" "/tmp/enum_fix_backup/$(basename $file).backup"
    fi
done

# Apply the fixes
echo
echo "Applying fixes..."
elixir scripts/fix_enum_pipes.exs

# Validate compilation
echo
echo "Validating compilation..."
if mix compile 2>&1 > /tmp/compile_after.log; then
    COMPILE_AFTER_SUCCESS=0
else
    COMPILE_AFTER_SUCCESS=$?
fi
WARNINGS_AFTER=$(grep -c "warning:" /tmp/compile_after.log || echo "0")

# Get new Credo count
CREDO_AFTER=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "0")

echo
echo "Results:"
echo "  Compilation before: $COMPILE_BEFORE_SUCCESS, after: $COMPILE_AFTER_SUCCESS (0=success)"
echo "  Warnings before: $WARNINGS_BEFORE, after: $WARNINGS_AFTER"
echo "  Enum warnings before: $CREDO_BEFORE, after: $CREDO_AFTER"

# Check if we should revert
if [ $COMPILE_AFTER_SUCCESS -ne 0 ] && [ $COMPILE_BEFORE_SUCCESS -eq 0 ]; then
    echo
    echo "ERROR: Compilation failed after fixes!"
    echo "Reverting changes..."
    
    # Restore from backups
    for backup in /tmp/enum_fix_backup/*.backup; do
        if [ -f "$backup" ]; then
            original=$(basename "$backup" .backup)
            find lib -name "$original" -exec cp "$backup" {} \;
        fi
    done
    
    echo "Changes reverted!"
    exit 1
elif [ $WARNINGS_AFTER -gt $((WARNINGS_BEFORE + 10)) ]; then
    echo
    echo "WARNING: Warnings increased significantly!"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        # Restore from backups
        for backup in /tmp/enum_fix_backup/*.backup; do
            if [ -f "$backup" ]; then
                original=$(basename "$backup" .backup)
                find lib -name "$original" -exec cp "$backup" {} \;
            fi
        done
        echo "Changes reverted!"
        exit 1
    fi
fi

echo
echo "SUCCESS! Fixes applied and compilation validated."
echo "Reduced Enum warnings by: $((CREDO_BEFORE - CREDO_AFTER))"

# Cleanup
rm -rf /tmp/enum_fix_backup