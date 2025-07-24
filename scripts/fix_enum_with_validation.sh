#!/bin/bash

# Script to fix Enum piping issues with validation and rollback

set -e

echo "=== Enum Pipe Fix with Validation ==="
echo

# Create backup branch
BACKUP_BRANCH="backup-enum-fixes-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup on branch: $BACKUP_BRANCH"
git checkout -b "$BACKUP_BRANCH" 2>/dev/null || true

# Record initial state
echo "Recording initial compilation state..."
mix compile --warnings-as-errors 2>&1 > /tmp/compile_before.log || true
ERRORS_BEFORE=$(grep -E "(error:|Error:|warning:)" /tmp/compile_before.log | wc -l || echo "0")
echo "Initial compilation issues: $ERRORS_BEFORE"

# Get initial Credo count
echo "Getting initial Credo warnings count..."
CREDO_BEFORE=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "0")
echo "Initial Enum warnings: $CREDO_BEFORE"

# Run dry run first
echo
echo "Running dry run to preview changes..."
elixir scripts/fix_enum_pipes.exs --dry-run

# Ask for confirmation
echo
read -p "Do you want to apply these changes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Switching back to original branch..."
    git checkout -
    git branch -D "$BACKUP_BRANCH"
    exit 1
fi

# Apply the fixes
echo
echo "Applying fixes..."
elixir scripts/fix_enum_pipes.exs

# Check if any files were modified
if ! git diff --quiet; then
    echo "Files were modified. Validating changes..."
    
    # Try to compile
    echo "Compiling with fixes..."
    if mix compile --warnings-as-errors 2>&1 > /tmp/compile_after.log; then
        COMPILE_SUCCESS=true
        ERRORS_AFTER=0
    else
        COMPILE_SUCCESS=false
        ERRORS_AFTER=$(grep -E "(error:|Error:|warning:)" /tmp/compile_after.log | wc -l || echo "999")
    fi
    
    echo "Compilation after fixes: $ERRORS_AFTER issues"
    
    # Get new Credo count
    CREDO_AFTER=$(mix credo --strict 2>&1 | grep -c "There should be no unused return values for Enum functions" || echo "999")
    echo "Enum warnings after fixes: $CREDO_AFTER"
    
    # Decide whether to keep or revert
    if [[ "$COMPILE_SUCCESS" == "false" ]] || [[ $ERRORS_AFTER -gt $ERRORS_BEFORE ]]; then
        echo
        echo "ERROR: Compilation failed or got worse after fixes!"
        echo "Reverting all changes..."
        git checkout -- .
        echo "Changes reverted. Original state restored."
        exit 1
    else
        echo
        echo "SUCCESS: Compilation still works!"
        echo "  Compilation issues: $ERRORS_BEFORE -> $ERRORS_AFTER"
        echo "  Enum warnings: $CREDO_BEFORE -> $CREDO_AFTER"
        
        # Show what changed
        echo
        echo "Modified files:"
        git diff --name-only
        
        # Commit the changes
        echo
        read -p "Do you want to commit these changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add -A
            git commit -m "fix: automatically fix missing Enum pipe operators

- Fixed $((CREDO_BEFORE - CREDO_AFTER)) Enum piping warnings
- Used automated script to add missing |> operators
- All fixes validated to ensure compilation still works"
            echo "Changes committed!"
        else
            echo "Changes not committed. You can review and commit manually."
        fi
    fi
else
    echo "No files were modified."
fi

# Switch back to original branch
echo
echo "Switching back to original branch..."
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git checkout -

# Ask about deleting backup branch
if [[ "$ORIGINAL_BRANCH" != "$BACKUP_BRANCH" ]]; then
    read -p "Delete backup branch $BACKUP_BRANCH? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git branch -D "$BACKUP_BRANCH"
        echo "Backup branch deleted."
    else
        echo "Backup branch kept: $BACKUP_BRANCH"
    fi
fi

echo
echo "Done!"