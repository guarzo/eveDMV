#!/bin/bash
set -e

# Script to rebase gamma changes to all team branches
# Usage: ./scripts/rebase_gamma_to_teams.sh
# This updates all team branches with the latest gamma integration

echo "🔄 Rebasing gamma changes to all team branches..."

# Get gamma worktree path
GAMMA_PATH=$(git worktree list | grep "\[gamma\]" | awk '{print $1}')

if [ -z "$GAMMA_PATH" ]; then
    echo "Error: Gamma worktree not found"
    exit 1
fi

# Get all team worktrees dynamically (exclude main branches)
TEAM_WORKTREES=$(git worktree list | grep -E "\[(alpha|beta|delta)\]" | awk '{print $1 ":" $NF}' | sed 's/\[//g' | sed 's/\]//g')

if [ -z "$TEAM_WORKTREES" ]; then
    echo "Warning: No team worktrees found"
    exit 0
fi

# Ensure gamma is up to date
cd "$GAMMA_PATH"
git checkout gamma
git fetch origin
git pull origin gamma

GAMMA_COMMIT=$(git rev-parse HEAD)
echo "📍 Rebasing from gamma commit: $GAMMA_COMMIT"

# Rebase each team branch
echo "$TEAM_WORKTREES" | while IFS=':' read -r WORKTREE_PATH BRANCH_NAME; do
    echo ""
    echo "🔄 Processing team: $BRANCH_NAME"
    echo "   Path: $WORKTREE_PATH"
    
    # Switch to team worktree
    cd "$WORKTREE_PATH"
    
    # Ensure we're on the correct branch
    git checkout "$BRANCH_NAME"
    
    # Fetch latest changes
    git fetch origin
    
    # Check if branch has uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠️  Warning: $BRANCH_NAME has uncommitted changes - skipping rebase"
        echo "   Please commit or stash changes in $WORKTREE_PATH"
        continue
    fi
    
    # Get current commit before rebase
    BEFORE_COMMIT=$(git rev-parse HEAD)
    
    # Perform rebase
    echo "📝 Rebasing $BRANCH_NAME onto gamma..."
    if git rebase gamma; then
        AFTER_COMMIT=$(git rev-parse HEAD)
        
        if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
            echo "✅ Successfully rebased $BRANCH_NAME"
            echo "   Before: $BEFORE_COMMIT"
            echo "   After:  $AFTER_COMMIT"
            
            # Run quality checks after rebase
            echo "🔍 Running quick quality check..."
            if command -v mix >/dev/null 2>&1; then
                mix format --check-formatted || {
                    echo "⚠️  Formatting issues detected in $BRANCH_NAME - please run 'mix format'"
                }
            fi
        else
            echo "ℹ️  $BRANCH_NAME already up to date with gamma"
        fi
    else
        echo "❌ Rebase failed for $BRANCH_NAME - manual intervention required"
        echo "   Path: $WORKTREE_PATH"
        echo "   Please resolve conflicts manually and run 'git rebase --continue'"
        
        # Abort the failed rebase
        git rebase --abort
        continue
    fi
done

echo ""
echo "✅ Rebase operation completed"
echo "📋 Summary:"
git worktree list
echo ""
echo "📝 Next steps for each team:"
echo "  1. Review rebased changes in their worktree"
echo "  2. Run quality checks: mix format && mix credo && mix test"
echo "  3. Push updated branches: git push origin [branch-name]"
echo ""
echo "⚠️  Note: Teams should verify their changes still work after rebase"