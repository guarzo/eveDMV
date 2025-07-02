#!/bin/bash
set -e

# Script to set up team worktrees for the first time
# Usage: ./scripts/setup_team_worktrees.sh

BASE_DIR="$(dirname "$(pwd)")"
TEAMS=("alpha" "beta" "gamma" "delta")

echo "🏗️  Setting up team worktrees..."
echo "Base directory: $BASE_DIR"

for TEAM in "${TEAMS[@]}"; do
    WORKTREE_PATH="$BASE_DIR/$TEAM"
    
    if [ -d "$WORKTREE_PATH" ]; then
        echo "⚠️  Worktree already exists: $WORKTREE_PATH"
        continue
    fi
    
    echo "📁 Creating worktree for team $TEAM at $WORKTREE_PATH"
    
    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$TEAM"; then
        echo "🌿 Creating branch: $TEAM"
        git branch "$TEAM"
    fi
    
    # Create worktree
    git worktree add "$WORKTREE_PATH" "$TEAM"
    
    echo "✅ Created worktree for $TEAM"
done

echo ""
echo "✅ All team worktrees set up successfully"
echo "📋 Worktree list:"
git worktree list
echo ""
echo "📝 Teams can now work in their respective directories:"
for TEAM in "${TEAMS[@]}"; do
    echo "  Team $TEAM: $BASE_DIR/$TEAM"
done