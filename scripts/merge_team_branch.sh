#!/bin/bash
set -e

# Script to merge a team's branch into gamma (integration branch)
# Usage: ./scripts/merge_team_branch.sh [team_name]
# Example: ./scripts/merge_team_branch.sh alpha

TEAM_NAME="${1}"

if [ -z "$TEAM_NAME" ]; then
    echo "Usage: $0 [team_name]"
    echo "Available teams: alpha, beta, delta"
    exit 1
fi

# Validate team name
if [[ ! "$TEAM_NAME" =~ ^(alpha|beta|delta)$ ]]; then
    echo "Error: Invalid team name. Must be one of: alpha, beta, delta"
    exit 1
fi

# Get worktree paths dynamically
GAMMA_PATH=$(git worktree list | grep "\[gamma\]" | awk '{print $1}')
TEAM_PATH=$(git worktree list | grep "\[${TEAM_NAME}\]" | awk '{print $1}')

if [ -z "$GAMMA_PATH" ]; then
    echo "Error: Gamma worktree not found"
    exit 1
fi

if [ -z "$TEAM_PATH" ]; then
    echo "Error: ${TEAM_NAME} worktree not found"
    exit 1
fi

echo "🔄 Merging ${TEAM_NAME} branch into gamma..."
echo "Gamma path: $GAMMA_PATH"
echo "Team path: $TEAM_PATH"

# Switch to gamma worktree
cd "$GAMMA_PATH"

# Ensure we're on gamma branch
git checkout gamma

# Fetch latest changes
git fetch origin

# Ensure gamma is up to date
git pull origin gamma

# Switch to team worktree to get latest changes
cd "$TEAM_PATH"
git checkout "$TEAM_NAME"
git pull origin "$TEAM_NAME"

# Get the latest commit hash from team branch
TEAM_COMMIT=$(git rev-parse HEAD)

# Switch back to gamma
cd "$GAMMA_PATH"

# Merge team branch into gamma
echo "📝 Merging commit $TEAM_COMMIT from $TEAM_NAME into gamma"
git merge --no-ff "$TEAM_NAME" -m "Merge team $TEAM_NAME into gamma

Weekly integration merge from $TEAM_NAME team.
Commit: $TEAM_COMMIT

🤖 Generated merge via team coordination script"

# Run quality checks after merge
echo "🔍 Running quality checks after merge..."
mix format
mix credo --strict

# Check if tests pass
echo "🧪 Running tests..."
if mix test --warnings-as-errors; then
    echo "✅ All tests pass after merge"
else
    echo "❌ Tests failed after merge - manual intervention required"
    exit 1
fi

echo "✅ Successfully merged $TEAM_NAME into gamma"
echo "📋 Next steps:"
echo "  1. Review the merged changes"
echo "  2. Run ./scripts/rebase_gamma_to_teams.sh to update other teams"
echo "  3. Push gamma branch: git push origin gamma"